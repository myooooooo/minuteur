import SwiftUI
import Combine

/// Représente les 3 onglets principaux de l'application.
enum AppTab: String, CaseIterable {
    case focus
    case stats
    case settings
}

enum FocusSoundscape: String, CaseIterable {
    case cyberRain
    case pureWhiteNoise
    case calmCafe

    var title: String {
        switch self {
        case .cyberRain: return "Pluie Cyberpunk"
        case .pureWhiteNoise: return "Bruit Blanc Pur"
        case .calmCafe: return "Café Calme"
        }
    }
}

enum NeonTheme: String, CaseIterable {
    case cyan
    case indigo
    case emerald
    case fireOrange
    case gold
    case violet
    case crimson

    var title: String {
        switch self {
        case .cyan: return "Cyan"
        case .indigo: return "Indigo"
        case .emerald: return "Vert Émeraude"
        case .fireOrange: return "Orange Feu"
        case .gold: return "Or"
        case .violet: return "Violet"
        case .crimson: return "Rouge"
        }
    }

    var colors: [Color] {
        switch self {
        case .cyan:
            return [.cyan, .indigo]
        case .indigo:
            return [.indigo, .blue]
        case .emerald:
            return [Color.green, Color.mint]
        case .fireOrange:
            return [Color.orange, Color.red]
        case .gold:
            return [Color.yellow, Color.orange]
        case .violet:
            return [Color.purple, Color.indigo]
        case .crimson:
            return [Color.red, Color.pink]
        }
    }

    var accentColor: Color {
        colors.first ?? .cyan
    }

    /// Tier index (0-based) for exponential XP threshold calculation.
    /// nil = always unlocked (free tiers).
    var tier: Int? {
        switch self {
        case .cyan, .indigo, .emerald, .fireOrange: return nil
        case .gold: return 0    // ~300 XP (5h)
        case .violet: return 1  // ~900 XP (15h)
        case .crimson: return 2 // ~2700 XP (45h)
        }
    }

    /// XP required to unlock, computed via exponential scaling: base * 3^tier.
    /// Returns nil for always-unlocked themes.
    var requiredXP: Int? {
        guard let tier else { return nil }
        return NeonTheme.xpThreshold(forTier: tier)
    }

    /// Exponential threshold: 300 * 3^tier → 300, 900, 2700, ...
    static func xpThreshold(forTier tier: Int) -> Int {
        let base = 300
        var result = base
        for _ in 0..<tier { result *= 3 }
        return result
    }

    func isUnlocked(totalXP: Int) -> Bool {
        guard let requiredXP else { return true }
        return totalXP >= requiredXP
    }
}

/// Centralise l'état global de l'application (onboarding + navigation + préférences).
@MainActor
final class AppStateManager: ObservableObject {
    @AppStorage("hasCompletedOnboarding") private var onboardingStorage: Bool = false
    @AppStorage("selectedNeonTheme") private var selectedNeonThemeStorage: String = NeonTheme.cyan.rawValue
    @AppStorage("isVibrationsEnabled") private var isVibrationsEnabledStorage: Bool = true
    @AppStorage("selectedSoundscape") private var selectedSoundscapeStorage: String = FocusSoundscape.cyberRain.rawValue
    @AppStorage("isStrictFocusModeEnabled") private var isStrictFocusModeEnabledStorage: Bool = false
    @AppStorage("focusflow.totalXP") private var totalXPStorage: Int = 0
    @AppStorage("focusflow.streak") private var streakStorage: Int = 0
    @AppStorage("focusflow.lastFocusDate") private var lastFocusDateStorage: String = ""

    @Published var hasCompletedOnboarding: Bool = false
    @Published var selectedTab: AppTab = .focus
    @Published var neonTheme: NeonTheme = .cyan
    @Published var isVibrationsEnabled: Bool = true
    @Published var selectedSoundscape: FocusSoundscape = .cyberRain
    @Published var isStrictFocusModeEnabled: Bool = false
    @Published var totalXP: Int = 0
    @Published var newlyUnlockedTheme: NeonTheme?
    /// Consecutive days with at least one completed focus session.
    @Published private(set) var streak: Int = 0

