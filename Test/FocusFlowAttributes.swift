import Foundation

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

struct FocusFlowAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var targetDate: Date
        var phaseLabel: String
        var isPaused: Bool
        var remainingSeconds: Int
        var totalSeconds: Int
    }

    var sessionID: UUID
}

extension FocusFlowAttributes {
    static var preview: FocusFlowAttributes {
        FocusFlowAttributes(sessionID: UUID())
    }
}

extension FocusFlowAttributes.ContentState {
    static var preview: FocusFlowAttributes.ContentState {
        FocusFlowAttributes.ContentState(
            targetDate: Date().addingTimeInterval(50 * 60),
            phaseLabel: "TRAVAIL",
            isPaused: false,
            remainingSeconds: 50 * 60,
            totalSeconds: 50 * 60
        )
    }
}
#endif
