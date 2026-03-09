import SwiftUI

private struct FocusArcShape: Shape {
    var progress: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start = Angle.degrees(-90)
        let end = Angle.degrees(-90 + (360 * progress))

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: start,
            endAngle: end,
            clockwise: false
        )
        return path
    }
}

struct ContentView: View {
    @StateObject private var viewModel = FocusFlowViewModel()
    @Namespace private var ringNamespace

    @State private var pulse = false
    @State private var isVisible = false

    // Daily persistence with AppStorage as requested.
    @AppStorage("focusflow.totalMinutesToday") private var totalMinutesToday = 0
    @AppStorage("focusflow.lastDate") private var lastDate = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                header

                Group {
                    switch viewModel.phase {
                    case .setting:
                        settingMode
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale), removal: .opacity))
                    case .running, .completed:
                        runningMode
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale), removal: .opacity))
                    }
                }
                .animation(.spring(response: 0.55, dampingFraction: 0.86), value: viewModel.phase)

                footer
            }
            .padding(24)
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectionHapticTrigger)
        .sensoryFeedback(.success, trigger: viewModel.successHapticTrigger)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.secondTickHapticTrigger) { _, _ in
            viewModel.isTickHapticsEnabled && viewModel.phase == .running
        }
        .onAppear {
            syncDailyStorageIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isVisible = true
            }
        }
        .onChange(of: viewModel.sessionCompletionTrigger) { _, _ in
            syncDailyStorageIfNeeded()
            totalMinutesToday += viewModel.lastCompletedSessionMinutes
        }
        .onChange(of: viewModel.phase) { _, newValue in
            if newValue == .running {
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                pulse = false
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("FocusFlow")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("\(totalMinutesToday) min de focus aujourd'hui")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var settingMode: some View {
        VStack(spacing: 26) {
            if isVisible {
                ring(progress: Double(viewModel.selectedMinutes) / 60)
                    .matchedGeometryEffect(id: "focus-ring", in: ringNamespace)
                    .overlay {
                        VStack(spacing: 6) {
                            Text("Durée")
                                .foregroundStyle(.white.opacity(0.62))
                            Text("\(viewModel.selectedMinutes)")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                            Text("minutes")
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let minutes = minutesForDrag(location: value.location, in: CGSize(width: 290, height: 290))
                                viewModel.setMinutesFromDrag(minutes)
                            }
                    )
            }

            Button {
                viewModel.start()
            } label: {
                Text("Démarrer")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: [.cyan, .indigo], startPoint: .leading, endPoint: .trailing))
                    )
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
    }

    private var runningMode: some View {
        VStack(spacing: 24) {
            if isVisible {
                ring(progress: viewModel.progress)
                    .matchedGeometryEffect(id: "focus-ring", in: ringNamespace)
                    .overlay {
                        VStack(spacing: 8) {
                            Text(viewModel.timeDisplay)
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())

                            Text(viewModel.phase == .completed ? "Session terminée" : "En cours")
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    }
            }

            Button {
                viewModel.reset()
            } label: {
                Text(viewModel.phase == .completed ? "Nouvelle session" : "Arrêter")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        Toggle(isOn: $viewModel.isTickHapticsEnabled) {
            Text("Tic-tac haptique")
                .foregroundStyle(.white.opacity(0.78))
        }
        .tint(.cyan)
    }

    private func ring(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 24)

            // Custom Path-based progression ring with neon gradient.
            FocusArcShape(progress: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.cyan,
                            Color.indigo,
                            Color.cyan
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: .cyan.opacity(0.6), radius: 6)
                .shadow(color: .indigo.opacity(0.5), radius: 12)
                .opacity(viewModel.phase == .running ? (pulse ? 1.0 : 0.52) : 1.0)
                .animation(.easeInOut(duration: 1.3), value: pulse)
        }
        .frame(width: 290, height: 290)
    }

    private func minutesForDrag(location: CGPoint, in size: CGSize) -> Int {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 {
            angle += 2 * .pi
        }

        let percentage = angle / (2 * .pi)
        let minute = Int(round(percentage * 60))
        return min(max(minute, 1), 60)
    }

    private func syncDailyStorageIfNeeded() {
        let current = Self.dayStamp(for: Date())
        if lastDate != current {
            totalMinutesToday = 0
            lastDate = current
        }
    }

    private static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
