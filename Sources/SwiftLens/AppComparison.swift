import Foundation

// MARK: - 版本对比模型

enum DiffKind {
    case unchanged
    case changed
    case added
    case removed
}

/// 一行差异：label 为键名，old/new 为两边的值。
struct DiffItem: Identifiable {
    let id: String
    let label: String
    let oldValue: String?
    let newValue: String?
    let kind: DiffKind

    var hasChange: Bool { kind != .unchanged }
}

struct DiffSection: Identifiable {
    let id: String
    let title: String
    let items: [DiffItem]

    var changedCount: Int { items.filter(\.hasChange).count }
}

/// 两个 bundle 是否属于同一软件的判定等级。
enum SoftwareMatchLevel {
    case confirmed      // Bundle ID 相同，或多项强证据
    case likely         // 证据足够，可以对比
    case uncertain      // 证据不足，默认拒绝
}

struct SoftwareMatchResult {
    let level: SoftwareMatchLevel
    /// 0...100 的相似度（Bundle ID 相同直接 100）
    let similarity: Int
    let evidence: [String]
    let concerns: [String]
}

/// 两个版本的完整对比结果。
struct AppComparison {
    let old: AppInfo
    let new: AppInfo
    let match: SoftwareMatchResult
    let sections: [DiffSection]
    /// 身份证据一般但差异比例过高：提示可能是大版本更新，也可能不是同一软件。
    let caution: Bool

    init(old: AppInfo, new: AppInfo, match: SoftwareMatchResult, sections: [DiffSection]) {
        self.old = old
        self.new = new
        self.match = match
        self.sections = sections
        let total = sections.reduce(0) { $0 + $1.items.count }
        let changed = sections.reduce(0) { $0 + $1.changedCount }
        let ratio = total == 0 ? 0 : Double(changed) / Double(total)
        self.caution = match.level != .confirmed && ratio > 0.7
    }

    var changedCount: Int { sections.reduce(0) { $0 + $1.changedCount } }
    var itemCount: Int { sections.reduce(0) { $0 + $1.items.count } }

    var sizeDelta: Int64 { Int64(new.fileSize) - Int64(old.fileSize) }
    var fileDelta: Int { new.bundleTree.totalFiles - old.bundleTree.totalFiles }
}

enum AppComparator {

    // MARK: 入口
    static func compare(old: AppInfo, new: AppInfo) -> AppComparison {
        let match = evaluateMatch(old: old, new: new)
        var sections: [DiffSection] = []
        sections.append(identitySection(old: old, new: new))
        sections.append(structureSection(old: old, new: new))
        sections.append(sizeSection(old: old, new: new))
        sections.append(architectureSection(old: old, new: new))
        sections.append(dependencySection(old: old, new: new))
        sections.append(subBundleSection(old: old, new: new))
        sections.append(entitlementsSection(old: old, new: new))
        sections.append(plistSection(old: old, new: new))
        sections.append(documentTypeSection(old: old, new: new))
        sections.append(urlSchemeSection(old: old, new: new))
        sections.append(privacySection(old: old, new: new))
        sections.append(launchAgentSection(old: old, new: new))
        return AppComparison(old: old, new: new, match: match, sections: sections)
    }

    // MARK: 同一软件判定

