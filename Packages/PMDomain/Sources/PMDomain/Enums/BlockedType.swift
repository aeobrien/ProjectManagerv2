import Foundation

/// The reason a task is blocked.
public enum BlockedType: String, Codable, Sendable, CaseIterable {
    case poorlyDefined
    case tooLarge
    case missingInfo
    case missingResource
    case decisionRequired
}
