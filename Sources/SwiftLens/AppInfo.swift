import Foundation
import AppKit

// MARK: - AppInfo 模型

/// Contents/Library/LaunchAgents 或 LaunchDaemons 中的一项。
struct LaunchAgentItem: Identifiable {
    var id: String { relativePath }
    let relativePath: String
    let label: String
}

/// 顶层目录体积构成（Contents/MacOS、Frameworks、Resources…）。
struct SizeBreakdownItem: Identifiable {
    var id: String { name }
    let name: String
    let size: UInt64
}

/// Info.plist 结构健康检查。
struct InfoPlistHealth {
    let path: String?
    let format: String?
    let missingKeys: [String]
    let hasExecutable: Bool
    let hasCodeSignature: Bool

    var isOK: Bool {
        path != nil && hasExecutable && missingKeys.isEmpty
    }
}

/// 收集一个 .app bundle 的完整信息。
struct AppInfo {
    let bundleURL: URL

    // 基本信息
    let displayName: String?
    let bundleName: String?
    let bundleIdentifier: String?
    let bundleShortVersion: String?     // CFBundleShortVersionString
    let bundleVersion: String?          // CFBundleVersion
    let executableName: String?
    let executablePath: String?
    let bundlePackageType: String?
    let infoDictionaryVersion: String?
    let developmentRegion: String?

    // 运行环境
    /// 通用最低系统版本: 优先 LSMinimumSystemVersion (macOS), 回退 MinimumOSVersion (iOS/Catalyst)
    let minimumOSVersion: String?
    let lsMinimumSystemVersion: String?
    /// iOS / Catalyst 移植包使用的最低系统版本键
    let minimumOSVersionIOS: String?
    let applicationCategoryType: String?
    let requiresAquaSystemAppearance: Bool?
    let highResolutionCapable: Bool?
    let canAnimateAlpha: Bool?
    let supportsHighResolutionDisplays: Bool?
    let uses24HourClock: Bool?
    /// LSMinimumSystemVersionByArchitecture: { "arm64": "11.0", "x86_64": "10.15" }
    let lsMinimumSystemVersionByArchitecture: [String: String]

    // 链接 / 部署
    let sdkVersion: String?   // DTSDKName
    let platformName: String?
    let platformVersion: String?    // DTPlatformVersion
    let sdkBuild: String?
    let platformBuild: String?
    let xcodeVersion: String?       // DTXcode
    let xcodeBuild: String?         // DTXcodeBuild
    let buildMachineOSBuild: String? // BuildMachineOSBuild
    let dtCompiler: String?         // DTCompiler

    // 其它 Info.plist 文本性元数据
    let principalClass: String?    // NSPrincipalClass
    let humanReadableCopyright: String?  // NSHumanReadableCopyright
    let longVersionString: String?  // CFBundleLongVersionString
    let getInfoString: String?     // CFBundleGetInfoString
    let bundleSignature: String?    // CFBundleSignature
    let supportedPlatforms: [String]  // CFBundleSupportedPlatforms

    // 其它 Info.plist 布尔/字典
    let supportsAutomaticGraphicsSwitching: Bool?
    let quitAlwaysKeepsWindows: Bool?
    let prefersDisplaySafeAreaCompatibilityMode: Bool?
    let csResourcesFileMapped: Bool?
    let lsEnvironment: [String: String]
    let appTransportSecurity: [String: Any]?   // NSAppTransportSecurity
    let electronAsarIntegrity: [String: Any]?   // ElectronAsarIntegrity

    // 文档 / URL
    let documentTypes: [[String: Any]]
    let urlSchemes: [String]
    let exportedTypeIdentifiers: [[String: Any]]
    let importedTypeIdentifiers: [[String: Any]]
    let services: [[String: Any]]

    // 权限 / 沙盒
    let lsUIElement: Bool?                 // 代理应用 (无 Dock 图标 / 无菜单栏)
    let lsBackgroundOnly: Bool?            // 仅后台运行
    let privacyEntries: [PrivacyEntry]   // NS***UsageDescription
    let isIOSPort: Bool                    // 是否带 iOS-only Info.plist 键

    // 文件系统
    let fileSize: UInt64
    let sizeBreakdown: [SizeBreakdownItem]
    let bundleTree: BundleTree
    let modificationDate: Date?
    let creationDate: Date?
    let permissions: String?

    // Info.plist 全部键值
    let rawInfoPlist: [String: Any]
    let flatRows: [(String, String)]
    let infoPlistHealth: InfoPlistHealth

    // 扩展属性 / 隔离
    let quarantine: QuarantineInfo?
    let extendedXattrs: ExtendedXattrInfo

    // 代码签名
    let codeSign: CodeSignInfo

    // 架构
    let architectures: [ArchitectureReader.ArchInfo]

    // Mach-O 依赖（LC_LOAD_DYLIB / LC_RPATH 诊断）
    let dependencies: DependencyInfo?

    // 子 bundle
    let subBundles: [SubBundle]
    let subBundlesTotalSize: UInt64
    let launchAgents: [LaunchAgentItem]

    // 其它高价值键 (Sparkle / AppleScript / iCloud / Notifications / 开关)
    let extra: ExtraInfo

    // 隐私清单 / App Store 收据
    let privacyManifests: [PrivacyManifest]
    let hasMASReceipt: Bool

    // 图标
    let icon: NSImage?
}

enum AppInfoLoader {

