import Foundation

/// How a session was completed, recorded in its summary.
public enum SessionCompletionStatus: String, Codable, Sendable, CaseIterable {
    case completed
    case incompleteAutoSummarised
    case incompleteUserEnded
}
