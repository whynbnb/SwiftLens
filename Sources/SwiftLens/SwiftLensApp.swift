import SwiftUI
import AppKit

// MARK: - 应用入口

@main
struct SwiftLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @State private var showSettings: Bool = false
    @State private var showAbout: Bool = false
    @State private var showHelp: Bool = false

    var body: some Scene {
        WindowGroup("SwiftLens") {
            ContentView()
                .preferredColorScheme(appState.theme.colorScheme)
                .environmentObject(appState)
                .frame(minWidth: 960, minHeight: 640)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                        .environmentObject(appState)
                        .id(appState.language.rawValue)
                }
                .sheet(isPresented: $showAbout) {
                    AboutView()
                        .id(appState.language.rawValue)
                }
                .sheet(isPresented: $showHelp) {
                    HelpView()
                        .id(appState.language.rawValue)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                    showSettings = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .openAbout)) { _ in
                    showAbout = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .openHelp)) { _ in
                    showHelp = true
                }
        }
        .commands {
            // 保留系统默认 "About SwiftLens" 项, 但拦截其动作打开自定义 AboutView
            CommandGroup(replacing: .appInfo) {
                Button(L10n.t(.about)) {
                    showAbout = true
                }
            }
            CommandGroup(after: .appSettings) {
                Button(L10n.t(.settings)) {
                    showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .help) {
                Button(L10n.t(.help)) {
                    showHelp = true
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("SwiftLens.openSettings")
    static let openAbout    = Notification.Name("SwiftLens.openAbout")
    static let openHelp     = Notification.Name("SwiftLens.openHelp")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // 隐藏 CLI 模式：传入一个 .app 路径作为参数时，直接打印摘要并退出。
        let args = CommandLine.arguments
        if args.count >= 2, args[1].hasSuffix(".app"),
           FileManager.default.fileExists(atPath: args[1]) {
            let info = AppInfoLoader.load(url: URL(fileURLWithPath: args[1]))
            print(summary(for: info))
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

    private func summary(for info: AppInfo) -> String { info.summaryText }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}