import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    @EnvironmentObject var appState: AppStateManager

    let entryNamespace: Namespace.ID

    @State private var currentStep = 0
    @State private var dragOffset: CGFloat = 0
    @State private var glitchTrigger = 0
    @State private var xpPreview = 0
    @State private var launchFill = false

    private struct Step: Identifiable {
        let id: Int
        let title: String
        let subtitle: String
        let symbol: String
    }

    private let steps: [Step] = [
        Step(
            id: 0,
            title: "INTERFACE VOLT",
            subtitle: "Un cockpit noir carbone, des accents reactifs, une lisibilite totale.",
            symbol: "bolt.horizontal.circle.fill"
        ),
        Step(
            id: 1,
            title: "SENSATION ACTIVE",
            subtitle: "Chaque transition emet une reponse tactile precise.",
            symbol: "waveform.path.ecg"
        ),
        Step(
            id: 2,
            title: "PROGRESSION RPG",
            subtitle: "+50 XP, niveau 2 atteint, theme Matrix debloque.",
            symbol: "shield.lefthalf.filled"
        )
    ]

    private var accent: Color {
        appState.neonTheme.accentColor
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VoltCarbonBackground(accent: accent)
            GrainOverlayView(opacity: 0.08)

            VStack(spacing: 18) {
                topHUD

                ZStack {
                    ForEach(steps) { step in
                        if step.id == currentStep {
                            stepCard(step)
                                .id(step.id)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                                        removal: .opacity.combined(with: .move(edge: .leading))
                                    )
                                )
                        }
                    }
                }
                .offset(x: dragOffset)
                .gesture(swipeGesture)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: currentStep)
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: dragOffset)

                progressDots

                actionBar
            }
            .padding(20)

            Rectangle()
                .fill(accent)
                .ignoresSafeArea()
                .scaleEffect(launchFill ? 1 : 0.001, anchor: .bottom)
                .opacity(launchFill ? 0.95 : 0)
                .animation(.easeInOut(duration: 0.36), value: launchFill)
                .allowsHitTesting(false)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: currentStep)
        .onChange(of: currentStep) { _, _ in
            glitchTrigger += 1
            if currentStep == 2 {
                withAnimation(.easeOut(duration: 0.9)) {
                    xpPreview = 50
                }
            } else {
                xpPreview = 0
            }
        }
        .onAppear {
            glitchTrigger = 1
        }
    }

    private var topHUD: some View {
        HStack {
            Text("FOCUSFLOW_INIT")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(white: 0.75))

            Spacer()

            Text("0\(currentStep + 1)/0\(steps.count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
        }
    }

    private func stepCard(_ step: Step) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: step.symbol)
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.45), radius: 10)
                .offset(x: glitchTrigger.isMultiple(of: 2) ? -1.2 : 1.1)

            Text(step.title)
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .textCase(.uppercase)

            Text(step.subtitle)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.8))

            if step.id == 2 {
                rpgPreview
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(white: 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(white: 0.22), lineWidth: 1)
        )
    }

    private var rpgPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NIVEAU SIMULE")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(white: 0.76))

            HStack {
                Text("LVL 1")
                Spacer()
                Text("LVL 2")
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(Color(white: 0.7))

            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.17)).frame(height: 10)
                Capsule().fill(accent).frame(width: CGFloat(xpPreview) * 2.4, height: 10)
            }

            Text("+\(xpPreview) XP - Theme Matrix debloque")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(accent)
        }
        .padding(.top, 8)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? accent : Color(white: 0.25))
                    .frame(width: index == currentStep ? 28 : 8, height: 6)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                guard currentStep > 0 else { return }
                currentStep -= 1
            } label: {
                Text("PREV")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
            }
            .buttonStyle(.plain)
            .opacity(currentStep == 0 ? 0.45 : 1)
            .disabled(currentStep == 0)

            if currentStep < steps.count - 1 {
                Button {
                    currentStep += 1
                } label: {
                    Text("NEXT")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(accent))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    completeFlow()
                } label: {
                    Text("COMMENCER")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(accent)
                                .matchedGeometryEffect(id: "entry.accent", in: entryNamespace)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                dragOffset = value.translation.width * 0.18
            }
            .onEnded { value in
                defer { dragOffset = 0 }
                if value.translation.width < -70, currentStep < steps.count - 1 {
                    currentStep += 1
                } else if value.translation.width > 70, currentStep > 0 {
                    currentStep -= 1
                }
            }
    }

    private func completeFlow() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif

        launchFill = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeInOut(duration: 0.28)) {
                appState.completeOnboarding()
            }
        }
    }
}

private struct VoltCarbonBackground: View {
    let accent: Color

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.28), Color.black],
                center: .topLeading,
                startRadius: 20,
                endRadius: 360
            )

            LinearGradient(
                colors: [Color(white: 0.12).opacity(0.22), .clear, Color(white: 0.16).opacity(0.2)],
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
                    let value = sin((x * 0.17) + (y * 0.11))
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

#Preview {
    OnboardingPreviewHost()
}
private struct OnboardingPreviewHost: View {
    @Namespace private var ns

    var body: some View {
        OnboardingView(entryNamespace: ns)
            .environmentObject(AppStateManager())
    }
}

