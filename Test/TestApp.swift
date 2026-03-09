import SwiftUI

@main
struct FocusFlowApp: App {
    @StateObject private var appState = AppStateManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(appState)
        }
    }
}