    static func evaluateMatch(old: AppInfo, new: AppInfo) -> SoftwareMatchResult {
        var evidence: [String] = []
        var concerns: [String] = []
        var score = 0

        let oldBID = clean(old.bundleIdentifier)?.lowercased()
        let newBID = clean(new.bundleIdentifier)?.lowercased()
        let bundleIDSame = oldBID != nil && oldBID == newBID

        let oldTeam = clean(old.codeSign.teamIdentifier)
        let newTeam = clean(new.codeSign.teamIdentifier)
        let teamSame = oldTeam != nil && oldTeam == newTeam

        let oldName = normalizedName(old.displayName ?? old.bundleName
            ?? old.bundleURL.deletingPathExtension().lastPathComponent)
        let newName = normalizedName(new.displayName ?? new.bundleName
            ?? new.bundleURL.deletingPathExtension().lastPathComponent)
        let nameSame = !oldName.isEmpty && oldName == newName
        let nameSimilarity = tokenSimilarity(oldName, newName)

        let oldExec = clean(old.executableName)?.lowercased()
        let newExec = clean(new.executableName)?.lowercased()
        let execSame = oldExec != nil && oldExec == newExec

        let oldCert = clean(old.codeSign.authorities.first)?.lowercased()
        let newCert = clean(new.codeSign.authorities.first)?.lowercased()
        let certSame = oldCert != nil && oldCert == newCert

        let structure = structureOverlap(old: old, new: new)

        if bundleIDSame {
            score = 100
            evidence.append(L10n.t(.cmpEvidenceBundleID))
        } else {
            concerns.append(L10n.t(.cmpConcernBundleID))
        }

        if teamSame {
            score += 20
            evidence.append(L10n.t(.cmpEvidenceTeam))
        } else if oldTeam != nil || newTeam != nil {
            concerns.append(L10n.t(.cmpConcernTeam))
        }

        if nameSame {
            score += 25
            evidence.append(L10n.t(.cmpEvidenceName))
        } else if nameSimilarity >= 0.6 {
            score += 12
            evidence.append(L10n.t(.cmpEvidenceNameSimilar))
        } else {
            concerns.append(L10n.t(.cmpConcernName))
        }

        if execSame {
            score += 25
            evidence.append(L10n.t(.cmpEvidenceExec))
        } else {
            concerns.append(L10n.t(.cmpConcernExec))
        }

        if certSame {
            score += 10
            evidence.append(L10n.t(.cmpEvidenceCert))
        }

        if structure.common >= 2 && structure.ratio >= 0.6 {
            score += 15
            evidence.append(L10n.t(.cmpEvidenceStructure))
        } else if structure.common >= 1 && structure.ratio >= 0.3 {
            score += 6
        } else if structure.common == 0 && !structure.emptyOnBothSides {
            concerns.append(L10n.t(.cmpConcernStructure))
        }

        if old.codeSign.state == .unsigned || new.codeSign.state == .unsigned
            || old.codeSign.state == .adhoc || new.codeSign.state == .adhoc {
            concerns.append(L10n.t(.cmpConcernSigning))
        }

        score = min(bundleIDSame ? 100 : 95, score)
        // 可执行文件名相同通常意味着应用被改名 / 换了 Bundle ID，仍允许对比
        let same = bundleIDSame || score >= 35 || (nameSame && execSame) || execSame
        let level: SoftwareMatchLevel
        if bundleIDSame || score >= 50 {
            level = .confirmed
        } else if same {
            level = .likely
        } else {
            level = .uncertain
        }
        return SoftwareMatchResult(level: level, similarity: score,
                                   evidence: evidence, concerns: concerns)
    }

    /// 内嵌结构重合度：子 bundle / 依赖 / 隐私清单 / 启动项路径的 Jaccard 系数。
    private static func structureOverlap(old: AppInfo, new: AppInfo)
        -> (ratio: Double, common: Int, emptyOnBothSides: Bool) {
        let a = notablePaths(old)
        let b = notablePaths(new)
        if a.isEmpty && b.isEmpty { return (0, 0, true) }
        let inter = a.intersection(b)
        let union = a.union(b)
        guard !union.isEmpty else { return (0, 0, true) }
        return (Double(inter.count) / Double(union.count), inter.count, false)
    }

