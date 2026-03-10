import SwiftUI
import Combine

/// Représente les 3 onglets principaux de l'application.
enum AppTab: String, CaseIterable {
    case focus
    case stats
    case settings
}

// MARK: - Session Log

/// A single completed focus session record persisted as JSON via @AppStorage.
struct FocusSessionRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let durationMinutes: Int
    let earnedXP: Int
    /// Hour of day (0-23) when the session was completed.
    let completionHour: Int

    init(durationMinutes: Int, earnedXP: Int) {
        self.id = UUID()
        self.date = Date()
        self.durationMinutes = durationMinutes
        self.earnedXP = earnedXP
        self.completionHour = Calendar.current.component(.hour, from: Date())
    }
}

// MARK: - Badges

enum FocusBadge: String, CaseIterable, Identifiable {
    case firstHour       // Cumulate 60+ min total
    case streak7         // 7-day streak
    case streak30        // 30-day streak
    case nightOwl        // Complete a session between 00:00-05:00
    case marathoner      // Single session >= 120 min
    case centurion       // 100 sessions completed
    case level10         // Reach level 10

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstHour:  return "Première Heure"
        case .streak7:    return "Série de 7 Jours"
        case .streak30:   return "Série de 30 Jours"
        case .nightOwl:   return "Maître du Minuit"
        case .marathoner: return "Marathonien"
        case .centurion:  return "Centurion"
        case .level10:    return "Élite Niveau 10"
        }
    }

    var symbol: String {
        switch self {
        case .firstHour:  return "clock.badge.checkmark"
        case .streak7:    return "flame"
        case .streak30:   return "flame.fill"
        case .nightOwl:   return "moon.stars.fill"
        case .marathoner: return "figure.run"
        case .centurion:  return "shield.checkered"
        case .level10:    return "crown.fill"
        }
    }

    var requirement: String {
        switch self {
        case .firstHour:  return "Cumuler 60 min de focus"
        case .streak7:    return "7 jours consécutifs"
        case .streak30:   return "30 jours consécutifs"
        case .nightOwl:   return "Session entre minuit et 5h"
        case .marathoner: return "Session unique de 2h+"
        case .centurion:  return "100 sessions complétées"
        case .level10:    return "Atteindre le niveau 10"
        }
    }
}

// MARK: - Daily Challenge

struct DailyChallenge: Codable {
    let dayStamp: String
    let type: ChallengeType
    let targetCount: Int
    let targetMinutes: Int
    let bonusXP: Int
    var currentProgress: Int

    var isCompleted: Bool { currentProgress >= targetCount }

    var description: String {
        switch type {
        case .sessionCount:
            return "Complète \(targetCount) session\(targetCount > 1 ? "s" : "") de \(targetMinutes)+ min"
        case .totalMinutes:
            return "Accumule \(targetMinutes) min de focus aujourd'hui"
        }
    }

    enum ChallengeType: String, Codable {
        case sessionCount
        case totalMinutes
    }

