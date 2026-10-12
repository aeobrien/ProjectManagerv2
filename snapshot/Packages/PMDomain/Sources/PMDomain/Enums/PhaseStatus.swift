import Foundation

/// The status of a project phase.
public enum PhaseStatus: String, Codable, Sendable, CaseIterable {
    case notStarted
    case inProgress
    case completed

    public var displayName: String {
        switch self {
        case .notStarted: "Not Started"
        case .inProgress: "In Progress"
        case .completed: "Completed"
        }
    }
}
