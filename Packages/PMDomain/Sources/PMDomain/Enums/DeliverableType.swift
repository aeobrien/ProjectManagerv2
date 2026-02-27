import Foundation

/// The type of a typed deliverable from the deliverable catalogue.
public enum DeliverableType: String, Codable, Sendable, CaseIterable {
    case visionStatement
    case technicalBrief
    case setupSpecification
    case researchPlan
    case creativeBrief
}
