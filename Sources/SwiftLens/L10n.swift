import Foundation

// MARK: - 运行时本地化 (zh / en)

/// 极简的运行时字符串本地化表。
/// 设置面板切换语言时，AppState.language 改变 -> 所有依赖 L10n 的视图刷新。
enum L10n {

    /// 已支持的 key，与下面两张表一一对应。
    enum Key: String {
        // 设置 / 关于 / 帮助
        case settings
        case about
        case help
        case language
        case theme
        case langSystem
        case langZh
        case langEn
        case themeSystem
        case themeLight
        case themeDark
        case close
        // 顶部工具栏 / 通用
        case appName
        case openApp
        case clear
        case revealInFinder
        case copySummary
        case placeholderOpen
        case placeholderDrop
        case placeholderRelease
        case placeholderPick
        // 头部徽标
        case badgeIsolated
        case badgeNoQuarantine
        case badgeAgentApp
        case badgeBackground
        case badgeIOSPort
        case badgeSandboxed
        case badgeNoSandbox
        // 分区标题
        case basicInfo
        case runtime
        case architectures
        case documentTypes
        case urlSchemes
        case privacy
        case ats
        case quarantine
        case xattrs
        case codeSigning
        case entitlements
        case subBundles
        case sparkle
        case appleScriptSiri
        case icloud
        case notifications
        case behaviors
        case localization
        case iosPortFields
        case buildMetadata
        case bonjour
        case fileInfo
        case rawPlist
        case rawCodesign
        // 文档类型 row inner
        case extName
        case prioLogo
        case utis
        case prioKey
        case iconFile
        // 隐私 / 计数提示
        case noneDocType
        case noneXattrs
        // CLI/其它
        case invalidApp
        case fileMissing
        case analyzing
        // RowView / 按钮通用
        case copyValue
        case copyKeyValue
        // 基本信息区
        case execPath
        // 架构区
        case buildToolchain
        case noExecOrIntelSlice
        case sliceSize
        case offsetInFat
        case nonFat
        // URL Scheme
        case noUrlScheme
        // 隐私
        case noUsageDescription
        // ATS
        case noATS
        // Quarantine
        case rawValue
        case downloadAgent
        case downloadUUID
        case timestampHex
        case downloadTime
        case copyRemoveCmd
        case pasteToRemoveHint
        case noQuarantineHint
        // 代码签名
        case signState
        case validity
        case notarization
        case copyCodesignCmd
        case copySpctlCmd
        case pasteToVerifyHint
        case authorityChain
        case noEntitlements
        // 文件信息
        case fullPath
        case totalSize
        case modifiedTime
        case createdTime
        case permissionsOctal
        // 子 bundle 版本
        case versionLabel
        // 各区空状态
        case noAppleScript
        case noICloudContainer
        case noNotificationKeys
        case noSwitches
        case noLocalizationKeys
        case noIOSPortFields
        case noBuildMetadata
        // 打开面板
        case pickAppPanelTitle
        // 通用单位
        case bytesUnit
        // Bonjour
        case noBonjour
        // flags
        case flagsRaw
        case flagsDecoded
        case emptyPlaceholder
    }