    static func load(url: URL) -> AppInfo {
        let rawPlist = InfoPlistParser.parse(at: url) ?? [:]
        let rows = InfoPlistParser.flatten(rawPlist)

        func str(_ key: String) -> String? {
            if let v = rawPlist[key] as? String { return v }
            return rawPlist[key].map { InfoPlistParser.describe($0) }
        }
        func dict(_ key: String) -> [[String: Any]] {
            (rawPlist[key] as? [[String: Any]]) ?? (rawPlist[key] as? [String: Any]).map { [$0] } ?? []
        }

        let execName = str("CFBundleExecutable").flatMap {
            $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0
        }
        let execPath: String? = {
            if let name = execName {
                // 标准 macOS: Contents/MacOS/<exec>
                let stdPath = url.appendingPathComponent("Contents/MacOS/\(name)").path
                if FileManager.default.fileExists(atPath: stdPath) { return stdPath }
                // iOS Wrapper: Wrapper/<name>.app/<exec>
                let wrapperDir = url.appendingPathComponent("Wrapper")
                if let entries = try? FileManager.default.contentsOfDirectory(atPath: wrapperDir.path) {
                    for appDir in entries where appDir.hasSuffix(".app") {
                        let iosPath = wrapperDir.appendingPathComponent("\(appDir)/\(name)").path
                        if FileManager.default.fileExists(atPath: iosPath) { return iosPath }
                    }
                }
            }
            // 部分应用 (如 DB Browser for SQLite) 的 CFBundleExecutable 为空,
            // 回退到 Contents/MacOS 下第一个非目录文件。
            let macosDir = url.appendingPathComponent("Contents/MacOS")
            if let entries = try? FileManager.default.contentsOfDirectory(atPath: macosDir.path) {
                for name in entries.sorted() {
                    var isDir: ObjCBool = false
                    let p = macosDir.appendingPathComponent(name).path
                    if FileManager.default.fileExists(atPath: p, isDirectory: &isDir), !isDir.boolValue {
                        return p
                    }
                }
            }
            return nil
        }()

        // 文件系统属性
        var modDate: Date?
        var creationDate: Date?
        var perms: String?
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            modDate = attrs[.modificationDate] as? Date
            creationDate = attrs[.creationDate] as? Date
            if let posix = attrs[.posixPermissions] as? NSNumber {
                perms = String(format: "%o", posix.intValue)
            }
        }
        // bundle 是目录：一次遍历同时得到总体积、顶级目录构成与限量文件树
        let treeResult = BundleTreeReader.read(bundleURL: url, executableName: execName)
        let fileSize = treeResult.totalSize
        let sizeBreakdown = treeResult.breakdown

        // URL Schemes
        var schemes: [String] = []
        for cf in dict("CFBundleURLTypes") {
            if let s = cf["CFBundleURLSchemes"] as? [String] {
                schemes.append(contentsOf: s)
            }
        }

        // CFBundleSupportedPlatforms
        let supportedPlatforms: [String] = (rawPlist["CFBundleSupportedPlatforms"] as? [String]) ?? []

        // LSEnvironment -> [String: String]
        var lsEnv: [String: String] = [:]
        if let env = rawPlist["LSEnvironment"] as? [String: Any] {
            for (k, v) in env {
                lsEnv[k] = (v as? String) ?? InfoPlistParser.describe(v)
            }
        }

        // 子 bundle 扫描
        let subResult = SubBundleScanner.scan(parent: url)

        // 隐私清单 / App Store 收据
        let privacyManifests = PrivacyManifestReader.read(bundleURL: url, subBundles: subResult.subBundles)
        let hasMASReceipt = PrivacyManifestReader.hasMASReceipt(bundleURL: url)

        // LaunchAgents / LaunchDaemons
        let launchAgents = scanLaunchAgents(at: url)

        // 隐私权限条目
        let privacyEntries = PrivacyReader.parse(from: rawPlist)

        // 扩展属性全列表
        let extendedXattrs = ExtendedXattrReader.read(for: url)

        // LSUIElement / LSBackgroundOnly
        let lsUIElement = rawPlist["LSUIElement"] as? Bool
        let lsBackgroundOnly = rawPlist["LSBackgroundOnly"] as? Bool

        // iOS 移植包特征：含 UIDeviceFamily / UILaunchStoryboardName / UIRequiresFullScreen 等
        let isIOSPort = ["UIDeviceFamily",
                         "UILaunchStoryboardName",
                         "UIRequiresFullScreen",
                         "UISupportedInterfaceOrientations",
                         "UIStatusBarStyle"]
            .contains { rawPlist[$0] != nil }

