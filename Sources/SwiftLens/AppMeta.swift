import AppKit

// MARK: - AppMeta

/// 应用元数据：从 Bundle.main 读取（Xcode 构建版本有 Info.plist），
/// 取不到时回落到默认值（SPM `swift run` 没有 Info.plist 的场景）。
@MainActor
final class AppMeta {
    static let shared = AppMeta()

    let appName: String
    let versionString: String       // CFBundleShortVersionString
    let buildString: String         // CFBundleVersion
    let repositoryURL: URL
    let licenseName: String
    let licenseURL: URL
    let copyright: String
    let appIcon: NSImage

    private init() {
        let bundle = Bundle.main

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? AppMeta.defaultAppName
        self.appName = name

        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? AppMeta.defaultVersion
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? AppMeta.defaultBuild
        self.versionString = version
        self.buildString = build

        let repoString = (bundle.object(forInfoDictionaryKey: "SwiftLensRepositoryURL") as? String)
            ?? AppMeta.defaultRepositoryURL.absoluteString
        let licenseString = (bundle.object(forInfoDictionaryKey: "SwiftLensLicenseURL") as? String)
            ?? AppMeta.defaultLicenseURL.absoluteString
        self.repositoryURL = URL(string: repoString) ?? AppMeta.defaultRepositoryURL
        self.licenseURL = URL(string: licenseString) ?? AppMeta.defaultLicenseURL
        self.licenseName = "MIT License"

        let cr = (bundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String)
            ?? AppMeta.defaultCopyright
        self.copyright = cr

        if let asset = NSImage(named: "AppIcon") {
            self.appIcon = asset
        } else {
            let icon = NSWorkspace.shared.icon(forFile: bundle.bundleURL.path)
            if icon.size.width < 32 {
                self.appIcon = NSImage(systemSymbolName: "app", accessibilityDescription: "App")
                    ?? NSWorkspace.shared.icon(forFile: bundle.bundleURL.path)
            } else {
                self.appIcon = icon
            }
        }
    }

    // MARK: 默认值
    private static let defaultAppName        = "SwiftLens"
    private static let defaultVersion        = "1.3"
    private static let defaultBuild          = "4"
    private static let defaultRepositoryURL  = URL(string: "https://github.com/whynbnb/SwiftLens")!
    private static let defaultLicenseURL     = URL(string: "https://github.com/whynbnb/SwiftLens/blob/main/LICENSE")!
    private static let defaultCopyright      = "Copyright © 2026 0x574859. MIT License."
}

// MARK: - 标准 About 面板

@MainActor
enum AboutPanel {
    /// 使用 macOS 标准 About 面板（小型、居中图标、版本与版权、可点击链接）。
    static func show() {
        let meta = AppMeta.shared

        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let separatorAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let credits = NSMutableAttributedString()
        credits.append(NSAttributedString(
            string: L10n.t(.repository),
            attributes: [.font: font, .link: meta.repositoryURL]
        ))
        credits.append(NSAttributedString(string: "  ·  ", attributes: separatorAttributes))
        credits.append(NSAttributedString(
            string: L10n.t(.license),
            attributes: [.font: font, .link: meta.licenseURL]
        ))
        // 标准面板会从 Info.plist 读取 NSHumanReadableCopyright；
        // SPM 运行没有 Info.plist 时补在 credits 里。
        if Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") == nil {
            credits.append(NSAttributedString(
                string: "\n\(meta.copyright)",
                attributes: separatorAttributes
            ))
        }

        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: meta.appName,
            .applicationVersion: meta.versionString,
            .version: meta.buildString,
            .applicationIcon: meta.appIcon,
            .credits: credits
        ]
        NSApp.orderFrontStandardAboutPanel(options: options)
        NSApp.activate(ignoringOtherApps: true)
    }
}
