import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 主界面 — 即用即走：拖入或选择一个 .app bundle 直接展示详情。
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @State private var info: AppInfo?
    @State private var loading: Bool = false
    @State private var dropHover: Bool = false
    @State private var lastError: String?
    @State private var spinnerSpin: Bool = false   // 持续旋转的触发开关
    @State private var loadID: UInt = 0            // 加载请求 token, 防止旧任务覆盖新结果

    var body: some View {
        Group {
            if let info = info {
                DetailView(info: info)
                    .id("\(appState.language.rawValue)-\(info.bundleURL.path)")
            } else {
                placeholder
                    .opacity(loading ? 0 : 1)      // 加载时隐藏占位避免与 ProgressView 重叠
                    .id(appState.language.rawValue)
            }
        }
        .overlay {
            if loading { loadingOverlay }
        }
        .background(
            // 整窗拖放接收器
            DropZoneView(
                isHovered: $dropHover,
                onDrop: { url in handle(url: url) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { openPanel() } label: {
                    Label(L10n.t(.openApp), systemImage: "folder.badge.plus")
                }
                .help(L10n.t(.openApp))
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    let recents = appState.recentApps
                    if appState.recentAppsEnabled, !recents.isEmpty {
                        Menu {
                            ForEach(recents) { entry in
                                let status = appState.recentAppStatus(entry)
                                Button {
                                    openRecent(entry)
                                } label: {
                                    Label(recentText(entry, status: status),
                                          systemImage: status.icon)
                                }
                                .disabled(status != .valid)
                            }
                            Divider()
                            Menu(L10n.t(.removeRecent)) {
                                ForEach(recents) { entry in
                                    Button(entry.name) {
                                        appState.removeRecentApp(path: entry.path)
                                    }
                                }
                            }
                            Button(L10n.t(.clearRecentApps)) {
                                appState.clearRecentApps()
                            }
                        } label: {
                            Label(L10n.t(.recentApps), systemImage: "clock.arrow.circlepath")
                        }
                        Divider()
                    }
                    if let info {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([info.bundleURL])
                        } label: {
                            Label(L10n.t(.revealInFinder), systemImage: "folder")
                        }
                        Button {
                            copyToPasteboard(info.summaryText)
                        } label: {
                            Label(L10n.t(.copySummary), systemImage: "doc.on.doc")
                        }
                        Button {
                            copyToPasteboard(info.jsonSummary)
                        } label: {
                            Label(L10n.t(.copyJSON), systemImage: "curlybraces")
                        }
                        Button {
                            NotificationCenter.default.post(name: .focusSearch, object: nil)
                        } label: {
                            Label(L10n.t(.search), systemImage: "magnifyingglass")
                        }
                        .keyboardShortcut("f", modifiers: .command)
                        Divider()
                        Button {
                            reset()
                        } label: {
                            Label(L10n.t(.clear), systemImage: "arrow.uturn.backward")
                        }
                        Divider()
                    }
                    Button {
                        openSettings()
                    } label: {
                        Label(L10n.t(.settings), systemImage: "gearshape")
                    }
                    Button {
                        NotificationCenter.default.post(name: .openHelp, object: nil)
                    } label: {
                        Label(L10n.t(.help), systemImage: "questionmark.circle")
                    }
                } label: {
                    Label(L10n.t(.more), systemImage: "ellipsis.circle")
                }
                .help(L10n.t(.more))
            }
        }
        .navigationTitle(info?.bundleURL.lastPathComponent ?? L10n.t(.appName))
        // 设置 sheet 现在由 SwiftLensApp 统一管理，工具栏按钮只负责发通知
    }

    private var placeholder: some View {
        VStack(spacing: 22) {
            Image(systemName: "app.badge")
                .font(.system(size: 110, weight: .light))
                .foregroundStyle(dropHover ? Color.accentColor : Color.secondary)
                .scaleEffect(dropHover ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.25), value: dropHover)
            Text(dropHover ? L10n.t(.placeholderRelease) : L10n.t(.placeholderDrop))
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(dropHover ? Color.accentColor : Color.primary)
            Text(L10n.t(.placeholderPick))
                .font(.system(.body))
                .foregroundStyle(.secondary)
            if let err = lastError {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    dropHover ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .padding(dropHover ? 8 : 28)
        )
        .transition(.opacity)
    }

    // MARK: - 加载遮罩
    private var loadingOverlay: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(spinnerSpin ? 360 : 0))   // 持续旋转
                    .animation(
                        .linear(duration: 0.9)
                            .repeatForever(autoreverses: false),
                        value: spinnerSpin
                    )
            }
            .frame(width: 96, height: 96)
            Text(L10n.t(.analyzing))
                .font(.system(.title3, design: .default).bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .transition(.opacity)
        .onAppear {
            // appear 时启动连续旋转；下一 runloop 再翻转，避免初值 0 与最终值相同被 SwiftUI 优化掉
            DispatchQueue.main.async { spinnerSpin = true }
        }
        .onDisappear { spinnerSpin = false }
    }

    // MARK: - Actions
    private func recentText(_ entry: RecentAppEntry, status: RecentAppStatus) -> String {
        status == .valid ? entry.name : "\(entry.name) — \(status.localizedName)"
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.title = L10n.t(.pickAppPanelTitle)
        if panel.runModal() == .OK, let url = panel.url {
            handle(url: url)
        }
    }

    private func handle(url: URL, securityScoped: Bool = false) {
        guard url.pathExtension.lowercased() == "app" else {
            if securityScoped { url.stopAccessingSecurityScopedResource() }
            lastError = L10n.t(.invalidApp) + ": \(url.lastPathComponent)"
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            if securityScoped { url.stopAccessingSecurityScopedResource() }
            lastError = L10n.t(.fileMissing) + ": \(url.path)"
            return
        }
        lastError = nil
        loading = true
        loadID &+= 1
        let currentID = loadID
        let work = url
        // 在仍有访问权限时创建安全作用域书签，供「最近打开」重启后使用
        let bookmark = appState.recentAppsEnabled ? try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) : nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = AppInfoLoader.load(url: work)
            if securityScoped { work.stopAccessingSecurityScopedResource() }
            DispatchQueue.main.async {
                // 只接受最新一次请求的结果, 丢弃过期任务
                guard currentID == loadID else { return }
                self.info = result
                self.loading = false
                self.appState.recordRecentApp(
                    url: work,
                    name: result.displayName ?? result.bundleName
                        ?? work.deletingPathExtension().lastPathComponent,
                    bundleID: result.bundleIdentifier,
                    bookmark: bookmark
                )
                // 加载完成后把应用拉到前台并使窗口获得焦点
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func openRecent(_ entry: RecentAppEntry) {
        guard let url = appState.resolveRecentAppURL(entry) else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        handle(url: url, securityScoped: accessed)
    }

    private func reset() {
        // 使在飞的加载任务失效, 否则清空后旧结果会把界面重新填上
        loadID &+= 1
        info = nil
        lastError = nil
        loading = false
    }
}

// MARK: - DropZoneView
private struct DropZoneView: NSViewRepresentable {
    @Binding var isHovered: Bool
    let onDrop: (URL) -> Void

    func makeNSView(context: Context) -> DropNSView {
        let v = DropNSView()
        v.onDrop = onDrop
        v.onHoverChange = { isHovered = $0 }
        return v
    }

    func updateNSView(_ nsView: DropNSView, context: Context) {
        nsView.onDrop = onDrop
        nsView.onHoverChange = { isHovered = $0 }
    }
}

@MainActor
private final class DropNSView: NSView {
    var onDrop: ((URL) -> Void)?
    var onHoverChange: ((Bool) -> Void)?

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let ok = extractedURL(from: sender) != nil
        onHoverChange?(ok)
        return ok ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let ok = extractedURL(from: sender) != nil
        return ok ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onHoverChange?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = extractedURL(from: sender) else { return false }
        onHoverChange?(false)
        onDrop?(url)
        return true
    }

    private func extractedURL(from sender: NSDraggingInfo) -> URL? {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = urls.first else { return nil }
        return url.pathExtension.lowercased() == "app" ? url : nil
    }
}