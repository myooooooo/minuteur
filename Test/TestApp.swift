import SwiftUI

@main
struct FocusFlowApp: App {
    @StateObject private var appState = AppStateManager()
    private let forceLanding = ProcessInfo.processInfo.arguments.contains("-forceLanding")

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding && !forceLanding {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    LandingPageView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: appState.hasCompletedOnboarding || forceLanding)
            .environmentObject(appState)
        }
    }
}
