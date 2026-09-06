import Foundation

/// The type of a project document.
public enum DocumentType: String, Codable, Sendable, CaseIterable {
    case visionStatement
    case technicalBrief
    case other
}
