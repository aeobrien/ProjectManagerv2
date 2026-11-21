import Foundation

/// Sub-mode within Execution Support sessions.
public enum SessionSubMode: String, Codable, Sendable, CaseIterable {
    case checkIn
    case returnBriefing
    case projectReview
    case retrospective

    /// Human-readable display name for UI.
    public var displayName: String {
        switch self {
        case .checkIn: "Check-in"
        case .returnBriefing: "Return Briefing"
        case .projectReview: "Project Review"
        case .retrospective: "Retrospective"
        }
    }
}