        // 图标 — 优先从 Info.plist 声明的图标文件加载, 回退到 NSWorkspace
        // CFBundleIcons 是字典 (含 CFBundlePrimaryIcon.CFBundleIconFiles 数组),
        // 不能用 str() 取, 需解析字典提取图标名
        var icon: NSImage?
        var iconCandidates: [URL] = []
        // 1) CFBundleIconFile — 直接是文件名
        if let name = str("CFBundleIconFile") {
            iconCandidates.append(url.appendingPathComponent("Contents/Resources/\(name)"))
            iconCandidates.append(url.appendingPathComponent("Contents/Resources/\(name).icns"))
        }
        // 2) CFBundleIcons 字典 → CFBundlePrimaryIcon.CFBundleIconFiles 数组
        if let iconsDict = rawPlist["CFBundleIcons"] as? [String: Any],
           let primary = iconsDict["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [Any] {
            for f in files {
                if let name = f as? String {
                    iconCandidates.append(url.appendingPathComponent("Contents/Resources/\(name)"))
                    iconCandidates.append(url.appendingPathComponent("Contents/Resources/\(name).icns"))
                    iconCandidates.append(url.appendingPathComponent("Contents/Resources/\(name)@2x.png"))
                }
            }
        }
        // 3) 默认 AppIcon
        iconCandidates.append(url.appendingPathComponent("Contents/Resources/AppIcon"))
        iconCandidates.append(url.appendingPathComponent("Contents/Resources/AppIcon.icns"))
        // iOS Wrapper 布局: Wrapper/<name>.app/<iconName>
        let wrapperDir = url.appendingPathComponent("Wrapper")
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: wrapperDir.path) {
            for appDir in entries where appDir.hasSuffix(".app") {
                iconCandidates.append(wrapperDir.appendingPathComponent("\(appDir)/AppIcon60x60@2x.png"))
                iconCandidates.append(wrapperDir.appendingPathComponent("\(appDir)/AppIcon.icns"))
            }
        }
        for c in iconCandidates {
            if FileManager.default.fileExists(atPath: c.path) {
                icon = NSImage(contentsOf: c)
                if icon != nil { break }
            }
        }
        if icon == nil {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        }

        let architectures = ArchitectureReader.read(for: url)
        let dependencies = MachODependencyReader.read(
            executablePath: execPath,
            bundleURL: url,
            mainArchs: architectures.map(\.name)
        )

        // Info.plist 健康检查
        let plistURL = InfoPlistParser.plistURL(at: url)
        let requiredKeys = [
            "CFBundleIdentifier", "CFBundleExecutable", "CFBundlePackageType",
            "CFBundleVersion", "CFBundleShortVersionString", "CFBundleName"
        ]
        var codeSignatureCandidates = [
            url.appendingPathComponent("Contents/_CodeSignature/CodeResources"),
            url.appendingPathComponent("_CodeSignature/CodeResources")
        ]
        let wrapperDirForSig = url.appendingPathComponent("Wrapper")
        if let apps = try? FileManager.default.contentsOfDirectory(atPath: wrapperDirForSig.path) {
            for app in apps where app.hasSuffix(".app") {
                codeSignatureCandidates.append(
                    wrapperDirForSig.appendingPathComponent("\(app)/_CodeSignature/CodeResources"))
            }
        }
        let infoPlistHealth = InfoPlistHealth(
            path: plistURL.map {
                $0.path.replacingOccurrences(of: url.path + "/", with: "")
            },
            format: plistURL.flatMap { InfoPlistParser.formatDescription(at: $0) },
            missingKeys: requiredKeys.filter { key in
                guard let value = rawPlist[key] else { return true }
                if let s = value as? String {
                    return s.trimmingCharacters(in: .whitespaces).isEmpty
                }
                return false
            },
            hasExecutable: execPath != nil,
            hasCodeSignature: codeSignatureCandidates.contains {
                FileManager.default.fileExists(atPath: $0.path)
            }
        )
        let lsMinByArch: [String: String] =
            (rawPlist["LSMinimumSystemVersionByArchitecture"] as? [String: Any])?
                .mapValues { InfoPlistParser.describe($0) } ?? [:]

        return AppInfo(
            bundleURL: url,
            displayName: str("CFBundleDisplayName"),
            bundleName: str("CFBundleName"),
            bundleIdentifier: str("CFBundleIdentifier"),
            bundleShortVersion: str("CFBundleShortVersionString"),
            bundleVersion: str("CFBundleVersion"),
            executableName: execName,
            executablePath: execPath,
            bundlePackageType: str("CFBundlePackageType"),
            infoDictionaryVersion: str("CFBundleInfoDictionaryVersion"),
            developmentRegion: str("CFBundleDevelopmentRegion"),
            minimumOSVersion: str("LSMinimumSystemVersion") ?? str("MinimumOSVersion")
                ?? ArchitectureReader.maxMinOSVersion(architectures),
            lsMinimumSystemVersion: str("LSMinimumSystemVersion"),
            minimumOSVersionIOS: str("MinimumOSVersion"),
            applicationCategoryType: str("LSApplicationCategoryType"),
            requiresAquaSystemAppearance: (rawPlist["LSRequiresAquaSystemAppearance"] as? Bool),
            highResolutionCapable: (rawPlist["NSHighResolutionCapable"] as? Bool),
            canAnimateAlpha: (rawPlist["NSCanAnimateAlpha"] as? Bool),
            supportsHighResolutionDisplays: (rawPlist["NSSupportsHighResolutionDisplays"] as? Bool),
            uses24HourClock: (rawPlist["CFBundleUses24HourClock"] as? Bool),
            lsMinimumSystemVersionByArchitecture: lsMinByArch,
            sdkVersion: str("DTSDKName"),
            platformName: str("DTPlatformName"),
            platformVersion: str("DTPlatformVersion"),
            sdkBuild: str("DTSDKBuild"),
            platformBuild: str("DTPlatformBuild"),
            xcodeVersion: str("DTXcode"),
            xcodeBuild: str("DTXcodeBuild"),
            buildMachineOSBuild: str("BuildMachineOSBuild"),
            dtCompiler: str("DTCompiler"),
            principalClass: str("NSPrincipalClass"),
            humanReadableCopyright: str("NSHumanReadableCopyright"),
            longVersionString: str("CFBundleLongVersionString"),
            getInfoString: str("CFBundleGetInfoString"),
            bundleSignature: str("CFBundleSignature"),
            supportedPlatforms: supportedPlatforms,
            supportsAutomaticGraphicsSwitching: (rawPlist["NSSupportsAutomaticGraphicsSwitching"] as? Bool),
            quitAlwaysKeepsWindows: (rawPlist["NSQuitAlwaysKeepsWindows"] as? Bool),
            prefersDisplaySafeAreaCompatibilityMode: (rawPlist["NSPrefersDisplaySafeAreaCompatibilityMode"] as? Bool),
            csResourcesFileMapped: (rawPlist["CSResourcesFileMapped"] as? Bool),
            lsEnvironment: lsEnv,
            appTransportSecurity: rawPlist["NSAppTransportSecurity"] as? [String: Any],
            electronAsarIntegrity: rawPlist["ElectronAsarIntegrity"] as? [String: Any],
            documentTypes: dict("CFBundleDocumentTypes"),
            urlSchemes: schemes,
            exportedTypeIdentifiers: dict("UTExportedTypeDeclarations"),
            importedTypeIdentifiers: dict("UTImportedTypeDeclarations"),
            services: dict("NSServices"),
            lsUIElement: lsUIElement,
            lsBackgroundOnly: lsBackgroundOnly,
            privacyEntries: privacyEntries,
            isIOSPort: isIOSPort,
            fileSize: fileSize,
            sizeBreakdown: sizeBreakdown,
            bundleTree: treeResult.tree,
            modificationDate: modDate,
            creationDate: creationDate,
            permissions: perms,
            rawInfoPlist: rawPlist,
            flatRows: rows,
            infoPlistHealth: infoPlistHealth,
            quarantine: QuarantineReader.read(for: url),
            extendedXattrs: extendedXattrs,
            codeSign: CodeSignReader.read(for: url),
            architectures: architectures,
            dependencies: dependencies,
            subBundles: subResult.subBundles,
            subBundlesTotalSize: subResult.totalSize,
            launchAgents: launchAgents,
            extra: ExtraInfoReader.read(from: rawPlist, bundleURL: url),
            privacyManifests: privacyManifests,
            hasMASReceipt: hasMASReceipt,
            icon: icon
        )
    }

    /// 扫描 Contents/Library/LaunchAgents 与 LaunchDaemons 中的 plist。
    private static func scanLaunchAgents(at bundleURL: URL) -> [LaunchAgentItem] {
        let dirs = [
            "Contents/Library/LaunchAgents",
            "Contents/Library/LaunchDaemons"
        ]
        var items: [LaunchAgentItem] = []
        for dir in dirs {
            let dirURL = bundleURL.appendingPathComponent(dir)
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dirURL.path) else { continue }
            for name in entries where name.hasSuffix(".plist") {
                let url = dirURL.appendingPathComponent(name)
                var label = name
                if let data = try? Data(contentsOf: url),
                   let plist = try? PropertyListSerialization.propertyList(
                    from: data, options: [], format: nil) as? [String: Any],
                   let l = plist["Label"] as? String, !l.isEmpty {
                    label = l
                }
                let rel = url.path.replacingOccurrences(of: bundleURL.path + "/", with: "")
                items.append(LaunchAgentItem(relativePath: rel, label: label))
            }
        }
        return items.sorted { $0.relativePath < $1.relativePath }
    }
}

