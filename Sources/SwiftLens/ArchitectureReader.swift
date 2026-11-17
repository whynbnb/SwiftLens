import Foundation
import MachO

// MARK: - Mach-O 架构解析

/// 解析 .app bundle 主可执行文件包含的 CPU 架构列表。
/// 支持普通 Mach-O 以及通用 (Fat) 二进制。
enum ArchitectureReader {

    struct ArchInfo {
        let name: String
        let cpuType: String
        let bits: Int            // 32 / 64
        let fileSize: UInt64
        let offsetInFat: UInt64  // 在 fat 二进制中的偏移；非 fat 则为 0
        /// 该切片声明的最低系统版本 (LC_BUILD_VERSION.minos / LC_VERSION_MIN_*)
        let minOSVersion: String?
        /// 该切片编译所用 SDK 版本
        let sdkVersion: String?
    }

    /// 所有切片中的最高最低系统要求。Info.plist 未声明 min OS 时的兜底。
    static func maxMinOSVersion(_ archs: [ArchInfo]) -> String? {
        let versions = archs.compactMap { $0.minOSVersion }
        guard !versions.isEmpty else { return nil }
        return versions.max { versionTuple($0) < versionTuple($1) }
    }

    private static func versionTuple(_ s: String) -> (Int, Int, Int) {
        let parts = s.split(separator: ".").compactMap { Int($0) }
        return (parts.count > 0 ? parts[0] : 0,
                parts.count > 1 ? parts[1] : 0,
                parts.count > 2 ? parts[2] : 0)
    }

