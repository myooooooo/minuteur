import SwiftUI

#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

struct LandingPageView: View {
    @EnvironmentObject var appState: AppStateManager

    @State private var breath = false
    @State private var flicker = false
    @State private var liveActivityErrorText: String?

    private var accent: Color {
        appState.neonTheme.accentColor
    }

    private var secondaryAccent: Color {
        appState.neonTheme.accentColor == .cyan ? Color.green : Color.cyan
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VoltCarbonBackground(accent: accent)
            GrainOverlayView(opacity: 0.07)

            VStack(spacing: 18) {
                Spacer(minLength: 20)

                Image(systemName: "timer.circle.fill")
                    .font(.system(size: 110, weight: .regular))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(flicker ? 0.82 : 0.35), radius: flicker ? 26 : 12)
                    .shadow(color: secondaryAccent.opacity(flicker ? 0.35 : 0.12), radius: flicker ? 18 : 8)
                    .scaleEffect(breath ? 1.06 : 0.95)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: breath)
                    .animation(.easeInOut(duration: 0.22).repeatForever(autoreverses: true), value: flicker)

                Text("FOCUS FLOW")
                    .font(.system(size: 46, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(white: 0.95))

                Text("Entrez dans la zone. Gagnez de l'XP. Maitrisez votre temps.")
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(white: 0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    landingRow(title: "Boot Sequence", value: "READY")
                    landingRow(title: "Theme", value: appState.neonTheme.title.uppercased())
                    landingRow(title: "Level", value: "\(appState.level)")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(white: 0.22), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                if let liveActivityErrorText {
                    Text(liveActivityErrorText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.red.opacity(0.85))
                        .padding(.horizontal, 24)
                }

                Button {
                    Task {
                        await startFocusActivity()
                    }
                } label: {
                    Text("PRE-LAUNCH ISLAND")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(accent))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 8) {
                    Text("A propos")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.65))

                    HStack(spacing: 16) {
                        Link("Portfolio", destination: URL(string: "https://example.com/portfolio")!)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(accent)

                        Link("LinkedIn", destination: URL(string: "https://www.linkedin.com")!)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(accent)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            breath = true
            flicker = true
        }
    }

    private func landingRow(title: String, value: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(white: 0.65))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
        }
    }

    @MainActor
    private func startFocusActivity() async {
        #if canImport(ActivityKit) && os(iOS)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            liveActivityErrorText = "Live Activities disabled."
            return
        }

        let total = 50 * 60
        let state = FocusFlowAttributes.ContentState(
            targetDate: Date().addingTimeInterval(TimeInterval(total)),
            phaseLabel: "TRAVAIL",
            isPaused: false,
            remainingSeconds: total,
            totalSeconds: total
        )

        do {
            _ = try Activity<FocusFlowAttributes>.request(
                attributes: FocusFlowAttributes(sessionID: UUID()),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            liveActivityErrorText = nil
        } catch {
            liveActivityErrorText = "Activity request failed: \(error.localizedDescription)"
        }
        #endif
    }
}

#Preview {
    LandingPageView()
        .environmentObject(AppStateManager())
}

private struct VoltCarbonBackground: View {
    let accent: Color

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.22), Color.black],
                center: .top,
                startRadius: 20,
                endRadius: 360
            )
            LinearGradient(
                colors: [Color(white: 0.13).opacity(0.18), .clear, Color(white: 0.18).opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct GrainOverlayView: View {
    let opacity: Double

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0.0, to: size.width, by: 3.0) {
                for y in stride(from: 0.0, to: size.height, by: 3.0) {
                    let value = sin((x * 0.19) + (y * 0.13))
                    if value > 0.94 {
                        path.addRect(CGRect(x: x, y: y, width: 1, height: 1))
                    }
                }
            }
            context.fill(path, with: .color(.white.opacity(opacity)))
        }
        .allowsHitTesting(false)
        .blendMode(.overlay)
    }
}
