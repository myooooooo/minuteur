import SwiftUI

@main
struct FocusFlowApp: App {
    @StateObject private var appState = AppStateManager()
    @Namespace private var entryNamespace

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    MainTabView(entryNamespace: entryNamespace)
                        .transition(.opacity)
                } else {
                    OnboardingView(entryNamespace: entryNamespace)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: appState.hasCompletedOnboarding)
            .environmentObject(appState)
        }
    }
}
