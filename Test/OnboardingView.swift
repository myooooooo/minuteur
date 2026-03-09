import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        TabView {
            onboardingPage(
                symbolName: "timer",
                symbolColor: .white,
                title: "FocusFlow",
                subtitle: "La productivité par le minimalisme"
            )

            onboardingPage(
                symbolName: "hand.tap.fill",
                symbolColor: .cyan,
                title: "Interface Sensorielle",
                subtitle: "Des retours haptiques pour chaque minute écoulée"
            )

            thirdPage
        }
        .background(Color.black.ignoresSafeArea())
        .tabViewStyle(.page(indexDisplayMode: .always))
    }

    private func onboardingPage(
        symbolName: String,
        symbolColor: Color,
        title: String,
        subtitle: String
    ) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: symbolName)
                    .font(.system(size: 80, weight: .regular))
                    .foregroundStyle(symbolColor)

                Text(title)
                    .font(.system(size: 40, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Spacer()
            }
            .padding(.bottom, 34)
        }
    }

    private var thirdPage: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "waveform.path")
                    .font(.system(size: 80, weight: .regular))
                    .foregroundStyle(.indigo)

                Text("Deep Work")
                    .font(.system(size: 40, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Button {
                    appState.completeOnboarding()
                } label: {
                    Text("Commencer l'expérience")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.top, 8)

                Spacer()
            }
            .padding(.bottom, 34)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppStateManager())
}
