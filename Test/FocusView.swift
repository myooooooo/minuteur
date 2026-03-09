import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

struct FocusView: View {
    @EnvironmentObject var appState: AppStateManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = FocusFlowViewModel()

    @State private var totalAccumulatedMinutes: Int = 50
    @State private var previousDragAngle: Double?
    @State private var accumulatedDragAngle: Double = 0
    @State private var gestureStartMinutes: Int = 50

    private let ringSize: CGFloat = 300
    private let ringLineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 10)

                Text(viewModel.currentSegment.displayName)
                    .font(.system(size: 16, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))

                NeonRingView(
                    progress: ringProgress,
                    colors: ringColors,
                    lineWidth: ringLineWidth
                )
                .frame(width: ringSize, height: ringSize)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard viewModel.phase == .setting else { return }
                                handleRotationChange(location: value.location)
                            }
                            .onEnded { _ in
                                previousDragAngle = nil
                                accumulatedDragAngle = 0
                                gestureStartMinutes = totalAccumulatedMinutes
                            }
                    )

                VStack(spacing: 2) {
                    Text(centerTimeText)
                        .font(.system(size: 80, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(displayReferenceMinutes < 60 ? "minutes" : "h:mm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    Menu {
                        Button(viewModel.isSoundEnabled ? "Couper le son" : "Activer le son") {
                            viewModel.toggleSound()
                        }

                        Divider()

                        ForEach(FocusSoundscape.allCases, id: \.rawValue) { sound in
                            Button {
                                appState.updateSoundscape(sound)
                                viewModel.setSoundscape(sound)
                            } label: {
                                if appState.selectedSoundscape == sound {
                                    Label(sound.title, systemImage: "checkmark")
                                } else {
                                    Text(sound.title)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: viewModel.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.86))
                    }

                    Button {
                        primaryAction()
                    } label: {
                        Image(systemName: mainControlIcon)
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .accessibilityLabel(mainControlAccessibility)

                    Button {
                        viewModel.reset()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .accessibilityLabel("Stop")
                }

                Spacer()

                Toggle(isOn: Binding(
                    get: { appState.isVibrationsEnabled },
                    set: { appState.updateVibrations($0) }
                )) {
                    Text("Tic-tac haptique")
                        .foregroundStyle(.white.opacity(0.76))
                }
                .tint(activeAccent)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 28)
        }
        .sensoryFeedback(.success, trigger: viewModel.successHapticTrigger)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.secondTickHapticTrigger) { _, _ in
            appState.isVibrationsEnabled && viewModel.isRunningActive
        }
        .onAppear {
            totalAccumulatedMinutes = viewModel.selectedMinutes
            gestureStartMinutes = totalAccumulatedMinutes
            viewModel.isTickHapticsEnabled = appState.isVibrationsEnabled
            viewModel.setSoundscape(appState.selectedSoundscape)
        }
        .onChange(of: viewModel.selectedMinutes) { _, newValue in
            if previousDragAngle == nil {
                totalAccumulatedMinutes = newValue
                gestureStartMinutes = newValue
            }
        }
        .onChange(of: viewModel.phase) { _, newValue in
            if newValue != .setting {
                previousDragAngle = nil
                accumulatedDragAngle = 0
            }
        }
        .onChange(of: appState.isVibrationsEnabled) { _, newValue in
            viewModel.isTickHapticsEnabled = newValue
        }
        .onChange(of: appState.selectedSoundscape) { _, newValue in
            viewModel.setSoundscape(newValue)
        }
        .onChange(of: viewModel.earnedFocusTrigger) { _, _ in
            appState.addXP(minutes: viewModel.earnedFocusMinutes)
        }
        .onChange(of: scenePhase) { _, newValue in
            handleScenePhaseChange(newValue)
        }
    }

    private var ringColors: [Color] {
        guard viewModel.phase == .running else { return appState.neonTheme.colors }
        return viewModel.currentSegment == .work ? [.cyan, .indigo] : [Color.green, Color.mint]
    }

    private var activeAccent: Color {
        ringColors.first ?? .cyan
    }

    private var displayReferenceMinutes: Int {
        if viewModel.phase == .setting {
            return totalAccumulatedMinutes
        }

        if viewModel.remainingSeconds == 0 {
            return 0
        }

        return Int(ceil(Double(viewModel.remainingSeconds) / 60))
    }

    private var ringProgress: Double {
        let minutes = displayReferenceMinutes
        if minutes == 0 {
            return 0
        }

        let minuteInCurrentHour = minuteInCurrentHour(for: minutes)
        return Double(minuteInCurrentHour) / 60.0
    }

    private var centerTimeText: String {
        let minutes = displayReferenceMinutes
        guard minutes >= 60 else { return "\(minutes)" }

        let hours = minutes / 60
        let remainderMinutes = minutes % 60
        return String(format: "%d:%02d", hours, remainderMinutes)
    }

    private var mainControlIcon: String {
        if viewModel.phase == .setting || viewModel.phase == .completed {
            return "play.circle.fill"
        }
        return viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill"
    }

    private var mainControlAccessibility: String {
        if viewModel.phase == .setting || viewModel.phase == .completed {
            return "Démarrer"
        }
        return viewModel.isPaused ? "Reprendre" : "Pause"
    }

    private func minuteInCurrentHour(for totalMinutes: Int) -> Int {
        let remainder = totalMinutes % 60
        return remainder == 0 ? 60 : remainder
    }

    private func primaryAction() {
        switch viewModel.phase {
        case .setting, .completed:
            #if canImport(ActivityKit) && os(iOS)
            viewModel.startLiveActivity(minutes: displayReferenceMinutes)
            #endif
            viewModel.start()
        case .running:
            viewModel.togglePauseResume()
        }
    }

    private func handleRotationChange(location: CGPoint) {
        let angle = angleForDrag(location: location, in: CGSize(width: ringSize, height: ringSize))

        if previousDragAngle == nil {
            previousDragAngle = angle
            accumulatedDragAngle = 0
            gestureStartMinutes = totalAccumulatedMinutes
            return
        }

        guard let previousDragAngle else { return }

        let delta = unwrappedDelta(from: previousDragAngle, to: angle)
        self.previousDragAngle = angle
        accumulatedDragAngle += delta

        let deltaMinutes = Int(round((accumulatedDragAngle / (2 * .pi)) * 60))
        let proposedMinutes = gestureStartMinutes + deltaMinutes
        let clampedMinutes = min(max(proposedMinutes, 1), 300)

        updateAccumulatedMinutes(clampedMinutes)
    }

    private func updateAccumulatedMinutes(_ newValue: Int) {
        guard newValue != totalAccumulatedMinutes else { return }

        let oldValue = totalAccumulatedMinutes
        totalAccumulatedMinutes = newValue
        viewModel.setMinutesFromDrag(newValue)

        triggerRotationHaptic(from: oldValue, to: newValue)
    }

    private func unwrappedDelta(from previous: Double, to current: Double) -> Double {
        var delta = current - previous
        if delta > .pi {
            delta -= 2 * .pi
        } else if delta < -.pi {
            delta += 2 * .pi
        }
        return delta
    }

    private func angleForDrag(location: CGPoint, in size: CGSize) -> Double {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 {
            angle += 2 * .pi
        }

        return angle
    }

    private func crossedHourBoundary(from oldValue: Int, to newValue: Int) -> Bool {
        guard oldValue != newValue else { return false }

        let lower = min(oldValue, newValue) + 1
        let upper = max(oldValue, newValue)

        for hourMark in stride(from: 60, through: 300, by: 60) {
            if hourMark >= lower && hourMark <= upper {
                return true
            }
        }

        return false
    }

    private func triggerRotationHaptic(from oldValue: Int, to newValue: Int) {
        #if canImport(UIKit)
        guard appState.isVibrationsEnabled else { return }
        let shouldUseHeavy = (newValue % 60 == 0) || crossedHourBoundary(from: oldValue, to: newValue)
        let generator = UIImpactFeedbackGenerator(style: shouldUseHeavy ? .heavy : .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        guard phase == .background else { return }
        guard appState.isStrictFocusModeEnabled else { return }
        guard viewModel.isRunningActive else { return }

        Task {
            await StrictFocusNotificationManager.scheduleReminder(remainingSeconds: viewModel.remainingSeconds)
        }
    }
}

private enum StrictFocusNotificationManager {
    static func scheduleReminder(remainingSeconds: Int) async {
        let center = UNUserNotificationCenter.current()
        let granted = await requestPermissionIfNeeded(center: center)
        guard granted else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["focusflow.strict.reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Mode Concentration Strict"
        let remainingMinutes = max(1, Int(ceil(Double(remainingSeconds) / 60)))
        content.body = "Reviens à FocusFlow. Il reste \(remainingMinutes) minute(s) de session."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 8, repeats: false)
        let request = UNNotificationRequest(identifier: "focusflow.strict.reminder", content: content, trigger: trigger)
        try? await center.add(request)
    }

    private static func requestPermissionIfNeeded(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            return true
        }

        if settings.authorizationStatus == .notDetermined {
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }

        return false
    }
}

#Preview {
    FocusView()
        .environmentObject(AppStateManager())
}
