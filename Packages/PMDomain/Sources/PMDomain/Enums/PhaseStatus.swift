import Foundation

/// The status of a project phase.
public enum PhaseStatus: String, Codable, Sendable, CaseIterable {
    case notStarted
    case inProgress
    case completed
}
