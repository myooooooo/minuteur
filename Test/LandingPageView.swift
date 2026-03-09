import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

struct LandingPageView: View {
    @State private var logoBreathing = false
    @State private var buttonPulse = false

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
                Spacer()

                Group {
                    if UIImage(named: "FocusLogo") != nil {
                        Image("FocusLogo")
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "scope")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.cyan)
                    }
                }
                .frame(width: 110, height: 110)
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

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        featureCard(
                            title: "Interface Neon",
                            subtitle: "Design immersif."
                        )
                        featureCard(
                            title: "Systeme RPG",
                            subtitle: "Evoluez a chaque session."
                        )
                        featureCard(
                            title: "Stats Deep",
                            subtitle: "Analysez vos performances."
                        )
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 10)

                Button {
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

    private func featureCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(width: 185, height: 100, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
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
