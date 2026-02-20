import Foundation

/// The type of entity that can participate in a dependency relationship.
public enum DependableType: String, Codable, Sendable, CaseIterable {
    case milestone
    case task
}
