import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 版本对比窗口

struct CompareView: View {
    @EnvironmentObject private var appState: AppState

    @State private var oldURL: URL?
    @State private var newURL: URL?
    @State private var oldInfo: AppInfo?
    @State private var newInfo: AppInfo?
    @State private var isLoading = false
    @State private var loadToken: UInt = 0
    @State private var forceCompare = false
    @State private var showUnchanged = false
    @State private var filter = ""
    @State private var collapsedSections: Set<String> = []
    @State private var didPrefill = false
    @State private var comparison: AppComparison?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                slotsRow
                if isLoading {
                    loadingCard
                } else if let comparison {
                    summaryCard(comparison)
                    if comparison.match.level == .uncertain && !forceCompare {
                        uncertainCard(comparison)
                    } else {
                        if forceCompare && comparison.match.level == .uncertain {
                            forcedBanner
                        }
                        if comparison.caution {
                            cautionBanner
                        }
                        controlsRow
                        sectionsView(comparison)
                    }
                } else {
                    emptyCard
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 980, minHeight: 660)
        .navigationTitle(L10n.t(.compareWindowTitle))
        .onAppear { prefillFromMainWindow() }
        .onChange(of: oldURL) { _, _ in reload() }
        .onChange(of: newURL) { _, _ in reload() }
        .onChange(of: appState.language) { _, _ in rebuildComparison() }
        .onChange(of: appState.currentAppURL) { _, url in
            if newURL == nil, let url { newURL = url }
        }
    }

    // MARK: 顶部两个版本槽

    private var slotsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            CompareSlotView(title: L10n.t(.cmpOldVersion),
                            url: oldURL,
                            info: oldInfo,
                            onPick: { pick(slot: .old) },
                            onClear: { oldURL = nil; oldInfo = nil },
                            onDropURL: { url in set(url, for: .old) })
            Button {
                swap(&oldURL, &newURL)
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help(L10n.t(.cmpSwap))
            .disabled(oldURL == nil && newURL == nil)
            CompareSlotView(title: L10n.t(.cmpNewVersion),
                            url: newURL,
                            info: newInfo,
                            onPick: { pick(slot: .new) },
                            onClear: { newURL = nil; newInfo = nil },
                            onDropURL: { url in set(url, for: .new) })
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(L10n.t(.cmpAnalyzing)).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.25)))
    }

    private var emptyCard: some View {
        Text(L10n.t(.cmpReadyHint))
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.25)))
    }

    // MARK: 概览

    private func summaryCard(_ cmp: AppComparison) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(versionText(cmp.old)).font(.title3.weight(.semibold)).monospacedDigit()
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                Text(versionText(cmp.new)).font(.title3.weight(.semibold)).monospacedDigit()
                Spacer()
                matchBadge(cmp.match)
            }
            HStack(spacing: 18) {
                stat(L10n.t(.cmpDifferences), "\(cmp.changedCount)")
                stat(L10n.t(.cmpSizeDelta), sizeDeltaText(cmp))
                stat(L10n.t(.cmpFileCount), fileDeltaText(cmp))
                stat(L10n.t(.cmpSimilarity), "\(cmp.match.similarity)%")
            }
            if !cmp.match.evidence.isEmpty || !cmp.match.concerns.isEmpty {
                HStack(alignment: .top, spacing: 24) {
                    if !cmp.match.evidence.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.t(.cmpEvidence)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(cmp.match.evidence, id: \.self) { text in
                                Label(text, systemImage: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    if !cmp.match.concerns.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.t(.cmpConcerns)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(cmp.match.concerns, id: \.self) { text in
                                Label(text, systemImage: "exclamationmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.25)))
    }

    private func matchBadge(_ match: SoftwareMatchResult) -> some View {
        let (text, color): (String, Color) = {
            switch match.level {
            case .confirmed: return (L10n.t(.cmpIdentitySame), .green)
            case .likely:    return (L10n.t(.cmpIdentityLikely), .orange)
            case .uncertain: return (L10n.t(.cmpIdentityUncertain), .gray)
            }
        }()
        return Badge(text: text, color: color)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13, weight: .medium)).monospacedDigit()
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)
            TextField(L10n.t(.cmpFilterPlaceholder), text: $filter)
                .textFieldStyle(.plain)
            if !filter.isEmpty {
                Button { filter = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Divider().frame(height: 14)
            Toggle(L10n.t(.cmpShowUnchanged), isOn: $showUnchanged)
                .toggleStyle(.checkbox)
        }
        .font(.caption)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.25)))
    }

    private var forcedBanner: some View {
        Label(L10n.t(.cmpForced), systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.orange.opacity(0.1)))
    }

    private var cautionBanner: some View {
        Label(L10n.t(.cmpCaution), systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.orange.opacity(0.1)))
    }

    private func uncertainCard(_ cmp: AppComparison) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.t(.cmpIdentityUncertain), systemImage: "questionmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(L10n.t(.cmpIdentityHint))
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Button(L10n.t(.cmpForceCompare)) { forceCompare = true }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(.orange.opacity(0.08)))
    }

    // MARK: 差异分区

    @ViewBuilder
    private func sectionsView(_ cmp: AppComparison) -> some View {
        let visible = cmp.sections.compactMap { section -> (DiffSection, [DiffItem])? in
            let items = visibleItems(section)
            return items.isEmpty ? nil : (section, items)
        }
        if visible.isEmpty {
            Text(L10n.t(.cmpNoChanges))
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.25)))
        } else {
            ForEach(visible, id: \.0.id) { section, items in
                DiffSectionCard(section: section,
                                items: items,
                                isExpanded: Binding(
                                    get: { !collapsedSections.contains(section.id) },
                                    set: { expanded in
                                        if expanded { collapsedSections.remove(section.id) }
                                        else { collapsedSections.insert(section.id) }
                                    }
                                ))
            }
        }
    }

    private func visibleItems(_ section: DiffSection) -> [DiffItem] {
        var items = showUnchanged ? section.items : section.items.filter(\.hasChange)
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return items }
        items = items.filter { item in
            item.label.lowercased().contains(query)
                || (item.oldValue ?? "").lowercased().contains(query)
                || (item.newValue ?? "").lowercased().contains(query)
        }
        return items
    }

    // MARK: 文本辅助

    private func versionText(_ info: AppInfo) -> String {
        let name = info.displayName ?? info.bundleName ?? info.bundleURL.deletingPathExtension().lastPathComponent
        let version = [info.bundleShortVersion, info.bundleVersion.map { "(\($0))" }]
            .compactMap { $0 }.joined(separator: " ")
        return version.isEmpty ? name : "\(name) \(version)"
    }

    private func sizeDeltaText(_ cmp: AppComparison) -> String {
        let delta = cmp.sizeDelta
        let sign = delta > 0 ? "+" : delta < 0 ? "−" : ""
        return "\(sign)\(ByteSize.string(UInt64(abs(delta))))"
    }

    private func fileDeltaText(_ cmp: AppComparison) -> String {
        let delta = cmp.fileDelta
        let sign = delta > 0 ? "+" : delta < 0 ? "−" : ""
        return "\(sign)\(abs(delta))"
    }

    // MARK: 选择 / 加载

    private enum Slot { case old, new }

    private func pick(slot: Slot) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.title = L10n.t(.cmpPickApp)
        if panel.runModal() == .OK, let url = panel.url {
            set(url, for: slot)
        }
    }

    private func set(_ url: URL, for slot: Slot) {
        forceCompare = false
        switch slot {
        case .old: oldURL = url
        case .new: newURL = url
        }
    }

    private func swap(_ lhs: inout URL?, _ rhs: inout URL?) {
        let tmp = lhs
        lhs = rhs
        rhs = tmp
        forceCompare = false
    }

    private func prefillFromMainWindow() {
        guard !didPrefill else { return }
        didPrefill = true
        if newURL == nil, let current = appState.currentAppURL {
            newURL = current
        }
    }

    private func reload() {
        guard let old = oldURL, let new = newURL else {
            oldInfo = nil
            newInfo = nil
            comparison = nil
            isLoading = false
            return
        }
        loadToken &+= 1
        let token = loadToken
        isLoading = true
        comparison = nil
        // 预填自「最近打开」的 URL 没有长期读取权限，这里用主窗口留下的书签恢复
        let oldTarget = readingTarget(for: old)
        let newTarget = readingTarget(for: new)
        DispatchQueue.global(qos: .userInitiated).async {
            let oldAccess = oldTarget.startAccessingSecurityScopedResource()
            let newAccess = newTarget.startAccessingSecurityScopedResource()
            let loadedOld = AppInfoLoader.load(url: oldTarget)
            let loadedNew = AppInfoLoader.load(url: newTarget)
            if oldAccess { oldTarget.stopAccessingSecurityScopedResource() }
            if newAccess { newTarget.stopAccessingSecurityScopedResource() }
            DispatchQueue.main.async {
                guard token == loadToken else { return }
                oldInfo = loadedOld
                newInfo = loadedNew
                comparison = AppComparator.compare(old: loadedOld, new: loadedNew)
                isLoading = false
            }
        }
    }

    /// 对比窗口预填的是主窗口当前 app：若只有书签权限，解析书签后再读取。
    private func readingTarget(for url: URL) -> URL {
        guard appState.currentAppURL?.standardizedFileURL.path == url.standardizedFileURL.path,
              let data = appState.currentAppBookmark
        else { return url }
        var stale = false
        return (try? URL(resolvingBookmarkData: data,
                         options: [.withSecurityScope],
                         relativeTo: nil,
                         bookmarkDataIsStale: &stale)) ?? url
    }

    /// 语言切换后重建文案（判定依据 / 分区标题都是运行时本地化的）。
    private func rebuildComparison() {
        guard let oldInfo, let newInfo else { return }
        comparison = AppComparator.compare(old: oldInfo, new: newInfo)
    }
}

