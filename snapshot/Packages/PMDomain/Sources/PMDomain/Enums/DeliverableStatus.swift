import Foundation

/// The status of a typed deliverable.
public enum DeliverableStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case inProgress
    case completed
    case revised
}
