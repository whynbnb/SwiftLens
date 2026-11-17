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
        helpSection(title: L10n.t(.helpNotarizationTitle), icon: "checkmark.shield.fill") {
            badgeRow(color: .green,  title: L10n.t(.helpNotarizedTitle), desc: L10n.t(.helpNotarizedDesc))
            badgeRow(color: .orange, title: L10n.t(.helpDevIDTitle), desc: L10n.t(.helpDevIDDesc))
            badgeRow(color: .blue,   title: L10n.t(.helpMASTitle), desc: L10n.t(.helpMASDesc))
            badgeRow(color: .pink,   title: L10n.t(.helpIOSStoreTitle), desc: L10n.t(.helpIOSStoreDesc))
            badgeRow(color: .teal,   title: L10n.t(.helpAppleSystemTitle), desc: L10n.t(.helpAppleSystemDesc))
            badgeRow(color: .gray,   title: L10n.t(.helpNotNotarizedTitle), desc: L10n.t(.helpNotNotarizedDesc))
        }
    }

    // MARK: - 沙盒
    private var sandboxSection: some View {
        helpSection(title: L10n.t(.helpSandboxTitle), icon: "lock.shield.fill") {
            badgeRow(color: .green,  title: L10n.t(.helpSandboxedTitle), desc: L10n.t(.helpSandboxedDesc))
            badgeRow(color: .orange, title: L10n.t(.helpNoSandboxTitle), desc: L10n.t(.helpNoSandboxDesc))
        }
    }

    // MARK: - 隔离
    private var quarantineSection: some View {
        helpSection(title: L10n.t(.helpQuarantineTitle), icon: "xmark.shield.fill") {
            badgeRow(color: .yellow, title: L10n.t(.helpQuarantinedTitle), desc: L10n.t(.helpQuarantinedDesc))
            badgeRow(color: .gray,   title: L10n.t(.helpNoQuarantineTitle), desc: L10n.t(.helpNoQuarantineDesc))
        }
    }

    // MARK: - 签名有效性
    private var signatureStateSection: some View {
        helpSection(title: L10n.t(.helpValidityTitle), icon: "signature") {
            badgeRow(color: .green,  title: L10n.t(.helpBasicValidTitle), desc: L10n.t(.helpBasicValidDesc))
            badgeRow(color: .green,  title: L10n.t(.helpStrictValidTitle), desc: L10n.t(.helpStrictValidDesc))
            badgeRow(color: .red,    title: L10n.t(.helpInvalidTitle), desc: L10n.t(.helpInvalidDesc))
            badgeRow(color: .gray,   title: L10n.t(.helpUntestedTitle), desc: L10n.t(.helpUntestedDesc))
        }
    }

    // MARK: - 其它徽章
    private var badgesSection: some View {
        helpSection(title: L10n.t(.helpBadgesTitle), icon: "tag.fill") {
            badgeRow(color: .purple, title: L10n.t(.helpAgentAppTitle), desc: L10n.t(.helpAgentAppDesc))
            badgeRow(color: .indigo, title: L10n.t(.helpBackgroundTitle), desc: L10n.t(.helpBackgroundDesc))
            badgeRow(color: .pink,   title: L10n.t(.helpIOSPortTitle), desc: L10n.t(.helpIOSPortDesc))
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