    var level: Int {
        max(1, (totalXP / 300) + 1)
    }

    var totalFocusHours: Int {
        totalXP / 60
    }

    /// XP multiplier based on streak: 1.0x base + 0.1x per streak day, capped at 2.0x.
    var streakMultiplier: Double {
        min(2.0, 1.0 + Double(streak) * 0.1)
    }

    var levelTitle: String {
        switch level {
        case 1...2: return "Apprenti du Focus"
        case 3...5: return "Architecte du Flux"
        case 6...9: return "Maître du Deep Work"
        default: return "Légende du Flux"
        }
    }

    var unlockedThemes: [NeonTheme] {
        NeonTheme.allCases.filter { $0.isUnlocked(totalXP: totalXP) }
    }

    /// XP required to reach the next level from the current level.
    var xpForNextLevel: Int { level * 300 }

    /// XP progress within the current level (0.0 to 1.0).
    var xpProgressInLevel: Double {
        let currentLevelBase = (level - 1) * 300
        let progressInLevel = totalXP - currentLevelBase
        return Double(progressInLevel) / 300.0
    }

    init() {
        hasCompletedOnboarding = onboardingStorage
        totalXP = totalXPStorage
        streak = streakStorage

        let storedTheme = NeonTheme(rawValue: selectedNeonThemeStorage) ?? .cyan
        neonTheme = storedTheme.isUnlocked(totalXP: totalXP) ? storedTheme : .cyan

        isVibrationsEnabled = isVibrationsEnabledStorage
        selectedSoundscape = FocusSoundscape(rawValue: selectedSoundscapeStorage) ?? .cyberRain
        isStrictFocusModeEnabled = isStrictFocusModeEnabledStorage
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        onboardingStorage = true
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        onboardingStorage = false
    }

    func updateNeonTheme(_ theme: NeonTheme) {
        guard theme.isUnlocked(totalXP: totalXP) else { return }
        neonTheme = theme
        selectedNeonThemeStorage = theme.rawValue
    }

    func updateVibrations(_ isEnabled: Bool) {
        isVibrationsEnabled = isEnabled
        isVibrationsEnabledStorage = isEnabled
    }

    func updateSoundscape(_ soundscape: FocusSoundscape) {
        selectedSoundscape = soundscape
        selectedSoundscapeStorage = soundscape.rawValue
    }

    func updateStrictFocusMode(_ isEnabled: Bool) {
        isStrictFocusModeEnabled = isEnabled
        isStrictFocusModeEnabledStorage = isEnabled
    }

    func addXP(minutes: Int) {
        guard minutes > 0 else { return }

        // Update streak based on date continuity.
        updateStreak()

        // Apply streak multiplier to earned XP.
        let multipliedXP = Int(ceil(Double(minutes) * streakMultiplier))

        let previouslyUnlocked = Set(unlockedThemes)
        totalXP += multipliedXP
        totalXPStorage = totalXP

        let nowUnlocked = Set(unlockedThemes)
        let newThemes = nowUnlocked.subtracting(previouslyUnlocked)
        newlyUnlockedTheme = newThemes.sorted { ($0.requiredXP ?? 0) < ($1.requiredXP ?? 0) }.last

        // If current selected theme becomes invalid after migration edge cases, fallback.
        if !neonTheme.isUnlocked(totalXP: totalXP) {
            neonTheme = .cyan
            selectedNeonThemeStorage = NeonTheme.cyan.rawValue
        }
    }

    /// Updates the streak counter: increments if today is the day after last focus,
    /// resets to 1 if more than one day has passed, stays unchanged if same day.
    private func updateStreak() {
        let todayStamp = Self.dayStamp(for: Date())
        let lastStamp = lastFocusDateStorage

        if lastStamp == todayStamp {
            // Already counted today — no change.
            return
        }

        if lastStamp == Self.dayStamp(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            // Consecutive day — increment streak.
            streak += 1
        } else {
            // Gap detected — reset streak.
            streak = 1
        }

        streakStorage = streak
        lastFocusDateStorage = todayStamp
    }

    private static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
