import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

struct LandingPageView: View {
    @EnvironmentObject var appState: AppStateManager

    @State private var logoBreathing = false
    @State private var buttonPulse = false
    @State private var selectedPage = 0

    private let pages: [(title: String, subtitle: String)] = [
        ("Interface Neon", "Design immersif."),
        ("Systeme RPG", "Evoluez a chaque session."),
        ("Stats Deep", "Analysez vos performances.")
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.cyan.opacity(0.35),
                    Color.cyan.opacity(0.08),
                    Color.black
                ],
                center: .top,
                startRadius: 30,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer(minLength: 16)

                Image(systemName: "timer.circle.fill")
                .font(.system(size: 98, weight: .regular))
                .foregroundStyle(.cyan)
                .shadow(color: .cyan, radius: 20)
                .scaleEffect(logoBreathing ? 1.06 : 0.94)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: logoBreathing)

                VStack(spacing: 10) {
                    Text("FOCUS FLOW")
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                        )

                    Text("Entrez dans la zone. Gagnez de l'XP. Maitrisez votre temps.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        onboardingPage(title: page.title, subtitle: page.subtitle)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Spacer(minLength: 10)

                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        appState.hasCompletedOnboarding = true
                    }
                    appState.completeOnboarding()
                    Task {
                        await startFocusActivity()
                    }
                } label: {
                    Text("DÉMARRER LE FOCUS")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.black.opacity(0.45))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.cyan, lineWidth: 1.6)
                        )
                        .shadow(color: .cyan.opacity(buttonPulse ? 0.9 : 0.35), radius: buttonPulse ? 18 : 8)
                        .animation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true), value: buttonPulse)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            logoBreathing = true
            buttonPulse = true
        }
    }

    private func onboardingPage(title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            Spacer()

            Text(title)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    @MainActor
    private func startFocusActivity() async {
        #if canImport(ActivityKit) && os(iOS)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let total = 50 * 60
        let state = FocusFlowAttributes.ContentState(
            targetDate: Date().addingTimeInterval(TimeInterval(total)),
            phaseLabel: "TRAVAIL",
            isPaused: false,
            remainingSeconds: total,
            totalSeconds: total
        )

        _ = try? Activity<FocusFlowAttributes>.request(
            attributes: FocusFlowAttributes(sessionID: UUID()),
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
        #endif
    }
}

#Preview {
    LandingPageView()
        .environmentObject(AppStateManager())
}
