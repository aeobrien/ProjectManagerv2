import Foundation

/// Priority level for milestones and tasks.
public enum Priority: String, Codable, Sendable, CaseIterable {
    case high
    case normal
    case low

    /// Sort value for ordering (lower = higher priority).
    public var sortValue: Int {
        switch self {
        case .high: return 0
        case .normal: return 1
        case .low: return 2
        }
    }
}
