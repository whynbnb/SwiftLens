import SwiftUI
import AppKit

// MARK: - 文件树

/// 「文件树」分区：按体积排序的 bundle 目录树，标注 macOS 经典结构。
struct BundleTreeSection: View {
    let tree: BundleTree
    let bundleURL: URL
    let appIcon: NSImage?
    let onHide: () -> Void

    @State private var expanded: Set<String>

    init(tree: BundleTree, bundleURL: URL, appIcon: NSImage?,
         onHide: @escaping () -> Void) {
        self.tree = tree
        self.bundleURL = bundleURL
        self.appIcon = appIcon
        self.onHide = onHide
        _expanded = State(initialValue: Self.defaultExpanded(tree.root))
    }

    var body: some View {
        SectionView(L10n.t(.bundleTree), subtitle: subtitle,
                    leading: hideButton, trailing: headerActions) {
            VStack(alignment: .leading, spacing: 0) {
                BundleNodeRow(node: tree.root,
                              depth: 0,
                              expanded: $expanded,
                              totalSize: tree.root.size,
                              bundleURL: bundleURL,
                              appIcon: appIcon)
            }
            .padding(.vertical, 2)

            if tree.isTruncated {
                Label(L10n.t(.treeTruncated), systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        let size = ByteSize.string(tree.root.size)
        return "\(tree.totalFiles) \(L10n.t(.treeFileUnit)) · \(size)"
    }

    /// 紧贴标题的隐藏按钮，避免与右侧展开/折叠误触
    private var hideButton: AnyView {
        AnyView(
            Button(action: onHide) {
                Image(systemName: "eye.slash")
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .help(L10n.t(.hideFileTree))
        )
    }

    /// 标题栏右侧：展开常用 / 展开所有 / 全部折叠
    private var headerActions: AnyView {
        AnyView(
            HStack(spacing: 10) {
                Button(L10n.t(.treeExpandCommon)) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        expanded = Self.defaultExpanded(tree.root, allCommon: true)
                    }
                }
                .buttonStyle(.link)
                .font(.caption)
                Button(L10n.t(.treeExpandAll)) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        expanded = Self.expandableIDs(tree.root)
                    }
                }
                .buttonStyle(.link)
                .font(.caption)
                Button(L10n.t(.treeCollapseAll)) {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded = [] }
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        )
    }

    /// 默认展开：根 + Contents；「展开常用」再展开标准子目录。
    private static func defaultExpanded(_ root: BundleNode, allCommon: Bool = false) -> Set<String> {
        var set: Set<String> = [root.id]
        let commonRoles: Set<BundleRole> = [
            .contents, .macos, .resources, .frameworks, .sharedFrameworks,
            .plugins, .xpcServices, .helpers, .library, .codeSignature, .wrapper
        ]
        func walk(_ node: BundleNode) {
            if node.isDirectory, let role = node.role, commonRoles.contains(role) {
                if !allCommon && role != .contents { return }
                set.insert(node.id)
                for child in node.children { walk(child) }
            }
        }
        for child in root.children { walk(child) }
        return set
    }

    /// 所有可展开目录（用于「展开所有」）。
    private static func expandableIDs(_ root: BundleNode) -> Set<String> {
        var set: Set<String> = []
        func walk(_ node: BundleNode) {
            if node.isDirectory, !node.children.isEmpty {
                set.insert(node.id)
            }
            for child in node.children { walk(child) }
        }
        walk(root)
        return set
    }
}

// MARK: - 单行 / 递归子树

private struct BundleNodeRow: View {
    let node: BundleNode
    let depth: Int
    @Binding var expanded: Set<String>
    let totalSize: UInt64
    let bundleURL: URL
    let appIcon: NSImage?

    @State private var hovered = false

    private var isExpanded: Bool { expanded.contains(node.id) }
    private var canExpand: Bool { node.isDirectory && !node.children.isEmpty }
    private var isRoot: Bool { node.path.isEmpty }
    private var percentText: String? {
        guard node.isDirectory, totalSize > 0, node.size > 0 else { return nil }
        return String(format: "%.1f%%", Double(node.size) / Double(totalSize) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
                .padding(.vertical, 2)
                .padding(.horizontal, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hovered && canExpand
                              ? Color.secondary.opacity(0.09)
                              : Color.clear)
                )
                .padding(.leading, CGFloat(depth) * 16)
                .contentShape(Rectangle())
                .onHover { hovered = $0 }
                .onTapGesture {
                    guard canExpand else { return }
                    withAnimation(.easeInOut(duration: 0.12)) { toggle() }
                }
            if isExpanded {
                ForEach(node.children) { child in
                    BundleNodeRow(node: child,
                                  depth: depth + 1,
                                  expanded: $expanded,
                                  totalSize: totalSize,
                                  bundleURL: bundleURL,
                                  appIcon: appIcon)
                }
            }
        }
    }

    private var row: some View {
        HStack(spacing: 7) {
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 10)
                .opacity(canExpand ? 1 : 0)

            icon

            Text(displayName)
                .font(.system(.callout, weight: node.isDirectory ? .medium : .regular))
                .foregroundStyle(node.isOmitted ? Color.secondary : Color.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(fullPath)

            if let role = node.role, role != .bundleRoot,
               role.title.caseInsensitiveCompare(node.name) != .orderedSame {
                Text(role.title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(.quaternary.opacity(0.45)))
                    .help("\(role.pattern)\n\(role.detail)")
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .help("\(role.pattern)\n\(role.detail)")
            }

            Spacer(minLength: 12)

            if !node.isOmitted {
                Text(sizeText)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .help(percentText.map { "\(sizeText) · \($0)" } ?? sizeText)
            }
        }
        .contextMenu {
            Button(L10n.t(.treeCopyPath)) {
                copyToPasteboard(node.path.isEmpty ? node.name : node.path)
            }
            Button(L10n.t(.revealInFinder)) {
                let url = node.path.isEmpty
                    ? bundleURL
                    : bundleURL.appendingPathComponent(node.path)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        if isRoot, let appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: iconName)
                .font(.system(size: 12))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 16)
        }
    }

    private var displayName: String {
        if node.isOmitted {
            return "\(node.name) · \(node.fileCount)"
        }
        return node.name
    }

    private var iconName: String {
        if node.isOmitted { return "ellipsis.circle" }
        if let role = node.role { return role.symbol }
        if node.isDirectory { return "folder" }
        return "doc"
    }

    private var fullPath: String {
        node.path.isEmpty ? bundleURL.path : bundleURL.path + "/" + node.path
    }

    private var sizeText: String {
        ByteSize.string(node.size)
    }

    private func toggle() {
        if isExpanded {
            expanded.remove(node.id)
        } else {
            expanded.insert(node.id)
        }
    }
}

// MARK: - 搜索辅助

extension BundleTree {
    /// 深度优先列出节点，供全局搜索使用。
    func flattenedNodes(limit: Int = 400) -> [BundleNode] {
        var out: [BundleNode] = []
        func walk(_ node: BundleNode) {
            guard out.count < limit else { return }
            if !node.isOmitted { out.append(node) }
            for child in node.children { walk(child) }
        }
        walk(root)
        return out
    }
}
