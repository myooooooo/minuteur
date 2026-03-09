import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppStateManager

    init() {
        UITabBar.appearance().barStyle = .black
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            FocusView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
                .tag(AppTab.focus)

            StatsView()
                .tabItem {
                    Label("Statistiques", systemImage: "chart.bar.fill")
                }
                .tag(AppTab.stats)

            SettingsView()
                .tabItem {
                    Label("Réglages", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(appState.neonTheme.accentColor)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppStateManager())
}
