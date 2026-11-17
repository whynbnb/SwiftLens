import SwiftUI

// MARK: - 设置面板

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题行
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(L10n.t(.settings))
                    .font(.title2.bold())
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .help(L10n.t(.close))
            }

            // 语言
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.t(.language), systemImage: "globe")
                    .font(.headline)
                Picker(L10n.t(.language), selection: bindingLanguage) {
                    ForEach(AppLanguage.allCases) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 400)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 主题
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.t(.theme), systemImage: "sun.max.fill")
                    .font(.headline)
                Picker(L10n.t(.theme), selection: bindingTheme) {
                    ForEach(AppTheme.allCases) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 400)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 最近打开
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: bindingRecentApps) {
                    Label(L10n.t(.recentAppsEnabled), systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                }
                .toggleStyle(.switch)
                Text(L10n.t(.recentAppsHint))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !appState.recentApps.isEmpty {
                    HStack {
                        Text("\(appState.recentApps.count) \(L10n.t(.entryUnit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.t(.clearRecentApps)) {
                            appState.clearRecentApps()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 占位提示
            Text(verbatim: "SwiftLens \(AppMeta.shared.versionString)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(28)
        .frame(width: 480, height: 380)
        .background(.regularMaterial)
    }

    private var bindingRecentApps: Binding<Bool> {
        Binding(
            get: { appState.recentAppsEnabled },
            set: { appState.recentAppsEnabled = $0 }
        )
    }

    // AppStorage 双向绑定 (枚举) 需要走 String 中介
    private var bindingLanguage: Binding<AppLanguage> {
        Binding(
            get: { appState.language },
            set: { appState.language = $0 }
        )
    }
    private var bindingTheme: Binding<AppTheme> {
        Binding(
            get: { appState.theme },
            set: { appState.theme = $0 }
        )
    }
}