// MARK: - 格式化辅助
extension AppInfo {
    func formattedFileSize() -> String {
        ByteSize.string(fileSize)
    }

    /// 仅来自 Mach-O 切片的最低系统版本 (Info.plist 未声明时的兜底/交叉校验)。
    var machOMinimumOSVersion: String? {
        ArchitectureReader.maxMinOSVersion(architectures)
    }

    /// 解析符号链接后的真实路径（例如 /Applications/Safari.app → /System/...）。
    var resolvedBundlePath: String {
        bundleURL.resolvingSymlinksInPath().path
    }

    /// 是否位于只读系统卷 /System 下（用于区分“Apple 签名”与“系统预装”）。
    var isSystemLocation: Bool {
        resolvedBundlePath.hasPrefix("/System/")
    }

    /// 子 bundle 审计：签名有效性 / TeamID / 架构与主应用是否一致。
    /// 返回首个问题的本地化描述，全部正常时返回 nil。
    func subBundleIssue(_ sub: SubBundle) -> String? {
        if sub.validity == .invalid { return L10n.t(.warnSubInvalid) }
        if sub.strictValidity == .invalid { return L10n.t(.warnSubStrict) }
        if let mainTeam = codeSign.teamIdentifier, !mainTeam.isEmpty,
           let subTeam = sub.teamIdentifier, !subTeam.isEmpty,
           mainTeam != subTeam {
            return L10n.t(.warnTeamMismatch)
        }
        let mainArchs = Set(architectures.map { Self.normalizedArch($0.name) })
        let subArchs = Set(sub.architectures.map { Self.normalizedArch($0) })
        if !mainArchs.isEmpty, !subArchs.isEmpty, !mainArchs.isSubset(of: subArchs) {
            return L10n.t(.warnArchMismatch)
        }
        return nil
    }

    private static func normalizedArch(_ name: String) -> String {
        if name.hasPrefix("arm64") { return "arm64" }
        if name.hasPrefix("x86_64") { return "x86_64" }
        return name
    }

    /// BundleID 与签名 Identifier 是否一致（任一方缺失时返回 nil）
    var bundleIDMatchesSignature: Bool? {
        guard let bid = bundleIdentifier, let sid = codeSign.identifier else { return nil }
        return bid == sid
    }

    /// Info.plist TeamIdentifier 与签名 TeamIdentifier 是否一致
    var plistTeamMatchesSignature: Bool? {
        guard let p = extra.teamIdentifierPlist, !p.isEmpty,
              let s = codeSign.teamIdentifier else { return nil }
        return p == s
    }

    /// 是否启用了 App Sandbox：
    /// - entitlements 中含 `com.apple.security.app-sandbox = true`
    /// - 或为 iOS 应用 (通过 iPhone OS Application Signing 证书判定, iOS 应用天然沙盒)
    var isSandboxed: Bool {
        guard let ent = codeSign.entitlements else {
            // iOS 应用: 无 entitlements 时, 通过签名状态判定
            return codeSign.notarization == .iosAppStore
        }
        if let v = ent["com.apple.security.app-sandbox"] as? Bool { return v }
        // 部分签名工具输出该键为字符串 "true" / "1"
        if let s = ent["com.apple.security.app-sandbox"] as? String {
            return s.lowercased() == "true" || s == "1"
        }
        // iOS 应用: 即使无显式 app-sandbox entitlement, 也是沙盒的
        if codeSign.notarization == .iosAppStore { return true }
        return false
    }
}

// MARK: - 摘要文本 (CLI + 复制摘要共享)

extension AppInfo {
    nonisolated(unsafe) private static let isoFormatter = ISO8601DateFormatter()

    private static func formatBytes(_ n: UInt64) -> String {
        ByteSize.string(n)
    }

