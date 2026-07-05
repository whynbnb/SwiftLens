import Foundation

// MARK: - 隐私权限描述 (TCC Usage Descriptions)

/// 提取 Info.plist 中所有 NS[Resource]UsageDescription 描述并归入分类。
struct PrivacyEntry: Identifiable {
    // 用 key 作 id, 身份稳定 (语言切换/重渲染时 diff 一致)
    var id: String { key }
    let key: String
    /// 本地化 key (运行时通过 L10n.t 求值, 切语言实时跟随)
    let titleKey: L10n.Key?
    /// 兜底派生标题 (key 不在 descriptor 中时使用, 已经按当前语言派生好)
    let derivedTitle: String?
    let systemImage: String
    let description: String          // Info.plist 里的描述串

    /// 当前语言下的展示标题: 优先用 titleKey, 否则用 derivedTitle, 最后兜底 key
    var displayTitle: String {
        if let k = titleKey { return L10n.t(k) }
        if let d = derivedTitle, !d.isEmpty { return d }
        return key
    }
}

enum PrivacyReader {
    // 已知的隐私/权限键映射到 (L10n Key, SF Symbol)
    private static let descriptor: [String: (key: L10n.Key, symbol: String)] = [
        // 通讯录 / 日历 / 提醒
        "NSContactsUsageDescription":         (.pContacts, "person.crop.circle"),
        "NSCalendarsUsageDescription":        (.pCalendars, "calendar"),
        "NSCalendarsFullAccessUsageDescription": (.pCalendarsFull, "calendar.badge.clock"),
        "NSRemindersUsageDescription":        (.pReminders, "list.bullet.rectangle"),
        "NSRemindersFullAccessUsageDescription": (.pRemindersFull, "list.bullet.rectangle.portrait"),
        // 位置
        "NSLocationUsageDescription":         (.pLocation, "location"),
        "NSLocationAlwaysUsageDescription":    (.pLocationAlways, "location.fill"),
        "NSLocationWhenInUseUsageDescription": (.pLocationWhenInUse, "location.viewfinder"),
        "NSLocationAlwaysAndWhenInUseUsageDescription": (.pLocationBoth, "location.fill.viewfinder"),
        "NSLocationDefaultAccuracyReduced":    (.pLocationDefaultReduced, "location.slash"),
        // 媒体捕获
        "NSCameraUsageDescription":           (.pCamera, "camera"),
        "NSMicrophoneUsageDescription":       (.pMicrophone, "mic"),
        "NSAudioCaptureUsageDescription":     (.pAudioCapture, "waveform"),
        // 蓝牙
        "NSBluetoothAlwaysUsageDescription":  (.pBluetoothAlways, "antenna.radiowaves.left.and.right"),
        "NSBluetoothPeripheralUsageDescription": (.pBluetoothPeripheral, "antenna.radiowaves.left.and.right"),
        // 健康 / HomeKit / Motion
        "NSHealthShareUsageDescription":      (.pHealthShare, "heart"),
        "NSHealthClinicalHealthRecordsShareUsageDescription": (.pHealthClinical, "heart.text.squarefill"),
        "NSHealthUpdateUsageDescription":     (.pHealthUpdate, "heart.arrow.circlepath"),
        "NSHomeKitUsageDescription":          (.pHomeKit, "house"),
        "NSMotionUsageDescription":           (.pMotion, "figure.walk"),
        "NSExtensionUsageDescription":        (.pExtension, "puzzlepiece.extension"),
        // 媒体库 / Photos
        "NSAppleMusicUsageDescription":       (.pAppleMusic, "music.note"),
        "NSPhotoLibraryUsageDescription":     (.pPhotoLibrary, "photo"),
        "NSPhotoLibraryAddUsageDescription":  (.pPhotoLibraryAdd, "photo.badge.plus"),
        "NSCameraReactionEffectGesturesEnabledDefault": (.pCameraReaction, "camera.turn.left"),
        // 语音 / Siri
        "NSSpeechRecognitionUsageDescription": (.pSpeechRecognition, "waveform.badge.magnifyingglass"),
        "NSSiriUsageDescription":             (.pSiri, "siri"),
        // 网络卷 / 文件 / 文件夹
        "NSFilesDownloadedUsageDescription":  (.pFilesDownloaded, "arrow.down.circle"),
        // Apple Events / Automation
        "NSAppleEventsUsageDescription":      (.pAppleEvents, "applescript"),
        "NSSystemAdministrationUsageDescription": (.pSystemAdministration, "lock.shield"),
        // 媒体的另外几类
        "NSVideoSubscriberAccountUsageDescription": (.pVideoAccount, "tv"),
        // AVP spatial
        "NSCameraCaptureUsageDescription":    (.pCameraCapture, "camera.viewfinder"),
        // Face ID / Health extras (Motion 已在健康区中)
        "NSFaceIDUsageDescription":           (.pFaceID, "faceid"),
        // 系统扩展 / 屏幕捕获
        "NSSystemExtensionUsageDescription": (.pSystemExtension, "puzzlepiece.extension"),
        "NSScreenCaptureUsageDescription":   (.pScreenCapture, "rectangle.dashed"),
        // FileProvider / 通知
        "NSFileProviderDomainUsageDescription": (.pFileProvider, "folder.fill.badge.plus"),
        "NSUserNotificationsUsageDescription": (.pUserNotifications, "bell"),
        "NSLocalNotificationUsageDescription": (.pLocalNotifications, "bell.badge"),
        "NSRemoteNotificationUsageDescription": (.pRemoteNotifications, "bell.badge.wifi"),
        // 自动填充 / 安全 / 升级
        "NSAutoFillRequiresTextContentTypeForOneTimeCodeOnMac": (.pAutoFill, "text.badge.checkmark"),
        "NSUpdateSecurityPolicy":            (.pUpdateSecurityPolicy, "lock.shield"),
        // 临时位置
        "NSLocationTemporaryUsageDescriptionDictionary": (.pLocationTemporary, "location.tor"),
        // 共享/通讯组
        "NSContactsAddUsageDescription":      (.pContactsAdd, "person.badge.plus"),
        "NSContactsCardUsageDescription":     (.pContactsCard, "person.crop.rectangle"),
        // Keyboard
        "NSInputAssistantUsageDescription":   (.pInputAssistant, "keyboard"),
        // File access
        "NSDesktopFolderUsageDescription":    (.pDesktop, "desktopcomputer"),
        "NSDocumentsFolderUsageDescription":  (.pDocuments, "folder"),
        "NSDownloadsFolderUsageDescription":  (.pDownloads, "arrow.down.circle"),
        "NSNetworkVolumesUsageDescription":   (.pNetworkVolumes, "network"),
        "NSRemovableVolumesUsageDescription": (.pRemovable, "externaldrive"),
        // Service
        "NSServicesUsageDescription":         (.pServices, "wrench.adjustable"),
        // 通用键兜底 —— 任何 "NS<Name>UsageDescription" 但未在上述列表中的
        // 由 parse 时用 default fallback 处理
    ]