    private static func notablePaths(_ info: AppInfo) -> Set<String> {
        var set = Set<String>()
        for sub in info.subBundles {
            set.insert("sub:" + sub.relativePath.lowercased())
        }
        for dep in info.dependencies?.entries ?? [] where dep.status != .system {
            set.insert("dep:" + (dep.path as NSString).lastPathComponent.lowercased())
        }
        for manifest in info.privacyManifests {
            set.insert("privacy:" + manifest.path.lowercased())
        }
        for agent in info.launchAgents {
            set.insert("agent:" + agent.relativePath.lowercased())
        }
        return set
    }

    private static func normalizedName(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func tokenSimilarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let sa = Set(a.map(String.init))
        let sb = Set(b.map(String.init))
        let inter = sa.intersection(sb).count
        let union = sa.union(sb).count
        return union == 0 ? 0 : Double(inter) / Double(union)
    }

    // MARK: 各分区

    private static func identitySection(old: AppInfo, new: AppInfo) -> DiffSection {
        var items: [DiffItem] = []
        items.append(row("CFBundleDisplayName", clean(old.displayName), clean(new.displayName)))
        items.append(row("CFBundleName", clean(old.bundleName), clean(new.bundleName)))
        items.append(row("CFBundleIdentifier", clean(old.bundleIdentifier), clean(new.bundleIdentifier)))
        items.append(row("CFBundleShortVersionString",
                         clean(old.bundleShortVersion), clean(new.bundleShortVersion)))
        items.append(row("CFBundleVersion", clean(old.bundleVersion), clean(new.bundleVersion)))
        items.append(row("CFBundleExecutable", clean(old.executableName), clean(new.executableName)))
        items.append(row("LSApplicationCategoryType",
                         clean(old.applicationCategoryType), clean(new.applicationCategoryType)))
        items.append(row("LSMinimumSystemVersion",
                         clean(old.minimumOSVersion), clean(new.minimumOSVersion)))
        items.append(row("DTSDKName", clean(old.sdkVersion), clean(new.sdkVersion)))
        items.append(row("TeamIdentifier",
                         clean(old.codeSign.teamIdentifier), clean(new.codeSign.teamIdentifier)))
        items.append(row(L10n.t(.signState),
                         old.codeSign.state.localizedName, new.codeSign.state.localizedName))
        items.append(row(L10n.t(.validity),
                         old.codeSign.validity.localizedName, new.codeSign.validity.localizedName))
        items.append(row(L10n.t(.strictValidation),
                         old.codeSign.strictValidity.strictName, new.codeSign.strictValidity.strictName))
        items.append(row(L10n.t(.notarization),
                         old.codeSign.notarization.localizedName, new.codeSign.notarization.localizedName))
        items.append(row(L10n.t(.cmpSandbox), yesNo(old.isSandboxed), yesNo(new.isSandboxed)))
        items.append(row(L10n.t(.hardenedRuntime),
                         yesNo(old.codeSign.hasHardenedRuntime), yesNo(new.codeSign.hasHardenedRuntime)))
        items.append(row(L10n.t(.libraryValidation),
                         yesNo(old.codeSign.hasLibraryValidation), yesNo(new.codeSign.hasLibraryValidation)))
        items.append(row(L10n.t(.masReceipt), yesNo(old.hasMASReceipt), yesNo(new.hasMASReceipt)))
        return DiffSection(id: "identity", title: L10n.t(.cmpIdentity), items: items)
    }

    private static func structureSection(old: AppInfo, new: AppInfo) -> DiffSection {
        let oldRoles = roles(in: old)
        let newRoles = roles(in: new)
        var items: [DiffItem] = []
        for role in BundleRole.allCases {
            let o = oldRoles.contains(role)
            let n = newRoles.contains(role)
            guard o || n else { continue }
            items.append(item(label: role.title,
                              old: o ? role.pattern : nil,
                              new: n ? role.pattern : nil))
        }
        return DiffSection(id: "structure", title: L10n.t(.cmpStructure), items: items)
    }

