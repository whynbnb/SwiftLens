import Foundation

// MARK: - 经典结构角色

/// .app bundle 中具有固定含义的路径 / 文件。
/// 标题与说明走 L10n，树中的标注和「经典结构说明」分区共用。
enum BundleRole: String, CaseIterable, Identifiable {
    case bundleRoot
    case contents
    case macos
    case executable
    case resources
    case frameworks
    case sharedFrameworks
    case plugins
    case xpcServices
    case helpers
    case library
    case codeSignature
    case codeResources
    case infoPlist
    case pkgInfo
    case embeddedProfile
    case privacyManifest
    case localization
    case assetCatalog
    case icon
    case receipt
    case wrapper

    var id: String { rawValue }

    /// 短标题，用于树中的小徽章。
    var title: String {
        switch self {
        case .bundleRoot:      return L10n.t(.roleBundleRoot)
        case .contents:        return L10n.t(.roleContents)
        case .macos:           return L10n.t(.roleMacOS)
        case .executable:      return L10n.t(.roleExecutable)
        case .resources:       return L10n.t(.roleResources)
        case .frameworks:      return L10n.t(.roleFrameworks)
        case .sharedFrameworks: return L10n.t(.roleSharedFrameworks)
        case .plugins:         return L10n.t(.rolePlugIns)
        case .xpcServices:     return L10n.t(.roleXPCServices)
        case .helpers:         return L10n.t(.roleHelpers)
        case .library:         return L10n.t(.roleLibrary)
        case .codeSignature:   return L10n.t(.roleCodeSignature)
        case .codeResources:   return L10n.t(.roleCodeResources)
        case .infoPlist:       return L10n.t(.roleInfoPlist)
        case .pkgInfo:         return L10n.t(.rolePkgInfo)
        case .embeddedProfile: return L10n.t(.roleEmbeddedProfile)
        case .privacyManifest: return L10n.t(.rolePrivacyManifest)
        case .localization:    return L10n.t(.roleLocalization)
        case .assetCatalog:    return L10n.t(.roleAssetCatalog)
        case .icon:            return L10n.t(.roleIcon)
        case .receipt:         return L10n.t(.roleReceipt)
        case .wrapper:         return L10n.t(.roleWrapper)
        }
    }

    /// 一句话解释。
    var detail: String {
        switch self {
        case .bundleRoot:      return L10n.t(.roleBundleRootDesc)
        case .contents:        return L10n.t(.roleContentsDesc)
        case .macos:           return L10n.t(.roleMacOSDesc)
        case .executable:      return L10n.t(.roleExecutableDesc)
        case .resources:       return L10n.t(.roleResourcesDesc)
        case .frameworks:      return L10n.t(.roleFrameworksDesc)
        case .sharedFrameworks: return L10n.t(.roleSharedFrameworksDesc)
        case .plugins:         return L10n.t(.rolePlugInsDesc)
        case .xpcServices:     return L10n.t(.roleXPCServicesDesc)
        case .helpers:         return L10n.t(.roleHelpersDesc)
        case .library:         return L10n.t(.roleLibraryDesc)
        case .codeSignature:   return L10n.t(.roleCodeSignatureDesc)
        case .codeResources:   return L10n.t(.roleCodeResourcesDesc)
        case .infoPlist:       return L10n.t(.roleInfoPlistDesc)
        case .pkgInfo:         return L10n.t(.rolePkgInfoDesc)
        case .embeddedProfile: return L10n.t(.roleEmbeddedProfileDesc)
        case .privacyManifest: return L10n.t(.rolePrivacyManifestDesc)
        case .localization:    return L10n.t(.roleLocalizationDesc)
        case .assetCatalog:    return L10n.t(.roleAssetCatalogDesc)
        case .icon:            return L10n.t(.roleIconDesc)
        case .receipt:         return L10n.t(.roleReceiptDesc)
        case .wrapper:         return L10n.t(.roleWrapperDesc)
        }
    }

