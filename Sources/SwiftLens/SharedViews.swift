import SwiftUI
import AppKit

/// 复制到剪贴板
func copyToPasteboard(_ string: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
}

/// 与应用内语言一致的体积格式化。
/// ByteCountFormatter 跟随系统 Locale，英文界面下会出现中文单位（如「字节」），
/// 因此这里自行选择单位与小数位。
enum ByteSize {
    static func string(_ bytes: UInt64) -> String {
        let units = ["KB", "MB", "GB", "TB", "PB"]
        if bytes < 1000 {
            return "\(bytes) \(L10n.t(.bytesUnit))"
        }
        var value = Double(bytes) / 1000
        var index = 0
        while value >= 1000, index < units.count - 1 {
            value /= 1000
            index += 1
        }

        let number: String
        if value >= 100 {
            number = String(format: "%.0f", value)
        } else if value >= 10 {
            number = trimmed(String(format: "%.1f", value))
        } else {
            number = trimmed(String(format: "%.2f", value))
        }
        return "\(number) \(units[index])"
    }

    private static func trimmed(_ s: String) -> String {
        var out = s
        while out.hasSuffix("0") { out.removeLast() }
        if out.hasSuffix(".") { out.removeLast() }
        return out
    }
}

/// 单行 键 -> 值 展示，支持长按 / 右键复制。
/// 超长键名改为「键在上、值在下」，避免在单词中间换行。
struct RowView: View {
    let key: String
    let value: String
    var warning: String? = nil

    private var isLongKey: Bool { key.count > 32 }

    var body: some View {
        Group {
            if isLongKey {
                VStack(alignment: .leading, spacing: 2) {
                    Text(key)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help(key)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        valueText
                        warningIcon
                    }
                    .padding(.leading, 12)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(key)
                        .font(.system(.body, design: .default))
                        .foregroundStyle(.secondary)
                        .frame(width: 240, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(key)
                    valueText
                    warningIcon
                }
            }
        }
        .contextMenu {
            Button(L10n.t(.copyValue)) { copyToPasteboard(value) }
            Button(L10n.t(.copyKeyValue)) { copyToPasteboard("\(key): \(value)") }
        }
    }

    private var valueText: some View {
        Text(value.isEmpty ? "—" : value)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(value.isEmpty ? "" : value)
    }

    @ViewBuilder
    private var warningIcon: some View {
        if let warning {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .help(warning)
        }
    }
}

/// 标题分区。可选在标题栏右侧放置操作按钮。
struct SectionView<Content: View>: View {
    let title: String
    let subtitle: String?
    let leading: AnyView?
    let trailing: AnyView?
    @ViewBuilder let content: () -> Content

    init(_ title: String, subtitle: String? = nil,
         leading: AnyView? = nil, trailing: AnyView? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                if let s = subtitle {
                    Text(s)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let leading {
                    leading
                }
                Spacer()
                if let trailing {
                    trailing
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
            Divider().opacity(0.3)
        }
    }
}

/// 通用占用提示。
struct PlaceholderRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(.body).italic())
            .foregroundStyle(.secondary)
    }
}