    private static func sizeSection(old: AppInfo, new: AppInfo) -> DiffSection {
        var items: [DiffItem] = []
        items.append(row(L10n.t(.totalSize),
                         ByteSize.string(old.fileSize), ByteSize.string(new.fileSize)))
        items.append(row(L10n.t(.cmpFileCount),
                         "\(old.bundleTree.totalFiles)", "\(new.bundleTree.totalFiles)"))

        let oldMap = Dictionary(uniqueKeysWithValues: old.sizeBreakdown.map { ($0.name, $0.size) })
        let newMap = Dictionary(uniqueKeysWithValues: new.sizeBreakdown.map { ($0.name, $0.size) })
        let names = Set(oldMap.keys).union(newMap.keys).sorted { lhs, rhs in
            max(oldMap[lhs] ?? 0, newMap[lhs] ?? 0) > max(oldMap[rhs] ?? 0, newMap[rhs] ?? 0)
        }
        for name in names {
            let o = oldMap[name]
            let n = newMap[name]
            items.append(item(label: name,
                              old: o.map(ByteSize.string),
                              new: n.map(ByteSize.string)))
        }
        return DiffSection(id: "size", title: L10n.t(.cmpSize), items: items)
    }

    private static func architectureSection(old: AppInfo, new: AppInfo) -> DiffSection {
        let oldMap = Dictionary(uniqueKeysWithValues: old.architectures.map { ($0.name, $0) })
        let newMap = Dictionary(uniqueKeysWithValues: new.architectures.map { ($0.name, $0) })
        let names = Array(Set(oldMap.keys).union(newMap.keys)).sorted()
        var items: [DiffItem] = []
        for name in names {
            let o = oldMap[name].map { "\($0.minOSVersion ?? "—") · \($0.sdkVersion ?? "—")" }
            let n = newMap[name].map { "\($0.minOSVersion ?? "—") · \($0.sdkVersion ?? "—")" }
            items.append(item(label: name, old: o, new: n))
        }
        return DiffSection(id: "arch", title: L10n.t(.architectures), items: items)
    }

    private static func dependencySection(old: AppInfo, new: AppInfo) -> DiffSection {
        let oldMap = Dictionary(uniqueKeysWithValues:
            (old.dependencies?.entries ?? []).map { ($0.path, $0) })
        let newMap = Dictionary(uniqueKeysWithValues:
            (new.dependencies?.entries ?? []).map { ($0.path, $0) })
        let paths = Array(Set(oldMap.keys).union(newMap.keys)).sorted()
        var items: [DiffItem] = []
        for path in paths {
            items.append(item(label: path,
                              old: oldMap[path].map(depValue),
                              new: newMap[path].map(depValue)))
        }
        for rpath in Set(old.dependencies?.rpaths ?? []).union(new.dependencies?.rpaths ?? []).sorted() {
            items.append(item(label: "RPATH \(rpath)",
                              old: (old.dependencies?.rpaths.contains(rpath) ?? false) ? "✓" : nil,
                              new: (new.dependencies?.rpaths.contains(rpath) ?? false) ? "✓" : nil))
        }
        return DiffSection(id: "deps", title: L10n.t(.dependencies), items: items)
    }

    private static func subBundleSection(old: AppInfo, new: AppInfo) -> DiffSection {
        let oldMap = Dictionary(uniqueKeysWithValues: old.subBundles.map { ($0.relativePath, $0) })
        let newMap = Dictionary(uniqueKeysWithValues: new.subBundles.map { ($0.relativePath, $0) })
        let paths = Array(Set(oldMap.keys).union(newMap.keys)).sorted()
        var items: [DiffItem] = []
        for path in paths {
            items.append(item(label: path,
                              old: oldMap[path].map(subValue),
                              new: newMap[path].map(subValue)))
        }
        return DiffSection(id: "subBundles", title: L10n.t(.subBundles), items: items)
    }

