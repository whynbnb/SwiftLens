import Foundation

// MARK: - 子 bundle 扫描

/// 扫描 .app 包内嵌的子 bundle（Frameworks / PlugIns / XPCServices / Helpers / Library/LoginItems）。
struct SubBundle: Identifiable {
    let id = UUID()
    let kind: Kind
    let relativePath: String        // 相对父 .app 路径
    let bundleIdentifier: String?
    let bundleVersion: String?
    let executableName: String?
    let signatureState: CodeSignInfo.SignedState
    let signatureType: String?       // "adhoc" / "valid" 等
    let runtimeVersion: String?
    let note: String?                // 比如签名失败原因

    enum Kind: String {
        case framework = "Framework"
        case app       = "Helper App"
        case xpc       = "XPC"
        case kext      = "Kernel Extension"
        case plugin    = "Plug-in"
        case loginItem = "Login Item"
        case other     = "Bundle"
    }
}

struct SubBundleScanResult {
    let subBundles: [SubBundle]
    let totalSize: UInt64
}

enum SubBundleScanner {
    static func scan(parent: URL) -> SubBundleScanResult {
        let contents = parent.appendingPathComponent("Contents")

        let directories: [(URL, SubBundle.Kind)] = [
            (contents.appendingPathComponent("Frameworks"), .framework),
            (contents.appendingPathComponent("EmbeddedFrameworks"), .framework),
            (contents.appendingPathComponent("PlugIns"), .plugin),
            (contents.appendingPathComponent("XPCServices"), .xpc),
            (contents.appendingPathComponent("Helpers"), .app),
            (contents.appendingPathComponent("Library/LoginItems"), .loginItem)
        ]

        var out: [SubBundle] = []
        var totalSize: UInt64 = 0

        for (dir, defaultKind) in directories {
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { continue }
            for name in entries.sorted() {
                let url = dir.appendingPathComponent(name)
                guard isBundle(at: url) else { continue }
                let kind = inferKind(at: url, default: defaultKind)
                out.append(parseSubBundle(at: url, kind: kind, parent: parent))
                totalSize += directorySize(at: url)
            }
        }

        // 按类型再路径排序，便于浏览
        out.sort { lhs, rhs in
            (lhs.kind.rawValue, lhs.relativePath) < (rhs.kind.rawValue, rhs.relativePath)
        }
        return SubBundleScanResult(subBundles: out, totalSize: totalSize)
    }

    // MARK: Helpers
    /// 在多种典型 bundle 布局下寻找 Info.plist
    static func findInfoPlist(at url: URL) -> URL? {
        let candidates = [
            url.appendingPathComponent("Contents/Info.plist"),                  // .app / kext / plugin
            url.appendingPathComponent("Info.plist"),                           // 主包退化布局
            url.appendingPathComponent("Versions/Current/Resources/Info.plist"),// framework
            url.appendingPathComponent("Resources/Info.plist")
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c.path) { return c }
        }
        // 找不到 Current, 试 Versions/<第一个> / Resources
        if let versions = try? FileManager.default.contentsOfDirectory(
            atPath: url.appendingPathComponent("Versions").path
        ) {
            for v in versions {
                let c = url.appendingPathComponent("Versions/\(v)/Resources/Info.plist")
                if FileManager.default.fileExists(atPath: c.path) { return c }
            }
        }
        return nil
    }

    private static func isBundle(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        return findInfoPlist(at: url) != nil
    }

    private static func inferKind(at url: URL, default fallback: SubBundle.Kind) -> SubBundle.Kind {
        switch url.pathExtension {
        case "framework": return .framework
        case "app":       return .app
        case "xpc":       return .xpc
        case "kext":      return .kext
        case "plugin", "bundle": return .plugin
        default:          return fallback
        }
    }

    private static func parseSubBundle(at url: URL, kind: SubBundle.Kind, parent: URL) -> SubBundle {
        let relPath = url.path.replacingOccurrences(of: parent.path + "/", with: "")
        // 处理 framework 的非标准 Info.plist 布局
        let plist: [String: Any]
        if let plistURL = findInfoPlist(at: url),
           let data = try? Data(contentsOf: plistURL),
           let parsed = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            plist = parsed
        } else {
            plist = [:]
        }
        func pull(_ key: String) -> String? {
            if let s = plist[key] as? String { return s }
            if let v = plist[key] { return InfoPlistParser.describe(v) }
            return nil
        }
        let bid  = pull("CFBundleIdentifier") ?? pull("CFBundleName")
        let ver  = pull("CFBundleShortVersionString") ?? pull("CFBundleVersion")
        let exec = pull("CFBundleExecutable")

        // 轻量签名检查 —— 使用 Security 框架 (沙盒兼容)
        let (state, sigType, runtime) = quickSign(at: url)

        return SubBundle(
            kind: kind,
            relativePath: relPath,
            bundleIdentifier: bid,
            bundleVersion: ver,
            executableName: exec,
            signatureState: state,
            signatureType: sigType,
            runtimeVersion: runtime,
            note: nil
        )
    }

    /// 沙盒兼容的轻量签名检查: SecStaticCode + SecCodeCopySigningInformation
    private static func quickSign(at url: URL) -> (CodeSignInfo.SignedState, String?, String?) {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            url as CFURL,
            SecCSFlags(rawValue: 0),
            &staticCode
        )
        guard createStatus == errSecSuccess, let code = staticCode else {
            return (.unknown, nil, nil)
        }
        var infoDict: CFDictionary?
        // 仅 kSecCSSigningInformation; 附加 kSecCSEntitlements 会导致调用失败
        let signStatus = SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &infoDict
        )
        guard signStatus == errSecSuccess, let dict = infoDict as? [String: Any] else {
            if signStatus == errSecCSUnsigned { return (.unsigned, nil, nil) }
            return (.unknown, nil, nil)
        }
        let flags = (dict["flags"] as? NSNumber)?.uint32Value ?? 0
        let isAdhoc = flags & 0x2 != 0   // CS_ADHOC
        let isRuntime = flags & 0x10000 != 0  // CS_RUNTIME
        let state: CodeSignInfo.SignedState = isAdhoc ? .adhoc : .signed
        let sigType: String? = isAdhoc ? "adhoc" : "signed"
        let runtime: String? = isRuntime ? "Hardened Runtime" : nil
        return (state, sigType, runtime)
    }

    private static func directorySize(at url: URL) -> UInt64 {
        var total: UInt64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: []
        ) else { return 0 }
        for case let fileURL as URL in enumerator {
            if let v = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let s = v.fileSize {
                total += UInt64(s)
            }
        }
        return total
    }
}