    /// 展示用的经典路径（尖括号表示随应用变化的部分）。
    var pattern: String {
        switch self {
        case .bundleRoot:      return "<App>.app/"
        case .contents:        return "Contents/"
        case .macos:           return "Contents/MacOS/"
        case .executable:      return "Contents/MacOS/<CFBundleExecutable>"
        case .resources:       return "Contents/Resources/"
        case .frameworks:      return "Contents/Frameworks/"
        case .sharedFrameworks: return "Contents/SharedFrameworks/"
        case .plugins:         return "Contents/PlugIns/"
        case .xpcServices:     return "Contents/XPCServices/"
        case .helpers:         return "Contents/Helpers/"
        case .library:         return "Contents/Library/"
        case .codeSignature:   return "Contents/_CodeSignature/"
        case .codeResources:   return "Contents/_CodeSignature/CodeResources"
        case .infoPlist:       return "Contents/Info.plist"
        case .pkgInfo:         return "Contents/PkgInfo"
        case .embeddedProfile: return "Contents/embedded.provisionprofile"
        case .privacyManifest: return "PrivacyInfo.xcprivacy"
        case .localization:    return "Contents/Resources/<lang>.lproj/"
        case .assetCatalog:    return "Contents/Resources/Assets.car"
        case .icon:            return "Contents/Resources/<name>.icns"
        case .receipt:         return "Contents/_MASReceipt/receipt"
        case .wrapper:         return "Wrapper/<name>.app/"
        }
    }

    /// 树中使用的 SF Symbol。
    var symbol: String {
        switch self {
        case .bundleRoot:      return "shippingbox"
        case .contents:        return "folder.badge.gearshape"
        case .macos:           return "terminal"
        case .executable:      return "gearshape.2"
        case .resources:       return "photo.on.rectangle"
        case .frameworks:      return "cube"
        case .sharedFrameworks: return "cube.transparent"
        case .plugins:         return "puzzlepiece.extension"
        case .xpcServices:     return "bolt.horizontal.circle"
        case .helpers:         return "wrench.and.screwdriver"
        case .library:         return "books.vertical"
        case .codeSignature:   return "checkmark.seal"
        case .codeResources:   return "checkmark.seal.fill"
        case .infoPlist:       return "doc.text"
        case .pkgInfo:         return "doc.plaintext"
        case .embeddedProfile: return "person.text.rectangle"
        case .privacyManifest: return "hand.raised"
        case .localization:    return "globe"
        case .assetCatalog:    return "square.stack.3d.up"
        case .icon:            return "app.dashed"
        case .receipt:         return "cart"
        case .wrapper:         return "iphone"
        }
    }
}

// MARK: - 树模型

/// 文件树节点。目录的 size / fileCount 为递归汇总。
struct BundleNode: Identifiable {
    let path: String        // 相对 bundle 根的路径，根为 ""
    let name: String
    let isDirectory: Bool
    let size: UInt64
    let fileCount: Int
    let role: BundleRole?
    /// >0 表示「其余 N 项未展开」的合成节点。
    let omittedCount: Int
    let children: [BundleNode]

    var id: String { path.isEmpty ? "." : path }
    var isOmitted: Bool { omittedCount > 0 }
}

struct BundleTree {
    let root: BundleNode
    let totalFiles: Int
    /// 节点数超过上限时为 true（体积统计仍是完整的）。
    let isTruncated: Bool
}

/// 一次遍历同时得到：完整体积 / 顶级目录构成 / 限量的可视化文件树。
enum BundleTreeReader {

    /// 可视化树的最大节点数（不含合成节点）。
    private static let maxNodes = 4000
    /// 单个目录最多列出的子项数，其余折叠为「其余 N 项」。
    private static let maxChildrenPerDirectory = 200

    struct Result {
        let tree: BundleTree
        let totalSize: UInt64
        let breakdown: [SizeBreakdownItem]
    }

