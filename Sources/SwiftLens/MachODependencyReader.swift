import Foundation

// MARK: - Mach-O 依赖诊断

/// 解析主可执行文件的 LC_LOAD_DYLIB / LC_RPATH，并检查依赖是否可解析。
struct DependencyInfo {
    struct Entry: Identifiable {
        var id: String { path }
        let path: String
        let kind: Kind
        let status: Status
        let resolvedPath: String?
        /// 依赖缺少、但主程序需要的架构（archMismatch 时非空）
        let missingArchs: [String]

        enum Kind: String {
            case normal, weak, reexport, upward
        }

        enum Status: String {
            case system        // /usr/lib、/System/Library 等，由 dyld 共享缓存提供
            case ok
            case missing
            case archMismatch
        }
    }

    let entries: [Entry]
    let rpaths: [String]

    var total: Int { entries.count }
    var systemCount: Int { entries.filter { $0.status == .system }.count }
    var missing: [Entry] {
        entries.filter { $0.status == .missing && $0.kind != .weak }
    }
    var weak: [Entry] { entries.filter { $0.kind == .weak } }
    var archMismatches: [Entry] { entries.filter { $0.status == .archMismatch } }
}

enum MachODependencyReader {

    private static let LC_LOAD_DYLIB: UInt32 = 0x0000000C
    private static let LC_LOAD_WEAK_DYLIB: UInt32 = 0x80000018
    private static let LC_REEXPORT_DYLIB: UInt32 = 0x8000001F
    private static let LC_LOAD_UPWARD_DYLIB: UInt32 = 0x80000023
    private static let LC_RPATH: UInt32 = 0x8000001C

    /// 读取主可执行文件依赖。无主可执行文件时返回 nil。
    static func read(executablePath: String?, bundleURL: URL, mainArchs: [String]) -> DependencyInfo? {
        guard let executablePath,
              let data = try? Data(contentsOf: URL(fileURLWithPath: executablePath), options: .alwaysMapped)
        else { return nil }
        let execDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent()

        var raw: [(path: String, kind: DependencyInfo.Entry.Kind)] = []
        var rpaths: [String] = []
        for offset in sliceOffsets(data) {
            parseLoadCommands(data: data, at: offset, dependencies: &raw, rpaths: &rpaths)
        }
        // 去重：同一路径只保留一次；重复出现时优先非 weak
        var seen = Set<String>()
        var unique: [(path: String, kind: DependencyInfo.Entry.Kind)] = []
        for d in raw {
            if seen.contains(d.path) {
                if d.kind != .weak,
                   let i = unique.firstIndex(where: { $0.path == d.path }) {
                    unique[i] = d
                }
                continue
            }
            seen.insert(d.path)
            unique.append(d)
        }

        let normalizedMain = Set(mainArchs.map(normalizeArch))
        let entries = unique.map { dep -> DependencyInfo.Entry in
            // 系统库位于 dyld 共享缓存，磁盘上通常不存在，不判定为缺失
            if dep.path.hasPrefix("/usr/lib/")
                || dep.path.hasPrefix("/System/Library/")
                || dep.path.hasPrefix("/System/iOSSupport/") {
                return DependencyInfo.Entry(path: dep.path, kind: dep.kind, status: .system,
                                           resolvedPath: nil, missingArchs: [])
            }
            let resolved = resolve(dep.path, execDir: execDir, bundleURL: bundleURL, rpaths: rpaths)
            guard let resolved else {
                return DependencyInfo.Entry(path: dep.path, kind: dep.kind, status: .missing,
                                           resolvedPath: nil, missingArchs: [])
            }
            let depArchs = Set(ArchitectureReader.archNames(at: URL(fileURLWithPath: resolved)))
                .map(normalizeArch)
            let missingArchs = normalizedMain.subtracting(depArchs).sorted()
            let status: DependencyInfo.Entry.Status =
                (!normalizedMain.isEmpty && !depArchs.isEmpty && !missingArchs.isEmpty)
                ? .archMismatch : .ok
            return DependencyInfo.Entry(path: dep.path, kind: dep.kind, status: status,
                                        resolvedPath: resolved, missingArchs: missingArchs)
        }

        return DependencyInfo(entries: entries, rpaths: Array(Set(rpaths)).sorted())
    }

    // MARK: - Mach-O 解析

    /// 返回各架构切片的文件偏移；单架构返回 [0]。
    private static func sliceOffsets(_ data: Data) -> [Int] {
        guard data.count >= 8 else { return [] }
        let magic = data.readBE32(0)
        if magic == FAT_MAGIC || magic == FAT_MAGIC_64 {
            let is64 = magic == FAT_MAGIC_64
            let count = Int(data.readBE32(4))
            let size = is64 ? 32 : 20
            var offsets: [Int] = []
            for i in 0..<count {
                let base = 8 + i * size
                guard base + size <= data.count else { break }
                let off = is64 ? Int(data.readBE64(base + 8)) : Int(data.readBE32(base + 8))
                if off >= 0, off < data.count { offsets.append(off) }
            }
            return offsets
        }
        return [0]
    }

