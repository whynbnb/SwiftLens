import Foundation
import Security

// MARK: - 代码签名信息

struct CodeSignInfo {
    enum SignedState: String {
        case signed       = "已签名 (Signed)"
        case adhoc        = "Ad-hoc 签名"
        case unsigned     = "未签名 (Not signed)"
        case unknown      = "未知"
    }
    enum Validity: String {
        case valid    = "通过 (Valid)"
        case invalid  = "无效 (Invalid)"
        case untested = "未验证"
    }
    enum Notarization: String {
        case notarized      = "已公证 (Notarized)"
        case notNotarized   = "未公证"
        case unknown        = "未知"
    }

    let state: SignedState
    let validity: Validity
    let notarization: Notarization

    /// 合成的签名详情文本（替代旧版 codesign -dvvv 输出）
    let detailRaw: String
    let identifier: String?
    let teamIdentifier: String?
    let authorities: [String]        // 证书链 subject 列表
    let cdHash: String?              // 十六进制字符串
    let hashType: String?            // sha256 / sha1
    let signatureType: String?       // "adhoc" / "Developer ID" / "adhoc" 等
    let flags: String?               // 原始 flags 十六进制
    let decodedFlags: [String]       // 解码后的标志列表
    let format: String?
    let runtimeVersion: String?      // Hardened Runtime 时填 "Hardened Runtime", 否则 nil
    let entitlementsRaw: String?     // 由 entitlements dict 序列化的 XML plist
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
            return makeUnsigned(error: "SecStaticCodeCreateWithPath 失败: status=\(createStatus)")
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
            return makeUnsigned(error: "SecCodeCopySigningInformation 失败: status=\(signStatus)")
        }

        // 3. 提取字段 (dict 键名来自 SecCode.h, 部分常量未导出到 Swift)
        let identifier   = dict["identifier"] as? String
        let teamIdentifier = dict["teamid"] as? String
        let format       = dict["format"] as? String
        let flagsValue   = (dict["flags"] as? NSNumber)?.uint32Value
        // cdhashes 是数组 (universal binary 每个切片一个), 取第一个
        let cdHashData   = (dict["cdhashes"] as? [Data])?.first
        let certs        = (dict["certificates"] as? [SecCertificate]) ?? []

        // 4. CDHash → hex
        let cdHash = cdHashData.map { $0.map { String(format: "%02x", $0) }.joined() }

        // 5. flags 解码
        let flagsHex = flagsValue.map { String(format: "0x%x", $0) }
        let decodedFlags = decodeFlags(flagsValue ?? 0)

        // 6. 证书链 → authorities
        let authorities = certs.map { cert -> String in
            if let summary = SecCertificateCopySubjectSummary(cert) {
                return summary as String
            }
            return "(未知证书)"
        }

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
            // dict["runtime-version"] 是编码后的数字 0xMMmmrr
            if let rvNum = dict["runtime-version"] as? NSNumber {
                let rv = rvNum.uint32Value
                let major = (rv >> 16) & 0xFF
                let minor = (rv >> 8) & 0xFF
                let rev   = rv & 0xFF
                return "Hardened Runtime \(major).\(minor).\(rev)"
            }
            return "Hardened Runtime"
        }()

        // 9. Hash type
        let hashType: String? = {
            if let algNum = dict["digest-algorithm"] as? NSNumber {
                switch algNum.int32Value {
                case 1:  return "sha1"
                case 2:  return "sha256"
                case 3:  return "sha256_truncated"
                case 4:  return "sha384"
                default: return "alg=\(algNum.int32Value)"
                }
            }
            return nil
        }()

        // 10. 有效性验证
        let validity = checkValidity(code: code)

        // 11. 公证检测 (沙盒下无法用 spctl, 启发式判断)
        let notarization = checkNotarization(
            state: state,
            validity: validity,
            authorities: authorities
        )

        // 12. Entitlements (来自 "entitlements-dict" 键)
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
            flagsHex: flagsHex,
            decodedFlags: decodedFlags,
            runtimeVersion: runtimeVersion,
            hashType: hashType,
            signatureType: signatureType,
            authorities: authorities,
            validity: validity,
            notarization: notarization,
            entitlements: entitlements
        )

        return CodeSignInfo(
            state: state,
            validity: validity,
            notarization: notarization,
            detailRaw: detailRaw,
            identifier: identifier,
            teamIdentifier: teamIdentifier,
            authorities: authorities,
            cdHash: cdHash,
            hashType: hashType,
            signatureType: signatureType,
            flags: flagsHex,
            decodedFlags: decodedFlags,
            format: format,
            runtimeVersion: runtimeVersion,
            entitlementsRaw: entitlementsRaw,
            entitlements: entitlements,
            error: nil
        )
    }

    // MARK: - Helpers

    private static let CS_ADHOC: UInt32 = 0x00000002

    /// 解码 flags 位字段为可读字符串数组
    private static func decodeFlags(_ raw: UInt32) -> [String] {
        if raw == 0 { return [] }
        var out: [String] = []
        // 逐位匹配 (排除冲突位, 单独处理)
        let knownBits: [(UInt32, String)] = [
            (0x00000001, "valid"),
            (0x00000002, "adhoc"),
            (0x00000004, "get-task-allow"),
            (0x00000008, "installer"),
            (0x00000100, "force-hard"),
            (0x00000200, "force-kill"),
            (0x00000400, "force-expires"),
            (0x00001000, "hard"),
            (0x00002000, "kill"),
            (0x00004000, "check-expires"),
            (0x00008000, "restrict"),
            (0x00010000, "runtime"),          // Hardened Runtime
            // 0x00020000 既有 require-lv 又有 linker-signed, 无法从 flags 单独区分; 统一标 runtime-lv
            (0x00020000, "require-lv/linker-signed"),
            (0x00040000, "entitlements-validated")
        ]
        for (bit, name) in knownBits {
            if raw & bit != 0 { out.append(name) }
        }
        // 检测未识别的高位
        let knownMask: UInt32 = knownBits.map { $0.0 }.reduce(0, |)
        let unknown = raw & ~knownMask
        if unknown != 0 {
            out.append(String(format: "unknown(0x%x)", unknown))
        }
        return out
    }

    /// 有效性验证: SecStaticCodeCheckValidity
    private static func checkValidity(code: SecStaticCode) -> CodeSignInfo.Validity {
        let flags = SecCSFlags(rawValue: kSecCSBasicValidateOnly)
        let status = SecStaticCodeCheckValidity(code, flags, nil)
        return status == errSecSuccess ? .valid : .invalid
    }

    /// 公证检测 (沙盒下启发式): signed + valid + Developer ID Application 证书 → 已公证
    /// 注: 无法 100% 准确区分 "带票据" 与 "未带票据", 这里给最可能的结果
    private static func checkNotarization(
        state: CodeSignInfo.SignedState,
        validity: CodeSignInfo.Validity,
        authorities: [String]
    ) -> CodeSignInfo.Notarization {
        switch state {
        case .adhoc, .unsigned, .unknown:
            return .notNotarized
        case .signed:
            // 只有 Developer ID Application 签名才涉及公证
            let hasDevID = authorities.contains { $0.contains("Developer ID Application") }
            if !hasDevID {
                // Apple Mac OS Application Signing / 其它 Apple 系统签名不需要 notarization
                return .notNotarized
            }
            if validity == .valid {
                // Developer ID + 有效 → 大概率已公证 (Gatekeeper 已通过)
                return .notarized
            }
            return .notNotarized
        }
    }

    /// 构造未签名 CodeSignInfo
    private static func makeUnsigned(error: String?) -> CodeSignInfo {
        return CodeSignInfo(
            state: .unsigned,
            validity: .untested,
            notarization: .notNotarized,
            detailRaw: "(未签名)\n\(error ?? "")",
            identifier: nil,
            teamIdentifier: nil,
            authorities: [],
            cdHash: nil,
            hashType: nil,
            signatureType: nil,
            flags: nil,
            decodedFlags: [],
            format: nil,
            runtimeVersion: nil,
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
        flagsHex: String?,
        decodedFlags: [String],
        runtimeVersion: String?,
        hashType: String?,
        signatureType: String?,
        authorities: [String],
        validity: CodeSignInfo.Validity,
        notarization: CodeSignInfo.Notarization,
        entitlements: [String: Any]?
    ) -> String {
        var lines: [String] = []
        lines.append("Bundle: \(bundleURL.lastPathComponent)")
        lines.append("Identifier=\(identifier ?? "—")")
        if let team = teamIdentifier { lines.append("TeamIdentifier=\(team)") }
        if let fmt = format { lines.append("Format=\(fmt)") }
        if let cdh = cdHash { lines.append("CDHash=\(cdh)") }
        if let ht = hashType { lines.append("Hash type=\(ht)") }
        if let sig = signatureType { lines.append("Signature=\(sig)") }
        if let fh = flagsHex {
            let decoded = decodedFlags.isEmpty ? "" : "(\(decodedFlags.joined(separator: ",")))"
            lines.append("CodeDirectory flags=\(fh)\(decoded)")
        }
        if let rt = runtimeVersion { lines.append("Runtime Version=\(rt)") }
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
