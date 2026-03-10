import Foundation
import Combine


#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

@MainActor
final class FocusFlowViewModel: ObservableObject {
    enum Phase {
        case setting
        case running
        case completed
    }

    enum SegmentType {
        case work
        case shortBreak
        case longBreak

        var label: String {
            switch self {
            case .work: return "TRAVAIL"
            case .shortBreak, .longBreak: return "PAUSE"
            }
        }

        var displayName: String {
            switch self {
            case .work: return "Session de Travail"
            case .shortBreak: return "Pause Courte"
            case .longBreak: return "Pause Longue"
            }
        }
    }

    @Published private(set) var phase: Phase = .setting
    @Published var selectedMinutes: Int = 50
    @Published private(set) var remainingSeconds: Int = 50 * 60
    @Published var isTickHapticsEnabled: Bool = true
    @Published private(set) var currentSegment: SegmentType = .work
    @Published private(set) var isPaused: Bool = false

    @Published var isSoundEnabled: Bool = false
    @Published var selectedSoundscape: FocusSoundscape = .cyberRain
    @Published var secondarySoundscape: FocusSoundscape? = nil
    @Published var primaryVolume: Float = 0.25
    @Published var secondaryVolume: Float = 0.15
    /// Trigger for the completion haptic sequence (consumed by the View).
    @Published private(set) var completionHapticTrigger: Int = 0
    /// Set by FocusView when the user leaves the app during strict mode.
    @Published var strictModeViolated: Bool = false

    // Tracks full rotations on the circular selector (0...4 for max 300 min).
    @Published private(set) var rotationCount: Int = 0

    // Sensory feedback triggers consumed by the View.
    @Published private(set) var selectionHapticTrigger: Int = 0
    @Published private(set) var secondTickHapticTrigger: Int = 0
    @Published private(set) var successHapticTrigger: Int = 0

    // Persistence events consumed by views/app state.
    @Published private(set) var sessionCompletionTrigger: Int = 0
    @Published private(set) var lastCompletedSessionMinutes: Int = 0
    @Published private(set) var earnedFocusMinutes: Int = 0
    @Published private(set) var earnedFocusTrigger: Int = 0
    @Published private(set) var liveActivityLastError: String?
    @Published private(set) var audioLastError: String?

    private var completedWorkSessions: Int = 0
    private let shortBreakMinutes = 5
    private let longBreakMinutes = 15

    #if canImport(ActivityKit) && os(iOS)
    @Published var currentActivity: Activity<FocusFlowAttributes>? = nil
    private var liveActivityStartTask: Task<Void, Never>?
    private var isStartingLiveActivity = false

    #endif

    private var timerCancellable: AnyCancellable?
    private var previousRotationAngle: Double?
    /// Tracks all fire-and-forget Tasks so they can be cancelled on reset/deinit.
    private var activeTasks: [Task<Void, Never>] = []
    private lazy var audioEngine = FocusAudioEngine(errorHandler: { [weak self] message in
        self?.audioLastError = message
    })
    private var segmentTargetDate: Date?

    /// Spawns a tracked Task that is automatically cancelled on reset/deinit.
    /// Inherits MainActor isolation from the class.
    @discardableResult
    private func spawnTask(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let task = Task { @MainActor [weak self] in
            await operation()
            self?.activeTasks.removeAll { $0.isCancelled }
        }
        activeTasks.append(task)
        return task
    }

    /// Cancels all tracked tasks.
    private func cancelAllTasks() {
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()
    }

    var totalSeconds: Int {
        segmentTotalSeconds
    }

    private var segmentTotalSeconds: Int = 50 * 60

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    var timeDisplay: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var isRunningActive: Bool {
        phase == .running && !isPaused
    }

    func setMinutesFromDrag(_ minutes: Int) {
        guard phase == .setting else { return }

        let clamped = min(max(minutes, 1), 300)
        guard clamped != selectedMinutes else { return }

        selectedMinutes = clamped
        if currentSegment == .work {
            remainingSeconds = clamped * 60
            segmentTotalSeconds = clamped * 60
            segmentTargetDate = nil
        }
        rotationCount = min(max((clamped - 1) / 60, 0), 4)
        selectionHapticTrigger += 1
    }

    func updateMinutesFromRotation(angle: Double) {
        guard phase == .setting else { return }

        if previousRotationAngle == nil {
            previousRotationAngle = angle
        } else if let previousRotationAngle {
            let delta = angle - previousRotationAngle

            if delta < -.pi {
                rotationCount += 1
            }
            if delta > .pi {
                rotationCount -= 1
            }

            rotationCount = min(max(rotationCount, 0), 4)
            self.previousRotationAngle = angle
        }

        let minuteInCurrentTurn = minuteFromAngle(angle)
        let proposed = (rotationCount * 60) + minuteInCurrentTurn
        let clamped = min(max(proposed, 1), 300)

        setMinutesFromDrag(clamped)
    }

