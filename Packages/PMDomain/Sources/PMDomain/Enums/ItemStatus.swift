import Foundation

/// The status of a milestone or task.
public enum ItemStatus: String, Codable, Sendable, CaseIterable {
    case notStarted
    case inProgress
    case blocked
    case waiting
    case completed
}