    private static func entitlementsSection(old: AppInfo, new: AppInfo) -> DiffSection {
        let oldFlat = old.codeSign.entitlements.map { InfoPlistParser.flatten($0) } ?? []
        let newFlat = new.codeSign.entitlements.map { InfoPlistParser.flatten($0) } ?? []
        return flatSection(id: "entitlements", title: L10n.t(.entitlements),
                           old: oldFlat, new: newFlat)
    }

    private static func plistSection(old: AppInfo, new: AppInfo) -> DiffSection {
        flatSection(id: "plist", title: L10n.t(.cmpPlist),
                    old: old.flatRows, new: new.flatRows)
    }

    private static func documentTypeSection(old: AppInfo, new: AppInfo) -> DiffSection {
        let oldMap = docTypeMap(old.documentTypes)
        let newMap = docTypeMap(new.documentTypes)
        var items: [DiffItem] = []
        for key in Set(oldMap.keys).union(newMap.keys).sorted() {
            items.append(item(label: key, old: oldMap[key], new: newMap[key]))
        }
        return DiffSection(id: "docTypes", title: L10n.t(.documentTypes), items: items)
    }

    private static func urlSchemeSection(old: AppInfo, new: AppInfo) -> DiffSection {
        let oldSet = Set(old.urlSchemes)
        let newSet = Set(new.urlSchemes)
        var items: [DiffItem] = []
        for scheme in oldSet.union(newSet).sorted() {
            items.append(item(label: scheme,
                              old: oldSet.contains(scheme) ? "✓" : nil,
                              new: newSet.contains(scheme) ? "✓" : nil))
        }
        return DiffSection(id: "urlSchemes", title: L10n.t(.urlSchemes), items: items)
    }

    private static func privacySection(old: AppInfo, new: AppInfo) -> DiffSection {
        let oldMap = Dictionary(uniqueKeysWithValues: old.privacyManifests.map { ($0.path, $0) })
        let newMap = Dictionary(uniqueKeysWithValues: new.privacyManifests.map { ($0.path, $0) })
        var items: [DiffItem] = []
        for path in Set(oldMap.keys).union(newMap.keys).sorted() {
            items.append(item(label: path,
                              old: oldMap[path].map(manifestValue),
                              new: newMap[path].map(manifestValue)))
        }
        let oldDescriptions = PrivacyReader.parse(from: old.rawInfoPlist)
        let newDescriptions = PrivacyReader.parse(from: new.rawInfoPlist)
        let oldKeys = Dictionary(uniqueKeysWithValues: oldDescriptions.map { ($0.key, $0.description) })
        let newKeys = Dictionary(uniqueKeysWithValues: newDescriptions.map { ($0.key, $0.description) })
        for key in Set(oldKeys.keys).union(newKeys.keys).sorted() {
            items.append(item(label: key, old: oldKeys[key], new: newKeys[key]))
        }
        return DiffSection(id: "privacy", title: L10n.t(.privacyManifests), items: items)
    }

    private static func launchAgentSection(old: AppInfo, new: AppInfo) -> DiffSection {
        let oldMap = Dictionary(uniqueKeysWithValues: old.launchAgents.map { ($0.relativePath, $0.label) })
        let newMap = Dictionary(uniqueKeysWithValues: new.launchAgents.map { ($0.relativePath, $0.label) })
        var items: [DiffItem] = []
        for path in Set(oldMap.keys).union(newMap.keys).sorted() {
            items.append(item(label: path, old: oldMap[path], new: newMap[path]))
        }
        return DiffSection(id: "launchAgents", title: L10n.t(.launchAgents), items: items)
    }

    // MARK: 辅助

    private static func flatSection(id: String, title: String,
                                    old: [(String, String)],
                                    new: [(String, String)]) -> DiffSection {
        let oldMap = Dictionary(uniqueKeysWithValues: old)
        let newMap = Dictionary(uniqueKeysWithValues: new)
        var items: [DiffItem] = []
        for key in Set(oldMap.keys).union(newMap.keys).sorted() {
            items.append(item(label: key, old: oldMap[key], new: newMap[key]))
        }
        return DiffSection(id: id, title: title, items: items)
    }