    /// 中文表
    private static let zh: [Key: String] = [
        .settings: "设置", .about: "关于 SwiftLens", .help: "帮助", .language: "语言", .theme: "主题",
        .langSystem: "跟随系统", .langZh: "中文", .langEn: "English",
        .themeSystem: "跟随系统", .themeLight: "浅色", .themeDark: "深色",
        .close: "关闭",
        .appName: "SwiftLens", .openApp: "打开 .app", .clear: "清空",
        .revealInFinder: "在访达中显示", .copySummary: "复制摘要",
        .placeholderOpen: "拖入 .app 到此处", .placeholderDrop: "拖入 .app 到此处",
        .placeholderRelease: "松开以加载", .placeholderPick: "或点击右上角 “打开 .app” 选择",
        .badgeIsolated: "已隔离", .badgeNoQuarantine: "无隔离",
        .badgeAgentApp: "Agent App (无 Dock)", .badgeBackground: "仅后台 (Background)",
        .badgeIOSPort: "iOS 移植包",
        .badgeSandboxed: "沙盒应用", .badgeNoSandbox: "非沙盒",
        .basicInfo: "基本信息", .runtime: "运行环境 & 部署",
        .architectures: "架构 (Mach-O)", .documentTypes: "文档类型 (CFBundleDocumentTypes)",
        .urlSchemes: "URL Schemes", .privacy: "隐私权限描述 (TCC Usage Descriptions)",
        .ats: "网络安全 / ATS · Electron", .quarantine: "Quarantine 隔离标记",
        .xattrs: "扩展属性 (xattrs)", .codeSigning: "代码签名 (Code Signing)",
        .entitlements: "Entitlements 权限", .subBundles: "内嵌子 bundle",
        .sparkle: "Sparkle 自动更新", .appleScriptSiri: "AppleScript / Siri / Intents",
        .icloud: "iCloud (NSUbiquitousContainers)", .notifications: "通知 (Notifications)",
        .behaviors: "杂项开关 (生命周期 / 加密合规 / GPU)",
        .localization: "帮助 / 本地化 / Accent / Spotlight",
        .iosPortFields: "iOS 移植包字段 (UI* 键)", .buildMetadata: "Electron / 构建元数据 / 厂商",
        .bonjour: "Bonjour 服务发现 (NSBonjourServices)",
        .fileInfo: "文件信息", .rawPlist: "Info.plist 完整内容", .rawCodesign: "codesign 原始输出",
        .extName: "扩展名", .prioLogo: "优先级", .utis: "UTIs", .prioKey: "优先级",
        .iconFile: "图标文件", .noneDocType: "未声明自定义文档类型",
        .noneXattrs: "无任何扩展属性", .invalidApp: "不是 .app bundle",
        .fileMissing: "文件不存在", .analyzing: "正在分析 .app …",
        // RowView 通用
        .copyValue: "复制值", .copyKeyValue: "复制键值",
        // 基本信息
        .execPath: "可执行文件路径",
        // 架构
        .buildToolchain: "构建工具链",
        .noExecOrIntelSlice: "未找到可执行文件或无法解析 Intel 切片",
        .sliceSize: "切片大小", .offsetInFat: "在 Fat 中偏移", .nonFat: "—(非 Fat)",
        // URL Scheme
        .noUrlScheme: "未声明 URL Scheme",
        // 隐私
        .noUsageDescription: "未声明任何 NS***UsageDescription 权限描述",
        // ATS
        .noATS: "未声明 NSAppTransportSecurity / ElectronAsarIntegrity",
        // Quarantine
        .rawValue: "原始值", .downloadAgent: "下载 Agent", .downloadUUID: "下载 UUID",
        .timestampHex: "时间戳(十六进制)", .downloadTime: "下载时间",
        .copyRemoveCmd: "复制移除命令", .pasteToRemoveHint: "在终端粘贴运行即可移除隔离标记",
        .noQuarantineHint: "未检测到 com.apple.quarantine 扩展属性 (可信来源 / 已清隔离)",
        // 代码签名
        .signState: "签名状态", .validity: "有效性", .notarization: "公证 (Notarization)",
        .copyCodesignCmd: "复制 codesign 命令", .copySpctlCmd: "复制 spctl 命令",
        .pasteToVerifyHint: "在终端粘贴运行即可手动验证签名 / 公证状态",
        .authorityChain: "Authority 链", .noEntitlements: "无 entitlements (未签名 / 无沙盒)",
        // 文件信息
        .fullPath: "完整路径", .totalSize: "总大小", .modifiedTime: "修改时间",
        .createdTime: "创建时间", .permissionsOctal: "权限 (octal)",
        // 子 bundle
        .versionLabel: "版本",
        // 空状态
        .noAppleScript: "未声明 AppleScript / Siri 相关支持",
        .noICloudContainer: "未声明 iCloud 容器", .noNotificationKeys: "未声明通知相关键",
        .noSwitches: "无相关开关", .noLocalizationKeys: "未声明帮助/本地化/Accent/Spotlight 关键词",
        .noIOSPortFields: "未声明 iOS 移植字段", .noBuildMetadata: "未声明 Electron/厂商/构建元数据",
        // 打开面板
        .pickAppPanelTitle: "选择 .app bundle",
        .bytesUnit: "字节",
        .noBonjour: "未声明 NSBonjourServices",
        .flagsRaw: "flags (原始)", .flagsDecoded: "flags (解码)",
        .emptyPlaceholder: "(无)"
    ]