    /// 生成纯文本摘要。CLI (`swift run SwiftLens app`) 与「复制摘要」按钮共用此逻辑，
    /// 避免两份重复实现漂移。
    var summaryText: String {
        var lines: [String] = []
        let cs = codeSign
        let ex = extra

        lines.append("# \(displayName ?? bundleName ?? bundleURL.lastPathComponent)")
        lines.append("\(L10n.t(.cliPath)): \(bundleURL.path)")
        if resolvedBundlePath != bundleURL.path {
            lines.append("  \(L10n.t(.resolvedPath)): \(resolvedBundlePath)")
        }
        lines.append("  \(L10n.t(.systemLocation)): \(isSystemLocation ? "YES" : "NO")")
        lines.append("BundleID: \(bundleIdentifier ?? "—")")
        lines.append("\(L10n.t(.cliVersion)): \(bundleShortVersion ?? "—") (\(bundleVersion ?? "—"))")
        lines.append("\(L10n.t(.cliMinOS)): \(minimumOSVersion ?? "—")")
        if !lsMinimumSystemVersionByArchitecture.isEmpty {
            let pairs = lsMinimumSystemVersionByArchitecture.keys.sorted().map {
                "\($0)=\(lsMinimumSystemVersionByArchitecture[$0] ?? "—")"
            }
            lines.append("  \(L10n.t(.lsMinByArch)): \(pairs.joined(separator: ", "))")
        }
        lines.append("\(L10n.t(.cliSDK)): \(sdkVersion ?? "—") / \(platformName ?? "—") \(sdkBuild ?? "")")
        let plistHealth = infoPlistHealth
        let plistIssues = (plistHealth.path == nil ? 1 : 0)
            + plistHealth.missingKeys.count
            + (plistHealth.hasExecutable ? 0 : 1)
        let healthText = plistIssues == 0
            ? L10n.t(.healthOK)
            : "\(plistIssues) \(L10n.t(.healthIssues))"
        lines.append("\(L10n.t(.plistHealth)): \(plistHealth.format ?? "—") (\(plistHealth.path ?? "—")) — \(healthText)")
        let archs = architectures.map { "\($0.name)(\($0.bits)-bit, \($0.cpuType))" }.joined(separator: ", ")
        lines.append("\(L10n.t(.cliArchs)): \(archs.isEmpty ? "—" : archs)")
        if !supportedPlatforms.isEmpty {
            lines.append("\(L10n.t(.cliPlatforms)): \(supportedPlatforms.joined(separator: ", "))")
        }
        if let dep = dependencies {
            lines.append("\(L10n.t(.dependencies)): \(dep.total) (\(L10n.t(.depSystem)) \(dep.systemCount), \(L10n.t(.depMissing)) \(dep.missing.count), \(L10n.t(.depWeak)) \(dep.weak.count), \(L10n.t(.depArchMismatch)) \(dep.archMismatches.count))")
            for m in dep.missing.prefix(5) {
                lines.append("  ⚠︎ \(L10n.t(.depMissing)): \(m.path)")
            }
            for m in dep.archMismatches.prefix(3) {
                lines.append("  ⚠︎ \(L10n.t(.depArchMismatch)): \(m.path) (\(m.missingArchs.joined(separator: ",")))")
            }
        }
        if let v = principalClass { lines.append("NSPrincipalClass: \(v)") }
        if let v = humanReadableCopyright { lines.append("\(L10n.t(.cliCopyright)): \(v)") }
        lines.append("\(L10n.t(.cliUrlSchemes)): \(urlSchemes.isEmpty ? "—" : urlSchemes.joined(separator: ", "))")
        lines.append("\(L10n.t(.cliDocTypes)): \(documentTypes.count) \(L10n.t(.cliPlistKeys))")

        // 签名
        lines.append("\(L10n.t(.cliSign)): \(cs.state.localizedName) — \(cs.validity.localizedName) — \(cs.notarization.localizedName)")
        lines.append("  \(L10n.t(.strictValidation)): \(cs.strictValidity.strictName)")
        lines.append("\(L10n.t(.cliSandbox)): \(isSandboxed ? L10n.t(.cliSandboxYes) : L10n.t(.cliSandboxNo))")
        if let v = cs.format { lines.append("  Format: \(v)") }
        if let v = cs.identifier { lines.append("  Identifier: \(v)") }
        lines.append("  TeamIdentifier: \(cs.teamIdentifier ?? "not set")")
        var checks: [String] = []
        if let ok = bundleIDMatchesSignature {
            checks.append("BundleID=\(ok ? L10n.t(.match) : L10n.t(.mismatch))")
        }
        if let ok = plistTeamMatchesSignature {
            checks.append("TeamID=\(ok ? L10n.t(.match) : L10n.t(.mismatch))")
        }
        checks.append("\(L10n.t(.hardenedRuntime))=\(cs.hasHardenedRuntime ? "YES" : "NO")")
        checks.append("\(L10n.t(.libraryValidation))=\(cs.hasLibraryValidation ? "YES" : "NO")")
        lines.append("  \(L10n.t(.consistencyCheck)): \(checks.joined(separator: ", "))")
        if let v = cs.cdHash { lines.append("  CDHash: \(v)") }
        if let v = cs.candidateCDHashFull { lines.append("  CandidateCDHashFull: \(v)") }
        if let v = cs.hashType { lines.append("  HashType: \(v)") }
        if let v = cs.hashChoices { lines.append("  Hash choices: \(v)") }
        if let v = cs.signatureType { lines.append("  Signature: \(v)") }
        if let v = cs.signatureSize { lines.append("  Signature size: \(v)") }
        if let v = cs.platformIdentifier { lines.append("  Platform identifier: \(v)") }
        if let v = cs.source { lines.append("  Source: \(v)") }
        if let v = cs.runtimeVersion { lines.append("  Runtime Version: \(v)") }
        if let v = cs.signingTime { lines.append("  Signing Time: \(v)") }
        if let v = cs.totalSignatures { lines.append("  Total signatures: \(v)") }
        if let v = cs.chosenSignature { lines.append("  Chosen signature: \(v)") }
        if let v = cs.infoPlistEntries { lines.append("  Info.plist entries: \(v)") }
        if !cs.decodedFlags.isEmpty { lines.append("  \(L10n.t(.cliFlagsDecoded)): \(cs.decodedFlags.joined(separator: ", "))") }
        if let v = cs.flags { lines.append("  \(L10n.t(.cliFlagsRaw)): \(v)") }
        if !cs.certificates.isEmpty {
            lines.append("  \(L10n.t(.cliAuthority)):")
            for c in cs.certificates {
                var line = "    - \(c.summary)"
                if let na = c.notAfter {
                    line += " (\(L10n.t(.certValidity)): \(Self.isoFormatter.string(from: na)))"
                }
                if c.isExpired { line += " ⚠︎ \(L10n.t(.certExpired))" }
                lines.append(line)
            }
        } else if !cs.authorities.isEmpty {
            lines.append("  \(L10n.t(.cliAuthority)):")
            cs.authorities.forEach { lines.append("    - \($0)") }
        }
        if let ent = cs.entitlements {
            lines.append("  Entitlements (\(ent.count) \(L10n.t(.cliEntitlementsCount))):")
            InfoPlistParser.flatten(ent).sorted { $0.0 < $1.0 }
                .forEach { lines.append("    \($0.0) = \($0.1)") }
        } else {
            lines.append("  Entitlements: \(L10n.t(.cliEntitlementsNone))")
        }
        let riskyEntitlements = EntitlementAudit.riskyKeys(in: cs.entitlements)
        if !riskyEntitlements.isEmpty {
            let shown = riskyEntitlements.prefix(6).joined(separator: ", ")
            let suffix = riskyEntitlements.count > 6 ? ", … (+\(riskyEntitlements.count - 6))" : ""
            lines.append("  ⚠︎ \(L10n.t(.riskCount)): \(shown)\(suffix)")
        }

        // 隐私
        lines.append("\(L10n.t(.cliPrivacy)): \(privacyEntries.count) \(L10n.t(.cliPlistKeys))")
        for e in privacyEntries.prefix(8) {
            lines.append("  · \(e.displayTitle) [\(e.key)]: \(e.description)")
        }
        if privacyEntries.count > 8 {
            lines.append("  ... \(L10n.t(.cliMore)) \(privacyEntries.count - 8) \(L10n.t(.cliPlistKeys))")
        }

        if !privacyManifests.isEmpty {
            lines.append("\(L10n.t(.privacyManifests)): \(privacyManifests.count)")
            for m in privacyManifests.prefix(8) {
                var line = "  · \(m.path)"
                if let t = m.tracking {
                    line += " (\(L10n.t(.privacyTracking))=\(t ? "YES" : "NO"))"
                }
                line += " — \(m.accessedAPIs.count) APIs, \(m.collectedData.count) data types"
                lines.append(line)
            }
            if privacyManifests.count > 8 {
                lines.append("  ... \(L10n.t(.cliMore)) \(privacyManifests.count - 8)")
            }
        }

        if appTransportSecurity != nil { lines.append("ATS: \(L10n.t(.cliATS))") }
        if electronAsarIntegrity != nil { lines.append("Electron: \(L10n.t(.cliElectron))") }
        if lsUIElement == true { lines.append(L10n.t(.cliFormAgent)) }
        if lsBackgroundOnly == true { lines.append(L10n.t(.cliFormBackground)) }
        if isIOSPort { lines.append(L10n.t(.cliFormIOSPort)) }

        // Sparkle
        if let sp = ex.sparkle {
            lines.append("\(L10n.t(.cliSparkle)):")
            if let v = sp.feedURL { lines.append("  SUFeedURL: \(v)") }
            if let v = sp.publicEDKey { lines.append("  SUPublicEDKey: \(v)") }
            if let v = sp.publicDSAKeyFile { lines.append("  SUPublicDSAKeyFile: \(v)") }
            if let v = sp.enableAutomaticChecks { lines.append("  SUEnableAutomaticChecks: \(v)") }
            if let v = sp.scheduledCheckInterval {
                lines.append("  SUScheduledCheckInterval: \(v) \(L10n.t(.cliSeconds)) (\(Double(v)/86400.0) \(L10n.t(.cliDays)))")
            }
            if let v = sp.allowsAutomaticUpdates { lines.append("  SUAllowsAutomaticUpdates: \(v)") }
            if let v = sp.enableInstallerLauncherService { lines.append("  SUEnableInstallerLauncherService: \(v)") }
            if let v = sp.enableDownloaderService { lines.append("  SUEnableDownloaderService: \(v)") }
            if let v = sp.showReleaseNotes { lines.append("  SUShowReleaseNotes: \(v)") }
            if let v = sp.enableSystemProfiling { lines.append("  SUEnableSystemProfiling: \(v)") }
            if let v = sp.sendProfileInfo { lines.append("  SUSendProfileInfo: \(v)") }
            if let v = sp.enableJavaScript { lines.append("  SUEnableJavaScript: \(v)") }
            if let v = sp.bundleName { lines.append("  SUBundleName: \(v)") }
        }

        // AppleScript / Siri
        if let v = ex.appleScriptEnabled { lines.append("NSAppleScriptEnabled: \(v)") }
        if let v = ex.scriptingDefinition { lines.append("OSAScriptingDefinition: \(v)") }
        if !ex.userActivityTypes.isEmpty {
            lines.append("NSUserActivityTypes: \(ex.userActivityTypes.joined(separator: ", "))")
        }
        if !ex.intentsSupported.isEmpty {
            lines.append("INIntentsSupported (Siri): \(ex.intentsSupported.joined(separator: ", "))")
        }
        if let v = ex.safariExtensionCorrespondingIOSApp {
            lines.append("SFSafariCorrespondingIOSAppBundleIdentifier: \(v)")
        }

        // iCloud
        if !ex.ubiquitousContainers.isEmpty {
            lines.append("iCloud Containers (\(ex.ubiquitousContainers.count) \(L10n.t(.cliICloudContainers))):")
            for (i, c) in ex.ubiquitousContainers.enumerated() {
                lines.append("  [\(i)] \(c.identifier): \(InfoPlistParser.flatten(c.config).map { "\($0.0)=\($0.1)" }.joined(separator: ", "))")
            }
        }

        // 通知
        if let v = ex.userNotificationAlertStyle { lines.append("NSUserNotificationAlertStyle: \(v)") }
        if let v = ex.userNotificationsUsageDescription { lines.append("NSUserNotificationsUsageDescription: \(v)") }
        if let v = ex.localNotificationUsageDescription { lines.append("NSLocalNotificationUsageDescription: \(v)") }
        if let v = ex.remoteNotificationUsageDescription { lines.append("NSRemoteNotificationUsageDescription: \(v)") }

        // 杂项开关
        if let v = ex.supportsSuddenTermination { lines.append("NSSupportsSuddenTermination: \(v)") }
        if let v = ex.supportsAutomaticTermination { lines.append("NSSupportsAutomaticTermination: \(v)") }
        if let v = ex.lsRequiresCarbon { lines.append("LSRequiresCarbon: \(v)") }
        if let v = ex.lsRequiresNativeExecution { lines.append("LSRequiresNativeExecution: \(v)") }
        if let v = ex.lsMultipleInstancesProhibited { lines.append("LSMultipleInstancesProhibited: \(v)") }
        if let v = ex.lsHasLocalizedDisplayName { lines.append("LSHasLocalizedDisplayName: \(v)") }
        if let v = ex.lsFileQuarantineEnabled { lines.append("LSFileQuarantineEnabled: \(v)") }
        if let v = ex.gpuEjectPolicy { lines.append("GPUEjectPolicy: \(v)") }
        if let v = ex.gpuSelectionPolicy { lines.append("GPUSelectionPolicy: \(v)") }
        if let v = ex.itmsAppUsesNonExemptEncryption { lines.append("ITSAppUsesNonExemptEncryption: \(v)") }

        // F. 帮助 / 本地化 / Accent / Spotlight
        if let v = ex.helpBookName { lines.append("CFBundleHelpBookName: \(v)") }
        if let v = ex.helpBookFolder { lines.append("CFBundleHelpBookFolder: \(v)") }
        if !ex.bundleLocalizations.isEmpty {
            lines.append("CFBundleLocalizations: \(ex.bundleLocalizations.joined(separator: ", "))")
        }
        if let v = ex.allowMixedLocalizations { lines.append("CFBundleAllowMixedLocalizations: \(v)") }
        if let v = ex.accentColorName { lines.append("NSAccentColorName: \(v)") }
        if let v = ex.mdItemKeywords { lines.append("MDItemKeywords: \(v)") }

        // G. iOS 移植包字段
        if !ex.uIDeviceFamily.isEmpty {
            let labels: [Int: String] = [1: "iPhone", 2: "iPad", 3: "Apple TV", 4: "Apple Watch"]
            lines.append("UIDeviceFamily: \(ex.uIDeviceFamily.map { labels[$0] ?? "\($0)" }.joined(separator: ", "))")
        }
        if let v = ex.uiLaunchStoryboardName { lines.append("UILaunchStoryboardName: \(v)") }
        if let v = ex.uiRequiresFullScreen { lines.append("UIRequiresFullScreen: \(v)") }
        if !ex.uiSupportedInterfaceOrientations.isEmpty {
            lines.append("UISupportedInterfaceOrientations: \(ex.uiSupportedInterfaceOrientations.joined(separator: ", "))")
        }
        if let v = ex.uiStatusBarStyle { lines.append("UIStatusBarStyle: \(v)") }
        if !ex.uiBackgroundModes.isEmpty {
            lines.append("UIBackgroundModes: \(ex.uiBackgroundModes.joined(separator: ", "))")
        }

        // H. Electron / 构建元数据 / 厂商
        if let v = ex.electronTeamID { lines.append("ElectronTeamID: \(v)") }
        if let v = ex.sourceVersion { lines.append("SourceVersion: \(v)") }
        if let v = ex.requiredBuildHash { lines.append("requiredBuildHash: \(v)") }
        if let v = ex.scmRevision { lines.append("SCMRevision: \(v)") }
        if let v = ex.appIdentifierPrefix { lines.append("AppIdentifierPrefix: \(v)") }
        if let v = ex.teamIdentifierPlist { lines.append("TeamIdentifier (plist): \(v)") }
        if let v = ex.bundleSpokenName { lines.append("CFBundleSpokenName: \(v)") }
        if let v = ex.vendorCode { lines.append("VendorCode: \(v)") }
        if let v = ex.organizationIdentifier { lines.append("OrganizationIdentifier: \(v)") }
        if let v = ex.ctFontSuppressAutoDownload { lines.append("CTFontSuppressAutoDownload: \(v)") }
        if let v = ex.asWebAuthenticationSessionWebBrowserSupportCapabilities {
            lines.append("ASWebAuthenticationSessionWebBrowserSupportCapabilities: \(v)")
        }

        // I. Bonjour
        if !ex.bonjourServices.isEmpty {
            lines.append("NSBonjourServices: \(ex.bonjourServices.joined(separator: ", "))")
        }

        // Quarantine / xattrs / 子 bundle / 文件
        if let q = quarantine {
            lines.append("Quarantine: flags=\(q.flags) agent=\(q.agent) uuid=\(q.uuid) \(L10n.t(.cliQuarantine))=\(q.timestampString) \(L10n.t(.cliDownloadTime))=\(q.downloadDate.map { Self.isoFormatter.string(from: $0) } ?? "—")")
        } else {
            lines.append("Quarantine: \(L10n.t(.cliQuarantineNone))")
        }
        if !extendedXattrs.names.isEmpty {
            lines.append("\(L10n.t(.cliXattrs)): \(extendedXattrs.names.joined(separator: ", "))")
        }
        lines.append("\(L10n.t(.cliSubBundles)): \(subBundles.count) \(L10n.t(.cliPlistKeys)) (\(Self.formatBytes(subBundlesTotalSize)))")
        for sub in subBundles.prefix(8) {
            var line = "  · [\(sub.kind.rawValue)] \(sub.relativePath) — \(sub.bundleIdentifier ?? "—") (\(sub.signatureState.localizedName)"
            if sub.validity == .invalid { line += " · \(sub.validity.localizedName)" }
            if sub.strictValidity == .invalid { line += " · \(L10n.t(.strictValidation)): \(sub.strictValidity.strictName)" }
            if !sub.architectures.isEmpty { line += " · \(sub.architectures.joined(separator: ","))" }
            if subBundleIssue(sub) != nil { line += " · ⚠" }
            line += ")"
            lines.append(line)
        }
        if subBundles.count > 8 {
            lines.append("  ... \(L10n.t(.cliMore)) \(subBundles.count - 8) \(L10n.t(.cliPlistKeys))")
        }
        if !launchAgents.isEmpty {
            lines.append("\(L10n.t(.launchAgents)): \(launchAgents.count)")
            for item in launchAgents.prefix(5) {
                lines.append("  · \(item.label) — \(item.relativePath)")
            }
        }
        lines.append("\(L10n.t(.cliFileSize)): \(formattedFileSize()) (\(fileSize) \(L10n.t(.bytesUnit)))")
        if !sizeBreakdown.isEmpty {
            let top = sizeBreakdown.prefix(6).map { "\($0.name) \(Self.formatBytes($0.size))" }
            lines.append("\(L10n.t(.sizeBreakdown)): \(top.joined(separator: ", "))")
        }
        lines.append("\(L10n.t(.masReceipt)): \(hasMASReceipt ? "YES" : "NO")")

        return lines.joined(separator: "\n")
    }

