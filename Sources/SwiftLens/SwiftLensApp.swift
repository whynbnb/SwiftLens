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

    private func summary(for info: AppInfo) -> String {
        var lines: [String] = []
        lines.append("# \(info.displayName ?? info.bundleName ?? info.bundleURL.lastPathComponent)")
        lines.append("\(L10n.t(.cliPath)): \(info.bundleURL.path)")
        lines.append("BundleID: \(info.bundleIdentifier ?? "—")")
        lines.append("\(L10n.t(.cliVersion)): \(info.bundleShortVersion ?? "—") (\(info.bundleVersion ?? "—"))")
        lines.append("\(L10n.t(.cliMinOS)): \(info.minimumOSVersion ?? "—")")
        lines.append("\(L10n.t(.cliSDK)): \(info.sdkVersion ?? "—") / \(info.platformName ?? "—") \(info.sdkBuild ?? "")")
        lines.append("Info.plist \(L10n.t(.cliPlistKeys)): \(info.flatRows.count)")
        lines.append("\(L10n.t(.cliArchs)): \(info.architectures.map { "\($0.name)(\($0.bits)-bit, \($0.cpuType))" }.joined(separator: ", "))")
        if !info.supportedPlatforms.isEmpty {
            lines.append("\(L10n.t(.cliPlatforms)): \(info.supportedPlatforms.joined(separator: ", "))")
        }
        if let p = info.principalClass { lines.append("NSPrincipalClass: \(p)") }
        if let c = info.humanReadableCopyright { lines.append("\(L10n.t(.cliCopyright)): \(c)") }
        lines.append("\(L10n.t(.cliUrlSchemes)): \(info.urlSchemes.isEmpty ? "—" : info.urlSchemes.joined(separator: ", "))")
        lines.append("\(L10n.t(.cliDocTypes)): \(info.documentTypes.count) \(L10n.t(.cliPlistKeys))")
        let cs = info.codeSign
        lines.append("\(L10n.t(.cliSign)): \(cs.state.localizedName) — \(cs.validity.localizedName) — \(cs.notarization.localizedName)")
        lines.append("\(L10n.t(.cliSandbox)): \(info.isSandboxed ? L10n.t(.cliSandboxYes) : L10n.t(.cliSandboxNo))")
        if let v = cs.format { lines.append("  Format: \(v)") }
        if let v = cs.identifier { lines.append("  Identifier: \(v)") }
        lines.append("  TeamIdentifier: \(cs.teamIdentifier ?? "not set")")
        if let v = cs.cdHash { lines.append("  CDHash: \(v)") }
        if let v = cs.candidateCDHashFull { lines.append("  CandidateCDHashFull: \(v)") }
        if let v = cs.hashType { lines.append("  HashType: \(v)") }
        if let v = cs.hashChoices { lines.append("  Hash choices: \(v)") }
        if let v = cs.signatureType { lines.append("  Signature: \(v)") }
        if let v = cs.signatureSize { lines.append("  Signature size: \(v)") }
        if let v = cs.platformIdentifier { lines.append("  Platform identifier: \(v)") }
        if let v = cs.source { lines.append("  Source: \(v)") }
        if let v = cs.runtimeVersion { lines.append("  Runtime Version: \(v)") }
        if let v = cs.signingTime { lines.append("  Signing Time: \(v)") }
        if let v = cs.totalSignatures { lines.append("  Total signatures: \(v)") }
        if let v = cs.chosenSignature { lines.append("  Chosen signature: \(v)") }
        if let v = cs.infoPlistEntries { lines.append("  Info.plist entries: \(v)") }
        if !cs.decodedFlags.isEmpty { lines.append("  \(L10n.t(.cliFlagsDecoded)): \(cs.decodedFlags.joined(separator: ", "))") }
        if let v = cs.flags { lines.append("  \(L10n.t(.cliFlagsRaw)): \(v)") }
        if !cs.authorities.isEmpty {
            lines.append("  \(L10n.t(.cliAuthority)):")
            cs.authorities.forEach { lines.append("    - \($0)") }
        }
        if let ent = cs.entitlements {
            lines.append("  Entitlements (\(ent.count) \(L10n.t(.cliEntitlementsCount))):")
            InfoPlistParser.flatten(ent).sorted { $0.0 < $1.0 }
                .forEach { lines.append("    \($0.0) = \($0.1)") }
        } else {
            lines.append("  Entitlements: \(L10n.t(.cliEntitlementsNone))")
        }
        lines.append("\(L10n.t(.cliPrivacy)): \(info.privacyEntries.count) \(L10n.t(.cliPlistKeys))")
        for e in info.privacyEntries.prefix(8) {
            lines.append("  · \(e.displayTitle) [\(e.key)]: \(e.description)")
        }
        if info.privacyEntries.count > 8 {
            lines.append("  ... \(L10n.t(.cliMore)) \(info.privacyEntries.count - 8) \(L10n.t(.cliPlistKeys))")
        }
        if info.appTransportSecurity != nil { lines.append("ATS: \(L10n.t(.cliATS))") }
        if info.electronAsarIntegrity != nil { lines.append("Electron: \(L10n.t(.cliElectron))") }
        if info.lsUIElement == true { lines.append(L10n.t(.cliFormAgent)) }
        if info.lsBackgroundOnly == true { lines.append(L10n.t(.cliFormBackground)) }
        if info.isIOSPort { lines.append(L10n.t(.cliFormIOSPort)) }
        // Sparkle 自动更新
        if let sp = info.extra.sparkle {
            lines.append("\(L10n.t(.cliSparkle)):")
            if let v = sp.feedURL { lines.append("  SUFeedURL: \(v)") }
            if let v = sp.publicEDKey { lines.append("  SUPublicEDKey: \(v)") }
            if let v = sp.publicDSAKeyFile { lines.append("  SUPublicDSAKeyFile: \(v)") }
            if let v = sp.enableAutomaticChecks { lines.append("  SUEnableAutomaticChecks: \(v)") }
            if let v = sp.scheduledCheckInterval {
                lines.append("  SUScheduledCheckInterval: \(v) \(L10n.t(.cliSeconds)) (\(Double(v)/86400.0) \(L10n.t(.cliDays)))")
            }
            if let v = sp.allowsAutomaticUpdates { lines.append("  SUAllowsAutomaticUpdates: \(v)") }
            if let v = sp.enableInstallerLauncherService { lines.append("  SUEnableInstallerLauncherService: \(v)") }
            if let v = sp.enableDownloaderService { lines.append("  SUEnableDownloaderService: \(v)") }
            if let v = sp.showReleaseNotes { lines.append("  SUShowReleaseNotes: \(v)") }
            if let v = sp.enableSystemProfiling { lines.append("  SUEnableSystemProfiling: \(v)") }
            if let v = sp.sendProfileInfo { lines.append("  SUSendProfileInfo: \(v)") }
            if let v = sp.enableJavaScript { lines.append("  SUEnableJavaScript: \(v)") }
            if let v = sp.bundleName { lines.append("  SUBundleName: \(v)") }
        }
        // AppleScript / Siri
        let ex = info.extra
        if let v = ex.appleScriptEnabled { lines.append("NSAppleScriptEnabled: \(v)") }
        if let v = ex.scriptingDefinition { lines.append("OSAScriptingDefinition: \(v)") }
        if !ex.userActivityTypes.isEmpty {
            lines.append("NSUserActivityTypes: \(ex.userActivityTypes.joined(separator: ", "))")
        }
        if !ex.intentsSupported.isEmpty {
            lines.append("INIntentsSupported (Siri): \(ex.intentsSupported.joined(separator: ", "))")
        }
        if let v = ex.safariExtensionCorrespondingIOSApp {
            lines.append("SFSafariCorrespondingIOSAppBundleIdentifier: \(v)")
        }
        // iCloud
        if !ex.ubiquitousContainers.isEmpty {
            lines.append("iCloud Containers (\(ex.ubiquitousContainers.count) \(L10n.t(.cliICloudContainers))):")
            for (i, c) in ex.ubiquitousContainers.enumerated() {
                lines.append("  [\(i)] \(c.identifier): \(InfoPlistParser.flatten(c.config).map { "\($0.0)=\($0.1)" }.joined(separator: ", "))")
            }
        }
        // Notifications
        if let v = ex.userNotificationAlertStyle { lines.append("NSUserNotificationAlertStyle: \(v)") }
        if let v = ex.userNotificationsUsageDescription { lines.append("NSUserNotificationsUsageDescription: \(v)") }
        if let v = ex.localNotificationUsageDescription { lines.append("NSLocalNotificationUsageDescription: \(v)") }
        if let v = ex.remoteNotificationUsageDescription { lines.append("NSRemoteNotificationUsageDescription: \(v)") }
        // 杂项开关
        if let v = ex.supportsSuddenTermination { lines.append("NSSupportsSuddenTermination: \(v)") }
        if let v = ex.supportsAutomaticTermination { lines.append("NSSupportsAutomaticTermination: \(v)") }
        if let v = ex.lsRequiresCarbon { lines.append("LSRequiresCarbon: \(v)") }
        if let v = ex.lsRequiresNativeExecution { lines.append("LSRequiresNativeExecution: \(v)") }
        if let v = ex.lsMultipleInstancesProhibited { lines.append("LSMultipleInstancesProhibited: \(v)") }
        if let v = ex.lsHasLocalizedDisplayName { lines.append("LSHasLocalizedDisplayName: \(v)") }
        if let v = ex.lsFileQuarantineEnabled { lines.append("LSFileQuarantineEnabled: \(v)") }
        if let v = ex.gpuEjectPolicy { lines.append("GPUEjectPolicy: \(v)") }
        if let v = ex.gpuSelectionPolicy { lines.append("GPUSelectionPolicy: \(v)") }
        if let v = ex.itmsAppUsesNonExemptEncryption { lines.append("ITSAppUsesNonExemptEncryption: \(v)") }
        // F. 帮助 / 本地化 / Accent / Spotlight
        if let v = ex.helpBookName { lines.append("CFBundleHelpBookName: \(v)") }
        if let v = ex.helpBookFolder { lines.append("CFBundleHelpBookFolder: \(v)") }
        if !ex.bundleLocalizations.isEmpty {
            lines.append("CFBundleLocalizations: \(ex.bundleLocalizations.joined(separator: ", "))")
        }
        if let v = ex.allowMixedLocalizations { lines.append("CFBundleAllowMixedLocalizations: \(v)") }
        if let v = ex.accentColorName { lines.append("NSAccentColorName: \(v)") }
        if let v = ex.mdItemKeywords { lines.append("MDItemKeywords: \(v)") }
        // G. iOS 移植包字段
        if !ex.uIDeviceFamily.isEmpty {
            let labels: [Int: String] = [1: "iPhone", 2: "iPad", 3: "Apple TV", 4: "Apple Watch"]
            lines.append("UIDeviceFamily: \(ex.uIDeviceFamily.map { labels[$0] ?? "\($0)" }.joined(separator: ", "))")
        }
        if let v = ex.uiLaunchStoryboardName { lines.append("UILaunchStoryboardName: \(v)") }
        if let v = ex.uiRequiresFullScreen { lines.append("UIRequiresFullScreen: \(v)") }
        if !ex.uiSupportedInterfaceOrientations.isEmpty {
            lines.append("UISupportedInterfaceOrientations: \(ex.uiSupportedInterfaceOrientations.joined(separator: ", "))")
        }
        if let v = ex.uiStatusBarStyle { lines.append("UIStatusBarStyle: \(v)") }
        if !ex.uiBackgroundModes.isEmpty {
            lines.append("UIBackgroundModes: \(ex.uiBackgroundModes.joined(separator: ", "))")
        }
        // H. Electron / 构建元数据 / 厂商
        if let v = ex.electronTeamID { lines.append("ElectronTeamID: \(v)") }
        if let v = ex.sourceVersion { lines.append("SourceVersion: \(v)") }
        if let v = ex.requiredBuildHash { lines.append("requiredBuildHash: \(v)") }
        if let v = ex.scmRevision { lines.append("SCMRevision: \(v)") }
        if let v = ex.appIdentifierPrefix { lines.append("AppIdentifierPrefix: \(v)") }
        if let v = ex.teamIdentifierPlist { lines.append("TeamIdentifier (plist): \(v)") }
        if let v = ex.bundleSpokenName { lines.append("CFBundleSpokenName: \(v)") }
        if let v = ex.vendorCode { lines.append("VendorCode: \(v)") }
        if let v = ex.organizationIdentifier { lines.append("OrganizationIdentifier: \(v)") }
        if let v = ex.ctFontSuppressAutoDownload { lines.append("CTFontSuppressAutoDownload: \(v)") }
        if let v = ex.asWebAuthenticationSessionWebBrowserSupportCapabilities {
            lines.append("ASWebAuthenticationSessionWebBrowserSupportCapabilities: \(v)")
        }
        // I. Bonjour
        if !ex.bonjourServices.isEmpty {
            lines.append("NSBonjourServices: \(ex.bonjourServices.joined(separator: ", "))")
        }
        if let q = info.quarantine {
            lines.append("Quarantine: flags=\(q.flags) agent=\(q.agent) uuid=\(q.uuid) \(L10n.t(.cliQuarantine))=\(q.timestampString) \(L10n.t(.cliDownloadTime))=\(q.downloadDate.map { ISO8601DateFormatter().string(from: $0) } ?? "—")")
        } else {
            lines.append("Quarantine: \(L10n.t(.cliQuarantineNone))")
        }
        if !info.extendedXattrs.names.isEmpty {
            lines.append("\(L10n.t(.cliXattrs)): \(info.extendedXattrs.names.joined(separator: ", "))")
        }
        lines.append("\(L10n.t(.cliSubBundles)): \(info.subBundles.count) \(L10n.t(.cliPlistKeys)) (\(ByteCountFormatter.string(fromByteCount: Int64(info.subBundlesTotalSize), countStyle: .file)))")
        for sub in info.subBundles.prefix(8) {
            lines.append("  · [\(sub.kind.rawValue)] \(sub.relativePath) — \(sub.bundleIdentifier ?? "—") (\(sub.signatureState.localizedName))")
        }
        if info.subBundles.count > 8 {
            lines.append("  ... \(L10n.t(.cliMore)) \(info.subBundles.count - 8) \(L10n.t(.cliPlistKeys))")
        }
        lines.append("\(L10n.t(.cliFileSize)): \(info.formattedFileSize()) (\(info.fileSize) \(L10n.t(.bytesUnit)))")
        return lines.joined(separator: "\n")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}