import Foundation

/// The type of a typed deliverable from the deliverable catalogue.
public enum DeliverableType: String, Codable, Sendable, CaseIterable {
    case visionStatement
    case technicalBrief
    case setupSpecification
    case researchPlan
    case creativeBrief

    /// Human-readable display name (e.g. "Vision Statement").
    public var displayName: String {
        switch self {
        case .visionStatement: "Vision Statement"
        case .technicalBrief: "Technical Brief"
        case .setupSpecification: "Setup Specification"
        case .researchPlan: "Research Plan"
        case .creativeBrief: "Creative Brief"
        }
    }

    /// Fuzzy match from a signal type string that may be in any format:
    /// "visionStatement", "Vision Statement", "vision_statement", "vision statement", etc.
    public static func fromSignalType(_ raw: String) -> DeliverableType? {
        // Try exact rawValue first
        if let exact = DeliverableType(rawValue: raw) { return exact }

        // Normalise: lowercase, remove spaces/underscores/hyphens
        let normalised = raw.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")

        for type in DeliverableType.allCases {
            if type.rawValue.lowercased() == normalised {
                return type
            }
        }

        // Keyword fallback
        let lower = raw.lowercased()
        if lower.contains("vision") { return .visionStatement }
        if lower.contains("technical") || lower.contains("tech brief") { return .technicalBrief }
        if lower.contains("setup") { return .setupSpecification }
        if lower.contains("research") { return .researchPlan }
        if lower.contains("creative") { return .creativeBrief }

        return nil
    }
}
