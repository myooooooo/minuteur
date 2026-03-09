import SwiftUI

@main
struct FocusFlowApp: App {
    @StateObject private var appState = AppStateManager()

    var body: some Scene {
        WindowGroup {
            LandingPageView()
            .environmentObject(appState)
        }
    }
}
