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
#endif
