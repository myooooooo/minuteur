import SwiftUI
import Charts

struct FocusData: Identifiable {
    let id = UUID()
    let day: String
    let minutes: Double
}

struct StatsView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedDay: String?

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

    private var xpProgressInLevel: Double {
        let progress = appState.totalXP % 300
        return Double(progress) / 300.0
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Niveau \(appState.level) - \(appState.levelTitle)")
                    .font(.system(size: 22, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Progression XP")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))

                    ProgressView(value: xpProgressInLevel)
                        .progressViewStyle(.linear)
                        .tint(
                            LinearGradient(colors: [.cyan, .indigo], startPoint: .leading, endPoint: .trailing)
                        )

                    Text("\(appState.totalXP) XP")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }

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
                .frame(height: 260)
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

                HStack(spacing: 12) {
                    scoreCard(title: "Total Semaine", value: formattedTotalHours(totalWeekMinutes))
                    scoreCard(title: "Moyenne Focus", value: "\(Int(averageFocusMinutes)) min")
                }

                if let selectedData {
                    Text("Sélection: \(selectedData.day) • \(Int(selectedData.minutes)) min")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }

                unlockedThemesCard

                Spacer()
            }
            .padding()
        }
    }

    private var unlockedThemesCard: some View {
        let names = appState.unlockedThemes.map(\.title).joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 6) {
            Text("Thèmes débloqués")
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
