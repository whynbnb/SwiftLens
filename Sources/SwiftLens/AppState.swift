import Foundation
import SwiftUI

// MARK: - 全局应用状态

/// 应用偏好：语言、主题色。@AppStorage 自动持久化到 UserDefaults。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zh     = "zh"
    case en     = "en"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L10n.t(.langSystem)
        case .zh:     return "中文"
        case .en:     return "English"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L10n.t(.themeSystem)
        case .light:  return L10n.t(.themeLight)
        case .dark:   return L10n.t(.themeDark)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// 最近打开的一项 app。bookmark 为安全作用域书签（沙盒下重启后仍可读取）。
struct RecentAppEntry: Codable, Identifiable {
    var id: String { path }
    let path: String
    let name: String
    let bundleID: String?
    let openedAt: Date
    let bookmark: Data?
}

enum RecentAppStatus: Equatable {
    case valid
    case missing
    case invalidBundle

    var localizedName: String {
        switch self {
        case .valid:        return L10n.t(.recentValid)
        case .missing:      return L10n.t(.recentMissing)
        case .invalidBundle: return L10n.t(.recentInvalid)
        }
    }

    var icon: String {
        switch self {
        case .valid:        return "checkmark.circle"
        case .missing:      return "xmark.circle"
        case .invalidBundle: return "exclamationmark.triangle"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    /// 共享实例：AppDelegate 接收 open-file 事件后，通过它把 URL 交给界面。
    static let shared = AppState()

    /// 由 Finder / 其他应用「用 SwiftLens 打开」传入的 .app，等待 ContentView 消费。
    @Published var pendingOpenURL: URL?

    /// 主窗口当前正在展示的 .app（供版本对比窗口预填）。
    @Published var currentAppURL: URL?
    /// 当前 app 的安全作用域书签：对比窗口预填时恢复读取权限。
    @Published var currentAppBookmark: Data?

    @AppStorage("swiftlens.language") var language: AppLanguage = .system
    @AppStorage("swiftlens.theme")   var theme: AppTheme = .system
    @AppStorage("swiftlens.recentAppsEnabled") var recentAppsEnabled: Bool = true
    @AppStorage("swiftlens.showFileTree") var showFileTree: Bool = true
    @AppStorage("swiftlens.recentApps") private var recentAppsJSON: String = "[]"

    private static let maxRecentApps = 10

    /// 最近打开（最新在前）。
    var recentApps: [RecentAppEntry] {
        guard let data = recentAppsJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([RecentAppEntry].self, from: data)
        else { return [] }
        return list.sorted { $0.openedAt > $1.openedAt }
    }

    func recordRecentApp(url: URL, name: String, bundleID: String?, bookmark: Data?) {
        guard recentAppsEnabled else { return }
        var list = recentApps
        list.removeAll { $0.path == url.path }
        list.insert(
            RecentAppEntry(path: url.path, name: name, bundleID: bundleID,
                           openedAt: Date(), bookmark: bookmark),
            at: 0
        )
        if list.count > Self.maxRecentApps {
            list = Array(list.prefix(Self.maxRecentApps))
        }
        saveRecentApps(list)
    }

    func removeRecentApp(path: String) {
        saveRecentApps(recentApps.filter { $0.path != path })
    }

    func clearRecentApps() {
        recentAppsJSON = "[]"
    }

    func resolveRecentAppURL(_ entry: RecentAppEntry) -> URL? {
        if let bookmark = entry.bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark,
                                  options: [.withSecurityScope, .withoutUI],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale) {
                return url
            }
        }
        return URL(fileURLWithPath: entry.path)
    }

    /// 轻量有效性检查：路径存在且是含 Info.plist 的 bundle。
    func recentAppStatus(_ entry: RecentAppEntry) -> RecentAppStatus {
        guard let url = resolveRecentAppURL(entry) else { return .missing }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
              isDir.boolValue else { return .missing }
        return InfoPlistParser.plistURL(at: url) == nil ? .invalidBundle : .valid
    }

    private func saveRecentApps(_ list: [RecentAppEntry]) {
        if let data = try? JSONEncoder().encode(list),
           let string = String(data: data, encoding: .utf8) {
            recentAppsJSON = string
        }
    }
}