    static func read(bundleURL: URL, executableName: String?) -> Result {
        let fm = FileManager.default
        let rootPath = bundleURL.path

        var totalSize: UInt64 = 0
        var totalFiles = 0
        var breakdown: [String: UInt64] = [:]
        // 目录 -> 递归体积 / 文件数（含被折叠的子项，因此数值完整）
        var dirSize: [String: UInt64] = [:]
        var dirFiles: [String: Int] = [:]

        if let enumerator = fm.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: []
        ) {
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                let isDirectory = values?.isDirectory ?? false
                let path = fileURL.path
                guard path.hasPrefix(rootPath + "/") else { continue }
                let rel = String(path.dropFirst(rootPath.count + 1))

                if isDirectory {
                    if dirSize[rel] == nil { dirSize[rel] = 0 }
                    if dirFiles[rel] == nil { dirFiles[rel] = 0 }
                    continue
                }

                let size = UInt64(max(0, values?.fileSize ?? 0))
                totalSize += size
                totalFiles += 1

                // 顶级目录构成（与旧逻辑一致）
                let parts = rel.split(separator: "/")
                if parts.first == "Contents", parts.count > 1 {
                    breakdown[String(parts[1]), default: 0] += size
                } else {
                    breakdown[parts.first.map(String.init) ?? "—", default: 0] += size
                }

                // 把所有祖先目录累加起来
                dirSize["", default: 0] += size
                dirFiles["", default: 0] += 1
                var prefix = ""
                for component in parts.dropLast() {
                    prefix = prefix.isEmpty ? String(component) : prefix + "/" + component
                    dirSize[prefix, default: 0] += size
                    dirFiles[prefix, default: 0] += 1
                }
            }
        }

        var budget = maxNodes
        var truncated = false

        func makeNode(rel: String, name: String, isDirectory: Bool,
                      fileSize: UInt64, allowDescend: Bool = true) -> BundleNode {
            budget -= 1
            let role = roleFor(rel: rel, name: name, isDirectory: isDirectory,
                               executableName: executableName)
            guard isDirectory else {
                return BundleNode(path: rel, name: name, isDirectory: false,
                                  size: fileSize, fileCount: 1,
                                  role: role, omittedCount: 0, children: [])
            }
            guard allowDescend else {
                return BundleNode(path: rel, name: name, isDirectory: true,
                                  size: dirSize[rel] ?? 0,
                                  fileCount: dirFiles[rel] ?? 0,
                                  role: role, omittedCount: 0, children: [])
            }

            let dirURL = rel.isEmpty ? bundleURL : bundleURL.appendingPathComponent(rel)
            let entries = (try? fm.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey],
                options: []
            )) ?? []

            struct Child {
                let name: String
                let rel: String
                let isDirectory: Bool
                let size: UInt64
                let roleOrder: Int
            }
            var children: [Child] = entries.map { url in
                let name = url.lastPathComponent
                let childRel = rel.isEmpty ? name : rel + "/" + name
                let values = try? url.resourceValues(
                    forKeys: [.fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey])
                // 符号链接按文件处理，避免递归进入链接目录
                let isLink = values?.isSymbolicLink ?? false
                let isDir = (values?.isDirectory ?? false) && !isLink
                let size = isDir
                    ? (dirSize[childRel] ?? 0)
                    : UInt64(max(0, values?.fileSize ?? 0))
                let role = roleFor(rel: childRel, name: name, isDirectory: isDir,
                                   executableName: executableName)
                let order = role.flatMap { BundleRole.allCases.firstIndex(of: $0) }
                    ?? Int.max
                return Child(name: name, rel: childRel, isDirectory: isDir,
                             size: size, roleOrder: order)
            }
            // 经典结构优先，其次体积大的在前，便于快速看出组成
            children.sort {
                if $0.roleOrder != $1.roleOrder { return $0.roleOrder < $1.roleOrder }
                if $0.size != $1.size { return $0.size > $1.size }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }

            let visible = children.prefix(maxChildrenPerDirectory)
            let folded = children.dropFirst(maxChildrenPerDirectory)

            var nodes: [BundleNode] = []
            var omittedSize: UInt64 = 0
            var omittedCount = 0

            for (index, child) in visible.enumerated() {
                // 为剩余兄弟预留节点预算，避免某个巨大子树（如 Xcode 的 Developer）
                // 把标准目录（MacOS / Resources / Frameworks…）全部挤掉
                let remainingSiblings = visible.count - index - 1
                let allowDescend = budget - 1 > remainingSiblings
                if !allowDescend && child.isDirectory && (dirFiles[child.rel] ?? 0) > 0 {
                    truncated = true
                }
                nodes.append(makeNode(rel: child.rel, name: child.name,
                                      isDirectory: child.isDirectory,
                                      fileSize: child.size,
                                      allowDescend: allowDescend))
            }
            for child in folded {
                omittedSize += child.size
                omittedCount += child.isDirectory ? max(1, dirFiles[child.rel] ?? 1) : 1
            }

            if omittedCount > 0 {
                nodes.append(BundleNode(
                    path: rel.isEmpty ? "__omitted__" : rel + "/__omitted__",
                    name: L10n.t(.treeOmitted),
                    isDirectory: false,
                    size: omittedSize,
                    fileCount: omittedCount,
                    role: nil,
                    omittedCount: omittedCount,
                    children: []
                ))
            }

            return BundleNode(path: rel, name: name, isDirectory: true,
                              size: dirSize[rel] ?? 0, fileCount: dirFiles[rel] ?? 0,
                              role: role, omittedCount: 0, children: nodes)
        }

        let root = makeNode(rel: "", name: bundleURL.lastPathComponent,
                            isDirectory: true, fileSize: 0)
        let shownFiles = root.fileCount
        let tree = BundleTree(root: root,
                              totalFiles: totalFiles > 0 ? totalFiles : shownFiles,
                              isTruncated: truncated)

        let breakdownItems = breakdown
            .map { SizeBreakdownItem(name: $0.key, size: $0.value) }
            .sorted { $0.size > $1.size }

        return Result(tree: tree, totalSize: totalSize, breakdown: breakdownItems)
    }

    // MARK: 角色判定

    private static func roleFor(rel: String, name: String,
                                isDirectory: Bool,
                                executableName: String?) -> BundleRole? {
        if rel.isEmpty { return .bundleRoot }

        switch rel {
        case "Contents":                    return .contents
        case "Contents/MacOS":              return .macos
        case "Contents/Resources":          return .resources
        case "Contents/Frameworks":         return .frameworks
        case "Contents/SharedFrameworks":   return .sharedFrameworks
        case "Contents/PlugIns":            return .plugins
        case "Contents/XPCServices":        return .xpcServices
        case "Contents/Helpers":            return .helpers
        case "Contents/Library":            return .library
        case "Contents/_CodeSignature":     return .codeSignature
        case "Contents/_CodeSignature/CodeResources": return .codeResources
        case "Contents/Info.plist":         return .infoPlist
        case "Contents/PkgInfo":            return .pkgInfo
        case "Contents/embedded.provisionprofile": return .embeddedProfile
        case "Wrapper":                     return .wrapper
        case "CodeResources":               return .codeResources
        case "Info.plist":                  return .infoPlist
        case "PkgInfo":                     return .pkgInfo
        case "embedded.provisionprofile":   return .embeddedProfile
        default: break
        }

        // 通用规则：iOS Wrapper 布局与内嵌 framework 里的同名结构也能标注
        if let exec = executableName, !exec.isEmpty, name == exec,
           rel.hasPrefix("Contents/MacOS/") || rel.contains("/MacOS/") {
            return .executable
        }
        if name == "PrivacyInfo.xcprivacy" { return .privacyManifest }
        if isDirectory, name.hasSuffix(".lproj") { return .localization }
        if isDirectory, name.hasSuffix(".framework") { return .frameworks }
        if name == "Assets.car" { return .assetCatalog }
        if !isDirectory, name.hasSuffix(".icns") { return .icon }
        if rel.hasSuffix("_MASReceipt/receipt") { return .receipt }
        if rel.hasSuffix("/CodeResources") { return .codeResources }
        if name == "Info.plist" { return .infoPlist }
        if name == "PkgInfo" { return .pkgInfo }
        if isDirectory, rel.hasSuffix("/_CodeSignature") { return .codeSignature }
        return nil
    }
}
