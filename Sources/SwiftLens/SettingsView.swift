import SwiftUI

// MARK: - 设置面板（原生 Settings 窗口）

/// 由 SwiftUI `Settings` scene 承载，使用系统标准设置窗口：
/// 工具栏标签页 + grouped Form，不再使用自定义 sheet / 关闭按钮。
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label(L10n.t(.general), systemImage: "gearshape")
                }
            recentTab
                .tabItem {
                    Label(L10n.t(.recentApps), systemImage: "clock.arrow.circlepath")
                }
        }
        .frame(width: 520, height: 300)
    }

    // MARK: 通用
    private var generalTab: some View {
        Form {
            Section {
                Picker(L10n.t(.language), selection: bindingLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Picker(L10n.t(.theme), selection: bindingTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
            }
            Section {
                Toggle(L10n.t(.showFileTree), isOn: bindingShowFileTree)
            } footer: {
                Text(L10n.t(.showFileTreeHint))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: 最近打开
    private var recentTab: some View {
        Form {
            Section {
                Toggle(L10n.t(.recentAppsEnabled), isOn: bindingRecentApps)
            } footer: {
                Text(L10n.t(.recentAppsHint))
            }

            if !appState.recentApps.isEmpty {
                Section {
                    HStack {
                        Text("\(appState.recentApps.count) \(L10n.t(.entryUnit))")
                        Spacer()
                        Button(L10n.t(.clearRecentApps)) {
                            appState.clearRecentApps()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
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
    private var bindingRecentApps: Binding<Bool> {
        Binding(
            get: { appState.recentAppsEnabled },
            set: { appState.recentAppsEnabled = $0 }
        )
    }
    private var bindingShowFileTree: Binding<Bool> {
        Binding(
            get: { appState.showFileTree },
            set: { appState.showFileTree = $0 }
        )
    }
}
