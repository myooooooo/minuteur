import SwiftUI

#if canImport(ActivityKit) && canImport(WidgetKit) && canImport(AppIntents) && os(iOS)
import ActivityKit
import WidgetKit
import AppIntents

struct TogglePauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause/Reprise"

    @MainActor
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

    @MainActor
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
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Go")
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("Focus")
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text("Session en cours")
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(.cyan)
            } compactTrailing: {
                Text("50m")
                    .foregroundColor(.cyan)
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
