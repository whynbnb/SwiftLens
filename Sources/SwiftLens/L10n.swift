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
        case machOMinOS
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
        case strictValidation
        case notarization
        case copyCodesignCmd
        case copySpctlCmd
        case pasteToVerifyHint
        case authorityChain
        case certDetails
        case certIssuer
        case certValidity
        case certFingerprint
        case certExpired
        case certExpiringSoon
        case noEntitlements
        case riskCount
        case riskDisableLibraryValidation
        case riskUnsignedExecMemory
        case riskDyldEnv
        case riskGetTaskAllow
        case riskDebugger
        case riskAllowJIT
        case riskDisableExecPageProtection
        case riskTempException
        // 文件信息
        case fullPath
        case totalSize
        case modifiedTime
        case createdTime
        case permissionsOctal
        // 子 bundle 版本
        case versionLabel
        case archShort
        case warnSubInvalid
        case warnSubStrict
        case warnTeamMismatch
        case warnArchMismatch
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
        // 头部徽章 tooltip
        case unknownArch
        case goArchSection
        case goQuarantineSection
        case goCodeSignSection
        case goEntitlementsSection
        // 关于面板
        case openInBrowser
        case repository
        case license
        // 帮助页 - 分区标题
        case helpNotarizationTitle
        case helpSandboxTitle
        case helpQuarantineTitle
        case helpValidityTitle
        case helpBadgesTitle
        // 帮助页 - 公证状态说明
        case helpNotarizedTitle
        case helpNotarizedDesc
        case helpDevIDTitle
        case helpDevIDDesc
        case helpMASTitle
        case helpMASDesc
        case helpIOSStoreTitle
        case helpIOSStoreDesc
        case helpAppleSystemTitle
        case helpAppleSystemDesc
        case helpNotNotarizedTitle
        case helpNotNotarizedDesc
        // 帮助页 - 沙盒
        case helpSandboxedTitle
        case helpSandboxedDesc
        case helpNoSandboxTitle
        case helpNoSandboxDesc
        // 帮助页 - 隔离
        case helpQuarantinedTitle
        case helpQuarantinedDesc
        case helpNoQuarantineTitle
        case helpNoQuarantineDesc
        // 帮助页 - 签名有效性
        case helpBasicValidTitle
        case helpBasicValidDesc
        case helpInvalidTitle
        case helpInvalidDesc
        case helpUntestedTitle
        case helpUntestedDesc
        case helpStrictValidTitle
        case helpStrictValidDesc
        // 帮助页 - 其它标识
        case helpAgentAppTitle
        case helpAgentAppDesc
        case helpBackgroundTitle
        case helpBackgroundDesc
        case helpIOSPortTitle
        case helpIOSPortDesc
        // CLI / 复制摘要 通用
        case cliPath
        case cliVersion
        case cliMinOS
        case cliSDK
        case cliPlistKeys
        case cliArchs
        case cliPlatforms
        case cliCopyright
        case cliUrlSchemes
        case cliDocTypes
        case cliSign
        case cliSandbox
        case cliSandboxYes
        case cliSandboxNo
        case cliPrivacy
        case cliATS
        case cliElectron
        case cliFormAgent
        case cliFormBackground
        case cliFormIOSPort
        case cliSparkle
        case cliAuthority
        case cliEntitlementsCount
        case cliEntitlementsNone
        case cliQuarantine
        case cliQuarantineNone
        case cliXattrs
        case cliSubBundles
        case cliMore
        case cliFileSize
        case cliFlagsDecoded
        case cliFlagsRaw
        case cliSignFlags
        case cliDays
        case cliSeconds
        case cliDownloadTime
        case cliICloudContainers
        case discloseRawXml
        case disclosePlistAll
        case discloseCodesignDetail
        case entryUnit
        case sandboxEnabled
        case sandboxDisabled
        case emptyDesc
        case atsNone
        case dayUnit
        case secUnit
        // SignedState
        case ssSigned
        case ssAdhoc
        case ssUnsigned
        case ssUnknown
        // Validity
        case vValid
        case vInvalid
        case vUntested
        case strictPass
        case strictFail
        case strictUntested
        // Notarization
        case nNotarized
        case nDevID
        case nMAS
        case nIOSStore
        case nAppleSystem
        case nNotNotarized
        case nUnknown
        // 错误/占位
        case errSecStaticCode
        case errSecCodeCopySign
        case unknownCert
        case unsignedDetail
        case emptyPlaceholder2
        case unreadablePlaceholder
        // PrivacyReader 中文标题
        case pContacts
        case pCalendars
        case pCalendarsFull
        case pReminders
        case pRemindersFull
        case pLocation
        case pLocationAlways
        case pLocationWhenInUse
        case pLocationBoth
        case pLocationDefaultReduced
        case pCamera
        case pMicrophone
        case pAudioCapture
        case pBluetoothAlways
        case pBluetoothPeripheral
        case pHealthShare
        case pHealthClinical
        case pHealthUpdate
        case pHomeKit
        case pMotion
        case pExtension
        case pAppleMusic
        case pPhotoLibrary
        case pPhotoLibraryAdd
        case pCameraReaction
        case pSpeechRecognition
        case pSiri
        case pFilesDownloaded
        case pAppleEvents
        case pSystemAdministration
        case pVideoAccount
        case pCameraCapture
        case pFaceID
        case pSystemExtension
        case pScreenCapture
        case pFileProvider
        case pUserNotifications
        case pLocalNotifications
        case pRemoteNotifications
        case pAutoFill
        case pUpdateSecurityPolicy
        case pLocationTemporary
        case pContactsAdd
        case pContactsCard
        case pInputAssistant
        case pDesktop
        case pDocuments
        case pDownloads
        case pNetworkVolumes
        case pRemovable
        case pServices
        // Fallback 助词
        case pAlways
        case pWhenInUse
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
        .machOMinOS: "Mach-O 最低系统 (minos)",
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
        .signState: "签名状态", .validity: "有效性", .strictValidation: "严格验证 (Strict)",
        .notarization: "公证 (Notarization)",
        .copyCodesignCmd: "复制 codesign 命令", .copySpctlCmd: "复制 spctl 命令",
        .pasteToVerifyHint: "在终端粘贴运行即可手动验证签名 / 公证状态",
        .authorityChain: "Authority 链", .noEntitlements: "无 entitlements (未签名 / 无沙盒)",
        .certDetails: "证书详情", .certIssuer: "签发者", .certValidity: "有效期",
        .certFingerprint: "SHA-256 指纹", .certExpired: "已过期", .certExpiringSoon: "即将过期",
        .riskCount: "高风险 entitlements",
        .riskDisableLibraryValidation: "关闭库验证：可加载未签名/第三方 dylib",
        .riskUnsignedExecMemory: "允许未签名可执行内存（常见于 JIT / 注入）",
        .riskDyldEnv: "允许 DYLD_* 环境变量影响加载",
        .riskGetTaskAllow: "允许调试器附加 (get-task-allow，通常为 Debug 签名)",
        .riskDebugger: "允许以调试器身份运行 (cs.debugger)",
        .riskAllowJIT: "允许 JIT 可执行内存",
        .riskDisableExecPageProtection: "关闭可执行页保护 (危险)",
        .riskTempException: "使用临时例外 entitlement (通常仅限 App Store)",
        // 文件信息
        .fullPath: "完整路径", .totalSize: "总大小", .modifiedTime: "修改时间",
        .createdTime: "创建时间", .permissionsOctal: "权限 (octal)",
        // 子 bundle
        .versionLabel: "版本",
        .archShort: "架构",
        .warnSubInvalid: "签名验证未通过",
        .warnSubStrict: "严格验证未通过 (资源可能被修改)",
        .warnTeamMismatch: "Team ID 与主应用不一致",
        .warnArchMismatch: "架构少于主应用 (可能在部分 Mac 上无法加载)",
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
        .emptyPlaceholder: "(无)",
        .unknownArch: "未知架构",
        .goArchSection: "跳转到「架构」分区",
        .goQuarantineSection: "跳转到「Quarantine」分区",
        .goCodeSignSection: "跳转到「代码签名」分区",
        .goEntitlementsSection: "跳转到「Entitlements」分区",
        .openInBrowser: "在浏览器中打开: ",
        .repository: "仓库", .license: "许可证",
        // 帮助页 - 分区标题
        .helpNotarizationTitle: "签名状态 / 公证状态",
        .helpSandboxTitle: "沙盒状态",
        .helpQuarantineTitle: "Quarantine 隔离标记",
        .helpValidityTitle: "签名有效性",
        .helpBadgesTitle: "其它标识",
        // 公证
        .helpNotarizedTitle: "已公证 (Notarized)",
        .helpNotarizedDesc: "Developer ID 签名且通过 Gatekeeper 严格验证。Apple 已公证该应用，可安全运行。",
        .helpDevIDTitle: "Developer ID 签名",
        .helpDevIDDesc: "Developer ID 证书签名，但未通过严格验证（签名可能已损坏、资源缺失或被修改）。Gatekeeper 会拒绝运行。",
        .helpMASTitle: "Mac App Store",
        .helpMASDesc: "通过 Mac App Store 分发的应用，使用 Apple Mac OS Application Signing 证书签名。",
        .helpIOSStoreTitle: "iOS App Store",
        .helpIOSStoreDesc: "iOS 应用（在 Apple Silicon Mac 上运行），使用 Apple iPhone OS Application Signing 证书签名。天然沙盒。",
        .helpAppleSystemTitle: "Apple 系统签名",
        .helpAppleSystemDesc: "macOS 系统自带应用，使用 macOS Software Signing 证书签名。无需公证。",
        .helpNotNotarizedTitle: "未公证",
        .helpNotNotarizedDesc: "Ad-hoc 签名、未签名或其它无法判定公证状态的情况。Gatekeeper 默认拒绝。",
        // 沙盒
        .helpSandboxedTitle: "沙盒应用",
        .helpSandboxedDesc: "Entitlements 中含 com.apple.security.app-sandbox，应用运行在 App Sandbox 沙盒内，文件和网络访问受限。",
        .helpNoSandboxTitle: "非沙盒",
        .helpNoSandboxDesc: "未启用 App Sandbox。应用可自由访问系统资源（受用户权限限制）。",
        // 隔离
        .helpQuarantinedTitle: "已隔离",
        .helpQuarantinedDesc: "应用带 com.apple.quarantine 扩展属性，通常是从网络下载的。首次运行会触发 Gatekeeper 检查。",
        .helpNoQuarantineTitle: "无隔离",
        .helpNoQuarantineDesc: "未检测到 quarantine 标记。可能来自可信来源（如 App Store）或已手动清除。",
        // 签名有效性
        .helpBasicValidTitle: "基础有效 (Basic Valid)",
        .helpBasicValidDesc: "SecStaticCodeCheckValidity 基础验证通过 (kSecCSBasicValidateOnly)。仅校验签名结构完整, 不等同于 Gatekeeper 完整验证或资源封印验证。完整可信度请参考「签名状态/公证状态」徽章。",
        .helpInvalidTitle: "无效 (Invalid)",
        .helpInvalidDesc: "基础验证失败。签名可能被篡改或损坏。",
        .helpUntestedTitle: "未验证",
        .helpUntestedDesc: "未签名应用, 无法进行有效性验证。",
        .helpStrictValidTitle: "严格验证 (Strict)",
        .helpStrictValidDesc: "在基础验证之上额外校验资源封印 (CodeResources)、嵌套代码与所有架构切片；资源被篡改或缺失时会失败。",
        // 其它标识
        .helpAgentAppTitle: "Agent App (无 Dock)",
        .helpAgentAppDesc: "Info.plist 中 LSUIElement=true。无 Dock 图标、无主菜单栏，常用于后台工具或菜单栏应用。",
        .helpBackgroundTitle: "仅后台 (Background)",
        .helpBackgroundDesc: "Info.plist 中 LSBackgroundOnly=true。纯后台运行，无 UI。",
        .helpIOSPortTitle: "iOS 移植包",
        .helpIOSPortDesc: "Info.plist 中含 UI* 键（UIDeviceFamily / UILaunchStoryboardName 等），是 iOS 移植到 macOS 的应用。",
        // CLI / 复制摘要
        .cliPath: "路径", .cliVersion: "版本", .cliMinOS: "最低系统版本",
        .cliSDK: "SDK", .cliPlistKeys: "项", .cliArchs: "架构", .cliPlatforms: "支持平台",
        .cliCopyright: "版权", .cliUrlSchemes: "URL Schemes", .cliDocTypes: "文档类型",
        .cliSign: "签名", .cliSandbox: "沙盒", .cliSandboxYes: "是 (App Sandbox)", .cliSandboxNo: "否",
        .cliPrivacy: "隐私权限描述", .cliATS: "已声明 NSAppTransportSecurity", .cliElectron: "已声明 ElectronAsarIntegrity",
        .cliFormAgent: "形态: Agent App (无 Dock 图标)", .cliFormBackground: "形态: 仅后台运行 (LSBackgroundOnly)",
        .cliFormIOSPort: "形态: iOS 移植包 (含 UI* 键)",
        .cliSparkle: "Sparkle 自动更新", .cliAuthority: "Authority",
        .cliEntitlementsCount: "项", .cliEntitlementsNone: "无",
        .cliQuarantine: "时间", .cliQuarantineNone: "无",
        .cliXattrs: "扩展属性 (xattrs)", .cliSubBundles: "子 bundle",
        .cliMore: "另外", .cliFileSize: "文件大小", .cliFlagsDecoded: "flags(解码)", .cliFlagsRaw: "flags(原始)",
        .cliSignFlags: "签名 flags",         .cliDays: "天", .cliSeconds: "秒", .cliDownloadTime: "日期",
        .cliICloudContainers: "项",
        .discloseRawXml: "原始 XML",
        .disclosePlistAll: "展开 Info.plist 全部键值",
        .discloseCodesignDetail: "展开签名详情 (Security 框架合成)",
        .entryUnit: "项", .sandboxEnabled: "✅ 已启用 (com.apple.security.app-sandbox)",
        .sandboxDisabled: "❌ 未启用", .emptyDesc: "<空>",
        .atsNone: "无",         .dayUnit: "天", .secUnit: "秒",
        // SignedState
        .ssSigned: "已签名 (Signed)", .ssAdhoc: "Ad-hoc 签名", .ssUnsigned: "未签名 (Not signed)", .ssUnknown: "未知",
        // Validity
        .vValid: "基础有效 (Basic Valid)", .vInvalid: "无效 (Invalid)", .vUntested: "未验证",
        .strictPass: "通过", .strictFail: "未通过", .strictUntested: "—",
        // Notarization
        .nNotarized: "已公证 (Notarized)", .nDevID: "Developer ID 签名", .nMAS: "Mac App Store",
        .nIOSStore: "iOS App Store", .nAppleSystem: "Apple 系统签名", .nNotNotarized: "未公证",         .nUnknown: "未知",
        // 错误
        .errSecStaticCode: "SecStaticCodeCreateWithPath 失败",
        .errSecCodeCopySign: "SecCodeCopySigningInformation 失败",
        .unknownCert: "(未知证书)", .unsignedDetail: "(未签名)",
        .emptyPlaceholder2: "<空>", .unreadablePlaceholder: "<无法读取>",
        // Privacy 标题 (zh)
        .pContacts: "通讯录", .pCalendars: "日历", .pCalendarsFull: "日历完整访问",
        .pReminders: "提醒事项", .pRemindersFull: "提醒事项完整访问",
        .pLocation: "位置", .pLocationAlways: "位置 (始终)", .pLocationWhenInUse: "位置 (使用时)",
        .pLocationBoth: "位置 (始终+使用时)", .pLocationDefaultReduced: "位置精度 (降级)",
        .pCamera: "相机", .pMicrophone: "麦克风", .pAudioCapture: "音频捕获",
        .pBluetoothAlways: "蓝牙 (始终)", .pBluetoothPeripheral: "蓝牙外设",
        .pHealthShare: "健康共享", .pHealthClinical: "健康临床记录", .pHealthUpdate: "健康更新",
        .pHomeKit: "HomeKit", .pMotion: "运动与健身", .pExtension: "扩展 (Extensions)",
        .pAppleMusic: "Apple Music", .pPhotoLibrary: "照片库", .pPhotoLibraryAdd: "照片库 (添加)",
        .pCameraReaction: "相机反应手势", .pSpeechRecognition: "语音识别", .pSiri: "Siri",
        .pFilesDownloaded: "下载文件夹", .pAppleEvents: "Apple 事件 (自动化)",
        .pSystemAdministration: "系统管理 (特权)", .pVideoAccount: "视频订阅账号",
        .pCameraCapture: "相机捕获", .pFaceID: "Face ID", .pSystemExtension: "系统扩展",
        .pScreenCapture: "屏幕捕获", .pFileProvider: "文件提供者域", .pUserNotifications: "用户通知",
        .pLocalNotifications: "本地通知", .pRemoteNotifications: "远程通知",
        .pAutoFill: "自动填充 (验证码)", .pUpdateSecurityPolicy: "更新安全策略",
        .pLocationTemporary: "位置临时使用 (字典)", .pContactsAdd: "通讯录 (添加)",
        .pContactsCard: "联系人卡片", .pInputAssistant: "输入助手", .pDesktop: "桌面文件夹",
        .pDocuments: "文稿文件夹", .pDownloads: "下载文件夹", .pNetworkVolumes: "网络卷",
        .pRemovable: "可移动卷", .pServices: "服务 (Services)",
        .pAlways: " (始终)", .pWhenInUse: " (使用时)"
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
        .machOMinOS: "Mach-O minos",
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
        .signState: "Signature State", .validity: "Validity", .strictValidation: "Strict Validation",
        .notarization: "Notarization",
        .copyCodesignCmd: "Copy codesign Command", .copySpctlCmd: "Copy spctl Command",
        .pasteToVerifyHint: "Paste in Terminal to manually verify signature / notarization",
        .authorityChain: "Authority Chain", .noEntitlements: "No entitlements (unsigned / no sandbox)",
        .certDetails: "Certificate Details", .certIssuer: "Issuer", .certValidity: "Validity",
        .certFingerprint: "SHA-256 Fingerprint", .certExpired: "Expired", .certExpiringSoon: "Expiring soon",
        .riskCount: "High-risk entitlements",
        .riskDisableLibraryValidation: "Library validation disabled: unsigned/third-party dylibs may load",
        .riskUnsignedExecMemory: "Unsigned executable memory allowed (JIT / injection)",
        .riskDyldEnv: "DYLD_* environment variables can affect loading",
        .riskGetTaskAllow: "Debugger attach allowed (get-task-allow, usually debug signing)",
        .riskDebugger: "Runs with debugger entitlement (cs.debugger)",
        .riskAllowJIT: "JIT executable memory allowed",
        .riskDisableExecPageProtection: "Executable page protection disabled (dangerous)",
        .riskTempException: "Uses temporary-exception entitlement (normally App Store only)",
        // 文件信息
        .fullPath: "Full Path", .totalSize: "Total Size", .modifiedTime: "Modification Time",
        .createdTime: "Creation Time", .permissionsOctal: "Permissions (octal)",
        // 子 bundle
        .versionLabel: "Version",
        .archShort: "Architectures",
        .warnSubInvalid: "Signature validation failed",
        .warnSubStrict: "Strict validation failed (resources may be modified)",
        .warnTeamMismatch: "Team ID differs from the main app",
        .warnArchMismatch: "Fewer architectures than the main app (may fail on some Macs)",
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
        .emptyPlaceholder: "(empty)",
        .unknownArch: "Unknown arch",
        .goArchSection: "Go to Architecture section",
        .goQuarantineSection: "Go to Quarantine section",
        .goCodeSignSection: "Go to Code Signing section",
        .goEntitlementsSection: "Go to Entitlements section",
        .openInBrowser: "Open in browser: ",
        .repository: "Repository", .license: "License",
        // 帮助页 - 分区标题
        .helpNotarizationTitle: "Signature / Notarization State",
        .helpSandboxTitle: "Sandbox State",
        .helpQuarantineTitle: "Quarantine Flag",
        .helpValidityTitle: "Signature Validity",
        .helpBadgesTitle: "Other Badges",
        // 公证
        .helpNotarizedTitle: "Notarized",
        .helpNotarizedDesc: "Signed with a Developer ID certificate and passed Gatekeeper strict validation. Apple has notarized this app; safe to run.",
        .helpDevIDTitle: "Developer ID (not notarized)",
        .helpDevIDDesc: "Signed with a Developer ID certificate but failed strict validation (signature may be damaged, resources missing, or modified). Gatekeeper will refuse to run.",
        .helpMASTitle: "Mac App Store",
        .helpMASDesc: "Distributed via the Mac App Store, signed with the Apple Mac OS Application Signing certificate.",
        .helpIOSStoreTitle: "iOS App Store",
        .helpIOSStoreDesc: "iOS app running on Apple Silicon Mac, signed with the Apple iPhone OS Application Signing certificate. Inherently sandboxed.",
        .helpAppleSystemTitle: "Apple System Signed",
        .helpAppleSystemDesc: "Bundled with macOS, signed with the macOS Software Signing certificate. Notarization not required.",
        .helpNotNotarizedTitle: "Not Notarized",
        .helpNotNotarizedDesc: "Ad-hoc signed, unsigned, or otherwise unable to determine notarization. Gatekeeper refuses by default.",
        // 沙盒
        .helpSandboxedTitle: "Sandboxed",
        .helpSandboxedDesc: "Entitlements include com.apple.security.app-sandbox; the app runs inside App Sandbox with restricted file and network access.",
        .helpNoSandboxTitle: "Not Sandboxed",
        .helpNoSandboxDesc: "App Sandbox is not enabled. The app can freely access system resources (subject to user permissions).",
        // 隔离
        .helpQuarantinedTitle: "Quarantined",
        .helpQuarantinedDesc: "The app carries the com.apple.quarantine extended attribute, typically from a download. First launch triggers a Gatekeeper check.",
        .helpNoQuarantineTitle: "No Quarantine",
        .helpNoQuarantineDesc: "No quarantine flag detected. May come from a trusted source (e.g. App Store) or have been manually cleared.",
        // 签名有效性
        .helpBasicValidTitle: "Basic Valid",
        .helpBasicValidDesc: "SecStaticCodeCheckValidity basic validation passed (kSecCSBasicValidateOnly). Only verifies signature structure; not equivalent to full Gatekeeper or sealed-resource validation. See the Signature/Notarization badge for trustworthiness.",
        .helpInvalidTitle: "Invalid",
        .helpInvalidDesc: "Basic validation failed. The signature may be tampered or corrupted.",
        .helpUntestedTitle: "Untested",
        .helpUntestedDesc: "The app is unsigned; validity could not be checked.",
        .helpStrictValidTitle: "Strict Validation",
        .helpStrictValidDesc: "In addition to basic validation, verifies the sealed resources (CodeResources), nested code, and every architecture slice; fails if resources were modified or are missing.",
        // 其它标识
        .helpAgentAppTitle: "Agent App (no Dock)",
        .helpAgentAppDesc: "Info.plist has LSUIElement=true. No Dock icon and no main menu bar; commonly used for background tools or menu-bar apps.",
        .helpBackgroundTitle: "Background-only",
        .helpBackgroundDesc: "Info.plist has LSBackgroundOnly=true. Runs purely in the background with no UI.",
        .helpIOSPortTitle: "iOS port",
        .helpIOSPortDesc: "Info.plist contains UI* keys (UIDeviceFamily / UILaunchStoryboardName, etc.); an iOS app ported to macOS.",
        // CLI / 复制摘要
        .cliPath: "Path", .cliVersion: "Version", .cliMinOS: "Min OS Version",
        .cliSDK: "SDK", .cliPlistKeys: "keys", .cliArchs: "Architectures", .cliPlatforms: "Supported Platforms",
        .cliCopyright: "Copyright", .cliUrlSchemes: "URL Schemes", .cliDocTypes: "Document Types",
        .cliSign: "Signature", .cliSandbox: "Sandbox", .cliSandboxYes: "Yes (App Sandbox)", .cliSandboxNo: "No",
        .cliPrivacy: "Privacy Usage Descriptions", .cliATS: "Declared NSAppTransportSecurity", .cliElectron: "Declared ElectronAsarIntegrity",
        .cliFormAgent: "Form: Agent App (no Dock icon)", .cliFormBackground: "Form: Background-only (LSBackgroundOnly)",
        .cliFormIOSPort: "Form: iOS port (contains UI* keys)",
        .cliSparkle: "Sparkle Auto Update", .cliAuthority: "Authority",
        .cliEntitlementsCount: "entries", .cliEntitlementsNone: "none",
        .cliQuarantine: "Time", .cliQuarantineNone: "none",
        .cliXattrs: "Extended Attributes (xattrs)", .cliSubBundles: "Sub Bundles",
        .cliMore: "more", .cliFileSize: "File Size", .cliFlagsDecoded: "flags (decoded)", .cliFlagsRaw: "flags (raw)",
        .cliSignFlags: "Signature flags",         .cliDays: "days", .cliSeconds: "seconds", .cliDownloadTime: "Date",
        .cliICloudContainers: "entries",
        .discloseRawXml: "Raw XML",
        .disclosePlistAll: "Expand all Info.plist keys",
        .discloseCodesignDetail: "Expand signing details (synthesized from Security framework)",
        .entryUnit: "entries",
        .sandboxEnabled: "✅ Enabled (com.apple.security.app-sandbox)",
        .sandboxDisabled: "❌ Disabled",
        .emptyDesc: "<empty>",
        .atsNone: "None",         .dayUnit: "days", .secUnit: "seconds",
        // SignedState
        .ssSigned: "Signed", .ssAdhoc: "Ad-hoc signed", .ssUnsigned: "Not signed", .ssUnknown: "Unknown",
        // Validity
        .vValid: "Basic Valid", .vInvalid: "Invalid", .vUntested: "Untested",
        .strictPass: "Pass", .strictFail: "Fail", .strictUntested: "—",
        // Notarization
        .nNotarized: "Notarized", .nDevID: "Developer ID", .nMAS: "Mac App Store",
        .nIOSStore: "iOS App Store", .nAppleSystem: "Apple System Signed", .nNotNotarized: "Not Notarized",         .nUnknown: "Unknown",
        // 错误
        .errSecStaticCode: "SecStaticCodeCreateWithPath failed",
        .errSecCodeCopySign: "SecCodeCopySigningInformation failed",
        .unknownCert: "(unknown certificate)", .unsignedDetail: "(unsigned)",
        .emptyPlaceholder2: "<empty>", .unreadablePlaceholder: "<unreadable>",
        // Privacy 标题 (en)
        .pContacts: "Contacts", .pCalendars: "Calendars", .pCalendarsFull: "Calendars (full)",
        .pReminders: "Reminders", .pRemindersFull: "Reminders (full)",
        .pLocation: "Location", .pLocationAlways: "Location (always)", .pLocationWhenInUse: "Location (when in use)",
        .pLocationBoth: "Location (always + when in use)", .pLocationDefaultReduced: "Location accuracy (reduced)",
        .pCamera: "Camera", .pMicrophone: "Microphone", .pAudioCapture: "Audio Capture",
        .pBluetoothAlways: "Bluetooth (always)", .pBluetoothPeripheral: "Bluetooth Peripheral",
        .pHealthShare: "Health Share", .pHealthClinical: "Health Clinical Records", .pHealthUpdate: "Health Update",
        .pHomeKit: "HomeKit", .pMotion: "Motion & Fitness", .pExtension: "Extensions",
        .pAppleMusic: "Apple Music", .pPhotoLibrary: "Photo Library", .pPhotoLibraryAdd: "Photo Library (add)",
        .pCameraReaction: "Camera Reaction Gestures", .pSpeechRecognition: "Speech Recognition", .pSiri: "Siri",
        .pFilesDownloaded: "Downloads Folder", .pAppleEvents: "Apple Events (automation)",
        .pSystemAdministration: "System Administration (privileged)", .pVideoAccount: "Video Subscriber Account",
        .pCameraCapture: "Camera Capture", .pFaceID: "Face ID", .pSystemExtension: "System Extension",
        .pScreenCapture: "Screen Capture", .pFileProvider: "File Provider Domain", .pUserNotifications: "User Notifications",
        .pLocalNotifications: "Local Notifications", .pRemoteNotifications: "Remote Notifications",
        .pAutoFill: "AutoFill (one-time code)", .pUpdateSecurityPolicy: "Update Security Policy",
        .pLocationTemporary: "Location Temporary Use (dictionary)", .pContactsAdd: "Contacts (add)",
        .pContactsCard: "Contact Card", .pInputAssistant: "Input Assistant", .pDesktop: "Desktop Folder",
        .pDocuments: "Documents Folder", .pDownloads: "Downloads Folder", .pNetworkVolumes: "Network Volumes",
        .pRemovable: "Removable Volumes", .pServices: "Services",
        .pAlways: " (always)", .pWhenInUse: " (when in use)"
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