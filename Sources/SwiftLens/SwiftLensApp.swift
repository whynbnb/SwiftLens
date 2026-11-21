import SwiftUI
import AppKit

// MARK: - 应用入口

@main
struct SwiftLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared
    @State private var showHelp: Bool = false

    var body: some Scene {
        // 单窗口应用：open-file 事件不应像 WindowGroup 那样再开一个新窗口
        Window("SwiftLens", id: "main") {
            ContentView()
                .preferredColorScheme(appState.theme.colorScheme)
                .environmentObject(appState)
                .frame(minWidth: 960, minHeight: 640)
                .sheet(isPresented: $showHelp) {
                    HelpView()
                        .id(appState.language.rawValue)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openHelp)) { _ in
                    showHelp = true
                }
        }
        .commands {
            // 拦截系统默认 About 项，改用标准 About 面板（带仓库/许可证链接）
            CommandGroup(replacing: .appInfo) {
                Button(L10n.t(.about)) {
                    AboutPanel.show()
                }
            }
            CommandGroup(after: .help) {
                Button(L10n.t(.help)) {
                    showHelp = true
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(appState.theme.colorScheme)
                .environmentObject(appState)
        }
    }
}

extension Notification.Name {
    static let openHelp     = Notification.Name("SwiftLens.openHelp")
    static let focusSearch  = Notification.Name("SwiftLens.focusSearch")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // 隐藏 CLI 模式：传入一个 .app 路径作为参数时，直接打印摘要并退出。
        // 可选 --json 输出结构化 JSON。
        let args = CommandLine.arguments
        let wantJSON = args.contains("--json")
        if let appArg = args.dropFirst().first(where: { $0.lowercased().hasSuffix(".app") }),
           FileManager.default.fileExists(atPath: appArg) {
            let info = AppInfoLoader.load(url: URL(fileURLWithPath: appArg))
            print(wantJSON ? info.jsonSummary : info.summaryText)
            exit(0)
        }

        // SPM `swift run` 启动的可执行文件没有 Info.plist，
        // 默认是 .accessory 策略 —— 无 Dock 图标、无窗口聚焦。
        // 改为常规 App 策略并在启动后主动激活，使窗口出现在 Dock 并取得焦点。
        let app = (notification.object as? NSApplication) ?? NSApp
        app?.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 应用启动完成后主动激活为前台应用，确保窗口立即获得焦点。
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Finder「打开方式 → SwiftLens」或其他应用通过 LaunchServices
    /// （NSWorkspace.open(_:withApplicationAt:configuration:)）传入 .app 时触发。
    ///
    /// 沙盒应用通过 open-file 事件获得系统附带的一次性文件读取授权，
    /// 因此这里不需要 URL Scheme，也不需要预先取得安全作用域书签。
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: {
            $0.pathExtension.lowercased() == "app"
                && FileManager.default.fileExists(atPath: $0.path)
        }) else { return }

        // 交给 ContentView 走与拖放 / 选择面板相同的加载路径
        AppState.shared.pendingOpenURL = url

        // 应用可能处于后台且没有窗口：先激活并把窗口带到前台
        if application.activationPolicy() != .regular {
            application.setActivationPolicy(.regular)
        }
        application.activate(ignoringOtherApps: true)
        application.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// 单窗口应用：关掉最后一个窗口就退出，避免留下一个没有窗口、也不知道该怎么再打开的进程。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// 点击 Dock 图标时把已有窗口带回前台（单窗口，不会有多个窗口需要挑选）。
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
