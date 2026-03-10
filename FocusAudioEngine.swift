import Foundation
import AVFoundation

/// Dual-layer audio engine with independent volume controls per channel.
/// Supports layering two soundscapes simultaneously (e.g. Cyber Rain + Calm Café).
actor FocusAudioEngine {
    // MARK: - Layer State

    /// Each channel holds its own player, soundscape reference, and volume target.
    private struct AudioLayer {
        var player: AVAudioPlayer?
        var soundscape: FocusSoundscape?
        var volume: Float = 0.25
    }

    private enum LayerID {
        case primary
        case secondary
    }

    private var primaryLayer = AudioLayer()
    private var secondaryLayer = AudioLayer()
    private var cachedPlayers: [FocusSoundscape: AVAudioPlayer] = [:]
    private var fadeGeneration: Int = 0
    private var isSessionConfigured = false
    private var wasPlayingBeforeInterruption = false

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

    // MARK: - Layer Accessors

    private func layer(_ id: LayerID) -> AudioLayer {
        switch id {
        case .primary: return primaryLayer
        case .secondary: return secondaryLayer
        }
    }

    private func setLayer(_ id: LayerID, _ value: AudioLayer) {
        switch id {
        case .primary: primaryLayer = value
        case .secondary: secondaryLayer = value
        }
    }

    // MARK: - Public API

    func preloadAll() async {
        for soundscape in FocusSoundscape.allCases {
            _ = playerFor(soundscape)
        }
    }

    /// Play a soundscape on the primary layer.
    func play(soundscape: FocusSoundscape) async {
        await configureSessionIfNeeded()
        await transitionLayer(.primary, to: soundscape)
    }

    /// Stop all layers.
    func stop() async {
        await fadeOutLayer(.primary)
        await fadeOutLayer(.secondary)
    }

    /// Transition the primary layer to a new soundscape.
    func transition(to soundscape: FocusSoundscape) async {
        await configureSessionIfNeeded()
        await transitionLayer(.primary, to: soundscape)
    }

    // MARK: - Dual-Layer Mixer API

    /// Set secondary soundscape for layered mixing (nil to disable).
    func setSecondaryLayer(_ soundscape: FocusSoundscape?) async {
        await configureSessionIfNeeded()
        if let soundscape {
            await transitionLayer(.secondary, to: soundscape)
        } else {
            await fadeOutLayer(.secondary)
        }
    }

    /// Adjust the primary layer volume (0.0 → 1.0).
    func setPrimaryVolume(_ volume: Float) {
        primaryLayer.volume = max(0, min(1, volume))
        primaryLayer.player?.volume = primaryLayer.volume
    }

    /// Adjust the secondary layer volume (0.0 → 1.0).
    func setSecondaryVolume(_ volume: Float) {
        secondaryLayer.volume = max(0, min(1, volume))
        secondaryLayer.player?.volume = secondaryLayer.volume
    }

    // MARK: - Layer Operations

    private func transitionLayer(_ id: LayerID, to soundscape: FocusSoundscape) async {
        let current = layer(id)
        if current.soundscape == soundscape, current.player?.isPlaying == true {
            await fadePlayer(current.player, to: current.volume, duration: fadeDuration)
            return
        }

        await fadeOutLayer(id)
        let player = playerFor(soundscape)
        player?.volume = 0
        player?.play()

        var updated = layer(id)
        updated.soundscape = soundscape
        updated.player = player
        setLayer(id, updated)

        await fadePlayer(player, to: updated.volume, duration: fadeDuration)
    }

    private func fadeOutLayer(_ id: LayerID) async {
        let current = layer(id)
        await fadePlayer(current.player, to: 0, duration: fadeDuration)
        current.player?.stop()

        var cleared = layer(id)
        cleared.player = nil
        cleared.soundscape = nil
        setLayer(id, cleared)
    }

    // MARK: - Fade Engine

    private func fadePlayer(_ player: AVAudioPlayer?, to volume: Float, duration: TimeInterval) async {
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

    // MARK: - Player Cache

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

    // MARK: - Session Configuration

    private func configureSessionIfNeeded() async {
        guard !isSessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true, options: [])
            isSessionConfigured = true
        } catch {
            Task { await errorHandler("Audio session error: \(error.localizedDescription)") }
            isSessionConfigured = false
        }
    }

    // MARK: - Interruption Handling

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
            let primaryPlaying = primaryLayer.player?.isPlaying == true
            let secondaryPlaying = secondaryLayer.player?.isPlaying == true
            wasPlayingBeforeInterruption = primaryPlaying || secondaryPlaying
            primaryLayer.player?.pause()
            secondaryLayer.player?.pause()

        case .ended:
            guard wasPlayingBeforeInterruption else { return }
            wasPlayingBeforeInterruption = false

            let session = AVAudioSession.sharedInstance()
            try? session.setActive(true, options: [])

            // Resume both layers with fade-in.
            if primaryLayer.player != nil {
                primaryLayer.player?.volume = 0
                primaryLayer.player?.play()
                await fadePlayer(primaryLayer.player, to: primaryLayer.volume, duration: fadeDuration)
            }
            if secondaryLayer.player != nil {
                secondaryLayer.player?.volume = 0
                secondaryLayer.player?.play()
                await fadePlayer(secondaryLayer.player, to: secondaryLayer.volume, duration: fadeDuration)
            }

        @unknown default:
            break
        }
    }
}
