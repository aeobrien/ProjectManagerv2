import Foundation

/// The primary mode of an AI session.
public enum SessionMode: String, Codable, Sendable, CaseIterable {
    case exploration
    case definition
    case planning
    case executionSupport

    /// Human-readable display name for UI.
    public var displayName: String {
        switch self {
        case .exploration: "Exploration"
        case .definition: "Definition"
        case .planning: "Planning"
        case .executionSupport: "Execution Support"
        }
    }
}