    /// 兜底解析：键以 "UsageDescription" 结尾且未在 descriptor 中时，仍尝试生成条目。
    static func parse(from plist: [String: Any]) -> [PrivacyEntry] {
        var results: [PrivacyEntry] = []
        for key in plist.keys.sorted() {
            let isUsageKey = key.hasSuffix("UsageDescription")
            let value: String
            if let s = plist[key] as? String { value = s }
            else { value = InfoPlistParser.describe(plist[key] ?? "") }
            if let meta = descriptor[key] {
                results.append(PrivacyEntry(
                    key: key,
                    titleKey: meta.key,
                    derivedTitle: nil,
                    systemImage: meta.symbol,
                    description: value
                ))
            } else if isUsageKey {
                // 自动从 key 派生显示名 — 派生时已按当前语言替换 Always/WhenInUse;
                // 切语言时 derivedTitle 作为静态字符串不会跟随,
                // 但绝大多数 NS***UsageDescription 都在 descriptor 里走 titleKey 路径。
                // 极少数兜底场景下切语言需重新拖入 app 才更新。
                let title = key
                    .replacingOccurrences(of: "NS", with: "")
                    .replacingOccurrences(of: "UsageDescription", with: "")
                    .replacingOccurrences(of: "Always", with: L10n.t(.pAlways))
                    .replacingOccurrences(of: "WhenInUse", with: L10n.t(.pWhenInUse))
                results.append(PrivacyEntry(
                    key: key,
                    titleKey: nil,
                    derivedTitle: title.isEmpty ? nil : title,
                    systemImage: "questionmark.shield",
                    description: value
                ))
            }
        }
        return results
    }
}