    private static func roles(in info: AppInfo) -> Set<BundleRole> {
        var set: Set<BundleRole> = []
        func walk(_ node: BundleNode) {
            if let role = node.role { set.insert(role) }
            for child in node.children { walk(child) }
        }
        walk(info.bundleTree.root)
        return set
    }

    private static func docTypeMap(_ types: [[String: Any]]) -> [String: String] {
        var map: [String: String] = [:]
        var seen: [String: Int] = [:]
        for type in types {
            let baseName = (type["CFBundleTypeName"] as? String)
                ?? (type["CFBundleTypeRole"] as? String)
                ?? "CFBundleDocumentTypes"
            let count = (seen[baseName] ?? 0) + 1
            seen[baseName] = count
            let key = count == 1 ? baseName : "\(baseName) #\(count)"
            var parts: [String] = []
            if let exts = type["CFBundleTypeExtensions"] as? [String], !exts.isEmpty {
                parts.append(exts.joined(separator: ", "))
            }
            if let utis = type["LSItemContentTypes"] as? [String], !utis.isEmpty {
                parts.append(utis.joined(separator: ", "))
            }
            if let role = type["CFBundleTypeRole"] as? String {
                parts.append(role)
            }
            map[key] = parts.joined(separator: " · ")
        }
        return map
    }

    private static func depValue(_ entry: DependencyInfo.Entry) -> String {
        var value: String
        switch entry.status {
        case .system:       value = L10n.t(.depSystem)
        case .ok:           value = L10n.t(.depOk)
        case .missing:      value = L10n.t(.depMissing)
        case .archMismatch: value = L10n.t(.depArchMismatch)
        }
        if entry.kind == .weak { value += " · \(L10n.t(.depWeak))" }
        return value
    }

    private static func subValue(_ sub: SubBundle) -> String {
        var parts: [String] = []
        parts.append(sub.bundleVersion ?? "—")
        parts.append(sub.signatureState.localizedName)
        if !sub.architectures.isEmpty {
            parts.append(sub.architectures.joined(separator: ", "))
        }
        if let team = sub.teamIdentifier, !team.isEmpty {
            parts.append("Team \(team)")
        }
        return parts.joined(separator: " · ")
    }

    private static func manifestValue(_ manifest: PrivacyManifest) -> String {
        var parts: [String] = []
        if !manifest.accessedAPIs.isEmpty {
            parts.append("\(L10n.t(.privacyAccessedAPIs)): "
                + manifest.accessedAPIs.map(\.type).joined(separator: ", "))
        }
        if let tracking = manifest.tracking {
            parts.append("\(L10n.t(.privacyTracking)): \(yesNo(tracking))")
        }
        if !manifest.trackingDomains.isEmpty {
            parts.append("\(L10n.t(.privacyTrackingDomains)): "
                + manifest.trackingDomains.joined(separator: ", "))
        }
        if !manifest.collectedData.isEmpty {
            parts.append("\(L10n.t(.privacyCollectedData)): "
                + manifest.collectedData.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    private static func row(_ label: String, _ old: String?, _ new: String?) -> DiffItem {
        item(label: label, old: old, new: new)
    }

    private static func item(label: String, old: String?, new: String?) -> DiffItem {
        let o = clean(old)
        let n = clean(new)
        let kind: DiffKind
        switch (o, n) {
        case (nil, nil):   kind = .unchanged
        case (nil, _):     kind = .added
        case (_, nil):     kind = .removed
        case let (o?, n?): kind = o == n ? .unchanged : .changed
        }
        return DiffItem(id: label, label: label, oldValue: o, newValue: n, kind: kind)
    }

    private static func clean(_ s: String?) -> String? {
        guard let s else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func yesNo(_ value: Bool) -> String { value ? "YES" : "NO" }
}
