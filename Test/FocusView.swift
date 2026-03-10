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
    @State private var speakerPulse = false
    @State private var glowPulse = false
    @State private var showMixer = false
    @State private var showBadgeAlert = false
    @State private var showChallengeComplete = false
    /// Tracks whether the user left the app during a strict-mode work session.
    @State private var didLeaveAppDuringStrict = false

    private let ringSize: CGFloat = 250
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
                    lineWidth: ringLineWidth,
                    glowIntensity: neonGlowIntensity
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
                            pulseSpeakerIcon()
                        }

                        Divider()

                        ForEach(FocusSoundscape.allCases, id: \.rawValue) { sound in
                            Button {
                                appState.updateSoundscape(sound)
                                viewModel.setSoundscape(sound)
                                pulseSpeakerIcon()
                            } label: {
                                if appState.selectedSoundscape == sound {
                                    Label(sound.title, systemImage: "checkmark")
                                } else {
                                    Text(sound.title)
                                }
                            }
                        }

                        Divider()

                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showMixer.toggle()
                            }
                        } label: {
                            Label("Mixer", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Image(systemName: viewModel.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(speakerPulse ? 1.0 : 0.86))
                            .scaleEffect(speakerPulse ? 1.12 : 1.0)
                            .animation(.easeInOut(duration: 0.18), value: speakerPulse)
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

                // MARK: - Dual-Layer Mixer Panel
                if showMixer {
                    mixerPanel
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
            viewModel.prepareAudio()
            // Schedule 24h inactivity reminder on each app launch.
            InactivityReminderManager.scheduleInactivityReminder()
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
            if newValue == .running {
                didLeaveAppDuringStrict = false
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            } else {
                glowPulse = false
            }
        }
        .onChange(of: appState.isVibrationsEnabled) { _, newValue in
            viewModel.isTickHapticsEnabled = newValue
        }
        .onChange(of: appState.selectedSoundscape) { _, newValue in
            viewModel.setSoundscape(newValue)
        }
        .onChange(of: viewModel.earnedFocusTrigger) { _, _ in
            appState.addXP(
                minutes: viewModel.earnedFocusMinutes,
                wasStrictViolation: didLeaveAppDuringStrict && appState.isStrictFocusModeEnabled
            )
            didLeaveAppDuringStrict = false
        }
        .onChange(of: viewModel.completionHapticTrigger) { _, _ in
            performCompletionHapticSequence()
        }
        .onChange(of: appState.newlyEarnedBadge) { _, badge in
            if badge != nil { showBadgeAlert = true }
        }
        .onChange(of: appState.challengeCompletedTrigger) { _, _ in
            showChallengeComplete = true
        }
        .onChange(of: scenePhase) { _, newValue in
            handleScenePhaseChange(newValue)
        }
        .overlay(alignment: .top) {
            if showBadgeAlert, let badge = appState.newlyEarnedBadge {
                badgeToast(badge)
            }
        }
        .overlay(alignment: .top) {
            if showChallengeComplete {
                challengeCompleteToast
            }
        }
    }

    /// Dynamic glow intensity: pulses between 0.3 and 1.0 during active sessions,
    /// intensifying as the session nears completion.
    private var neonGlowIntensity: Double {
        guard viewModel.phase == .running, !viewModel.isPaused else { return 0 }
        // Base intensity from progress (0→1 as time elapses).
        let progressFactor = viewModel.progress
        // Pulse oscillation adds dynamic life.
        let pulseFactor: Double = glowPulse ? 0.3 : 0.0
        return min(1.0, 0.2 + progressFactor * 0.5 + pulseFactor)
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
        switch phase {
        case .active:
            viewModel.refreshRemainingFromTargetDate()
            // Re-schedule 24h inactivity reminder each time app becomes active.
            InactivityReminderManager.scheduleInactivityReminder()
        case .inactive, .background:
            guard viewModel.isRunningActive else { return }

            // Strict Mode 2.0: flag XP penalty if the user leaves during a work session.
            if appState.isStrictFocusModeEnabled, viewModel.currentSegment == .work {
                didLeaveAppDuringStrict = true
            }

            guard appState.isStrictFocusModeEnabled else { return }
            Task {
                await StrictFocusNotificationManager.scheduleReminder(remainingSeconds: viewModel.remainingSeconds)
            }
        @unknown default:
            break
        }
    }

    // MARK: - Mixer Panel

    private var mixerPanel: some View {
        VStack(spacing: 12) {
            Text("MIXER")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)

            // Primary layer
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedSoundscape.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Slider(
                    value: Binding(
                        get: { viewModel.primaryVolume },
                        set: { viewModel.updatePrimaryVolume($0) }
                    ),
                    in: 0...1
                )
                .tint(activeAccent)
            }

            // Secondary layer
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(viewModel.secondarySoundscape?.title ?? "Couche 2")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Menu {
                        Button("Aucun") {
                            viewModel.setSecondarySoundscape(nil)
                        }
                        ForEach(FocusSoundscape.allCases, id: \.rawValue) { sound in
                            Button(sound.title) {
                                viewModel.setSecondarySoundscape(sound)
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                if viewModel.secondarySoundscape != nil {
                    Slider(
                        value: Binding(
                            get: { viewModel.secondaryVolume },
                            set: { viewModel.updateSecondaryVolume($0) }
                        ),
                        in: 0...1
                    )
                    .tint(activeAccent.opacity(0.7))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Completion Haptic Sequence

    private func performCompletionHapticSequence() {
        #if canImport(UIKit)
        guard appState.isVibrationsEnabled else { return }

        let notification = UINotificationFeedbackGenerator()
        notification.prepare()

        // Pattern: success → light impact → heavy impact → success
        notification.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let light = UIImpactFeedbackGenerator(style: .light)
            light.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let finalSuccess = UINotificationFeedbackGenerator()
            finalSuccess.notificationOccurred(.success)
        }
        #endif
    }

    // MARK: - Badge Toast

    private func badgeToast(_ badge: FocusBadge) -> some View {
        HStack(spacing: 10) {
            Image(systemName: badge.symbol)
                .font(.system(size: 22))
                .foregroundStyle(activeAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Badge débloqué !")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                Text(badge.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { showBadgeAlert = false }
                appState.newlyEarnedBadge = nil
            }
        }
    }

    // MARK: - Challenge Complete Toast

    private var challengeCompleteToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow)
            Text("Défi du jour complété !")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { showChallengeComplete = false }
            }
        }
    }

    private func pulseSpeakerIcon() {
        speakerPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            speakerPulse = false
        }
    }
}

// MARK: - 24h Inactivity Reminder

private enum InactivityReminderManager {
    static func scheduleInactivityReminder() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional ||
                  settings.authorizationStatus == .notDetermined else { return }

            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }

            // Remove any previous inactivity reminder.
            center.removePendingNotificationRequests(withIdentifiers: ["focusflow.inactivity.24h"])

            let content = UNMutableNotificationContent()
            content.title = "Tu nous manques !"
            content.body = "Ça fait 24h sans session de focus. Reviens maintenir ta série !"
            content.sound = .default

            // Fire 24 hours from now.
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
            let request = UNNotificationRequest(identifier: "focusflow.inactivity.24h", content: content, trigger: trigger)
            try? await center.add(request)
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

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
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