    func endRotationGesture() {
        previousRotationAngle = nil
    }

    func start() {
        if phase == .running {
            if isPaused {
                togglePauseResume()
            }
            return
        }

        completedWorkSessions = 0
        beginSegment(.work, durationMinutes: selectedMinutes)
    }

    func reset() {
        stopTimer()
        cancelAllTasks()
        spawnTask { [weak self] in await self?.stopSoundIfNeeded() }
        isPaused = false
        phase = .setting
        currentSegment = .work
        remainingSeconds = selectedMinutes * 60
        segmentTotalSeconds = selectedMinutes * 60
        segmentTargetDate = nil
        rotationCount = min(max((selectedMinutes - 1) / 60, 0), 4)

        #if canImport(ActivityKit) && os(iOS)
        liveActivityStartTask?.cancel()
        liveActivityStartTask = nil
        spawnTask { [weak self] in
            await self?.endLiveActivity()
        }
        #endif
    }

    func togglePauseResume() {
        guard phase == .running else { return }
        if isPaused {
            isPaused = false
            segmentTargetDate = Date().addingTimeInterval(TimeInterval(max(remainingSeconds, 0)))
            spawnTask { [weak self] in await self?.startSoundIfNeeded() }
        } else {
            isPaused = true
            syncRemainingSecondsFromTargetDate()
            segmentTargetDate = nil
            spawnTask { [weak self] in await self?.stopSoundIfNeeded() }
        }

        #if canImport(ActivityKit) && os(iOS)
        spawnTask { [weak self] in
            await self?.refreshLiveActivityState()
        }
        #endif
    }

    func toggleSound() {
        isSoundEnabled.toggle()
        if isSoundEnabled {
            spawnTask { [weak self] in await self?.startSoundIfNeeded() }
        } else {
            spawnTask { [weak self] in await self?.stopSoundIfNeeded() }
        }
    }

    func setSoundscape(_ soundscape: FocusSoundscape) {
        selectedSoundscape = soundscape
        if isSoundEnabled && isRunningActive {
            spawnTask { [weak self] in
                guard let self else { return }
                await self.audioEngine.transition(to: soundscape)
            }
        }
    }

    func setSecondarySoundscape(_ soundscape: FocusSoundscape?) {
        secondarySoundscape = soundscape
        if isSoundEnabled && isRunningActive {
            spawnTask { [weak self] in
                guard let self else { return }
                await self.audioEngine.setSecondaryLayer(soundscape)
            }
        }
    }

    func updatePrimaryVolume(_ volume: Float) {
        primaryVolume = volume
        spawnTask { [weak self] in
            guard let self else { return }
            await self.audioEngine.setPrimaryVolume(volume)
        }
    }

    func updateSecondaryVolume(_ volume: Float) {
        secondaryVolume = volume
        spawnTask { [weak self] in
            guard let self else { return }
            await self.audioEngine.setSecondaryVolume(volume)
        }
    }

    func prepareAudio() {
        spawnTask { [weak self] in await self?.audioEngine.preloadAll() }
    }

    func refreshRemainingFromTargetDate() {
        syncRemainingSecondsFromTargetDate()
    }

    #if canImport(ActivityKit) && os(iOS)
    /// Starts or refreshes Live Activity with current segment metadata.
    func startLiveActivity(minutes: Int) {
        let clamped = min(max(minutes, 1), 300)

        if currentActivity != nil {
            spawnTask { [weak self] in await self?.refreshLiveActivityState() }
            return
        }

        guard !isStartingLiveActivity else { return }
        isStartingLiveActivity = true

        spawnTask { [weak self] in
            defer { self?.isStartingLiveActivity = false }
            guard let self else { return }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                liveActivityLastError = "ActivityKit disabled by system settings."
                return
            }

            guard currentActivity == nil else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            guard currentActivity == nil else { return }
            let configuredSeconds = clamped * 60
            let initialRemaining = phase == .running ? remainingSeconds : configuredSeconds
            let initialTotal = phase == .running ? segmentTotalSeconds : configuredSeconds
            let state = makeLiveState(
                remaining: initialRemaining,
                total: initialTotal,
                targetDate: liveTargetDate()
            )
            do {
                currentActivity = try Activity<FocusFlowAttributes>.request(
                    attributes: FocusFlowAttributes(sessionID: UUID()),
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
                liveActivityLastError = nil
            } catch {
                currentActivity = nil
                liveActivityLastError = "Activity request failed: \(error.localizedDescription)"
            }
        }
    }
    #endif