    static func read(for bundleURL: URL) -> [ArchInfo] {
        // 1. 标准 macOS 布局: Contents/MacOS/<CFBundleExecutable>
        let execURL = bundleURL.appendingPathComponent("Contents/MacOS")
        if FileManager.default.fileExists(atPath: execURL.path) {
            return readExec(at: bundleURL, execDir: execURL)
        }
        // 2. iOS 应用 Wrapper 布局: Wrapper/<name>.app/<CFBundleExecutable>
        let wrapperDir = bundleURL.appendingPathComponent("Wrapper")
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: wrapperDir.path) {
            for name in entries where name.hasSuffix(".app") {
                let iosAppURL = wrapperDir.appendingPathComponent(name)
                let plist = InfoPlistParser.parse(at: bundleURL)
                let execName = (plist?["CFBundleExecutable"] as? String) ?? name.replacingOccurrences(of: ".app", with: "")
                let execPath = iosAppURL.appendingPathComponent(execName)
                if let data = try? Data(contentsOf: execPath) {
                    return parseMachO(data: data, execPath: execPath)
                }
            }
        }
        return []
    }

    /// 从 Contents/MacOS 目录下找到主可执行文件并解析架构
    private static func readExec(at bundleURL: URL, execDir: URL) -> [ArchInfo] {
        let execName: String?
        // 注意: 部分应用的 CFBundleExecutable 为空字符串 (如 DB Browser for SQLite),
        // 需按缺失处理, 否则会把 Contents/MacOS 目录本身当作可执行文件。
        if let plist = InfoPlistParser.parse(at: bundleURL),
           let name = plist["CFBundleExecutable"] as? String,
           !name.trimmingCharacters(in: .whitespaces).isEmpty {
            execName = name
        } else {
            let entries = (try? FileManager.default.contentsOfDirectory(atPath: execDir.path)) ?? []
            execName = entries.sorted().first { !isDirectory(at: execDir.appendingPathComponent($0)) }
        }
        guard let name = execName else { return [] }
        let execPath = execDir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: execPath) else { return [] }
        return parseMachO(data: data, execPath: execPath)
    }

    /// 解析 Mach-O 数据 (支持 fat / single)
    private static func parseMachO(data: Data, execPath: URL) -> [ArchInfo] {
        guard data.count >= 4 else { return [] }
        let magBE = data.readUInt32BE(at: 0)
        if magBE == FAT_MAGIC || magBE == FAT_MAGIC_64 {
            return parseFat(data: data, is64: magBE == FAT_MAGIC_64, execPath: execPath)
        }
        if let single = parseSingle(data: data, fatOffset: 0, execPath: execPath) {
            return [single]
        }
        return []
    }

    private static func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func fileSize(of execPath: URL) -> UInt64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: execPath.path),
              let size = attrs[.size] as? UInt64 else { return 0 }
        return size
    }

    private static func parseFat(data: Data, is64: Bool, execPath: URL) -> [ArchInfo] {
        let nfat = data.readUInt32BE(at: 4)
        var archs: [ArchInfo] = []
        var off = 8
        let archSize = is64 ? 32 : 20  // fat_arch_64 = 32, fat_arch = 20

        for _ in 0..<Int(nfat) {
            guard off + archSize <= data.count else { break }
            let cpuType = Int32(bitPattern: data.readUInt32BE(at: off))
            let cpuSub  = Int32(bitPattern: data.readUInt32BE(at: off + 4))
            let thingOffset: UInt64
            let thingSize: UInt64
            if is64 {
                thingOffset = data.readUInt64BE(at: off + 8)
                thingSize   = data.readUInt64BE(at: off + 16)
            } else {
                thingOffset = UInt64(data.readUInt32BE(at: off + 8))
                thingSize   = UInt64(data.readUInt32BE(at: off + 12))
            }
            let (name, cpuName, bits) = describeCpu(cpuType, subtype: cpuSub)
            let build = buildInfo(in: data, at: Int(thingOffset))
            archs.append(ArchInfo(
                name: name,
                cpuType: cpuName,
                bits: bits,
                fileSize: thingSize,
                offsetInFat: thingOffset,
                minOSVersion: build.minOS,
                sdkVersion: build.sdk
            ))
            off += archSize
        }
        _ = execPath
        return archs
    }

    private static func parseSingle(data: Data, fatOffset: UInt64, execPath: URL) -> ArchInfo? {
        guard data.count >= Int(fatOffset) + 28 else { return nil }
        let magBE = data.readUInt32BE(at: Int(fatOffset))
        let magLE = data.readUInt32LE(at: Int(fatOffset))
        let bigEndian: Bool
        switch magBE {
        case UInt32(MH_MAGIC), UInt32(MH_MAGIC_64):
            // 大端存储：magic 以 BE 方式解读后等于 MH_MAGIC*
            bigEndian = true
        case UInt32(MH_CIGAM), UInt32(MH_CIGAM_64):
            // BE 解读得到 CIGAM，说明实际是小端
            bigEndian = false
        default:
            // 兜底：字节序由 LE 解读后是否等于 MH_MAGIC* 决定
            if magLE == UInt32(MH_MAGIC) || magLE == UInt32(MH_MAGIC_64) {
                bigEndian = false
            } else if magLE == UInt32(MH_CIGAM) || magLE == UInt32(MH_CIGAM_64) {
                bigEndian = true
            } else {
                return nil
            }
        }
        let raw = bigEndian ? data.readUInt32BE(at: Int(fatOffset) + 4)
                            : data.readUInt32LE(at: Int(fatOffset) + 4)
        let cputype = Int32(bitPattern: raw)
        // mach_header 之后是 cpusubtype (4 字节); 为判别 arm64e 同样需读取
        let subRaw = bigEndian ? data.readUInt32BE(at: Int(fatOffset) + 8)
                               : data.readUInt32LE(at: Int(fatOffset) + 8)
        let cpusubtype = Int32(bitPattern: subRaw)
        let size = fileSize(of: execPath)
        let (name, cpuName, bits) = describeCpu(cputype, subtype: cpusubtype)
        let build = buildInfo(in: data, at: Int(fatOffset))
        return ArchInfo(
            name: name,
            cpuType: cpuName,
            bits: bits,
            fileSize: size,
            offsetInFat: fatOffset,
            minOSVersion: build.minOS,
            sdkVersion: build.sdk
        )
    }

    /// 读取 Mach-O 切片的 LC_BUILD_VERSION / LC_VERSION_MIN_* 载入命令。
    /// 返回该切片声明的最低系统版本与 SDK 版本。
    private static func buildInfo(in data: Data, at offset: Int) -> (minOS: String?, sdk: String?) {
        guard offset >= 0, offset + 28 <= data.count else { return (nil, nil) }
        let magBE = data.readUInt32BE(at: offset)
        let is64: Bool
        let bigEndian: Bool
        switch magBE {
        case UInt32(MH_MAGIC):     is64 = false; bigEndian = true
        case UInt32(MH_MAGIC_64):  is64 = true;  bigEndian = true
        case UInt32(MH_CIGAM):     is64 = false; bigEndian = false
        case UInt32(MH_CIGAM_64):  is64 = true;  bigEndian = false
        default: return (nil, nil)
        }
        func read32(_ o: Int) -> UInt32 {
            bigEndian ? data.readUInt32BE(at: o) : data.readUInt32LE(at: o)
        }
        let headerSize = is64 ? 32 : 28
        guard offset + headerSize <= data.count else { return (nil, nil) }
        let ncmds = Int(read32(offset + 16))
        let sizeofcmds = Int(read32(offset + 20))
        let end = min(offset + headerSize + sizeofcmds, data.count)
        var legacy: (String?, String?) = (nil, nil)
        var p = offset + headerSize

        for _ in 0..<ncmds {
            guard p + 8 <= end else { break }
            let cmd = read32(p)
            let cmdsize = Int(read32(p + 4))
            guard cmdsize >= 8, p + cmdsize <= end else { break }
            switch cmd {
            case 0x32: // LC_BUILD_VERSION
                if cmdsize >= 24 {
                    let minos = read32(p + 12)
                    let sdk = read32(p + 16)
                    return (formatVersion(minos), formatVersion(sdk))
                }
            case 0x24, 0x25: // LC_VERSION_MIN_MACOSX / LC_VERSION_MIN_IPHONEOS
                if cmdsize >= 16, legacy.0 == nil {
                    legacy = (formatVersion(read32(p + 8)), formatVersion(read32(p + 12)))
                }
            default:
                break
            }
            p += cmdsize
        }
        return legacy
    }

    /// 版本号编码为 xxxx.yy.zz 的 32 位值。
    private static func formatVersion(_ v: UInt32) -> String? {
        guard v != 0 else { return nil }
        let major = Int((v >> 16) & 0xFFFF)
        let minor = Int((v >> 8) & 0xFF)
        let patch = Int(v & 0xFF)
        return patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)"
    }

    private static func describeCpu(_ cputype: Int32, subtype: Int32) -> (name: String, cpuType: String, bits: Int) {
        switch cputype {
        case CPU_TYPE_ARM64:
            // CPU_SUBTYPE_ARM64E = 2 (带指针身份验证扩展)。
            // mach_header 中 cpusubtype 高位常被设为库授权位 (0x80000000)，需要屏蔽。
            let sub = UInt32(bitPattern: subtype) & 0x00FFFFFF
            if sub == 2 { return ("arm64e", "ARM 64-bit (arm64e, PAC)", 64) }
            if sub == 12 { return ("arm64e.x1", "ARM 64-bit (arm64e.x1, PAC)", 64) }
            if sub == 0 { return ("arm64", "ARM 64-bit", 64) }
            return ("arm64(sub=\(sub))", "ARM 64-bit", 64)
        case CPU_TYPE_ARM:
            return ("arm", "ARM", 32)
        case CPU_TYPE_X86_64:
            return ("x86_64", "Intel x86_64", 64)
        case CPU_TYPE_X86:
            return ("i386", "Intel x86", 32)
        case CPU_TYPE_POWERPC64:
            return ("ppc64", "PowerPC 64-bit", 64)
        case CPU_TYPE_POWERPC:
            return ("ppc", "PowerPC", 32)
        default:
            return ("unknown(0x\(String(UInt32(bitPattern: cputype), radix: 16)))", "Unknown", 0)
        }
    }
}

// MARK: - Data 拓展
private extension Data {
    func readUInt32BE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset]) << 24 |
               UInt32(self[offset + 1]) << 16 |
               UInt32(self[offset + 2]) << 8 |
               UInt32(self[offset + 3])
    }
    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset]) |
               UInt32(self[offset + 1]) << 8 |
               UInt32(self[offset + 2]) << 16 |
               UInt32(self[offset + 3]) << 24
    }
    func readUInt64BE(at offset: Int) -> UInt64 {
        guard offset + 8 <= count else { return 0 }
        var v: UInt64 = 0
        for i in 0..<8 { v = (v << 8) | UInt64(self[offset + i]) }
        return v
    }
}