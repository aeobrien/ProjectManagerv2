import Foundation

/// Pure business logic for session lifecycle transitions.
public enum SessionStateMachine {

    /// Returns all valid target states reachable from the given status.
    public static func validTransitions(from status: SessionStatus) -> [SessionStatus] {
        switch status {
        case .active:
            return [.paused, .completed]
        case .paused:
            return [.active, .completed, .autoSummarised, .pendingAutoSummary]
        case .pendingAutoSummary:
            return [.autoSummarised]
        case .completed, .autoSummarised:
            return [] // terminal states
        }
    }

    /// Attempts a state transition. Returns the new status if valid, nil if not.
    public static func transition(from current: SessionStatus, to target: SessionStatus) -> SessionStatus? {
        guard validTransitions(from: current).contains(target) else { return nil }
        return target
    }

    /// Whether a session in this status occupies an active slot (counts toward the single-active-session limit).
    public static func occupiesActiveSlot(_ status: SessionStatus) -> Bool {
        switch status {
        case .active, .paused:
            return true
        case .completed, .autoSummarised, .pendingAutoSummary:
            return false
        }
    }

    /// Whether a session is eligible for auto-summarisation based on its status and inactivity.
    public static func isEligibleForAutoSummarisation(
        _ session: Session,
        now: Date = Date(),
        timeoutInterval: TimeInterval = 24 * 60 * 60
    ) -> Bool {
        guard session.status == .paused else { return false }
        return now.timeIntervalSince(session.lastActiveAt) >= timeoutInterval
    }
}
