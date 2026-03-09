import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppStateManager
    let entryNamespace: Namespace.ID?

    init(entryNamespace: Namespace.ID? = nil) {
        self.entryNamespace = entryNamespace
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
        .overlay(alignment: .bottom) {
            if let entryNamespace {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(appState.neonTheme.accentColor)
                    .frame(width: 1, height: 1)
                    .opacity(0.001)
                    .matchedGeometryEffect(id: "entry.accent", in: entryNamespace)
            }
        }
    }
}

#Preview {
    MainTabView(entryNamespace: nil)
        .environmentObject(AppStateManager())
}
