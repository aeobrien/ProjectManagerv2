import Foundation

/// The reason a task is blocked.
public enum BlockedType: String, Codable, Sendable, CaseIterable {
    case poorlyDefined
    case tooLarge
    case missingInfo
    case missingResource
    case decisionRequired

    public var displayName: String {
        switch self {
        case .poorlyDefined: "Poorly Defined"
        case .tooLarge: "Too Large"
        case .missingInfo: "Missing Info"
        case .missingResource: "Missing Resource"
        case .decisionRequired: "Decision Required"
        }
    }
}
