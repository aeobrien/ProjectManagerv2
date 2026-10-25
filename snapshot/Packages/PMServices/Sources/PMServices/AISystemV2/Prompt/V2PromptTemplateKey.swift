import Foundation

/// Identifies a prompt template in the v2 AI system.
public enum V2PromptTemplateKey: String, CaseIterable, Sendable {
    // Layer 1
    case foundation

    // Layer 2 — Mode prompts
    case exploration
    case definition
    case planning
    case executionSupport

    // Layer 2 — Sub-mode variants
    case executionSupportCheckIn
    case executionSupportReturnBriefing
    case executionSupportProjectReview
    case executionSupportRetrospective

    // Summary generation
    case summaryGeneration

    /// Human-readable display name for the settings UI.
    public var displayName: String {
        switch self {
        case .foundation: "Foundation (Layer 1)"
        case .exploration: "Exploration Mode"
        case .definition: "Definition Mode"
        case .planning: "Planning Mode"
        case .executionSupport: "Execution Support Mode"
        case .executionSupportCheckIn: "Execution Support: Check-in"
        case .executionSupportReturnBriefing: "Execution Support: Return Briefing"
        case .executionSupportProjectReview: "Execution Support: Project Review"
        case .executionSupportRetrospective: "Execution Support: Retrospective"
        case .summaryGeneration: "Summary Generation"
        }
    }

    /// Grouping for the settings UI.
    public var group: String {
        switch self {
        case .foundation: "Core"
        case .exploration, .definition, .planning: "Modes"
        case .executionSupport, .executionSupportCheckIn, .executionSupportReturnBriefing,
             .executionSupportProjectReview, .executionSupportRetrospective: "Execution Support"
        case .summaryGeneration: "System"
        }
    }

    /// Description of available {{variables}} for this template.
    public var variableHelp: String? {
        switch self {
        case .definition:
            "{{deliverable_list}}, {{current_deliverable}}, {{deliverable_template_info_requirements}}, {{deliverable_template_structure}}"
        case .executionSupport, .executionSupportCheckIn, .executionSupportReturnBriefing,
             .executionSupportProjectReview, .executionSupportRetrospective:
            "{{sub_mode}}"
        case .exploration:
            "{{deliverable_catalogue}}"
        default:
            nil
        }
    }
}