    private static func parseLoadCommands(
        data: Data,
        at offset: Int,
        dependencies: inout [(path: String, kind: DependencyInfo.Entry.Kind)],
        rpaths: inout [String]
    ) {
        guard offset >= 0, offset + 28 <= data.count else { return }
        let magicBE = data.readBE32(offset)
        let bigEndian: Bool
        let is64: Bool
        switch magicBE {
        case UInt32(MH_MAGIC):     bigEndian = true;  is64 = false
        case UInt32(MH_MAGIC_64):  bigEndian = true;  is64 = true
        case UInt32(MH_CIGAM):     bigEndian = false; is64 = false
        case UInt32(MH_CIGAM_64):  bigEndian = false; is64 = true
        default: return
        }
        func read32(_ o: Int) -> UInt32 {
            bigEndian ? data.readBE32(o) : data.readLE32(o)
        }
        let headerSize = is64 ? 32 : 28
        guard offset + headerSize <= data.count else { return }
        let ncmds = Int(read32(offset + 16))
        let sizeofcmds = Int(read32(offset + 20))
        let end = min(offset + headerSize + sizeofcmds, data.count)
        var p = offset + headerSize

        for _ in 0..<ncmds {
            guard p + 8 <= end else { break }
            let cmd = read32(p)
            let cmdsize = Int(read32(p + 4))
            guard cmdsize >= 8, p + cmdsize <= end else { break }
            switch cmd {
            case LC_LOAD_DYLIB, LC_LOAD_WEAK_DYLIB, LC_REEXPORT_DYLIB, LC_LOAD_UPWARD_DYLIB:
                if let path = string(data: data, command: p, cmdsize: cmdsize, bigEndian: bigEndian) {
                    let kind: DependencyInfo.Entry.Kind
                    switch cmd {
                    case LC_LOAD_WEAK_DYLIB:   kind = .weak
                    case LC_REEXPORT_DYLIB:    kind = .reexport
                    case LC_LOAD_UPWARD_DYLIB: kind = .upward
                    default:                   kind = .normal
                    }
                    dependencies.append((path, kind))
                }
            case LC_RPATH:
                if let path = string(data: data, command: p, cmdsize: cmdsize, bigEndian: bigEndian) {
                    rpaths.append(path)
                }
            default:
                break
            }
            p += cmdsize
        }
    }

    /// LC_STR 字符串（dylib_command / rpath_command 的 name/path.offset 都在 +8）。
    private static func string(data: Data, command: Int, cmdsize: Int, bigEndian: Bool) -> String? {
        let rawOffset = bigEndian ? data.readBE32(command + 8) : data.readLE32(command + 8)
        let strOffset = Int(rawOffset)
        guard strOffset >= 8, strOffset < cmdsize else { return nil }
        let start = command + strOffset
        let end = min(command + cmdsize, data.count)
        guard start < end else { return nil }
        var bytes: [UInt8] = []
        var i = start
        while i < end, data[i] != 0 {
            bytes.append(data[i])
            i += 1
        }
        guard !bytes.isEmpty else { return nil }
        return String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - 路径解析

    private static func resolve(
        _ path: String,
        execDir: URL,
        bundleURL: URL,
        rpaths: [String]
    ) -> String? {
        func expand(_ p: String) -> String {
            p.replacingOccurrences(of: "@executable_path", with: execDir.path)
             .replacingOccurrences(of: "@loader_path", with: execDir.path)
        }
        func exists(_ p: String) -> String? {
            FileManager.default.fileExists(atPath: p) ? p : nil
        }
        let frameworks = bundleURL.appendingPathComponent("Contents/Frameworks")

        if path.hasPrefix("@rpath/") {
            let suffix = String(path.dropFirst("@rpath/".count))
            var candidates: [String] = []
            for rpath in rpaths {
                candidates.append(expand(rpath) + "/" + suffix)
            }
            candidates.append(frameworks.path + "/" + suffix)
            candidates.append(frameworks.path + "/" + (suffix as NSString).lastPathComponent)
            // Foo.framework/Versions/A/Foo 以外的常见布局
            if let frameworkName = suffix.split(separator: "/").first {
                let base = frameworks.appendingPathComponent(String(frameworkName))
                candidates.append(base.appendingPathComponent((suffix as NSString).lastPathComponent).path)
                candidates.append(base.appendingPathComponent("Versions/Current/\((suffix as NSString).lastPathComponent)").path)
            }
            for c in candidates {
                if let r = exists(c) { return r }
            }
            return nil
        }

        if path.hasPrefix("@executable_path/") || path.hasPrefix("@loader_path/") {
            return exists(expand(path))
        }
        if path.hasPrefix("/") {
            return exists(path)
        }
        return exists(execDir.appendingPathComponent(path).path)
    }

    private static func normalizeArch(_ name: String) -> String {
        if name.hasPrefix("arm64") { return "arm64" }
        if name.hasPrefix("x86_64") { return "x86_64" }
        return name
    }
}

// MARK: - Data 读取（大端/小端）

private extension Data {
    func readBE32(_ offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset]) << 24 | UInt32(self[offset + 1]) << 16
             | UInt32(self[offset + 2]) << 8 | UInt32(self[offset + 3])
    }
    func readLE32(_ offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset]) | UInt32(self[offset + 1]) << 8
             | UInt32(self[offset + 2]) << 16 | UInt32(self[offset + 3]) << 24
    }
    func readBE64(_ offset: Int) -> UInt64 {
        guard offset + 8 <= count else { return 0 }
        var v: UInt64 = 0
        for i in 0..<8 { v = (v << 8) | UInt64(self[offset + i]) }
        return v
    }
}