// MARK: - 版本槽

private struct CompareSlotView: View {
    let title: String
    let url: URL?
    let info: AppInfo?
    let onPick: () -> Void
    let onClear: () -> Void
    let onDropURL: (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if url != nil {
                    Button(L10n.t(.cmpChange), action: onPick)
                        .buttonStyle(.link).font(.caption)
                    Button(L10n.t(.clear), action: onClear)
                        .buttonStyle(.link).font(.caption).foregroundStyle(.red)
                }
            }
            if let info {
                HStack(alignment: .top, spacing: 10) {
                    if let icon = info.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 40, height: 40)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.displayName ?? info.bundleName
                             ?? info.bundleURL.deletingPathExtension().lastPathComponent)
                            .font(.headline)
                        Text(versionLine(info))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(info.bundleIdentifier ?? "—")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Text(url?.path ?? "")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Button(action: onPick) {
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 20, weight: .light))
                        Text(L10n.t(.cmpDropHint))
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: 74)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.25)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTargeted ? Color.accentColor : Color.clear,
                              style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { dropped, _ in
                guard let dropped, dropped.pathExtension.lowercased() == "app" else { return }
                DispatchQueue.main.async { onDropURL(dropped) }
            }
            return true
        }
    }

    private func versionLine(_ info: AppInfo) -> String {
        let v = info.bundleShortVersion ?? "—"
        if let b = info.bundleVersion, !b.isEmpty { return "\(v) (\(b))" }
        return v
    }
}

