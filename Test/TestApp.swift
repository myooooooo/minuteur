import SwiftUI

@main
struct FocusFlowApp: App {
    @StateObject private var appState = AppStateManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    LandingPageView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: appState.hasCompletedOnboarding)
            .environmentObject(appState)
        }
    }
}
