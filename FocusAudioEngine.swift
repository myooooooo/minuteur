import Foundation
import AVFoundation

actor FocusAudioEngine {
    private var player: AVAudioPlayer?
    private var currentSoundscape: FocusSoundscape?
    private var cachedPlayers: [FocusSoundscape: AVAudioPlayer] = [:]
    private var fadeGeneration: Int = 0
    private var isSessionConfigured = false
    /// True when playback was active before an interruption (e.g. phone call).
    private var wasPlayingBeforeInterruption = false

    nonisolated private let targetVolume: Float = 0.25
    nonisolated private let fadeDuration: TimeInterval = 2.0

    private let errorHandler: @MainActor @Sendable (String) -> Void
    private var interruptionObserver: (any NSObjectProtocol)?

    init(errorHandler: @escaping @MainActor @Sendable (String) -> Void) {
        self.errorHandler = errorHandler
        Task { [weak self] in
            await self?.configureSessionIfNeeded()
            await self?.observeInterruptions()
        }
    }

    func preloadAll() async {
        for soundscape in FocusSoundscape.allCases {
            _ = playerFor(soundscape)
        }
    }

    func play(soundscape: FocusSoundscape) async {
        await configureSessionIfNeeded()
        await transition(to: soundscape)
    }

    func stop() async {
        await fadeOutAndStop()
    }

    func transition(to soundscape: FocusSoundscape) async {
        await configureSessionIfNeeded()
        if currentSoundscape == soundscape, player?.isPlaying == true {
            await fade(to: targetVolume, duration: fadeDuration)
            return
        }

        await fadeOutAndStop()
        currentSoundscape = soundscape
        player = playerFor(soundscape)
        player?.volume = 0
        player?.play()
        await fade(to: targetVolume, duration: fadeDuration)
    }

    private func fadeOutAndStop() async {
        await fade(to: 0, duration: fadeDuration)
        player?.stop()
        player = nil
        currentSoundscape = nil
    }

    private func fade(to volume: Float, duration: TimeInterval) async {
        fadeGeneration += 1
        let token = fadeGeneration
        guard let player else { return }
        let steps = 20
        let stepDuration = duration / Double(steps)
        let startVolume = player.volume
        for index in 1...steps {
            if token != fadeGeneration { return }
            let progress = Float(index) / Float(steps)
            player.volume = startVolume + (volume - startVolume) * progress
            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }
    }

    private func playerFor(_ soundscape: FocusSoundscape) -> AVAudioPlayer? {
        if let cached = cachedPlayers[soundscape] {
            return cached
        }
        guard let url = resourceURL(for: soundscape) else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            cachedPlayers[soundscape] = player
            return player
        } catch {
            Task { await errorHandler("Audio file error: \(error.localizedDescription)") }
            return nil
        }
    }

    private func resourceURL(for soundscape: FocusSoundscape) -> URL? {
        let candidates: [(name: String, ext: String)]

        switch soundscape {
        case .cyberRain:
            candidates = [("cyber_rain", "mp3"), ("cyber_rain", "m4a"), ("cyber_rain", "wav")]
        case .pureWhiteNoise:
            candidates = [("white_noise", "mp3"), ("white_noise", "m4a"), ("white_noise", "wav")]
        case .calmCafe:
            candidates = [("calm_cafe", "mp3"), ("calm_cafe", "m4a"), ("calm_cafe", "wav")]
        }

        for candidate in candidates {
            if let url = Bundle.main.url(forResource: candidate.name, withExtension: candidate.ext) {
                return url
            }
        }

        return nil
    }

    private func configureSessionIfNeeded() async {
        guard !isSessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: [])
            isSessionConfigured = true
        } catch {
            Task { await errorHandler("Audio session error: \(error.localizedDescription)") }
            isSessionConfigured = false
        }
    }

    /// Observes AVAudioSession interruptions (e.g. incoming call) and resumes
    /// playback with a fade-in when the interruption ends.
    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            Task { [weak self] in
                await self?.handleInterruption(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = player?.isPlaying == true
            player?.pause()

        case .ended:
            guard wasPlayingBeforeInterruption else { return }
            wasPlayingBeforeInterruption = false

            // Re-activate audio session after interruption.
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(true, options: [])

            // Resume with fade-in for a smooth transition.
            player?.volume = 0
            player?.play()
            await fade(to: targetVolume, duration: fadeDuration)

        @unknown default:
            break
        }
    }
}
