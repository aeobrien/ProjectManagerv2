import Foundation

/// The lifecycle status of a session.
public enum SessionStatus: String, Codable, Sendable, CaseIterable {
    case active
    case paused
    case completed
    case completedPendingSummary
    case autoSummarised
    case pendingAutoSummary
}
