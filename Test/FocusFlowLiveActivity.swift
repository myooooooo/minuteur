import Foundation

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

enum FocusFlowLiveActivityError: Error {
    case activitiesDisabled
    case noActiveActivity
    case requestFailed(underlying: Error)
}

@MainActor
final class FocusFlowLiveActivityManager {
    static let shared = FocusFlowLiveActivityManager()

    private var activity: Activity<FocusFlowAttributes>?

    private init() {}

    /// Starts a Live Activity for the active focus session.
    func start(totalSeconds: Int, phaseLabel: String = "TRAVAIL") async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw FocusFlowLiveActivityError.activitiesDisabled
        }

        let clampedTotal = max(totalSeconds, 1)
        let state = FocusFlowAttributes.ContentState(
            targetDate: Date().addingTimeInterval(TimeInterval(clampedTotal)),
            phaseLabel: phaseLabel,
            isPaused: false,
            remainingSeconds: clampedTotal,
            totalSeconds: clampedTotal
        )

        do {
            activity = try Activity<FocusFlowAttributes>.request(
                attributes: FocusFlowAttributes(sessionID: UUID()),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            throw FocusFlowLiveActivityError.requestFailed(underlying: error)
        }
    }

    /// Updates remaining time so Lock Screen / Dynamic Island stay in sync.
    func update(
        remainingSeconds: Int,
        totalSeconds: Int,
        targetDate: Date,
        isPaused: Bool,
        phaseLabel: String = "TRAVAIL"
    ) async throws {
        guard let activity else {
            throw FocusFlowLiveActivityError.noActiveActivity
        }

        let state = FocusFlowAttributes.ContentState(
            targetDate: targetDate,
            phaseLabel: phaseLabel,
            isPaused: isPaused,
            remainingSeconds: max(remainingSeconds, 0),
            totalSeconds: max(totalSeconds, 1)
        )

        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    /// Ends current Live Activity.
    func end(phaseLabel: String = "TRAVAIL") async throws {
        guard let activity else {
            throw FocusFlowLiveActivityError.noActiveActivity
        }

        let finalState = FocusFlowAttributes.ContentState(
            targetDate: Date(),
            phaseLabel: phaseLabel,
            isPaused: true,
            remainingSeconds: 0,
            totalSeconds: 1
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        self.activity = nil
    }
}
#endif
