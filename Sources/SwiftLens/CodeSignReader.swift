import Foundation
import Security

// MARK: - 代码签名信息

struct CodeSignInfo {
    enum SignedState: String {
        case signed       = "signed"
        case adhoc        = "adhoc"
        case unsigned     = "unsigned"
        case unknown      = "unknown"
        /// 本地化展示名 (走 L10n, 受当前语言影响)
        var localizedName: String {
            switch self {
            case .signed:   return L10n.t(.ssSigned)
            case .adhoc:     return L10n.t(.ssAdhoc)
            case .unsigned:  return L10n.t(.ssUnsigned)
            case .unknown:   return L10n.t(.ssUnknown)
            }
        }
    }
    enum Validity: String {
        case valid    = "valid"
        case invalid  = "invalid"
        case untested = "untested"
        var localizedName: String {
            switch self {
            case .valid:    return L10n.t(.vValid)
            case .invalid:  return L10n.t(.vInvalid)
            case .untested: return L10n.t(.vUntested)
            }
        }
        /// 严格验证 (kSecCSStrictValidate) 结果的展示名, 与基础验证区分。
        var strictName: String {
            switch self {
            case .valid:    return L10n.t(.strictPass)
            case .invalid:  return L10n.t(.strictFail)
            case .untested: return L10n.t(.strictUntested)
            }
        }
    }
    enum Notarization: String {
        case notarized      = "notarized"
        case devID          = "developer-id"
        case macAppStore    = "mac-app-store"
        case iosAppStore    = "ios-app-store"
        case appleSystem    = "apple-system"
        case notNotarized   = "not-notarized"
        case unknown        = "unknown"
        var localizedName: String {
            switch self {
            case .notarized:    return L10n.t(.nNotarized)
            case .devID:        return L10n.t(.nDevID)
            case .macAppStore:  return L10n.t(.nMAS)
            case .iosAppStore:  return L10n.t(.nIOSStore)
            case .appleSystem:  return L10n.t(.nAppleSystem)
            case .notNotarized: return L10n.t(.nNotNotarized)
            case .unknown:      return L10n.t(.nUnknown)
            }
        }
    }

    let state: SignedState
    let validity: Validity
    /// 严格验证结果：在基础验证之上额外校验资源封印 (CodeResources) 与嵌套代码。
    /// 未签名 / 非 code 对象时为 .untested。
    let strictValidity: Validity
    let notarization: Notarization

    /// 合成的签名详情文本（替代旧版 codesign -dvvv 输出）
    let detailRaw: String
    let identifier: String?
    let teamIdentifier: String?        // nil 时 UI 显示 "not set"
    let authorities: [String]        // 证书链 subject 列表
    let cdHash: String?              // 十六进制字符串 (20 bytes, truncated)
    let candidateCDHashFull: String? // 十六进制字符串 (32 bytes, full sha256)
    let hashType: String?            // sha256 / sha1
    let hashChoices: String?         // Hash choices, 如 "sha256"
    let signatureType: String?       // "adhoc" / "Developer ID" / "adhoc" 等
    let flags: String?               // 原始 flags 十六进制
    let decodedFlags: [String]       // 解码后的标志列表
    let format: String?
    let runtimeVersion: String?      // 管制化运行时的版本号, 如 "26.2.0"
    let signingTime: String?          // 签名时间
    let totalSignatures: String?      // 总签名数
    let chosenSignature: String?      // 选中签名索引
    let infoPlistEntries: String?     // 已纳入签名的 Info.plist 项数
    let signatureSize: String?        // 签名大小 (字节)
    let platformIdentifier: String?   // 平台标识
    let source: String?               // 签名位置, 如 "embedded"
    let entitlementsRaw: String?      // 由 entitlements dict 序列化的 XML plist
    let entitlements: [String: Any]?
    let error: String?
}

enum CodeSignReader {