    /// 英文表（缺失时回退到 zh key 字面名）
    private static let en: [Key: String] = [
        .settings: "Settings", .about: "About SwiftLens", .help: "Help", .language: "Language", .theme: "Theme",
        .langSystem: "Follow System", .langZh: "中文", .langEn: "English",
        .themeSystem: "Follow System", .themeLight: "Light", .themeDark: "Dark",
        .close: "Close",
        .appName: "SwiftLens", .openApp: "Open .app", .clear: "Clear",
        .revealInFinder: "Reveal in Finder", .copySummary: "Copy Summary",
        .placeholderOpen: "Drop .app here", .placeholderDrop: "Drop .app here",
        .placeholderRelease: "Release to load", .placeholderPick: "or click “Open .app” at top right",
        .badgeIsolated: "Quarantined", .badgeNoQuarantine: "No Quarantine",
        .badgeAgentApp: "Agent App (no Dock)", .badgeBackground: "Background-only",
        .badgeIOSPort: "iOS port",
        .badgeSandboxed: "Sandboxed", .badgeNoSandbox: "Not Sandboxed",
        .basicInfo: "Basic", .runtime: "Runtime & Deployment",
        .architectures: "Architectures (Mach-O)", .documentTypes: "Document Types (CFBundleDocumentTypes)",
        .urlSchemes: "URL Schemes", .privacy: "Privacy (TCC Usage Descriptions)",
        .ats: "Network Security / ATS · Electron", .quarantine: "Quarantine Flag",
        .xattrs: "Extended Attributes (xattrs)", .codeSigning: "Code Signing",
        .entitlements: "Entitlements", .subBundles: "Embedded Sub Bundles",
        .sparkle: "Sparkle Auto Update", .appleScriptSiri: "AppleScript / Siri / Intents",
        .icloud: "iCloud (NSUbiquitousContainers)", .notifications: "Notifications",
        .behaviors: "Misc Switches (Lifecycle / Crypto / GPU)",
        .localization: "Help / Localization / Accent / Spotlight",
        .iosPortFields: "iOS port fields (UI* keys)", .buildMetadata: "Electron / Build metadata / Vendor",
        .bonjour: "Bonjour (NSBonjourServices)",
        .fileInfo: "File Info", .rawPlist: "Info.plist (raw)", .rawCodesign: "codesign (raw)",
        .extName: "Extensions", .prioLogo: "Rank", .utis: "UTIs", .prioKey: "Rank",
        .iconFile: "Icon file", .noneDocType: "No custom document type declared",
        .noneXattrs: "No extended attributes", .invalidApp: "Not an .app bundle",
        .fileMissing: "File not found", .analyzing: "Analyzing .app …",
        // RowView 通用
        .copyValue: "Copy Value", .copyKeyValue: "Copy Key:Value",
        // 基本信息
        .execPath: "Executable Path",
        // 架构
        .buildToolchain: "Build Toolchain",
        .noExecOrIntelSlice: "No executable found, or Intel slice could not be parsed",
        .sliceSize: "Slice Size", .offsetInFat: "Offset in Fat", .nonFat: "— (not fat)",
        // URL Scheme
        .noUrlScheme: "No URL Scheme declared",
        // 隐私
        .noUsageDescription: "No NS***UsageDescription declared",
        // ATS
        .noATS: "No NSAppTransportSecurity / ElectronAsarIntegrity declared",
        // Quarantine
        .rawValue: "Raw", .downloadAgent: "Download Agent", .downloadUUID: "Download UUID",
        .timestampHex: "Timestamp (hex)", .downloadTime: "Download Time",
        .copyRemoveCmd: "Copy Remove Command", .pasteToRemoveHint: "Paste in Terminal to remove quarantine flag",
        .noQuarantineHint: "No com.apple.quarantine attribute (trusted source / already cleared)",
        // 代码签名
        .signState: "Signature State", .validity: "Validity", .notarization: "Notarization",
        .copyCodesignCmd: "Copy codesign Command", .copySpctlCmd: "Copy spctl Command",
        .pasteToVerifyHint: "Paste in Terminal to manually verify signature / notarization",
        .authorityChain: "Authority Chain", .noEntitlements: "No entitlements (unsigned / no sandbox)",
        // 文件信息
        .fullPath: "Full Path", .totalSize: "Total Size", .modifiedTime: "Modification Time",
        .createdTime: "Creation Time", .permissionsOctal: "Permissions (octal)",
        // 子 bundle
        .versionLabel: "Version",
        // 空状态
        .noAppleScript: "No AppleScript / Siri support declared",
        .noICloudContainer: "No iCloud container declared", .noNotificationKeys: "No notification keys declared",
        .noSwitches: "No switches declared", .noLocalizationKeys: "No Help/i10n/Accent/Spotlight keywords declared",
        .noIOSPortFields: "No iOS port fields declared", .noBuildMetadata: "No Electron / vendor / build metadata declared",
        // 打开面板
        .pickAppPanelTitle: "Select .app bundle",
        .bytesUnit: "bytes",
        .noBonjour: "No NSBonjourServices declared",
        .flagsRaw: "flags (raw)", .flagsDecoded: "flags (decoded)",
        .emptyPlaceholder: "(empty)"
    ]

    /// 当前生效语言（system 时按系统首选判断）。
    private static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "swiftlens.language") ?? AppLanguage.system.rawValue
        let lang = AppLanguage(rawValue: raw) ?? .system
        switch lang {
        case .zh: return .zh
        case .en: return .en
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("zh") ? .zh : .en
        }
    }

    /// 查询字符串。注意：因为不依赖 SwiftUI 环境，调用者需要让视图依赖 AppState.language 以便刷新。
    static func t(_ key: Key) -> String {
        switch current {
        case .zh, .system: return zh[key] ?? key.rawValue
        case .en:          return en[key] ?? zh[key] ?? key.rawValue
        }
    }
}