// MARK: - 差异分区卡片

private struct DiffSectionCard: View {
    let section: DiffSection
    let items: [DiffItem]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(section.title)
                        .font(.headline)
                    Text("\(section.changedCount) \(L10n.t(.cmpChangedUnit))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                let rows = VStack(alignment: .leading, spacing: 2) {
                    ForEach(items) { item in
                        DiffRowView(item: item)
                    }
                }
                if items.count > 60 {
                    ScrollView {
                        rows
                    }
                    .frame(maxHeight: 420)
                } else {
                    rows
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
    }
}

// MARK: - 单行差异

private struct DiffRowView: View {
    let item: DiffItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 10))
                .foregroundStyle(iconColor)
                .frame(width: 12)
            Text(item.label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 230, alignment: .leading)
                .lineLimit(2)
                .truncationMode(.middle)
                .help(item.label)
            valueText(item.oldValue, color: oldColor)
            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
            valueText(item.newValue, color: newColor)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 4).fill(rowBackground))
    }

    private func valueText(_ text: String?, color: Color) -> some View {
        Text(text ?? "—")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var oldColor: Color {
        switch item.kind {
        case .removed:  return .red
        case .changed:  return .red.opacity(0.85)
        case .added:    return .secondary.opacity(0.5)
        case .unchanged: return .secondary
        }
    }

    private var newColor: Color {
        switch item.kind {
        case .added:    return .green
        case .changed:  return .green
        case .removed:  return .secondary.opacity(0.5)
        case .unchanged: return .secondary
        }
    }

    private var iconName: String {
        switch item.kind {
        case .added:    return "plus.circle.fill"
        case .removed:  return "minus.circle.fill"
        case .changed:  return "pencil.circle.fill"
        case .unchanged: return "equal.circle"
        }
    }

    private var iconColor: Color {
        switch item.kind {
        case .added:    return .green
        case .removed:  return .red
        case .changed:  return .orange
        case .unchanged: return .secondary.opacity(0.6)
        }
    }

    private var rowBackground: Color {
        switch item.kind {
        case .added:    return .green.opacity(0.06)
        case .removed:  return .red.opacity(0.06)
        case .changed:  return .orange.opacity(0.05)
        case .unchanged: return .clear
        }
    }
}
