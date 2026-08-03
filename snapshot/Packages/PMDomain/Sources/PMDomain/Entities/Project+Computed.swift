import Foundation

extension Project {
    /// Whether the project hasn't been worked on recently.
    public func isStale(thresholdDays: Int = 14, now: Date = Date()) -> Bool {
        guard lifecycleState == .focused || lifecycleState == .queued else { return false }
        guard let lastWorked = lastWorkedOn else { return true }
        let days = Calendar.current.dateComponents([.day], from: lastWorked, to: now).day ?? 0
        return days >= thresholdDays
    }

    /// Days since last check-in for this project.
    public func daysSinceCheckIn(lastCheckInDate: Date?, now: Date = Date()) -> Int? {
        guard let lastCheckIn = lastCheckInDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastCheckIn, to: now).day
    }
}