    private func beginSegment(_ segment: SegmentType, durationMinutes: Int) {
        currentSegment = segment
        segmentTotalSeconds = max(1, durationMinutes * 60)
        segmentTargetDate = Date().addingTimeInterval(TimeInterval(segmentTotalSeconds))
        remainingSeconds = segmentTotalSeconds
        isPaused = false
        phase = .running

        startTimer()
        spawnTask { [weak self] in await self?.startSoundIfNeeded() }

        #if canImport(ActivityKit) && os(iOS)
        liveActivityStartTask?.cancel()
        if currentActivity == nil {
            liveActivityStartTask = spawnTask { [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                guard let self, phase == .running else { return }
                startLiveActivity(minutes: durationMinutes)
                liveActivityStartTask = nil
            }
        } else {
            spawnTask { [weak self] in
                await self?.refreshLiveActivityState()
            }
        }
        #endif
    }

    private func startTimer() {
        stopTimer()

        timerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.handleTick()
            }
        handleTick()
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func handleTick() {
        guard phase == .running else { return }

        if isPaused {
            return
        }

        let previousRemaining = remainingSeconds
        syncRemainingSecondsFromTargetDate()

        if remainingSeconds < previousRemaining, isTickHapticsEnabled {
            secondTickHapticTrigger += 1
        }

        if remainingSeconds == 0 {
            finishCurrentSegment()
        }
    }

    private func finishCurrentSegment() {
        if currentSegment == .work {
            completedWorkSessions += 1

            let earned = max(1, segmentTotalSeconds / 60)
            earnedFocusMinutes = earned
            earnedFocusTrigger += 1
            sessionCompletionTrigger += 1
            lastCompletedSessionMinutes = earned

            // Fire the completion haptic sequence trigger.
            completionHapticTrigger += 1

            if completedWorkSessions % 4 == 0 {
                beginSegment(.longBreak, durationMinutes: longBreakMinutes)
            } else {
                beginSegment(.shortBreak, durationMinutes: shortBreakMinutes)
            }
            return
        }

        // Any break completion sends user back to a work session.
        beginSegment(.work, durationMinutes: selectedMinutes)
    }

    private func startSoundIfNeeded() async {
        guard isSoundEnabled, isRunningActive else { return }
        await audioEngine.setPrimaryVolume(primaryVolume)
        await audioEngine.play(soundscape: selectedSoundscape)
        if let secondary = secondarySoundscape {
            await audioEngine.setSecondaryVolume(secondaryVolume)
            await audioEngine.setSecondaryLayer(secondary)
        }
    }

    private func stopSoundIfNeeded() async {
        await audioEngine.stop()
    }

    private func minuteFromAngle(_ angle: Double) -> Int {
        let normalized = max(0, min(1, angle / (2 * .pi)))
        let minute = Int(round(normalized * 60))
        return min(max(minute, 1), 60)
    }

    #if canImport(ActivityKit) && os(iOS)
    private func makeLiveState(remaining: Int, total: Int, targetDate: Date) -> FocusFlowAttributes.ContentState {
        FocusFlowAttributes.ContentState(
            targetDate: targetDate,
            phaseLabel: currentSegment.label,
            isPaused: isPaused,
            remainingSeconds: max(remaining, 0),
            totalSeconds: max(total, 1)
        )
    }

    private func refreshLiveActivityState() async {
        guard let currentActivity else { return }

        guard isActivityValid(currentActivity) else {
            self.currentActivity = nil
            return
        }

        let state = makeLiveState(
            remaining: remainingSeconds,
            total: segmentTotalSeconds,
            targetDate: liveTargetDate()
        )
        await currentActivity.update(ActivityContent(state: state, staleDate: nil))
    }

    private func isActivityValid(_ activity: Activity<FocusFlowAttributes>) -> Bool {
        let exists = Activity<FocusFlowAttributes>.activities.contains { $0.id == activity.id }
        guard exists else { return false }
        return activity.activityState == .active
    }

    private func endLiveActivity() async {
        guard let currentActivity else { return }

        guard isActivityValid(currentActivity) else {
            self.currentActivity = nil
            return
        }

        let finalState = makeLiveState(
            remaining: 0,
            total: max(segmentTotalSeconds, 1),
            targetDate: Date()
        )
        await currentActivity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        self.currentActivity = nil
    }

    private func liveTargetDate() -> Date {
        if isPaused {
            return Date().addingTimeInterval(TimeInterval(max(remainingSeconds, 0)))
        }
        return segmentTargetDate ?? Date().addingTimeInterval(TimeInterval(max(remainingSeconds, 0)))
    }
    #endif

    private func syncRemainingSecondsFromTargetDate() {
        guard let segmentTargetDate else {
            return
        }
        remainingSeconds = max(Int(ceil(segmentTargetDate.timeIntervalSinceNow)), 0)
    }

    deinit {
        timerCancellable?.cancel()
        activeTasks.forEach { $0.cancel() }
    }
}
