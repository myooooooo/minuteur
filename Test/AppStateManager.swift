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

    /// Nil means always unlocked.
    var requiredHours: Int? {
        switch self {
        case .gold: return 5
        case .violet: return 15
        case .crimson: return 30
        default: return nil
        }
    }

    func isUnlocked(totalXP: Int) -> Bool {
        guard let requiredHours else { return true }
        return (totalXP / 60) >= requiredHours
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

    @Published var hasCompletedOnboarding: Bool = false
    @Published var selectedTab: AppTab = .focus
    @Published var neonTheme: NeonTheme = .cyan
    @Published var isVibrationsEnabled: Bool = true
    @Published var selectedSoundscape: FocusSoundscape = .cyberRain
    @Published var isStrictFocusModeEnabled: Bool = false
    @Published var totalXP: Int = 0
    @Published var newlyUnlockedTheme: NeonTheme?

    var level: Int {
        max(1, (totalXP / 300) + 1)
    }

    var totalFocusHours: Int {
        totalXP / 60
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

    init() {
        hasCompletedOnboarding = onboardingStorage
        totalXP = totalXPStorage

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
        let previouslyUnlocked = Set(unlockedThemes)
        totalXP += minutes
        totalXPStorage = totalXP

        let nowUnlocked = Set(unlockedThemes)
        let newThemes = nowUnlocked.subtracting(previouslyUnlocked)
        newlyUnlockedTheme = newThemes.sorted { ($0.requiredHours ?? 0) < ($1.requiredHours ?? 0) }.last

        // If current selected theme becomes invalid after migration edge cases, fallback.
        if !neonTheme.isUnlocked(totalXP: totalXP) {
            neonTheme = .cyan
            selectedNeonThemeStorage = NeonTheme.cyan.rawValue
        }
    }
}
