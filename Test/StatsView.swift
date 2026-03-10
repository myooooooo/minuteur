import SwiftUI
import Charts

struct FocusData: Identifiable {
    let id = UUID()
    let day: String
    let minutes: Double
}

// MARK: - Hourly energy distribution data point

private struct HourlyPoint: Identifiable {
    let id = UUID()
    let hour: Int
    let count: Int

    var label: String {
        String(format: "%02d:00", hour)
    }
}

struct StatsView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedDay: String?
    @State private var statsSection: StatsSection = .overview

    private enum StatsSection: String, CaseIterable {
        case overview = "Vue d'ensemble"
        case journal = "Journal"
        case badges = "Badges"
        case shop = "Boutique"
    }

    private let mockData: [FocusData] = [
        FocusData(day: "Lun", minutes: 55),
        FocusData(day: "Mar", minutes: 130),
        FocusData(day: "Mer", minutes: 70),
        FocusData(day: "Jeu", minutes: 95),
        FocusData(day: "Ven", minutes: 165),
        FocusData(day: "Sam", minutes: 120),
        FocusData(day: "Dim", minutes: 80)
    ]

    private var selectedData: FocusData? {
        guard let selectedDay else { return nil }
        return mockData.first { $0.day == selectedDay }
    }

    private var totalWeekMinutes: Double {
        mockData.reduce(0) { $0 + $1.minutes }
    }

    private var averageFocusMinutes: Double {
        guard !mockData.isEmpty else { return 0 }
        return totalWeekMinutes / Double(mockData.count)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // Level header
                    Text("Niveau \(appState.level) - \(appState.levelTitle)")
                        .font(.system(size: 22, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(.white)

                    xpProgressSection

                    // Daily Challenge
                    if let challenge = appState.dailyChallenge {
                        dailyChallengeCard(challenge)
                    }

                    // Section picker
                    Picker("Section", selection: $statsSection) {
                        ForEach(StatsSection.allCases, id: \.self) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .colorMultiply(.cyan)

                    switch statsSection {
                    case .overview:
                        overviewSection
                    case .journal:
                        journalSection
                    case .badges:
                        badgesSection
                    case .shop:
                        shopSection
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
    }

    // MARK: - XP Progress

    private var xpProgressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Progression XP")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            ProgressView(value: appState.xpProgressInLevel)
                .progressViewStyle(.linear)
                .tint(
                    LinearGradient(colors: [.cyan, .indigo], startPoint: .leading, endPoint: .trailing)
                )

            HStack {
                Text("\(appState.totalXP) XP")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("×\(String(format: "%.1f", appState.streakMultiplier)) streak")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan.opacity(0.8))
            }
        }
    }

    // MARK: - Daily Challenge

    private func dailyChallengeCard(_ challenge: DailyChallenge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.cyan)
                Text("DÉFI DU JOUR")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                Spacer()
                if challenge.isCompleted {
                    Text("TERMINÉ")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                }
            }

            Text(challenge.description)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            HStack {
                let progress: Double = {
                    switch challenge.type {
                    case .sessionCount:
                        return Double(challenge.currentProgress) / Double(max(challenge.targetCount, 1))
                    case .totalMinutes:
                        return Double(challenge.currentProgress) / Double(max(challenge.targetMinutes, 1))
                    }
                }()

                ProgressView(value: min(progress, 1.0))
                    .progressViewStyle(.linear)
                    .tint(.cyan)

                Text("+\(challenge.bonusXP) XP")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.7))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            challenge.isCompleted
                                ? LinearGradient(colors: [.green.opacity(0.6), .cyan.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.cyan.opacity(0.5), .indigo.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.2
                        )
                )
        )
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Weekly chart
            Chart {
                ForEach(mockData) { item in
                    BarMark(
                        x: .value("Jour", item.day),
                        y: .value("Minutes", item.minutes)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .indigo],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(5)

                    if selectedDay == item.day {
                        RuleMark(x: .value("Jour sélectionné", item.day))
                            .lineStyle(StrokeStyle(lineWidth: 0))
                            .annotation(position: .top) {
                                Text("\(Int(item.minutes)) min")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.white))
                            }
                    }
                }
            }
            .frame(height: 220)
            .chartXSelection(value: $selectedDay)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: mockData.map(\.day)) { value in
                    AxisValueLabel {
                        if let day = value.as(String.self) {
                            Text(day)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    AxisGridLine().foregroundStyle(.clear)
                    AxisTick().foregroundStyle(.clear)
                }
            }

            // Hourly energy distribution
            hourlyDistributionChart

            // Score cards
            HStack(spacing: 12) {
                scoreCard(title: "Total Semaine", value: formattedTotalHours(totalWeekMinutes))
                scoreCard(title: "Moyenne Focus", value: "\(Int(averageFocusMinutes)) min")
            }

            HStack(spacing: 12) {
                scoreCard(title: "Série", value: "\(appState.streak) jour\(appState.streak > 1 ? "s" : "")")
                scoreCard(title: "Sessions", value: "\(appState.totalSessions)")
            }

            if let selectedData {
                Text("Sélection: \(selectedData.day) • \(Int(selectedData.minutes)) min")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }

            unlockedThemesCard
        }
    }

    // MARK: - Hourly Distribution Chart

    private var hourlyDistributionChart: some View {
        let distribution = appState.hourlyDistribution
        let points = (6...23).map { HourlyPoint(hour: $0, count: distribution[$0] ?? 0) }
        let hasData = points.contains { $0.count > 0 }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Distribution d'Énergie")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            if hasData {
                Chart(points) { point in
                    BarMark(
                        x: .value("Heure", point.label),
                        y: .value("Sessions", point.count)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, .cyan], startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(3)
                }
                .frame(height: 120)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: 3)) { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }
            } else {
                Text("Aucune donnée — complète des sessions pour voir ta distribution.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(height: 60)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [.indigo.opacity(0.5), .cyan.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.2
                        )
                )
        )
    }

    // MARK: - Journal

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dernières Sessions")
                .font(.system(size: 16, weight: .ultraLight, design: .rounded))
                .foregroundStyle(.white)

            if appState.sessionLog.isEmpty {
                Text("Aucune session enregistrée.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.vertical, 20)
            } else {
                ForEach(appState.sessionLog.reversed()) { record in
                    sessionRow(record)
                }
            }
        }
    }

    private func sessionRow(_ record: FocusSessionRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.date, style: .date)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                Text("\(record.durationMinutes) min • \(String(format: "%02d:00", record.completionHour))")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Text("+\(record.earnedXP) XP")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(white: 0.15), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges de Maîtrise")
                .font(.system(size: 16, weight: .ultraLight, design: .rounded))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(FocusBadge.allCases) { badge in
                    badgeCard(badge)
                }
            }
        }
    }

    private func badgeCard(_ badge: FocusBadge) -> some View {
        let isUnlocked = appState.unlockedBadges.contains(badge)

        return VStack(spacing: 8) {
            Image(systemName: badge.symbol)
                .font(.system(size: 28))
                .foregroundStyle(isUnlocked ? .cyan : Color(white: 0.25))

            Text(badge.title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isUnlocked ? .white : Color(white: 0.35))
                .multilineTextAlignment(.center)

            Text(badge.requirement)
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(isUnlocked ? .white.opacity(0.6) : Color(white: 0.25))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: isUnlocked ? 0.06 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isUnlocked
                                ? LinearGradient(colors: [.cyan.opacity(0.6), .indigo.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color(white: 0.15)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                )
        )
        .opacity(isUnlocked ? 1.0 : 0.55)
    }

    // MARK: - Shop

    private var shopSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Boutique Néon")
                .font(.system(size: 16, weight: .ultraLight, design: .rounded))
                .foregroundStyle(.white)

            Text("Dépense ton XP pour débloquer des thèmes premium.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            ForEach(NeonTheme.allCases.filter { $0.requiredXP != nil }, id: \.rawValue) { theme in
                shopRow(theme)
            }
        }
    }

    private func shopRow(_ theme: NeonTheme) -> some View {
        let owned = appState.purchasedThemes.contains(theme)
        let canBuy = appState.canPurchaseTheme(theme)
        let cost = theme.requiredXP ?? 0

        return HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 36, height: 36)
                .shadow(color: theme.accentColor.opacity(owned ? 0.5 : 0.15), radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Niveau \((theme.tier ?? 0) + 2) requis • \(cost) XP")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            if owned {
                Text("ACQUIS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
            } else {
                Button {
                    appState.purchaseTheme(theme)
                } label: {
                    Text("ACHETER")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(canBuy ? .cyan : Color(white: 0.2))
                        )
                }
                .disabled(!canBuy)
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(white: 0.12), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Reusable Components

    private var unlockedThemesCard: some View {
        let names = appState.unlockedThemes.map(\.title).joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 6) {
            Text("Thèmes actifs")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Text(names)
                .font(.system(size: 16, weight: .ultraLight, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.8), .indigo.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: .cyan.opacity(0.2), radius: 4)
        )
    }

    private func scoreCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Text(value)
                .font(.system(size: 28, weight: .ultraLight, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.8), .indigo.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: .cyan.opacity(0.25), radius: 4)
        )
    }

    private func formattedTotalHours(_ totalMinutes: Double) -> String {
        let total = Int(totalMinutes)
        let hours = total / 60
        let minutes = total % 60
        return "\(hours)h \(minutes)m"
    }
}

#Preview {
    StatsView()
        .environmentObject(AppStateManager())
}
