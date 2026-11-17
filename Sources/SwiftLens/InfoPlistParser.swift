import Foundation

// MARK: - Info.plist 解析

/// 从 .app bundle 的 Info.plist 中读取所有键值，并解析常用字段。
enum InfoPlistParser {

    /// 读取 .app bundle 的 Info.plist 为字典。
    /// 支持两种 bundle 布局:
    ///   - 标准 macOS: Contents/Info.plist
    ///   - iOS 应用 (Apple Silicon "iTMSTransporter" Wrapper): Wrapper/<name>.app/Info.plist
    static func parse(at bundleURL: URL) -> [String: Any]? {
        guard let url = plistURL(at: bundleURL),
              let data = try? Data(contentsOf: url),
              let pl = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return pl
    }

    /// 定位实际使用的 Info.plist（标准布局或 iOS Wrapper 布局）。
    static func plistURL(at bundleURL: URL) -> URL? {
        let standard = bundleURL.appendingPathComponent("Contents/Info.plist")
        if FileManager.default.fileExists(atPath: standard.path) { return standard }
        let wrapperDir = bundleURL.appendingPathComponent("Wrapper")
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: wrapperDir.path) {
            for name in entries where name.hasSuffix(".app") {
                let iosPlist = wrapperDir.appendingPathComponent("\(name)/Info.plist")
                if FileManager.default.fileExists(atPath: iosPlist.path) { return iosPlist }
            }
        }
        return nil
    }

    /// plist 文件格式（XML / Binary / OpenStep）。
    static func formatDescription(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard (try? PropertyListSerialization.propertyList(
            from: data, options: [], format: &format)) != nil else { return nil }
        switch format {
        case .xml:      return "XML"
        case .binary:   return "Binary"
        case .openStep: return "OpenStep"
        default:        return "Unknown"
        }
    }

    /// 将任意 plist 值规整为可展示字符串。
    static func describe(_ value: Any) -> String {
        if let s = value as? String { return s }
        // plist 中 Bool 经 PropertyListSerialization 加载后是 CFBoolean (NSNumber 子类),
        // 单纯 `as? Bool` 或 `as? NSNumber` 都不可靠: NSNumber(value:1) as? Bool 也会成功。
        // 用 CFGetTypeID 区分真正的布尔: 只有 CFBoolean 才走 YES/NO 分支。
        if let n = value as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() {
            return n.boolValue ? "YES" : "NO"
        }
        if let n = value as? NSNumber { return n.stringValue }
        if let d = value as? Data { return "Data (\(d.count) bytes)" }
        if let date = value as? Date { return ISO8601DateFormatter().string(from: date) }
        if let arr = value as? [Any] {
            return arr.map { describe($0) }.joined(separator: ", ")
        }
        if let dict = value as? [String: Any] {
            return dict.map { "\($0.key): \(describe($0.value))" }.joined(separator: ", ")
        }
        return String(describing: value)
    }

    /// 把 plist 字典扁平化为 (key, value) 排序列表，嵌套字典以 "a.b.c" 形式展开。
    static func flatten(_ dict: [String: Any], prefix: String = "") -> [(String, String)] {
        var rows: [(String, String)] = []
        let keys = dict.keys.sorted()
        for key in keys {
            let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
            let value = dict[key]
            if let nested = value as? [String: Any] {
                rows.append(contentsOf: flatten(nested, prefix: fullKey))
            } else if let arr = value as? [Any] {
                if arr.contains(where: { $0 is [String: Any] }) {
                    for (i, el) in arr.enumerated() {
                        if let d = el as? [String: Any] {
                            rows.append(contentsOf: flatten(d, prefix: "\(fullKey)[\(i)]"))
                        } else {
                            rows.append(("\(fullKey)[\(i)]", describe(el)))
                        }
                    }
                } else {
                    rows.append((fullKey, describe(arr)))
                }
            } else {
                rows.append((fullKey, describe(value ?? "")))
            }
        }
        return rows
    }
}