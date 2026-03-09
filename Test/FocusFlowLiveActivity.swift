import Foundation

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

struct FocusFlowActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endDate: Date
        var remainingSeconds: Int
        var totalSeconds: Int
        var isPaused: Bool
    }

    var sessionID: UUID
}

@MainActor
final class FocusFlowLiveActivityManager {
    static let shared = FocusFlowLiveActivityManager()

    private var activity: Activity<FocusFlowActivityAttributes>?

    private init() {}

    /// Starts a Live Activity for the active focus session.
    func start(totalSeconds: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = FocusFlowActivityAttributes(sessionID: UUID())
        let state = FocusFlowActivityAttributes.ContentState(
            endDate: Date().addingTimeInterval(TimeInterval(totalSeconds)),
            remainingSeconds: totalSeconds,
            totalSeconds: totalSeconds,
            isPaused: false
        )

        do {
            activity = try Activity<FocusFlowActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Silent fallback: app continues without Live Activity.
        }
    }

    /// Updates remaining time so Lock Screen / Dynamic Island stay in sync.
    func update(remainingSeconds: Int, totalSeconds: Int, isPaused: Bool) async {
        guard let activity else { return }

        let state = FocusFlowActivityAttributes.ContentState(
            endDate: Date().addingTimeInterval(TimeInterval(remainingSeconds)),
            remainingSeconds: remainingSeconds,
            totalSeconds: totalSeconds,
            isPaused: isPaused
        )

        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    /// Ends current Live Activity.
    func end() async {
        guard let activity else { return }

        let finalState = FocusFlowActivityAttributes.ContentState(
            endDate: Date(),
            remainingSeconds: 0,
            totalSeconds: 0,
            isPaused: false
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        self.activity = nil
    }
}
#endif