    /// Deterministic daily challenge generation from date stamp.
    static func generate(for dayStamp: String) -> DailyChallenge {
        // Hash the day stamp for deterministic randomness.
        let hash = abs(dayStamp.hashValue)
        let variant = hash % 4

        switch variant {
        case 0:
            return DailyChallenge(dayStamp: dayStamp, type: .sessionCount, targetCount: 2, targetMinutes: 50, bonusXP: 30, currentProgress: 0)
        case 1:
            return DailyChallenge(dayStamp: dayStamp, type: .totalMinutes, targetCount: 120, targetMinutes: 120, bonusXP: 40, currentProgress: 0)
        case 2:
            return DailyChallenge(dayStamp: dayStamp, type: .sessionCount, targetCount: 3, targetMinutes: 25, bonusXP: 35, currentProgress: 0)
        default:
            return DailyChallenge(dayStamp: dayStamp, type: .totalMinutes, targetCount: 90, targetMinutes: 90, bonusXP: 25, currentProgress: 0)
        }
    }
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
    @AppStorage("focusflow.sessionLog") private var sessionLogStorage: String = "[]"
    @AppStorage("focusflow.unlockedBadges") private var unlockedBadgesStorage: String = "[]"
    @AppStorage("focusflow.totalSessions") private var totalSessionsStorage: Int = 0
    @AppStorage("focusflow.dailyChallenge") private var dailyChallengeStorage: String = ""
    @AppStorage("focusflow.purchasedThemes") private var purchasedThemesStorage: String = "[]"

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
    /// Last 10 completed sessions.
    @Published private(set) var sessionLog: [FocusSessionRecord] = []
    /// Earned badges.
    @Published private(set) var unlockedBadges: Set<FocusBadge> = []
    /// Total completed work sessions across all time.
    @Published private(set) var totalSessions: Int = 0
    /// Today's daily challenge.
    @Published private(set) var dailyChallenge: DailyChallenge?
    /// Newly earned badge for display.
    @Published var newlyEarnedBadge: FocusBadge?
    /// Daily challenge just completed trigger.
    @Published private(set) var challengeCompletedTrigger: Int = 0
    /// Themes the user has purchased from the shop.
    @Published private(set) var purchasedThemes: Set<NeonTheme> = []

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
        NeonTheme.allCases.filter { isThemeAccessible($0) }
    }

    /// A theme is accessible if it's free OR purchased via the shop.
    func isThemeAccessible(_ theme: NeonTheme) -> Bool {
        guard theme.requiredXP != nil else { return true }
        return purchasedThemes.contains(theme)
    }

    /// Whether the user can buy a theme: must have enough XP and the level requirement.
    func canPurchaseTheme(_ theme: NeonTheme) -> Bool {
        guard let cost = theme.requiredXP else { return false }
        guard !purchasedThemes.contains(theme) else { return false }
        return totalXP >= cost && level >= (theme.tier ?? 0) + 2
    }

    /// Purchase a theme spending XP.
    func purchaseTheme(_ theme: NeonTheme) {
        guard let cost = theme.requiredXP, canPurchaseTheme(theme) else { return }
        totalXP -= cost
        totalXPStorage = totalXP
        purchasedThemes.insert(theme)
        savePurchasedThemes()
    }

    /// XP required to reach the next level from the current level.
    var xpForNextLevel: Int { level * 300 }

    /// XP progress within the current level (0.0 to 1.0).
    var xpProgressInLevel: Double {
        let currentLevelBase = (level - 1) * 300
        let progressInLevel = totalXP - currentLevelBase
        return Double(progressInLevel) / 300.0
    }

    /// Hourly distribution: count of sessions completed per hour of the day.
    var hourlyDistribution: [Int: Int] {
        var distribution: [Int: Int] = [:]
        for record in sessionLog {
            distribution[record.completionHour, default: 0] += 1
        }
        return distribution
    }

    init() {
        hasCompletedOnboarding = onboardingStorage
        totalXP = totalXPStorage
        streak = streakStorage
        totalSessions = totalSessionsStorage

        let storedTheme = NeonTheme(rawValue: selectedNeonThemeStorage) ?? .cyan

        isVibrationsEnabled = isVibrationsEnabledStorage
        selectedSoundscape = FocusSoundscape(rawValue: selectedSoundscapeStorage) ?? .cyberRain
        isStrictFocusModeEnabled = isStrictFocusModeEnabledStorage

        // Decode persisted data.
        sessionLog = Self.decodeSessionLog(sessionLogStorage)
        unlockedBadges = Self.decodeBadges(unlockedBadgesStorage)
        purchasedThemes = Self.decodePurchasedThemes(purchasedThemesStorage)
        dailyChallenge = Self.decodeDailyChallenge(dailyChallengeStorage, today: Self.dayStamp(for: Date()))

        neonTheme = isThemeAccessible(storedTheme) ? storedTheme : .cyan
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
        guard isThemeAccessible(theme) else { return }
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

    func addXP(minutes: Int, wasStrictViolation: Bool = false) {
        guard minutes > 0 else { return }

        // Update streak based on date continuity.
        updateStreak()

        // Apply streak multiplier to earned XP.
        var multipliedXP = Int(ceil(Double(minutes) * streakMultiplier))

        // Strict mode penalty: reduce XP by 50% if user left the app.
        if wasStrictViolation {
            multipliedXP = max(1, multipliedXP / 2)
        }

        totalXP += multipliedXP
        totalXPStorage = totalXP

        // Log the session.
        totalSessions += 1
        totalSessionsStorage = totalSessions
        let record = FocusSessionRecord(durationMinutes: minutes, earnedXP: multipliedXP)
        appendSessionRecord(record)

        // Update daily challenge progress.
        updateDailyChallengeProgress(sessionMinutes: minutes)

        // Check for new badges.
        checkBadges(latestSession: record)

        // If current theme no longer accessible, fallback.
        if !isThemeAccessible(neonTheme) {
            neonTheme = .cyan
            selectedNeonThemeStorage = NeonTheme.cyan.rawValue
        }
    }

    // MARK: - Streak

    /// Updates the streak counter: increments if today is the day after last focus,
    /// resets to 1 if more than one day has passed, stays unchanged if same day.
    private func updateStreak() {
        let todayStamp = Self.dayStamp(for: Date())
        let lastStamp = lastFocusDateStorage

        if lastStamp == todayStamp {
            return
        }

        if lastStamp == Self.dayStamp(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            streak += 1
        } else {
            streak = 1
        }

        streakStorage = streak
        lastFocusDateStorage = todayStamp
    }

    // MARK: - Session Log

    private func appendSessionRecord(_ record: FocusSessionRecord) {
        sessionLog.append(record)
        // Keep only the last 10 entries.
        if sessionLog.count > 10 {
            sessionLog = Array(sessionLog.suffix(10))
        }
        saveSessionLog()
    }

    private func saveSessionLog() {
        if let data = try? JSONEncoder().encode(sessionLog), let str = String(data: data, encoding: .utf8) {
            sessionLogStorage = str
        }
    }

    private static func decodeSessionLog(_ raw: String) -> [FocusSessionRecord] {
        guard let data = raw.data(using: .utf8),
              let records = try? JSONDecoder().decode([FocusSessionRecord].self, from: data) else {
            return []
        }
        return Array(records.suffix(10))
    }

    // MARK: - Badges

    private func checkBadges(latestSession: FocusSessionRecord) {
        let previousBadges = unlockedBadges

        if totalXP >= 60 { unlockedBadges.insert(.firstHour) }
        if streak >= 7 { unlockedBadges.insert(.streak7) }
        if streak >= 30 { unlockedBadges.insert(.streak30) }
        if latestSession.completionHour >= 0 && latestSession.completionHour < 5 {
            unlockedBadges.insert(.nightOwl)
        }
        if latestSession.durationMinutes >= 120 { unlockedBadges.insert(.marathoner) }
        if totalSessions >= 100 { unlockedBadges.insert(.centurion) }
        if level >= 10 { unlockedBadges.insert(.level10) }

        let newBadges = unlockedBadges.subtracting(previousBadges)
        if let badge = newBadges.first {
            newlyEarnedBadge = badge
        }

        saveBadges()
    }

    private func saveBadges() {
        let rawValues = unlockedBadges.map(\.rawValue)
        if let data = try? JSONEncoder().encode(rawValues), let str = String(data: data, encoding: .utf8) {
            unlockedBadgesStorage = str
        }
    }

    private static func decodeBadges(_ raw: String) -> Set<FocusBadge> {
        guard let data = raw.data(using: .utf8),
              let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(rawValues.compactMap { FocusBadge(rawValue: $0) })
    }

    // MARK: - Daily Challenge

    private func updateDailyChallengeProgress(sessionMinutes: Int) {
        let todayStamp = Self.dayStamp(for: Date())

        // Generate new challenge if needed.
        if dailyChallenge == nil || dailyChallenge?.dayStamp != todayStamp {
            dailyChallenge = DailyChallenge.generate(for: todayStamp)
        }

        guard var challenge = dailyChallenge, !challenge.isCompleted else { return }

        switch challenge.type {
        case .sessionCount:
            if sessionMinutes >= challenge.targetMinutes {
                challenge.currentProgress += 1
            }
        case .totalMinutes:
            challenge.currentProgress += sessionMinutes
        }

        dailyChallenge = challenge
        saveDailyChallenge()

        // Award bonus XP on completion.
        if challenge.isCompleted {
            totalXP += challenge.bonusXP
            totalXPStorage = totalXP
            challengeCompletedTrigger += 1
        }
    }

    private func saveDailyChallenge() {
        guard let challenge = dailyChallenge,
              let data = try? JSONEncoder().encode(challenge),
              let str = String(data: data, encoding: .utf8) else { return }
        dailyChallengeStorage = str
    }

    private static func decodeDailyChallenge(_ raw: String, today: String) -> DailyChallenge? {
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let challenge = try? JSONDecoder().decode(DailyChallenge.self, from: data) else {
            return DailyChallenge.generate(for: today)
        }
        // Reset if stale day.
        return challenge.dayStamp == today ? challenge : DailyChallenge.generate(for: today)
    }

    // MARK: - Theme Shop

    private func savePurchasedThemes() {
        let rawValues = purchasedThemes.map(\.rawValue)
        if let data = try? JSONEncoder().encode(rawValues), let str = String(data: data, encoding: .utf8) {
            purchasedThemesStorage = str
        }
    }

    private static func decodePurchasedThemes(_ raw: String) -> Set<NeonTheme> {
        guard let data = raw.data(using: .utf8),
              let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(rawValues.compactMap { NeonTheme(rawValue: $0) })
    }

    // MARK: - Utilities

    static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