    static func read(for bundleURL: URL) -> CodeSignInfo {
        // 1. 创建 SecStaticCode 引用 (即使未签名也成功)
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            bundleURL as CFURL,
            SecCSFlags(rawValue: 0),
            &staticCode
        )
        guard createStatus == errSecSuccess, let code = staticCode else {
            return makeUnsigned(error: "\(L10n.t(.errSecStaticCode)): status=\(createStatus)")
        }

        // 2. 取签名信息字典 (kSecCSSigningInformation 即可, 已包含 entitlements-dict)
        var infoDict: CFDictionary?
        let signStatus = SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &infoDict
        )
        guard signStatus == errSecSuccess, let dict = infoDict as? [String: Any] else {
            // SecCodeCopySigningInformation 对未签名 code 返回 errSecCSUnsigned
            if signStatus == errSecCSUnsigned {
                return makeUnsigned(error: nil)
            }
            // 其它错误: 视作未签名
            return makeUnsigned(error: "\(L10n.t(.errSecCodeCopySign)): status=\(signStatus)")
        }

        // 3. 提取字段 (dict 键名来自 SecCode.h, 部分常量未导出到 Swift)
        let identifier   = dict["identifier"] as? String
        let teamIdentifier = dict["teamid"] as? String
        let format       = dict["format"] as? String
        let flagsValue   = (dict["flags"] as? NSNumber)?.uint32Value
        // cdhashes-full 是 dict: {算法编号 = Data(完整 hash)}
        //   1 = sha1 (20 bytes), 2 = sha256 (32 bytes)
        // cdhashes 是 [Data] 数组, 每个元素是 20 bytes 的 truncated hash
        //   顺序通常是 [sha1, sha256] (dual-algorithm apps)
        let cdHashFullDict = dict["cdhashes-full"] as? [AnyHashable: Data]
        let cdHashFullData_sha256 = cdHashFullDict?[2] ?? cdHashFullDict?[NSNumber(value: 2)]
        let cdHashFullData_sha1   = cdHashFullDict?[1] ?? cdHashFullDict?[NSNumber(value: 1)]
        let certs        = (dict["certificates"] as? [SecCertificate]) ?? []

        // 未签名 bundle (尤其是非标准布局 / 目录) 有时 SecCodeCopySigningInformation
        // 仍返回成功, 但字典里只有 "main-executable" 一个键, 没有任何签名数据。
        // 若只看调用是否成功, 会把未签名应用误报成「已签名」。以真实签名字段判定。
        let hasSignatureData = dict["identifier"] != nil
            || dict["cdhashes"] != nil
            || dict["flags"] != nil
            || !certs.isEmpty
        guard hasSignatureData else {
            return makeUnsigned(error: nil)
        }

        // 4. CDHash → hex
        // codesign 的 "CDHash=" 显示的是 sha256 truncated (前 20 字节),
        // 没有 sha256 时回退到 sha1, 再没有就用 cdhashes 数组最后一个
        let cdHash: String? = {
            if let full = cdHashFullData_sha256, full.count >= 20 {
                return Data(full.prefix(20)).map { String(format: "%02x", $0) }.joined()
            }
            if let arr = dict["cdhashes"] as? [Data], let last = arr.last {
                return last.map { String(format: "%02x", $0) }.joined()
            }
            return nil
        }()
        // CandidateCDHashFull: sha256 完整 (32 字节), 回退 sha1
        let candidateCDHashFull: String? = {
            if let full = cdHashFullData_sha256 {
                return full.map { String(format: "%02x", $0) }.joined()
            }
            if let full = cdHashFullData_sha1 {
                return full.map { String(format: "%02x", $0) }.joined()
            }
            return nil
        }()

        // 5. flags 解码
        let flagsHex = flagsValue.map { String(format: "0x%x", $0) }
        let decodedFlags = decodeFlags(flagsValue ?? 0)

        // 6. 证书链 → authorities
        let authorities = certs.map { cert -> String in
            if let summary = SecCertificateCopySubjectSummary(cert) {
                return summary as String
            }
            return L10n.t(.unknownCert)
        }

        // 6.5 Hash choices (digest-algorithms 数组 → sha256/sha1 字符串)
        let hashChoices: String? = {
            if let algs = dict["digest-algorithms"] as? [NSNumber] {
                return algs.map { Self.algoName($0.int32Value) }.joined(separator: ",")
            }
            if let alg = dict["digest-algorithm"] as? NSNumber {
                return Self.algoName(alg.int32Value)
            }
            return nil
        }()

        // 6.6 Signature size (cms blob 字节数)
        let signatureSize = (dict["cms"] as? Data).map { "\($0.count)" }

        // 6.7 Platform identifier / source
        let platformIdentifier = (dict["platform-identifier"] as? NSNumber).map { "\($0.intValue)" }
            ?? (dict["platform-identifier"] as? String)
        let source = dict["source"] as? String

        // 7. 判断签名状态
        let isAdhoc = (flagsValue ?? 0) & CS_ADHOC != 0
        let state: CodeSignInfo.SignedState
        let signatureType: String?
        if isAdhoc {
            state = .adhoc
            signatureType = "adhoc"
        } else {
            state = .signed
            // 若证书链首张含 "Developer ID Application" → Developer ID 签名
            if authorities.first(where: { $0.contains("Developer ID Application") }) != nil {
                signatureType = "Developer ID Application"
            } else if authorities.first(where: { $0.contains("Apple Mac OS Application Signing") }) != nil {
                signatureType = "Apple Mac OS Application Signing"
            } else if authorities.first(where: { $0.contains("Apple iPhone OS Application Signing") }) != nil {
                signatureType = "Apple iPhone OS Application Signing"
            } else if authorities.first(where: { $0.contains("Software Signing") }) != nil {
                signatureType = "Apple Software Signing"
            } else {
                signatureType = "signed"
            }
        }

        // 8. Hardened Runtime 标志 + runtime version
        let isRuntime = decodedFlags.contains("runtime")
        let runtimeVersion: String? = {
            guard isRuntime else { return nil }
            // dict["runtime-version"] 是编码后的数字 0xMMmmrr (如 0x1A0200 → 26.2.0)
            if let rvNum = dict["runtime-version"] as? NSNumber {
                let rv = rvNum.uint32Value
                let major = (rv >> 16) & 0xFF
                let minor = (rv >> 8) & 0xFF
                let rev   = rv & 0xFF
                return "\(major).\(minor).\(rev)"
            }
            return "Hardened Runtime"
        }()

        // 9. Hash type
        let hashType: String? = {
            if let algNum = dict["digest-algorithm"] as? NSNumber {
                return Self.algoName(algNum.int32Value)
            }
            return nil
        }()

        // 10. 有效性验证
        let validity = checkValidity(code: code)
        // 10.1 严格验证 (资源封印 / 嵌套代码); 未签名时无从校验
        let computedStrictValidity: CodeSignInfo.Validity =
            (state == .signed || state == .adhoc)
                ? checkStrictValidity(code: code)
                : .untested

        // 11. 公证/分发渠道检测 (沙盒下用 Security 框架 strict 验证替代 spctl)
        let notarization = checkNotarization(
            state: state,
            strictValidity: computedStrictValidity,
            authorities: authorities
        )
        // iOS App Store 应用通常是 Wrapper/<x>.app 包装布局, 不是标准 macOS bundle,
        // strict 验证会因旧式资源封装 (obsolete envelope) 报错, 不代表签名损坏。
        let strictValidity: CodeSignInfo.Validity =
            notarization == .iosAppStore ? .untested : computedStrictValidity

        // 12. 补充字段: 签名时间 / 总签名数 / 选中签名 / 已签 Info.plist 项数
        let signingTime: String? = {
            if let d = dict["signing-time"] as? Date {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f.string(from: d)
            }
            return dict["signing-time"] as? String
        }()
        let totalSignatures = (dict["total-signatures"] as? NSNumber).map { "\($0.intValue)" }
        let chosenSignature = (dict["chosen-signature"] as? NSNumber).map { "\($0.intValue)" }
        let infoPlistEntries = (dict["info-plist"] as? [String: Any]).map { "\($0.count)" }

        // 13. Entitlements (来自 "entitlements-dict" 键)
        var entitlementsRaw: String?
        let entitlements = dict["entitlements-dict"] as? [String: Any]
        if let ent = entitlements {
            // 序列化为 XML plist
            if let data = try? PropertyListSerialization.data(
                fromPropertyList: ent,
                format: .xml,
                options: 0
            ) {
                entitlementsRaw = String(data: data, encoding: .utf8)
            }
        }

        // 13. 合成详情文本
        let detailRaw = synthesizeDetailRaw(
            bundleURL: bundleURL,
            identifier: identifier,
            teamIdentifier: teamIdentifier,
            format: format,
            cdHash: cdHash,
            candidateCDHashFull: candidateCDHashFull,
            flagsHex: flagsHex,
            decodedFlags: decodedFlags,
            runtimeVersion: runtimeVersion,
            signingTime: signingTime,
            totalSignatures: totalSignatures,
            chosenSignature: chosenSignature,
            infoPlistEntries: infoPlistEntries,
            signatureSize: signatureSize,
            platformIdentifier: platformIdentifier,
            source: source,
            hashType: hashType,
            hashChoices: hashChoices,
            signatureType: signatureType,
            authorities: authorities,
            validity: validity,
            notarization: notarization,
            entitlements: entitlements
        )

        return CodeSignInfo(
            state: state,
            validity: validity,
            strictValidity: strictValidity,
            notarization: notarization,
            detailRaw: detailRaw,
            identifier: identifier,
            teamIdentifier: teamIdentifier,
            authorities: authorities,
            cdHash: cdHash,
            candidateCDHashFull: candidateCDHashFull,
            hashType: hashType,
            hashChoices: hashChoices,
            signatureType: signatureType,
            flags: flagsHex,
            decodedFlags: decodedFlags,
            format: format,
            runtimeVersion: runtimeVersion,
            signingTime: signingTime,
            totalSignatures: totalSignatures,
            chosenSignature: chosenSignature,
            infoPlistEntries: infoPlistEntries,
            signatureSize: signatureSize,
            platformIdentifier: platformIdentifier,
            source: source,
            entitlementsRaw: entitlementsRaw,
            entitlements: entitlements,
            error: nil
        )
    }

    // MARK: - Helpers

    private static let CS_ADHOC: UInt32 = 0x00000002

    /// 算法编号 → 名称 (来自 SecCode.h kSecCodeInfoDigestAlgorithm)
    private static func algoName(_ n: Int32) -> String {
        switch n {
        case 1:  return "sha1"
        case 2:  return "sha256"
        case 3:  return "sha256_truncated"
        case 4:  return "sha384"
        default: return "alg=\(n)"
        }
    }

    /// 解码 CodeDirectory flags 位字段为可读字符串数组。
    /// 标注基于实际 codesign 工具在本机 (macOS 26) 的输出, 与旧 xnu/cs_common.h 的命名已不同
    /// (例如 0x2000 旧称 CS_KILL, codesign 现称 "library-validation"; 0x10000 旧称 CS_ENFORCEMENT,
    /// codesign 现称 "runtime" 即 Hardened Runtime)。
    private static func decodeFlags(_ raw: UInt32) -> [String] {
        if raw == 0 { return [] }
        // 位 -> 名称 (按 codesign 工具实际输出顺序排列)
        let knownBits: [(UInt32, String)] = [
            (0x00000001, "valid"),
            (0x00000002, "adhoc"),
            (0x00000004, "get-task-allow"),
            (0x00000008, "installer"),
            (0x00000100, "hard"),
            (0x00000200, "kill"),
            (0x00000400, "expires"),
            (0x00000800, "restrict"),
            (0x00001000, "hard"),                 // 注意: 与 0x100 同名, 需视 codesign 实际输出取舍
            (0x00002000, "library-validation"),
            (0x00004000, "check-expires"),
            (0x00008000, "restrict"),             // 同名: 见上
            (0x00010000, "runtime"),              // Hardened Runtime (CS_ENFORCEMENT)
            (0x00020000, "linker-signed"),        // CS_REQUIRE_LV 旧名, codesign 现称 linker-signed
            (0x00040000, "entitlements-validated")
        ]
        var out: [String] = []
        var seen = Set<String>()
        let knownMask: UInt32 = knownBits.map { $0.0 }.reduce(0, |)
        for (bit, name) in knownBits {
            if raw & bit != 0, !seen.contains(name) {
                out.append(name)
                seen.insert(name)
            }
        }
        let unknown = raw & ~knownMask
        if unknown != 0 {
            out.append(String(format: "unknown(0x%x)", unknown))
        }
        return out
    }

    /// 有效性验证: SecStaticCodeCheckValidity
    /// 附加 kSecCSCheckAllArchitectures, 对 fat 二进制所有切片(arm64/x86_64)都做校验,
    /// 而非仅校验当前主机架构切片。
    private static func checkValidity(code: SecStaticCode) -> CodeSignInfo.Validity {
        let flags = SecCSFlags(rawValue: kSecCSBasicValidateOnly | kSecCSCheckAllArchitectures)
        let status = SecStaticCodeCheckValidity(code, flags, nil)
        return status == errSecSuccess ? .valid : .invalid
    }

    /// 严格验证: 在基础验证之上校验资源封印 (CodeResources)、嵌套代码等。
    /// 资源被篡改/缺失时会失败 (基础验证仍可能通过)。
    private static func checkStrictValidity(code: SecStaticCode) -> CodeSignInfo.Validity {
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures)
        let status = SecStaticCodeCheckValidity(code, flags, nil)
        return status == errSecSuccess ? .valid : .invalid
    }

    /// 公证/分发渠道检测 (沙盒下启发式):
    /// - macOS Software Signing 证书 → Apple 系统签名 (系统自带应用)
    /// - Apple Mac OS Application Signing 证书 → Mac App Store 分发
    /// - Apple iPhone OS Application Signing 证书 → iOS App Store 分发
    /// - Developer ID Application 证书 + strict 验证通过 → 已公证 (Gatekeeper 通过)
    /// - Developer ID Application 证书 + strict 验证失败 → Developer ID 签名 (签名可能有损)
    /// - 其它 → 未公证
    private static func checkNotarization(
        state: CodeSignInfo.SignedState,
        strictValidity: CodeSignInfo.Validity,
        authorities: [String]
    ) -> CodeSignInfo.Notarization {
        switch state {
        case .adhoc, .unsigned, .unknown:
            return .notNotarized
        case .signed:
            // Apple 系统签名 (macOS Software Signing) → 系统自带应用
            if authorities.contains(where: { $0.contains("macOS Software Signing") }) {
                return .appleSystem
            }
            // Mac App Store 应用 (Apple Mac OS Application Signing 证书)
            if authorities.contains(where: { $0.contains("Apple Mac OS Application Signing") }) {
                return .macAppStore
            }
            // iOS App Store 应用 (Apple iPhone OS Application Signing 证书)
            if authorities.contains(where: { $0.contains("Apple iPhone OS Application Signing") }) {
                return .iosAppStore
            }
            // Developer ID 应用: 用 strict 验证判断是否真正通过 Gatekeeper
            let hasDevID = authorities.contains { $0.contains("Developer ID Application") }
            if hasDevID {
                // strict 验证会检查 sealed resources / bundle format 等,
                // basic 验证只检查签名结构, 可能放过签名损坏的应用
                return strictValidity == .valid ? .notarized : .devID
            }
            // 其它 → 未公证
            return .notNotarized
        }
    }

    /// 构造未签名 CodeSignInfo
    private static func makeUnsigned(error: String?) -> CodeSignInfo {
        return CodeSignInfo(
            state: .unsigned,
            validity: .untested,
            strictValidity: .untested,
            notarization: .notNotarized,
            detailRaw: "\(L10n.t(.unsignedDetail))\n\(error ?? "")",
            identifier: nil,
            teamIdentifier: nil,
            authorities: [],
            cdHash: nil,
            candidateCDHashFull: nil,
            hashType: nil,
            hashChoices: nil,
            signatureType: nil,
            flags: nil,
            decodedFlags: [],
            format: nil,
            runtimeVersion: nil,
            signingTime: nil,
            totalSignatures: nil,
            chosenSignature: nil,
            infoPlistEntries: nil,
            signatureSize: nil,
            platformIdentifier: nil,
            source: nil,
            entitlementsRaw: nil,
            entitlements: nil,
            error: error
        )
    }

    /// 合成详情文本 (替代 codesign -dvvv 原始输出, 沙盒下 Security 框架重新组织)
    private static func synthesizeDetailRaw(
        bundleURL: URL,
        identifier: String?,
        teamIdentifier: String?,
        format: String?,
        cdHash: String?,
        candidateCDHashFull: String?,
        flagsHex: String?,
        decodedFlags: [String],
        runtimeVersion: String?,
        signingTime: String?,
        totalSignatures: String?,
        chosenSignature: String?,
        infoPlistEntries: String?,
        signatureSize: String?,
        platformIdentifier: String?,
        source: String?,
        hashType: String?,
        hashChoices: String?,
        signatureType: String?,
        authorities: [String],
        validity: CodeSignInfo.Validity,
        notarization: CodeSignInfo.Notarization,
        entitlements: [String: Any]?
    ) -> String {
        var lines: [String] = []
        lines.append("Bundle: \(bundleURL.lastPathComponent)")
        lines.append("Identifier=\(identifier ?? "—")")
        lines.append("TeamIdentifier=\(teamIdentifier ?? "not set")")
        if let fmt = format { lines.append("Format=\(fmt)") }
        if let cdh = cdHash { lines.append("CDHash=\(cdh)") }
        if let cdf = candidateCDHashFull { lines.append("CandidateCDHashFull=\(cdf)") }
        if let ht = hashType { lines.append("Hash type=\(ht)") }
        if let hc = hashChoices { lines.append("Hash choices=\(hc)") }
        if let sig = signatureType { lines.append("Signature=\(sig)") }
        if let sz = signatureSize { lines.append("Signature size=\(sz)") }
        if let fh = flagsHex {
            let decoded = decodedFlags.isEmpty ? "(none)" : "(\(decodedFlags.joined(separator: ",")))"
            lines.append("CodeDirectory flags=\(fh)\(decoded)")
        }
        if let pi = platformIdentifier { lines.append("Platform identifier=\(pi)") }
        if let src = source { lines.append("Source=\(src)") }
        if let rt = runtimeVersion { lines.append("Runtime Version=\(rt)") }
        if let st = signingTime { lines.append("Signing Time=\(st)") }
        if let ts = totalSignatures { lines.append("Total signatures=\(ts)") }
        if let cs = chosenSignature { lines.append("Chosen signature=\(cs)") }
        if let ip = infoPlistEntries { lines.append("Info.plist entries=\(ip)") }
        lines.append("Validity=\(validity.rawValue)")
        lines.append("Notarization=\(notarization.rawValue)")
        if !authorities.isEmpty {
            lines.append("Authority chain:")
            for a in authorities { lines.append("  - \(a)") }
        }
        if let ent = entitlements, !ent.isEmpty {
            lines.append("Entitlements (\(ent.count) keys):")
            for k in ent.keys.sorted() {
                lines.append("  \(k)")
            }
        } else {
            lines.append("Entitlements: none")
        }
        return lines.joined(separator: "\n")
    }
}
