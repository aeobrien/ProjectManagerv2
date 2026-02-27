import Foundation
import PMDomain

/// Configuration for a conversation mode — defines what Layer 2 prompt to use,
/// which context components to include, whether actions are parsed, and what happens on completion.
public struct ModeConfiguration: Sendable {
    /// The session mode this configuration is for.
    public let mode: SessionMode
    /// Optional sub-mode.
    public let subMode: SessionSubMode?
    /// Whether ACTION blocks should be parsed from responses.
    public let parseActions: Bool
    /// Expected signals for this mode.
    public let expectedSignals: [String]
    /// Whether this mode produces artifacts (DOCUMENT_DRAFT or STRUCTURE_PROPOSAL).
    public let supportsArtifacts: Bool

    public init(
        mode: SessionMode,
        subMode: SessionSubMode? = nil,
        parseActions: Bool = false,
        expectedSignals: [String] = [],
        supportsArtifacts: Bool = false
    ) {
        self.mode = mode
        self.subMode = subMode
        self.parseActions = parseActions
        self.expectedSignals = expectedSignals
        self.supportsArtifacts = supportsArtifacts
    }
}

/// Registry of mode configurations for the v2 AI system.
public enum ModeConfigurationRegistry {

    /// Returns the configuration for a given mode and sub-mode.
    public static func configuration(for mode: SessionMode, subMode: SessionSubMode? = nil) -> ModeConfiguration {
        switch mode {
        case .exploration:
            return ModeConfiguration(
                mode: .exploration,
                parseActions: false,
                expectedSignals: ["MODE_COMPLETE", "PROCESS_RECOMMENDATION", "PLANNING_DEPTH", "PROJECT_SUMMARY"],
                supportsArtifacts: false
            )
        case .definition:
            return ModeConfiguration(
                mode: .definition,
                parseActions: false,
                expectedSignals: ["MODE_COMPLETE", "DELIVERABLES_PRODUCED", "DELIVERABLES_DEFERRED"],
                supportsArtifacts: true
            )
        case .planning:
            return ModeConfiguration(
                mode: .planning,
                parseActions: true,
                expectedSignals: ["MODE_COMPLETE", "STRUCTURE_SUMMARY", "FIRST_ACTION"],
                supportsArtifacts: true
            )
        case .executionSupport:
            return executionSupportConfig(subMode: subMode)
        }
    }

    private static func executionSupportConfig(subMode: SessionSubMode?) -> ModeConfiguration {
        switch subMode {
        case .checkIn:
            return ModeConfiguration(
                mode: .executionSupport,
                subMode: .checkIn,
                parseActions: true,
                expectedSignals: ["SESSION_END"],
                supportsArtifacts: false
            )
        case .returnBriefing:
            return ModeConfiguration(
                mode: .executionSupport,
                subMode: .returnBriefing,
                parseActions: false,
                expectedSignals: ["SESSION_END"],
                supportsArtifacts: false
            )
        case .projectReview:
            return ModeConfiguration(
                mode: .executionSupport,
                subMode: .projectReview,
                parseActions: true,
                expectedSignals: ["SESSION_END"],
                supportsArtifacts: false
            )
        case .retrospective:
            return ModeConfiguration(
                mode: .executionSupport,
                subMode: .retrospective,
                parseActions: false,
                expectedSignals: ["SESSION_END"],
                supportsArtifacts: false
            )
        case nil:
            return ModeConfiguration(
                mode: .executionSupport,
                parseActions: true,
                expectedSignals: ["SESSION_END"],
                supportsArtifacts: false
            )
        }
    }
}
