import SwiftUI

// MARK: - 帮助面板

/// 帮助面板：说明顶部各徽章 / 签名状态 / 沙盒状态的含义，
/// 帮助用户准确理解 SwiftLens 展示的各项信息。
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(L10n.t(.help))
                    .font(.system(.title2, design: .default).bold())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // 隐藏滚动条, 避免出现/消失时挤压内容
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    notarizationSection
                    sandboxSection
                    quarantineSection
                    signatureStateSection
                    badgesSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .frame(width: 640, height: 560)
        .background(.regularMaterial)
    }

    // MARK: - 签名 / 公证状态
    private var notarizationSection: some View {
        helpSection(title: "签名状态 / 公证状态", icon: "checkmark.shield.fill") {
            badgeRow(color: .green,  title: "已公证 (Notarized)",
                     desc: "Developer ID 签名且通过 Gatekeeper 严格验证。Apple 已公证该应用，可安全运行。")
            badgeRow(color: .orange, title: "Developer ID 签名",
                     desc: "Developer ID 证书签名，但未通过严格验证（签名可能已损坏、资源缺失或被修改）。Gatekeeper 会拒绝运行。")
            badgeRow(color: .blue,   title: "Mac App Store",
                     desc: "通过 Mac App Store 分发的应用，使用 Apple Mac OS Application Signing 证书签名。")
            badgeRow(color: .pink,   title: "iOS App Store",
                     desc: "iOS 应用（在 Apple Silicon Mac 上运行），使用 Apple iPhone OS Application Signing 证书签名。天然沙盒。")
            badgeRow(color: .teal,   title: "Apple 系统签名",
                     desc: "macOS 系统自带应用，使用 macOS Software Signing 证书签名。无需公证。")
            badgeRow(color: .gray,   title: "未公证",
                     desc: "Ad-hoc 签名、未签名或其它无法判定公证状态的情况。Gatekeeper 默认拒绝。")
        }
    }

    // MARK: - 沙盒
    private var sandboxSection: some View {
        helpSection(title: "沙盒状态", icon: "lock.shield.fill") {
            badgeRow(color: .green,  title: "沙盒应用",
                     desc: "Entitlements 中含 com.apple.security.app-sandbox，应用运行在 App Sandbox 沙盒内，文件和网络访问受限。")
            badgeRow(color: .orange, title: "非沙盒",
                     desc: "未启用 App Sandbox。应用可自由访问系统资源（受用户权限限制）。")
        }
    }

    // MARK: - 隔离
    private var quarantineSection: some View {
        helpSection(title: "Quarantine 隔离标记", icon: "xmark.shield.fill") {
            badgeRow(color: .yellow, title: "已隔离",
                     desc: "应用带 com.apple.quarantine 扩展属性，通常是从网络下载的。首次运行会触发 Gatekeeper 检查。")
            badgeRow(color: .gray,   title: "无隔离",
                     desc: "未检测到 quarantine 标记。可能来自可信来源（如 App Store）或已手动清除。")
        }
    }

    // MARK: - 签名有效性
    private var signatureStateSection: some View {
        helpSection(title: "签名有效性", icon: "signature") {
            badgeRow(color: .green,  title: "基础有效 (Basic Valid)",
                     desc: "SecStaticCodeCheckValidity 基础验证通过 (kSecCSBasicValidateOnly)。仅校验签名结构完整, 不等同于 Gatekeeper 完整验证或资源封印验证。完整可信度请参考「签名状态/公证状态」徽章。")
            badgeRow(color: .red,    title: "无效 (Invalid)",
                     desc: "基础验证失败。签名可能被篡改或损坏。")
            badgeRow(color: .gray,   title: "未验证",
                     desc: "未签名应用, 无法进行有效性验证。")
        }
    }

    // MARK: - 其它徽章
    private var badgesSection: some View {
        helpSection(title: "其它标识", icon: "tag.fill") {
            badgeRow(color: .purple, title: "Agent App (无 Dock)",
                     desc: "Info.plist 中 LSUIElement=true。无 Dock 图标、无主菜单栏，常用于后台工具或菜单栏应用。")
            badgeRow(color: .indigo, title: "仅后台 (Background)",
                     desc: "Info.plist 中 LSBackgroundOnly=true。纯后台运行，无 UI。")
            badgeRow(color: .pink,   title: "iOS 移植包",
                     desc: "Info.plist 中含 UI* 键（UIDeviceFamily / UILaunchStoryboardName 等），是 iOS 移植到 macOS 的应用。")
        }
    }

    // MARK: - UI 构建
    @ViewBuilder
    private func helpSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.system(.headline, design: .default).bold())
            }
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.leading, 28)
        }
    }

    /// 两行布局：第一行徽章，第二行说明文字（左对齐，整齐）
    @ViewBuilder
    private func badgeRow(color: Color, title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Badge(text: title, color: color)
                .fixedSize()
            Text(desc)
                .font(.system(.callout))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
