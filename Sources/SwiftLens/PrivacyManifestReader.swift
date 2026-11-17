import Foundation

// MARK: - PrivacyInfo.xcprivacy / App Store 收据

/// 一份 PrivacyInfo.xcprivacy 的解析结果。
struct PrivacyManifest: Identifiable {
    struct AccessedAPI: Identifiable {
        var id: String { "\(type)|\(reasons.joined(separator: ","))" }
        let type: String
        let reasons: [String]
    }

    var id: String { path }
    let path: String                  // 相对 app bundle 的路径
    let accessedAPIs: [AccessedAPI]
    let collectedData: [String]
    let trackingDomains: [String]
    let tracking: Bool?

    var isEmpty: Bool {
        accessedAPIs.isEmpty && collectedData.isEmpty
            && trackingDomains.isEmpty && tracking == nil
    }
}

enum PrivacyManifestReader {

    /// 扫描主包、iOS Wrapper 与所有子 bundle 中的 PrivacyInfo.xcprivacy。
    static func read(bundleURL: URL, subBundles: [SubBundle]) -> [PrivacyManifest] {
        var candidates: [URL] = [
            bundleURL.appendingPathComponent("Contents/Resources/PrivacyInfo.xcprivacy"),
            bundleURL.appendingPathComponent("PrivacyInfo.xcprivacy")
        ]
        // 子 bundle: 常见 3 种布局
        for sub in subBundles {
            let subURL = bundleURL.appendingPathComponent(sub.relativePath)
            candidates.append(subURL.appendingPathComponent("PrivacyInfo.xcprivacy"))
            candidates.append(subURL.appendingPathComponent("Contents/Resources/PrivacyInfo.xcprivacy"))
            candidates.append(subURL.appendingPathComponent("Versions/Current/Resources/PrivacyInfo.xcprivacy"))
            candidates.append(subURL.appendingPathComponent("Resources/PrivacyInfo.xcprivacy"))
        }
        // iOS Wrapper: 主 app 根目录 + Frameworks 一级子目录
        let wrapper = bundleURL.appendingPathComponent("Wrapper")
        if let apps = try? FileManager.default.contentsOfDirectory(atPath: wrapper.path) {
            for app in apps where app.hasSuffix(".app") {
                let root = wrapper.appendingPathComponent(app)
                candidates.append(root.appendingPathComponent("PrivacyInfo.xcprivacy"))
                candidates.append(root.appendingPathComponent("Contents/Resources/PrivacyInfo.xcprivacy"))
                let frameworks = root.appendingPathComponent("Frameworks")
                if let subs = try? FileManager.default.contentsOfDirectory(atPath: frameworks.path) {
                    for sub in subs {
                        let base = frameworks.appendingPathComponent(sub)
                        candidates.append(base.appendingPathComponent("PrivacyInfo.xcprivacy"))
                        candidates.append(base.appendingPathComponent("Resources/PrivacyInfo.xcprivacy"))
                    }
                }
            }
        }

        var seen = Set<String>()
        var manifests: [PrivacyManifest] = []
        for url in candidates {
            let path = url.standardizedFileURL.path
            guard !seen.contains(path), FileManager.default.fileExists(atPath: path) else { continue }
            seen.insert(path)
            guard let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(
                    from: data, options: [], format: nil) as? [String: Any]
            else { continue }
            let relative = path.replacingOccurrences(of: bundleURL.standardizedFileURL.path + "/", with: "")
            manifests.append(parse(plist: plist, path: relative))
        }
        return manifests.sorted { $0.path < $1.path }
    }

    private static func parse(plist: [String: Any], path: String) -> PrivacyManifest {
        var apis: [PrivacyManifest.AccessedAPI] = []
        if let raw = plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]] {
            for item in raw {
                let type = (item["NSPrivacyAccessedAPIType"] as? String) ?? "—"
                let reasons = (item["NSPrivacyAccessedAPITypeReasons"] as? [Any])?
                    .map { InfoPlistParser.describe($0) } ?? []
                apis.append(PrivacyManifest.AccessedAPI(type: type, reasons: reasons))
            }
        }
        let collected = (plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])?
            .map { ($0["NSPrivacyCollectedDataType"] as? String) ?? "—" } ?? []
        let domains = (plist["NSPrivacyTrackingDomains"] as? [Any])?
            .map { InfoPlistParser.describe($0) } ?? []
        let tracking: Bool? = {
            if let b = plist["NSPrivacyTracking"] as? Bool { return b }
            if let n = plist["NSPrivacyTracking"] as? NSNumber { return n.boolValue }
            return nil
        }()
        return PrivacyManifest(
            path: path,
            accessedAPIs: apis,
            collectedData: collected,
            trackingDomains: domains,
            tracking: tracking
        )
    }

    /// App Store 收据（MAS 应用通常包含 Contents/_MASReceipt/receipt）。
    static func hasMASReceipt(bundleURL: URL) -> Bool {
        let candidates = [
            bundleURL.appendingPathComponent("Contents/_MASReceipt/receipt"),
            bundleURL.appendingPathComponent("_MASReceipt/receipt")
        ]
        return candidates.contains { FileManager.default.fileExists(atPath: $0.path) }
    }
}
