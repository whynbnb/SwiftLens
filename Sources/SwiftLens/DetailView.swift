import SwiftUI
import AppKit

/// 详情面板：以分区形式展示 .app 信息。
struct DetailView: View {
    let info: AppInfo

    /// 顶部状态对应的目标位置锚点。
    enum DetailAnchor: Hashable {
        case architectures
        case quarantine
        case codeSign
        case entitlements
        case privacy
        case ats
        case subBundles
    }

    /// 顶部「架构」徽标：空 → [未知]；单 → [名字]；多切片 → [Universal] [a] [b] ... 多个独立 badge
    @ViewBuilder
    private func archBadges(proxy: ScrollViewProxy) -> some View {
        if info.architectures.isEmpty {
            Button {
                withAnimation { proxy.scrollTo(DetailAnchor.architectures, anchor: .top) }
            } label: { Badge(text: L10n.t(.unknownArch), color: .blue) }
                .buttonStyle(.plain).help(L10n.t(.goArchSection))
        } else if info.architectures.count == 1 {
            Button {
                withAnimation { proxy.scrollTo(DetailAnchor.architectures, anchor: .top) }
            } label: { Badge(text: info.architectures.first!.name, color: .blue) }
                .buttonStyle(.plain).help(L10n.t(.goArchSection))
        } else {
            Button {
                withAnimation { proxy.scrollTo(DetailAnchor.architectures, anchor: .top) }
            } label: { Badge(text: "Universal", color: .blue) }
                .buttonStyle(.plain).help(L10n.t(.goArchSection))
            ForEach(Array(info.architectures.enumerated()), id: \.offset) { _, arch in
                Button {
                    withAnimation { proxy.scrollTo(DetailAnchor.architectures, anchor: .top) }
                } label: { Badge(text: arch.name, color: .blue.opacity(0.85)) }
                    .buttonStyle(.plain).help(L10n.t(.goArchSection))
            }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection(proxy: proxy)
                    basicSection
                    runtimeSection
                    architecturesSection
                        .id(DetailAnchor.architectures)
                    documentTypesSection
                    urlSchemesSection
                    privacySection
                        .id(DetailAnchor.privacy)
                    atsSection
                        .id(DetailAnchor.ats)
                    quarantineSection
                        .id(DetailAnchor.quarantine)
                    xattrsSection
                    codeSignSection
                        .id(DetailAnchor.codeSign)
                    entitlementsSection
                        .id(DetailAnchor.entitlements)
                    subBundlesSection
                        .id(DetailAnchor.subBundles)
                    sparkleSection
                    appleScriptSiriSection
                    iCloudSection
                    notificationsSection
                    behaviorsSection
                    localizationSection
                    iosPortSection
                    buildMetadataSection
                    bonjourSection
                    fileSection
                    rawPlistSection
                    rawCodesignSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(info.bundleURL.lastPathComponent)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([info.bundleURL])
                    } label: { Label(L10n.t(.revealInFinder), systemImage: "folder") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        copyToPasteboard(summaryString())
                    } label: { Label(L10n.t(.copySummary), systemImage: "doc.on.doc") }
                }
            }
        }
    }

    // MARK: 顶部头
    private func headerSection(proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let icon = info.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
            } else {
                Image(systemName: "app")
                    .resizable()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(info.displayName ?? info.bundleName ?? info.bundleURL.lastPathComponent)
                        .font(.system(.title2, design: .default).bold())
                    // 版本徽章 —— 一眼可见
                    if info.bundleShortVersion != nil || info.bundleVersion != nil {
                        Text(versionBadgeText())
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().strokeBorder(.tertiary.opacity(0.5)))
                    }
                }
                if let bid = info.bundleIdentifier {
                    Text(bid).font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                Text(info.bundleURL.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                // 顺序与下方分区一致：架构 → 隔离 → 代码签名
                // 架构通用二进制时会拆成多个独立 badge (Universal · arm64 · x86_64 ...)
                HStack(spacing: 6) {
                    archBadges(proxy: proxy)
                }

                // Agent App / 仅后台 / iOS 移植 等标识
                if info.lsUIElement == true {
                    Badge(text: L10n.t(.badgeAgentApp), color: .purple)
                }
                if info.lsBackgroundOnly == true {
                    Badge(text: L10n.t(.badgeBackground), color: .indigo)
                }
                if info.isIOSPort {
                    Badge(text: L10n.t(.badgeIOSPort), color: .pink)
                }

                Button {
                    withAnimation { proxy.scrollTo(DetailAnchor.quarantine, anchor: .top) }
                } label: {
                    Badge(text: info.quarantine != nil ? L10n.t(.badgeIsolated) : L10n.t(.badgeNoQuarantine),
                          color: info.quarantine != nil ? .yellow : .gray)
                }
                .buttonStyle(.plain)
                .help(L10n.t(.goQuarantineSection))

                // 签名状态 + 有效性 + 公证，同一行，三个都跳转到代码签名分区
                HStack(spacing: 6) {
                    Button {
                        withAnimation { proxy.scrollTo(DetailAnchor.codeSign, anchor: .top) }
                    } label: {
                        Badge(text: info.codeSign.state.localizedName,
                              color: badgeColor(for: info.codeSign.state))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t(.goCodeSignSection))

                    Button {
                        withAnimation { proxy.scrollTo(DetailAnchor.codeSign, anchor: .top) }
                    } label: {
                        Badge(text: info.codeSign.validity.localizedName,
                              color: validityColor(info.codeSign.validity))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t(.goCodeSignSection))

                    Button {
                        withAnimation { proxy.scrollTo(DetailAnchor.codeSign, anchor: .top) }
                    } label: {
                        Badge(text: info.codeSign.notarization.localizedName,
                              color: notarizationColor(info.codeSign.notarization))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t(.goCodeSignSection))
                }

                // 沙盒状态徽章 —— 跳转到 Entitlements 分区
                Button {
                    withAnimation { proxy.scrollTo(DetailAnchor.entitlements, anchor: .top) }
                } label: {
                    Badge(text: L10n.t(info.isSandboxed ? .badgeSandboxed : .badgeNoSandbox),
                          color: info.isSandboxed ? .green : .orange)
                }
                .buttonStyle(.plain)
                .help(L10n.t(.goEntitlementsSection))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.3)))
    }

    // MARK: 基本信息
    private var basicSection: some View {
        SectionView(L10n.t(.basicInfo)) {
            RowView(key: "CFBundleDisplayName", value: info.displayName ?? "—")
            RowView(key: "CFBundleName", value: info.bundleName ?? "—")
            RowView(key: "CFBundleIdentifier", value: info.bundleIdentifier ?? "—")
            RowView(key: "CFBundleShortVersionString", value: info.bundleShortVersion ?? "—")
            RowView(key: "CFBundleVersion", value: info.bundleVersion ?? "—")
            if let v = info.longVersionString { RowView(key: "CFBundleLongVersionString", value: v) }
            if let v = info.getInfoString { RowView(key: "CFBundleGetInfoString", value: v) }
            if let v = info.bundleSignature { RowView(key: "CFBundleSignature", value: v) }
            RowView(key: "CFBundleExecutable", value: info.executableName ?? "—")
            RowView(key: L10n.t(.execPath), value: info.executablePath ?? "—")
            RowView(key: "CFBundlePackageType", value: info.bundlePackageType ?? "—")
            RowView(key: "CFBundleInfoDictionaryVersion", value: info.infoDictionaryVersion ?? "—")
            RowView(key: "CFBundleDevelopmentRegion", value: info.developmentRegion ?? "—")
            if let v = info.principalClass { RowView(key: "NSPrincipalClass", value: v) }
            if let v = info.humanReadableCopyright { RowView(key: "NSHumanReadableCopyright", value: v) }
            if !info.supportedPlatforms.isEmpty {
                RowView(key: "CFBundleSupportedPlatforms", value: info.supportedPlatforms.joined(separator: ", "))
            }
        }
    }

    // MARK: 运行时 / 部署
    private var runtimeSection: some View {
        SectionView(L10n.t(.runtime)) {
            RowView(key: "LSMinimumSystemVersion", value: info.lsMinimumSystemVersion ?? "—")
            if let v = info.minimumOSVersionIOS {
                RowView(key: "MinimumOSVersion", value: v)
            }
            RowView(key: "LSApplicationCategoryType", value: info.applicationCategoryType ?? "—")
            RowView(key: "LSRequiresAquaSystemAppearance", value: bool(info.requiresAquaSystemAppearance))
            RowView(key: "NSHighResolutionCapable", value: bool(info.highResolutionCapable))
            RowView(key: "NSSupportsHighResolutionDisplays", value: bool(info.supportsHighResolutionDisplays))
            RowView(key: "NSCanAnimateAlpha", value: bool(info.canAnimateAlpha))
            RowView(key: "NSSupportsAutomaticGraphicsSwitching", value: bool(info.supportsAutomaticGraphicsSwitching))
            RowView(key: "NSQuitAlwaysKeepsWindows", value: bool(info.quitAlwaysKeepsWindows))
            RowView(key: "NSPrefersDisplaySafeAreaCompatibilityMode", value: bool(info.prefersDisplaySafeAreaCompatibilityMode))
            RowView(key: "LSBackgroundOnly", value: bool(info.lsBackgroundOnly))
            RowView(key: "CSResourcesFileMapped", value: bool(info.csResourcesFileMapped))
            RowView(key: "CFBundleUses24HourClock", value: bool(info.uses24HourClock))
            if !info.lsEnvironment.isEmpty {
                Divider().padding(.vertical, 2)
                Text("LSEnvironment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(info.lsEnvironment.keys.sorted(), id: \.self) { k in
                    RowView(key: k, value: info.lsEnvironment[k] ?? "—")
                }
            }
            Divider().padding(.vertical, 2)
            Text(L10n.t(.buildToolchain))
                .font(.caption)
                .foregroundStyle(.secondary)
            RowView(key: "DTSDKName", value: info.sdkVersion ?? "—")
            RowView(key: "DTPlatformName", value: info.platformName ?? "—")
            RowView(key: "DTPlatformVersion", value: info.platformVersion ?? "—")
            RowView(key: "DTSDKBuild", value: info.sdkBuild ?? "—")
            RowView(key: "DTPlatformBuild", value: info.platformBuild ?? "—")
            RowView(key: "DTXcode", value: info.xcodeVersion ?? "—")
            RowView(key: "DTXcodeBuild", value: info.xcodeBuild ?? "—")
            RowView(key: "DTCompiler", value: info.dtCompiler ?? "—")
            RowView(key: "BuildMachineOSBuild", value: info.buildMachineOSBuild ?? "—")
        }
    }

    // MARK: 架构
    private var architecturesSection: some View {
        SectionView(L10n.t(.architectures),
                    subtitle: "Universal slices") {
            if info.architectures.isEmpty {
                PlaceholderRow(text: L10n.t(.noExecOrIntelSlice))
            } else {
                ForEach(Array(info.architectures.enumerated()), id: \.offset) { _, arch in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(arch.name).font(.system(.body, design: .monospaced).bold())
                            Text("· \(arch.cpuType) · \(arch.bits)-bit")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        RowView(key: L10n.t(.sliceSize), value: formattedSize(arch.fileSize))
                        RowView(key: L10n.t(.offsetInFat), value: arch.offsetInFat == 0 ? L10n.t(.nonFat) : "0x\(String(arch.offsetInFat, radix: 16))")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: 文档类型
    /// 数量超过该阈值时启用固定高度内嵌滚动，避免单一分区把整页拉得太长。
    private static let documentTypesCollapsableThreshold = 6

    private var documentTypesSection: some View {
        SectionView(L10n.t(.documentTypes), subtitle: "\(info.documentTypes.count)") {
            if info.documentTypes.isEmpty {
                PlaceholderRow(text: L10n.t(.noneDocType))
            } else {
                // 数量较多：固定高度 + 提示 + 内嵌滚动
                let bodyContent = VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(info.documentTypes.enumerated()), id: \.offset) { _, doc in
                        DocumentTypeRowView(doc: doc)
                    }
                }

                if info.documentTypes.count > Self.documentTypesCollapsableThreshold {
                    ScrollView {
                        bodyContent
                    }
                    .frame(maxHeight: 280)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.2)))
                } else {
                    bodyContent
                }
            }
            if !info.exportedTypeIdentifiers.isEmpty || !info.importedTypeIdentifiers.isEmpty {
                Divider().padding(.vertical, 4)
                RowView(key: "Exported UTIs", value: "\(info.exportedTypeIdentifiers.count)")
                RowView(key: "Imported UTIs", value: "\(info.importedTypeIdentifiers.count)")
            }
            if !info.services.isEmpty {
                RowView(key: "NSServices", value: "\(info.services.count) \(L10n.t(.entryUnit))")
            }
        }
    }

    // MARK: URL Schemes
    private var urlSchemesSection: some View {
        SectionView(L10n.t(.urlSchemes), subtitle: "\(info.urlSchemes.count)") {
            if info.urlSchemes.isEmpty {
                PlaceholderRow(text: L10n.t(.noUrlScheme))
            } else {
                ForEach(info.urlSchemes, id: \.self) { scheme in
                    RowView(key: scheme, value: "\(scheme)://")
                }
            }
        }
    }

    // MARK: 隐私 / TCC 权限描述
    private var privacySection: some View {
        SectionView(
            L10n.t(.privacy),
            subtitle: "\(info.privacyEntries.count)"
        ) {
            if info.privacyEntries.isEmpty {
                PlaceholderRow(text: L10n.t(.noUsageDescription))
            } else {
                ForEach(info.privacyEntries) { e in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: e.systemImage)
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.displayTitle).font(.body.bold())
                                Text(e.key)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        if !e.description.isEmpty {
                            Text(e.description)
                                .font(.system(.callout, design: .default))
                                .foregroundStyle(.primary)
                                .padding(.leading, 32)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.3)))
                }
            }
        }
    }

    // MARK: 网络安全 ATS · Electron
    private var atsSection: some View {
        let ats = info.appTransportSecurity
        let asar = info.electronAsarIntegrity
        return SectionView(
            L10n.t(.ats),
            subtitle: (ats == nil && asar == nil) ? L10n.t(.atsNone) :
                [ats != nil ? "ATS" : nil, asar != nil ? "Asar" : nil]
                    .compactMap { $0 }.joined(separator: ", ")
        ) {
            if let ats = ats {
                Text("NSAppTransportSecurity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(InfoPlistParser.flatten(ats).sorted { $0.0 < $1.0 }, id: \.0) { row in
                    RowView(key: row.0, value: row.1)
                }
            }
            if let asar = asar {
                if ats != nil { Divider().padding(.vertical, 4) }
                Text("ElectronAsarIntegrity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(InfoPlistParser.flatten(asar).sorted { $0.0 < $1.0 }, id: \.0) { row in
                    RowView(key: row.0, value: row.1)
                }
            }
            if ats == nil && asar == nil {
                PlaceholderRow(text: L10n.t(.noATS))
            }
        }
    }

    // MARK: 扩展属性全列表
    private var xattrsSection: some View {
        SectionView(
            L10n.t(.xattrs),
            subtitle: "\(info.extendedXattrs.names.count)"
        ) {
            if info.extendedXattrs.names.isEmpty {
                PlaceholderRow(text: L10n.t(.noneXattrs))
            } else {
                ForEach(info.extendedXattrs.names, id: \.self) { name in
                    RowView(
                        key: name,
                        value: info.extendedXattrs.descriptions[name] ?? L10n.t(.emptyDesc)
                    )
                }
            }
        }
    }

    // MARK: Quarantine
    private var quarantineSection: some View {
        let q = info.quarantine
        return SectionView(
            L10n.t(.quarantine),
            subtitle: q == nil ? "—" : L10n.t(.badgeIsolated)
        ) {
            if let q = q {
                RowView(key: L10n.t(.rawValue), value: q.raw)
                RowView(key: "Flags", value: q.flags)
                RowView(key: L10n.t(.downloadAgent), value: q.agent.isEmpty ? "—" : q.agent)
                if !q.uuid.isEmpty {
                    RowView(key: L10n.t(.downloadUUID), value: q.uuid)
                }
                RowView(key: L10n.t(.timestampHex), value: q.timestampString)
                if let d = q.downloadDate {
                    RowView(key: L10n.t(.downloadTime), value: iso(d))
                }

                Divider().padding(.vertical, 4)

                HStack {
                    Button {
                        copyToPasteboard("xattr -d com.apple.quarantine \"\(info.bundleURL.path)\"")
                    } label: {
                        Label(L10n.t(.copyRemoveCmd), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Text(L10n.t(.pasteToRemoveHint))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 360, alignment: .trailing)
                }
            } else {
                PlaceholderRow(text: L10n.t(.noQuarantineHint))
            }
        }
    }

    // MARK: 代码签名
    private var codeSignSection: some View {
        let cs = info.codeSign
        return SectionView(L10n.t(.codeSigning)) {
            RowView(key: L10n.t(.signState), value: cs.state.localizedName)
            RowView(key: L10n.t(.validity), value: cs.validity.localizedName)
            RowView(key: L10n.t(.notarization), value: cs.notarization.localizedName)

            // 手动验证命令 — 沙盒内无法调用 spctl/codesign, 提供复制命令让用户在终端运行
            HStack(spacing: 10) {
                Button {
                    copyToPasteboard("codesign -dvvv --strict --deep \"\(info.bundleURL.path)\"")
                } label: {
                    Label(L10n.t(.copyCodesignCmd), systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button {
                    copyToPasteboard("spctl --assess -vvv \"\(info.bundleURL.path)\"")
                } label: {
                    Label(L10n.t(.copySpctlCmd), systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Spacer()

                Text(L10n.t(.pasteToVerifyHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 320, alignment: .trailing)
            }
            .padding(.vertical, 2)

            if let v = cs.format { RowView(key: "Format", value: v) }
            if let v = cs.identifier { RowView(key: "Identifier", value: v) }
            RowView(key: "TeamIdentifier", value: cs.teamIdentifier ?? "not set")
            if let v = cs.signatureType { RowView(key: "Signature", value: v) }
            if let v = cs.signatureSize { RowView(key: "Signature size", value: v) }
            if let v = cs.runtimeVersion { RowView(key: "Runtime Version", value: v) }
            if let v = cs.platformIdentifier { RowView(key: "Platform identifier", value: v) }
            if let v = cs.source { RowView(key: "Source", value: v) }

            if let v = cs.flags { RowView(key: L10n.t(.flagsRaw), value: v) }
            if !cs.decodedFlags.isEmpty {
                RowView(key: L10n.t(.flagsDecoded), value: cs.decodedFlags.joined(separator: ", "))
            }

            if let v = cs.cdHash { RowView(key: "CDHash", value: v) }
            if let v = cs.candidateCDHashFull { RowView(key: "CandidateCDHashFull", value: v) }
            if let v = cs.hashType { RowView(key: "Hash type", value: v) }
            if let v = cs.hashChoices { RowView(key: "Hash choices", value: v) }
            if let v = cs.signingTime { RowView(key: "Signing Time", value: v) }
            if let v = cs.totalSignatures { RowView(key: "Total signatures", value: v) }
            if let v = cs.chosenSignature { RowView(key: "Chosen signature", value: v) }
            if let v = cs.infoPlistEntries { RowView(key: "Info.plist entries", value: v) }

            if !cs.authorities.isEmpty {
                Divider().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t(.authorityChain))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(cs.authorities, id: \.self) { a in
                        RowView(key: "• ", value: a)
                    }
                }
            }
        }
    }

    // MARK: Entitlements
    /// 数量超过该阈值时启用固定高度内嵌滚动，避免单一分区把整页拉得太长。
    private static let entitlementsCollapsableThreshold = 12

    private var entitlementsSection: some View {
        let cs = info.codeSign
        return SectionView(L10n.t(.entitlements),
                           subtitle: cs.entitlements == nil ? "—" : "\(cs.entitlements!.count)") {
            // 顶部明确显示沙盒状态
            RowView(key: "App Sandbox",
                    value: info.isSandboxed ? L10n.t(.sandboxEnabled) : L10n.t(.sandboxDisabled))
            if let ent = cs.entitlements, !ent.isEmpty {
                let rows = InfoPlistParser.flatten(ent).sorted { $0.0 < $1.0 }
                let bodyContent = VStack(alignment: .leading, spacing: 8) {
                    ForEach(rows, id: \.0) { row in
                        RowView(key: row.0, value: row.1)
                    }
                }

                if rows.count > Self.entitlementsCollapsableThreshold {
                    ScrollView {
                        bodyContent
                    }
                    .frame(maxHeight: 320)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.2)))
                } else {
                    bodyContent
                }
            } else if let raw = cs.entitlementsRaw {
                DisclosureGroup(L10n.t(.discloseRawXml)) {
                    ScrollView(.horizontal) {
                        Text(raw)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 220)
                }
            } else {
                PlaceholderRow(text: L10n.t(.noEntitlements))
            }
        }
    }

    // MARK: 文件信息
    private var fileSection: some View {
        SectionView(L10n.t(.fileInfo)) {
            RowView(key: L10n.t(.fullPath), value: info.bundleURL.path)
            RowView(key: L10n.t(.totalSize), value: "\(info.formattedFileSize()) (\(info.fileSize) \(L10n.t(.bytesUnit)))")
            RowView(key: L10n.t(.modifiedTime), value: info.modificationDate.map { iso($0) } ?? "—")
            RowView(key: L10n.t(.createdTime), value: info.creationDate.map { iso($0) } ?? "—")
            RowView(key: L10n.t(.permissionsOctal), value: info.permissions ?? "—")
        }
    }

    // MARK: 子 bundle (Frameworks / Helpers / XPC / PlugIns)
    /// 数量超过该阈值时启用固定高度内嵌滚动，避免单一分区把整页拉得太长。
    private static let subBundlesCollapsableThreshold = 4

    private var subBundlesSection: some View {
        SectionView(
            L10n.t(.subBundles),
            subtitle: "\(info.subBundles.count) · \(formattedSize(info.subBundlesTotalSize))"
        ) {
            if info.subBundles.isEmpty {
                PlaceholderRow(text: "—")
            } else {
                let bodyContent = VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(info.subBundles.enumerated()), id: \.element.id) { i, sub in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: subBundleIcon(for: sub.kind))
                                    .foregroundStyle(.tint)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(sub.relativePath)
                                        .font(.system(.body, design: .monospaced).bold())
                                    if let bid = sub.bundleIdentifier {
                                        Text(bid)
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Badge(text: sub.signatureState.localizedName,
                                      color: badgeColor(for: sub.signatureState))
                            }
                            if let ver = sub.bundleVersion {
                                RowView(key: L10n.t(.versionLabel), value: ver)
                            }
                            if let exec = sub.executableName {
                                RowView(key: "CFBundleExecutable", value: exec)
                            }
                            if let sig = sub.signatureType {
                                RowView(key: "Signature", value: sig)
                            }
                            if let runtime = sub.runtimeVersion {
                                RowView(key: "Runtime Version", value: runtime)
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.3)))
                        if i < info.subBundles.count - 1 { Spacer().frame(height: 4) }
                    }
                }

                if info.subBundles.count > Self.subBundlesCollapsableThreshold {
                    ScrollView {
                        bodyContent
                    }
                    .frame(maxHeight: 360)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.2)))
                } else {
                    bodyContent
                }
            }
        }
    }

    // MARK: 原始 Info.plist
    private var rawPlistSection: some View {
        SectionView(L10n.t(.rawPlist),
                    subtitle: "\(info.flatRows.count)") {
            DisclosureGroup(L10n.t(.disclosePlistAll)) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(info.flatRows, id: \.0) { row in
                            RowView(key: row.0, value: row.1)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
    }

    // MARK: 签名详情 (合成)
    private var rawCodesignSection: some View {
        SectionView(L10n.t(.rawCodesign)) {
            DisclosureGroup(L10n.t(.discloseCodesignDetail)) {
                ScrollView {
                    Text(info.codeSign.detailRaw.isEmpty ? L10n.t(.emptyPlaceholder) : info.codeSign.detailRaw)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)
            }
        }
    }

    // MARK: Sparkle 自动更新
    private var sparkleSection: some View {
        if let sp = info.extra.sparkle {
            return AnyView(
                SectionView(L10n.t(.sparkle),
                            subtitle: sp.feedURL ?? "—") {
                    if let v = sp.feedURL { RowView(key: "SUFeedURL", value: v) }
                    if let v = sp.publicEDKey { RowView(key: "SUPublicEDKey", value: v) }
                    if let v = sp.publicDSAKeyFile { RowView(key: "SUPublicDSAKeyFile", value: v) }
                    if let v = sp.bundleName { RowView(key: "SUBundleName", value: v) }
                    if let v = sp.enableAutomaticChecks { RowView(key: "SUEnableAutomaticChecks", value: bool(v)) }
                    if let v = sp.scheduledCheckInterval {
                        RowView(key: "SUScheduledCheckInterval",
                                value: "\(v) \(L10n.t(.secUnit)) (\(Double(v)/86400) \(L10n.t(.dayUnit)))")
                    }
                    if let v = sp.allowsAutomaticUpdates { RowView(key: "SUAllowsAutomaticUpdates", value: bool(v)) }
                    if let v = sp.enableInstallerLauncherService { RowView(key: "SUEnableInstallerLauncherService", value: bool(v)) }
                    if let v = sp.enableDownloaderService { RowView(key: "SUEnableDownloaderService", value: bool(v)) }
                    if let v = sp.showReleaseNotes { RowView(key: "SUShowReleaseNotes", value: bool(v)) }
                    if let v = sp.enableSystemProfiling { RowView(key: "SUEnableSystemProfiling", value: bool(v)) }
                    if let v = sp.sendProfileInfo { RowView(key: "SUSendProfileInfo", value: bool(v)) }
                    if let v = sp.enableJavaScript { RowView(key: "SUEnableJavaScript", value: bool(v)) }
                }
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    // MARK: AppleScript & Siri Intents
    private var appleScriptSiriSection: some View {
        let ex = info.extra
        let siriApple = ex.appleScriptEnabled != nil
            || ex.scriptingDefinition != nil
            || !ex.userActivityTypes.isEmpty
            || !ex.intentsSupported.isEmpty
            || ex.safariExtensionCorrespondingIOSApp != nil
        return SectionView(
            L10n.t(.appleScriptSiri),
            subtitle: siriApple ? nil : "—"
        ) {
            if !siriApple {
                PlaceholderRow(text: L10n.t(.noAppleScript))
            } else {
                if let v = ex.appleScriptEnabled { RowView(key: "NSAppleScriptEnabled", value: bool(v)) }
                if let v = ex.scriptingDefinition { RowView(key: "OSAScriptingDefinition (.sdef)", value: v) }
                if !ex.userActivityTypes.isEmpty {
                    Divider().padding(.vertical, 2)
                    Text("NSUserActivityTypes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(ex.userActivityTypes, id: \.self) { s in
                        RowView(key: "• ", value: s)
                    }
                }
                if !ex.intentsSupported.isEmpty {
                    Divider().padding(.vertical, 2)
                    Text("INIntentsSupported (Siri)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(ex.intentsSupported, id: \.self) { s in
                        RowView(key: "• ", value: s)
                    }
                }
                if let v = ex.safariExtensionCorrespondingIOSApp {
                    Divider().padding(.vertical, 2)
                    RowView(key: "SFSafariCorrespondingIOSAppBundleIdentifier", value: v)
                }
            }
        }
    }

    // MARK: iCloud 容器
    private var iCloudSection: some View {
        let ub = info.extra.ubiquitousContainers
        return SectionView(L10n.t(.icloud),
                           subtitle: ub.isEmpty ? "—" : "\(ub.count)") {
            if ub.isEmpty {
                PlaceholderRow(text: L10n.t(.noICloudContainer))
            } else {
                ForEach(Array(ub.enumerated()), id: \.offset) { i, c in
                    VStack(alignment: .leading, spacing: 4) {
                        // 容器标识作为标题, 突出显示
                        RowView(key: "Container Identifier", value: c.identifier)
                        ForEach(InfoPlistParser.flatten(c.config).sorted(by: { $0.0 < $1.0 }), id: \.0) { row in
                            RowView(key: row.0, value: row.1)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.3)))
                    if i < ub.count - 1 { Spacer().frame(height: 4) }
                }
            }
        }
    }

    // MARK: 通知
    private var notificationsSection: some View {
        let ex = info.extra
        let any = (ex.userNotificationAlertStyle != nil
                   || ex.userNotificationsUsageDescription != nil
                   || ex.localNotificationUsageDescription != nil
                   || ex.remoteNotificationUsageDescription != nil)
        return SectionView(L10n.t(.notifications), subtitle: any ? nil : "—") {
            if !any {
                PlaceholderRow(text: L10n.t(.noNotificationKeys))
            } else {
                if let v = ex.userNotificationAlertStyle {
                    RowView(key: "NSUserNotificationAlertStyle", value: v)
                }
                if let v = ex.userNotificationsUsageDescription {
                    RowView(key: "NSUserNotificationsUsageDescription", value: v)
                }
                if let v = ex.localNotificationUsageDescription {
                    RowView(key: "NSLocalNotificationUsageDescription", value: v)
                }
                if let v = ex.remoteNotificationUsageDescription {
                    RowView(key: "NSRemoteNotificationUsageDescription", value: v)
                }
            }
        }
    }

    // MARK: 杂项开发/生命周期开关
    private var behaviorsSection: some View {
        let ex = info.extra
        let any = (ex.supportsSuddenTermination != nil
                   || ex.supportsAutomaticTermination != nil
                   || ex.lsRequiresCarbon != nil
                   || ex.lsRequiresNativeExecution != nil
                   || ex.lsMultipleInstancesProhibited != nil
                   || ex.lsHasLocalizedDisplayName != nil
                   || ex.lsFileQuarantineEnabled != nil
                   || ex.gpuEjectPolicy != nil
                   || ex.gpuSelectionPolicy != nil
                   || ex.itmsAppUsesNonExemptEncryption != nil)
        return SectionView(L10n.t(.behaviors),
                           subtitle: any ? nil : "—") {
            if !any {
                PlaceholderRow(text: L10n.t(.noSwitches))
            } else {
                if let v = ex.supportsSuddenTermination { RowView(key: "NSSupportsSuddenTermination", value: bool(v)) }
                if let v = ex.supportsAutomaticTermination { RowView(key: "NSSupportsAutomaticTermination", value: bool(v)) }
                if let v = ex.lsRequiresCarbon { RowView(key: "LSRequiresCarbon", value: bool(v)) }
                if let v = ex.lsRequiresNativeExecution { RowView(key: "LSRequiresNativeExecution", value: bool(v)) }
                if let v = ex.lsMultipleInstancesProhibited { RowView(key: "LSMultipleInstancesProhibited", value: bool(v)) }
                if let v = ex.lsHasLocalizedDisplayName { RowView(key: "LSHasLocalizedDisplayName", value: bool(v)) }
                if let v = ex.lsFileQuarantineEnabled { RowView(key: "LSFileQuarantineEnabled", value: bool(v)) }
                if let v = ex.gpuEjectPolicy { RowView(key: "GPUEjectPolicy", value: v) }
                if let v = ex.gpuSelectionPolicy { RowView(key: "GPUSelectionPolicy", value: v) }
                if let v = ex.itmsAppUsesNonExemptEncryption {
                    RowView(key: "ITSAppUsesNonExemptEncryption", value: bool(v))
                }
            }
        }
    }

    // MARK: 帮助 / 本地化 / Accent / Spotlight
    private var localizationSection: some View {
        let ex = info.extra
        let any = (ex.helpBookName != nil || ex.helpBookFolder != nil
                   || !ex.bundleLocalizations.isEmpty
                   || ex.allowMixedLocalizations != nil
                   || ex.accentColorName != nil || ex.mdItemKeywords != nil)
        return SectionView(L10n.t(.localization),
                           subtitle: any ? nil : "—") {
            if !any {
                PlaceholderRow(text: L10n.t(.noLocalizationKeys))
            } else {
                if let v = ex.helpBookName { RowView(key: "CFBundleHelpBookName", value: v) }
                if let v = ex.helpBookFolder { RowView(key: "CFBundleHelpBookFolder", value: v) }
                if !ex.bundleLocalizations.isEmpty {
                    RowView(key: "CFBundleLocalizations",
                            value: ex.bundleLocalizations.joined(separator: ", "))
                }
                if let v = ex.allowMixedLocalizations {
                    RowView(key: "CFBundleAllowMixedLocalizations", value: bool(v))
                }
                if let v = ex.accentColorName { RowView(key: "NSAccentColorName", value: v) }
                if let v = ex.mdItemKeywords { RowView(key: "MDItemKeywords (Spotlight)", value: v) }
            }
        }
    }

    // MARK: iOS 移植包字段
    private var iosPortSection: some View {
        let ex = info.extra
        let any = (!ex.uIDeviceFamily.isEmpty || ex.uiLaunchStoryboardName != nil
                   || ex.uiRequiresFullScreen != nil
                   || !ex.uiSupportedInterfaceOrientations.isEmpty
                   || ex.uiStatusBarStyle != nil
                   || !ex.uiBackgroundModes.isEmpty)
        return SectionView(L10n.t(.iosPortFields),
                           subtitle: any ? (info.isIOSPort ? "iOS" : "partial") : "—") {
            if !any {
                PlaceholderRow(text: L10n.t(.noIOSPortFields))
            } else {
                if !ex.uIDeviceFamily.isEmpty {
                    let labels: [Int: String] = [1: "iPhone", 2: "iPad", 3: "Apple TV", 4: "Apple Watch"]
                    RowView(key: "UIDeviceFamily",
                            value: ex.uIDeviceFamily.map { labels[$0] ?? "\($0)" }.joined(separator: ", "))
                }
                if let v = ex.uiLaunchStoryboardName {
                    RowView(key: "UILaunchStoryboardName", value: v)
                }
                if let v = ex.uiRequiresFullScreen {
                    RowView(key: "UIRequiresFullScreen", value: bool(v))
                }
                if !ex.uiSupportedInterfaceOrientations.isEmpty {
                    RowView(key: "UISupportedInterfaceOrientations",
                            value: ex.uiSupportedInterfaceOrientations.joined(separator: ", "))
                }
                if let v = ex.uiStatusBarStyle {
                    RowView(key: "UIStatusBarStyle", value: v)
                }
                if !ex.uiBackgroundModes.isEmpty {
                    RowView(key: "UIBackgroundModes",
                            value: ex.uiBackgroundModes.joined(separator: ", "))
                }
            }
        }
    }

    // MARK: Electron / 构建元数据 / 厂商
    private var buildMetadataSection: some View {
        let ex = info.extra
        let any = (ex.electronTeamID != nil || ex.sourceVersion != nil
                   || ex.requiredBuildHash != nil || ex.scmRevision != nil
                   || ex.appIdentifierPrefix != nil || ex.teamIdentifierPlist != nil
                   || ex.bundleSpokenName != nil || ex.vendorCode != nil
                   || ex.organizationIdentifier != nil
                   || ex.ctFontSuppressAutoDownload != nil
                   || ex.asWebAuthenticationSessionWebBrowserSupportCapabilities != nil)
        return SectionView(L10n.t(.buildMetadata),
                           subtitle: any ? nil : "—") {
            if !any {
                PlaceholderRow(text: L10n.t(.noBuildMetadata))
            } else {
                if let v = ex.electronTeamID { RowView(key: "ElectronTeamID", value: v) }
                if let v = ex.sourceVersion { RowView(key: "SourceVersion", value: v) }
                if let v = ex.requiredBuildHash { RowView(key: "requiredBuildHash", value: v) }
                if let v = ex.scmRevision { RowView(key: "SCMRevision", value: v) }
                if let v = ex.appIdentifierPrefix { RowView(key: "AppIdentifierPrefix", value: v) }
                if let v = ex.teamIdentifierPlist { RowView(key: "TeamIdentifier (plist)", value: v) }
                if let v = ex.bundleSpokenName { RowView(key: "CFBundleSpokenName", value: v) }
                if let v = ex.vendorCode { RowView(key: "VendorCode", value: v) }
                if let v = ex.organizationIdentifier { RowView(key: "OrganizationIdentifier", value: v) }
                if let v = ex.ctFontSuppressAutoDownload {
                    RowView(key: "CTFontSuppressAutoDownload", value: bool(v))
                }
                if let v = ex.asWebAuthenticationSessionWebBrowserSupportCapabilities {
                    RowView(key: "ASWebAuthenticationSessionWebBrowserSupportCapabilities", value: bool(v))
                }
            }
        }
    }

    // MARK: Bonjour 服务发现
    private var bonjourSection: some View {
        let ex = info.extra
        return SectionView(L10n.t(.bonjour),
                           subtitle: ex.bonjourServices.isEmpty ? "—" : "\(ex.bonjourServices.count)") {
            if ex.bonjourServices.isEmpty {
                PlaceholderRow(text: L10n.t(.noBonjour))
            } else {
                ForEach(ex.bonjourServices, id: \.self) { s in
                    // NSBonjourServices 值已是完整服务类型 (如 _http._tcp), 不再追加后缀
                    RowView(key: s, value: s)
                }
            }
        }
    }

    // MARK: helpers
    private func bool(_ v: Bool?) -> String {
        switch v {
        case .some(true): return "YES"
        case .some(false): return "NO"
        case .none:        return "—"
        }
    }

    private func iso(_ d: Date) -> String {
        ISO8601DateFormatter().string(from: d)
    }

    private func formattedSize(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    /// 顶部版本徽章文本：`1.2.3` / `1.2.3 (456)` / `(456)`，按可用字段组合
    private func versionBadgeText() -> String {
        let v = info.bundleShortVersion
        let b = info.bundleVersion
        switch (v, b) {
        case let (v?, b?):     return "\(v) (\(b))"
        case let (v?, nil):    return v
        case let (nil, b?):    return "(\(b))"
        default:               return "—"
        }
    }

    private func badgeColor(for s: CodeSignInfo.SignedState) -> Color {
        switch s {
        case .signed:  return .green
        case .adhoc:   return .orange
        case .unsigned: return .red
        case .unknown: return .gray
        }
    }

    private func validityColor(_ v: CodeSignInfo.Validity) -> Color {
        switch v {
        case .valid: return .green
        case .invalid: return .red
        case .untested: return .gray
        }
    }

    private func notarizationColor(_ n: CodeSignInfo.Notarization) -> Color {
        switch n {
        case .notarized:    return .green
        case .devID:        return .orange
        case .macAppStore:  return .blue
        case .iosAppStore:  return .pink
        case .appleSystem:  return .teal
        case .notNotarized: return .gray
        case .unknown:      return .gray
        }
    }

    private func subBundleIcon(for kind: SubBundle.Kind) -> String {
        switch kind {
        case .framework: return "shippingbox"
        case .app:       return "app.gift"
        case .xpc:       return "antenna.radiowaves.left.and.right"
        case .kext:      return "externaldrive"
        case .plugin:    return "puzzlepiece.extension"
        case .loginItem: return "power"
        case .other:     return "shippingbox.fill"
        }
    }

    private func summaryString() -> String {
        var lines: [String] = []
        lines.append("# \(info.displayName ?? info.bundleName ?? info.bundleURL.lastPathComponent)")
        lines.append("\(L10n.t(.cliPath)): \(info.bundleURL.path)")
        lines.append("BundleID: \(info.bundleIdentifier ?? "—")")
        lines.append("\(L10n.t(.cliVersion)): \(info.bundleShortVersion ?? "—") (\(info.bundleVersion ?? "—"))")
        lines.append("\(L10n.t(.cliMinOS)): \(info.minimumOSVersion ?? "—")")
        let archs = info.architectures.map { $0.name }.joined(separator: ", ")
        lines.append("\(L10n.t(.cliArchs)): \(archs.isEmpty ? "—" : archs)")
        if !info.supportedPlatforms.isEmpty {
            lines.append("\(L10n.t(.cliPlatforms)): \(info.supportedPlatforms.joined(separator: ", "))")
        }
        if let v = info.principalClass { lines.append("NSPrincipalClass: \(v)") }
        if let v = info.humanReadableCopyright { lines.append("\(L10n.t(.cliCopyright)): \(v)") }
        let cs = info.codeSign
        lines.append("\(L10n.t(.cliSign)): \(cs.state.localizedName) — \(cs.validity.localizedName) — \(cs.notarization.localizedName)")
        if let v = cs.format { lines.append("Format: \(v)") }
        if let id = cs.identifier { lines.append("Identifier: \(id)") }
        if let team = cs.teamIdentifier { lines.append("TeamIdentifier: \(team)") }
        if let cdh = cs.cdHash { lines.append("CDHash: \(cdh)") }
        if !cs.decodedFlags.isEmpty { lines.append("\(L10n.t(.cliSignFlags)): \(cs.decodedFlags.joined(separator: ", "))") }
        if let v = cs.runtimeVersion { lines.append("Runtime Version: \(v)") }
        if let v = cs.signingTime { lines.append("Signing Time: \(v)") }
        if !cs.authorities.isEmpty {
            lines.append("\(L10n.t(.cliAuthority)):")
            cs.authorities.forEach { lines.append("  - \($0)") }
        }
        lines.append("\(L10n.t(.cliPrivacy)): \(info.privacyEntries.count) \(L10n.t(.cliPlistKeys))")
        if !info.privacyEntries.isEmpty {
            for e in info.privacyEntries.prefix(10) {
                lines.append("  · \(e.displayTitle) [\(e.key)]: \(e.description)")
            }
            if info.privacyEntries.count > 10 {
                lines.append("  ... \(L10n.t(.cliMore)) \(info.privacyEntries.count - 10) \(L10n.t(.cliPlistKeys))")
            }
        }
        if info.appTransportSecurity != nil { lines.append("ATS: \(L10n.t(.cliATS))") }
        if info.electronAsarIntegrity != nil { lines.append("Electron: \(L10n.t(.cliElectron))") }
        if info.lsUIElement == true { lines.append(L10n.t(.cliFormAgent)) }
        if info.lsBackgroundOnly == true { lines.append(L10n.t(.cliFormBackground)) }
        if info.isIOSPort { lines.append(L10n.t(.cliFormIOSPort)) }
        let ex = info.extra
        if let sp = info.extra.sparkle {
            lines.append("\(L10n.t(.cliSparkle)):")
            if let v = sp.feedURL { lines.append("  SUFeedURL: \(v)") }
            if let v = sp.scheduledCheckInterval {
                lines.append("  SUScheduledCheckInterval: \(v) \(L10n.t(.cliSeconds)) (\(Double(v)/86400.0) \(L10n.t(.cliDays)))")
            }
            if let v = sp.publicEDKey { lines.append("  SUPublicEDKey: \(v)") }
            if let v = sp.publicDSAKeyFile { lines.append("  SUPublicDSAKeyFile: \(v)") }
            if let v = sp.enableAutomaticChecks { lines.append("  SUEnableAutomaticChecks: \(v)") }
            if let v = sp.allowsAutomaticUpdates { lines.append("  SUAllowsAutomaticUpdates: \(v)") }
        }
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
        if !ex.ubiquitousContainers.isEmpty { lines.append("iCloud Containers: \(ex.ubiquitousContainers.count) \(L10n.t(.cliPlistKeys))") }
        if let v = ex.userNotificationAlertStyle { lines.append("NSUserNotificationAlertStyle: \(v)") }
        if let v = ex.supportsSuddenTermination { lines.append("NSSupportsSuddenTermination: \(v)") }
        if let v = ex.supportsAutomaticTermination { lines.append("NSSupportsAutomaticTermination: \(v)") }
        if let v = ex.itmsAppUsesNonExemptEncryption { lines.append("ITSAppUsesNonExemptEncryption: \(v)") }
        if let v = ex.lsMultipleInstancesProhibited { lines.append("LSMultipleInstancesProhibited: \(v)") }
        if let v = ex.lsFileQuarantineEnabled { lines.append("LSFileQuarantineEnabled: \(v)") }
        if let v = ex.gpuEjectPolicy { lines.append("GPUEjectPolicy: \(v)") }
        if let v = ex.gpuSelectionPolicy { lines.append("GPUSelectionPolicy: \(v)") }
        // F-I 新分区
        if let v = ex.helpBookName { lines.append("CFBundleHelpBookName: \(v)") }
        if let v = ex.helpBookFolder { lines.append("CFBundleHelpBookFolder: \(v)") }
        if !ex.bundleLocalizations.isEmpty {
            lines.append("CFBundleLocalizations: \(ex.bundleLocalizations.joined(separator: ", "))")
        }
        if let v = ex.accentColorName { lines.append("NSAccentColorName: \(v)") }
        if let v = ex.mdItemKeywords { lines.append("MDItemKeywords: \(v)") }
        if !ex.uIDeviceFamily.isEmpty {
            let labels: [Int: String] = [1: "iPhone", 2: "iPad", 3: "Apple TV", 4: "Apple Watch"]
            lines.append("UIDeviceFamily: \(ex.uIDeviceFamily.map { labels[$0] ?? "\($0)" }.joined(separator: ", "))")
        }
        if let v = ex.uiLaunchStoryboardName { lines.append("UILaunchStoryboardName: \(v)") }
        if !ex.uiBackgroundModes.isEmpty {
            lines.append("UIBackgroundModes: \(ex.uiBackgroundModes.joined(separator: ", "))")
        }
        if let v = ex.electronTeamID { lines.append("ElectronTeamID: \(v)") }
        if let v = ex.scmRevision { lines.append("SCMRevision: \(v)") }
        if let v = ex.requiredBuildHash { lines.append("requiredBuildHash: \(v)") }
        if let v = ex.bundleSpokenName { lines.append("CFBundleSpokenName: \(v)") }
        if !ex.bonjourServices.isEmpty {
            lines.append("NSBonjourServices: \(ex.bonjourServices.joined(separator: ", "))")
        }
        if let q = info.quarantine { lines.append("Quarantine: flags=\(q.flags) agent=\(q.agent) uuid=\(q.uuid) \(L10n.t(.cliQuarantine))=\(q.timestampString)") }
        else { lines.append("Quarantine: \(L10n.t(.cliQuarantineNone))") }
        if !info.extendedXattrs.names.isEmpty {
            lines.append("\(L10n.t(.cliXattrs)): \(info.extendedXattrs.names.joined(separator: ", "))")
        }
        lines.append("\(L10n.t(.cliSubBundles)): \(info.subBundles.count) \(L10n.t(.cliPlistKeys)) (\(formattedSize(info.subBundlesTotalSize)))")
        if !info.subBundles.isEmpty {
            for sub in info.subBundles.prefix(10) {
                lines.append("  · [\(sub.kind.rawValue)] \(sub.relativePath) — \(sub.bundleIdentifier ?? "—")")
            }
            if info.subBundles.count > 10 {
                lines.append("  ... \(L10n.t(.cliMore)) \(info.subBundles.count - 10) \(L10n.t(.cliPlistKeys))")
            }
        }
        lines.append("\(L10n.t(.cliFileSize)): \(info.formattedFileSize()) (\(info.fileSize) \(L10n.t(.bytesUnit)))")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Badge
struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.25)))
            .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
            .foregroundStyle(color)
    }
}

// MARK: - DocumentTypeRowView
/// 单个文档类型的卡片列表项：类型名 + 角色 badge，下面更小字号显示子信息。
struct DocumentTypeRowView: View {
    let doc: [String: Any]

    private var name: String   { (doc["CFBundleTypeName"] as? String) ?? "—" }
    private var role: String?  { doc["CFBundleTypeRole"] as? String }
    private var icon: String?  { doc["CFBundleTypeIconFile"] as? String }
    private var rank: String?  { doc["LSHandlerRank"] as? String }
    private var contentTypes: [String] {
        (doc["LSItemContentTypes"] as? [String])
            ?? (doc["LSItemContentTypes"] as? [Any]).map { $0.map { InfoPlistParser.describe($0) } }
            ?? []
    }
    private var extensions: [String] {
        (doc["CFBundleTypeExtensions"] as? [String]) ?? []
    }

    private func roleColor(_ r: String) -> Color {
        switch r.lowercased() {
        case "editor":    return .blue
        case "viewer":    return .gray
        case "shell":     return .purple
        case "qlgenerator","generator": return .indigo
        case "none":      return .secondary
        default:          return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 头部行：文档图标 + 名称 + 角色 badge
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: icon.map { _ in "doc.richtext" } ?? "doc.text")
                    .foregroundStyle(.tint)
                    .font(.body)
                Text(name)
                    .font(.system(.body, design: .default).bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(name)
                if let r = role {
                    Spacer()
                    Text(r)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(roleColor(r).opacity(0.2)))
                        .foregroundStyle(roleColor(r))
                }
            }

            // 子信息行 —— 用更小字号、灰色调表达
            VStack(alignment: .leading, spacing: 3) {
                if !extensions.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(L10n.t(.extName)).font(.caption).foregroundStyle(.tertiary)
                            .frame(width: 70, alignment: .leading)
                        Text(extensions.map { ".\($0)" }.joined(separator: "  "))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                if !contentTypes.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("UTIs").font(.caption).foregroundStyle(.tertiary)
                            .frame(width: 70, alignment: .leading)
                        Text(contentTypes.joined(separator: ", "))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                }
                if let rank = rank {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(L10n.t(.prioKey)).font(.caption).foregroundStyle(.tertiary)
                            .frame(width: 70, alignment: .leading)
                        Text(rank)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                if let icon = icon {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(L10n.t(.iconFile)).font(.caption).foregroundStyle(.tertiary)
                            .frame(width: 70, alignment: .leading)
                        Text(icon)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.leading, 24)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.25)))
    }
}