    /// 结构化 JSON 摘要（复制到剪贴板，供脚本/问题报告使用）。
    var jsonSummary: String {
        let cs = codeSign
        let health = infoPlistHealth
        let plistHealthDict: [String: Any] = [
            "path": health.path ?? "",
            "format": health.format ?? "",
            "missingKeys": health.missingKeys,
            "executableExists": health.hasExecutable,
            "codeSignature": health.hasCodeSignature,
            "ok": health.isOK
        ]
        let dict: [String: Any] = [
            "name": displayName ?? bundleName ?? bundleURL.lastPathComponent,
            "path": bundleURL.path,
            "resolvedPath": resolvedBundlePath,
            "systemLocation": isSystemLocation,
            "bundleIdentifier": bundleIdentifier ?? "",
            "version": bundleShortVersion ?? "",
            "build": bundleVersion ?? "",
            "minimumOSVersion": minimumOSVersion ?? "",
            "architectures": architectures.map { arch -> [String: Any] in
                var d: [String: Any] = [
                    "name": arch.name,
                    "bits": arch.bits,
                    "cpuType": arch.cpuType,
                    "size": arch.fileSize
                ]
                if let v = arch.minOSVersion { d["minos"] = v }
                if let v = arch.sdkVersion { d["sdk"] = v }
                return d
            },
            "sizeBreakdown": sizeBreakdown.map { ["name": $0.name, "size": $0.size] },
            "infoPlist": plistHealthDict,
            "lsMinByArch": lsMinimumSystemVersionByArchitecture,
            "signature": [
                "state": cs.state.rawValue,
                "validity": cs.validity.rawValue,
                "strictValidity": cs.strictValidity.rawValue,
                "notarization": cs.notarization.rawValue,
                "identifier": cs.identifier ?? "",
                "teamIdentifier": cs.teamIdentifier ?? "",
                "cdHash": cs.cdHash ?? "",
                "candidateCDHashFull": cs.candidateCDHashFull ?? "",
                "flags": cs.flags ?? "",
                "decodedFlags": cs.decodedFlags,
                "runtimeVersion": cs.runtimeVersion ?? "",
                "signingTime": cs.signingTime ?? "",
                "hardenedRuntime": cs.hasHardenedRuntime,
                "libraryValidation": cs.hasLibraryValidation,
                "authorities": cs.authorities,
                "certificates": cs.certificates.map { cert -> [String: Any] in
                    var d: [String: Any] = [
                        "summary": cert.summary,
                        "sha256": cert.sha256 ?? ""
                    ]
                    if let v = cert.issuer { d["issuer"] = v }
                    if let v = cert.notBefore { d["notBefore"] = Self.isoFormatter.string(from: v) }
                    if let v = cert.notAfter { d["notAfter"] = Self.isoFormatter.string(from: v) }
                    return d
                }
            ],
            "sandboxed": isSandboxed,
            "entitlements": Self.jsonSafe(cs.entitlements ?? [:]),
            "quarantine": quarantine.map { q -> [String: Any] in
                var d: [String: Any] = [
                    "raw": q.raw,
                    "flags": q.flags,
                    "agent": q.agent,
                    "uuid": q.uuid,
                    "timestamp": q.timestampString
                ]
                if let v = q.downloadDate { d["date"] = Self.isoFormatter.string(from: v) }
                return d
            } ?? NSNull(),
            "subBundles": subBundles.map { sub -> [String: Any] in
                var d: [String: Any] = [
                    "kind": sub.kind.rawValue,
                    "path": sub.relativePath,
                    "bundleIdentifier": sub.bundleIdentifier ?? "",
                    "version": sub.bundleVersion ?? "",
                    "signatureState": sub.signatureState.rawValue,
                    "validity": sub.validity.rawValue,
                    "strictValidity": sub.strictValidity.rawValue,
                    "teamIdentifier": sub.teamIdentifier ?? "",
                    "architectures": sub.architectures
                ]
                if let v = sub.extensionPoint { d["extensionPoint"] = v }
                if let v = sub.xpcServiceType { d["xpcServiceType"] = v }
                return d
            },
            "dependencies": dependencies.map { dep -> [String: Any] in
                [
                    "total": dep.total,
                    "system": dep.systemCount,
                    "missing": dep.missing.count,
                    "weak": dep.weak.count,
                    "archMismatch": dep.archMismatches.count,
                    "rpaths": dep.rpaths
                ]
            } ?? NSNull(),
            "privacyManifests": privacyManifests.map { m -> [String: Any] in
                var d: [String: Any] = [
                    "path": m.path,
                    "accessedAPIs": m.accessedAPIs.map { ["type": $0.type, "reasons": $0.reasons] },
                    "collectedData": m.collectedData,
                    "trackingDomains": m.trackingDomains
                ]
                if let v = m.tracking { d["tracking"] = v }
                return d
            },
            "launchAgents": launchAgents.map { ["label": $0.label, "path": $0.relativePath] },
            "masReceipt": hasMASReceipt
        ]
        let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    private static func jsonSafe(_ value: Any) -> Any {
        if let v = value as? [String: Any] { return v.mapValues(jsonSafe) }
        if let v = value as? [Any] { return v.map(jsonSafe) }
        if let v = value as? String { return v }
        if let v = value as? NSNumber {
            if CFGetTypeID(v) == CFBooleanGetTypeID() { return v.boolValue }
            return v
        }
        if let v = value as? Data { return "Data(\(v.count) bytes)" }
        if let v = value as? Date { return isoFormatter.string(from: v) }
        return String(describing: value)
    }
}

// MARK: - 高风险 Entitlements

/// 常见高风险 entitlement 的审计映射。返回本地化说明；nil 表示未命中。
enum EntitlementAudit {
    static func warning(for key: String) -> String? {
        if key.hasPrefix("com.apple.security.temporary-exception.") {
            return L10n.t(.riskTempException)
        }
        switch key {
        case "com.apple.security.cs.disable-library-validation":
            return L10n.t(.riskDisableLibraryValidation)
        case "com.apple.security.cs.allow-unsigned-executable-memory":
            return L10n.t(.riskUnsignedExecMemory)
        case "com.apple.security.cs.allow-dyld-environment-variables":
            return L10n.t(.riskDyldEnv)
        case "com.apple.security.get-task-allow":
            return L10n.t(.riskGetTaskAllow)
        case "com.apple.security.cs.debugger":
            return L10n.t(.riskDebugger)
        case "com.apple.security.cs.allow-jit":
            return L10n.t(.riskAllowJIT)
        case "com.apple.security.cs.disable-executable-page-protection":
            return L10n.t(.riskDisableExecPageProtection)
        default:
            return nil
        }
    }

    /// 返回所有命中风险的 entitlement 键（扁平化后）。
    static func riskyKeys(in entitlements: [String: Any]?) -> [String] {
        guard let entitlements else { return [] }
        return InfoPlistParser.flatten(entitlements)
            .map(\.0)
            .filter { warning(for: $0) != nil }
    }
}