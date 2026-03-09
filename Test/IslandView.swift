import SwiftUI

#if canImport(ActivityKit) && canImport(WidgetKit) && canImport(AppIntents) && os(iOS)
import ActivityKit
import WidgetKit
import AppIntents

struct TogglePauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause/Reprise"

    func perform() async throws -> some IntentResult {
        for activity in Activity<FocusFlowAttributes>.activities {
            let wasPaused = activity.content.state.isPaused
            let remaining = wasPaused
                ? max(activity.content.state.remainingSeconds, 0)
                : max(Int(activity.content.state.targetDate.timeIntervalSinceNow), 0)

            let newState = FocusFlowAttributes.ContentState(
                targetDate: Date().addingTimeInterval(TimeInterval(remaining)),
                phaseLabel: activity.content.state.phaseLabel,
                isPaused: !wasPaused,
                remainingSeconds: remaining,
                totalSeconds: activity.content.state.totalSeconds
            )
            await activity.update(ActivityContent(state: newState, staleDate: nil))
        }
        return .result()
    }
}

struct StopFocusIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Arrêter le chrono"

    func perform() async throws -> some IntentResult {
        for activity in Activity<FocusFlowAttributes>.activities {
            let finalState = FocusFlowAttributes.ContentState(
                targetDate: Date(),
                phaseLabel: activity.content.state.phaseLabel,
                isPaused: true,
                remainingSeconds: 0,
                totalSeconds: max(activity.content.state.totalSeconds, 1)
            )
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        return .result()
    }
}

struct IslandView: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusFlowAttributes.self) { context in
            ZStack {
                Color.black

                VStack(spacing: 8) {
                    HStack {
                        Text(context.state.phaseLabel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                        Spacer()
                        trailingTimeText(for: context.state)
                    }

                    ProgressView(value: progressValue(for: context.state))
                        .progressViewStyle(.linear)
                        .tint(
                            LinearGradient(colors: [.cyan, .indigo], startPoint: .leading, endPoint: .trailing)
                        )
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "timer")
                            .foregroundColor(.cyan)
                        Text(context.state.phaseLabel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: 70, height: 72, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    trailingTimeText(for: context.state)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(width: 120, height: 72, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        ProgressView(value: progressValue(for: context.state))
                            .progressViewStyle(.linear)
                            .tint(
                                LinearGradient(colors: [.cyan, .indigo], startPoint: .leading, endPoint: .trailing)
                            )

                        HStack(spacing: 8) {
                            Button(intent: TogglePauseIntent()) {
                                Text(context.state.isPaused ? "Reprendre" : "Pause")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.black)
                                            .overlay(Capsule().stroke(Color.cyan, lineWidth: 1.5))
                                    )
                            }
                            .buttonStyle(.plain)

                            Button(intent: StopFocusIntent()) {
                                Text("Stop")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.black)
                                            .overlay(Capsule().stroke(Color.red, lineWidth: 1.5))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 72, maxHeight: 92, alignment: .top)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(.cyan)
                    .font(.title3)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.targetDate, countsDown: true)
                    .monospacedDigit()
                    .foregroundColor(.cyan)
                    .frame(width: 50)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(.cyan)
            }
        }
    }

    private func trailingTimeText(for state: FocusFlowAttributes.ContentState) -> Text {
        if state.isPaused {
            return Text(formatHM(state.remainingSeconds))
        }
        return Text(state.targetDate, style: .timer)
    }

    private func progressValue(for state: FocusFlowAttributes.ContentState) -> Double {
        guard state.totalSeconds > 0 else { return 0 }
        let remaining: Int
        if state.isPaused {
            remaining = state.remainingSeconds
        } else {
            remaining = max(Int(state.targetDate.timeIntervalSinceNow), 0)
        }
        return max(0, min(1, 1 - (Double(remaining) / Double(state.totalSeconds))))
    }

    private func formatHM(_ totalSeconds: Int) -> String {
        let minutes = max(0, totalSeconds) / 60
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}
#endif
