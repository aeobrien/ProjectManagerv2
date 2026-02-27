import Foundation
import PMDomain

/// Defines which context components to include for a given mode, with priority levels for token budget management.
public struct V2ContextConfiguration: Sendable {
    /// A single context component with its priority for token budget truncation.
    public struct Component: Sendable {
        public enum Kind: String, Sendable {
            case projectOverview
            case processProfile
            case documents
            case sessionSummaries
            case projectStructure
            case frequentlyDeferred
            case estimateCalibration
            case patternsAndObservations
            case activeSessionContext
            case portfolioSummary
        }

        public let kind: Kind
        /// Lower number = higher priority (never truncated first). Layer 1 and 2 are never truncated.
        public let priority: Int

        public init(kind: Kind, priority: Int) {
            self.kind = kind
            self.priority = priority
        }
    }

    public let mode: SessionMode
    public let subMode: SessionSubMode?
    public let components: [Component]
    /// Target token budget for Layer 3 context.
    public let tokenBudget: Int
    /// How many session summaries to include in full.
    public let fullSummaryCount: Int
    /// How many additional condensed summaries to include.
    public let condensedSummaryCount: Int

    public init(
        mode: SessionMode,
        subMode: SessionSubMode? = nil,
        components: [Component],
        tokenBudget: Int,
        fullSummaryCount: Int = 2,
        condensedSummaryCount: Int = 3
    ) {
        self.mode = mode
        self.subMode = subMode
        self.components = components
        self.tokenBudget = tokenBudget
        self.fullSummaryCount = fullSummaryCount
        self.condensedSummaryCount = condensedSummaryCount
    }

    /// Returns the configuration for a given mode and sub-mode.
    public static func configuration(for mode: SessionMode, subMode: SessionSubMode? = nil) -> V2ContextConfiguration {
        switch mode {
        case .exploration:
            return explorationConfig
        case .definition:
            return definitionConfig
        case .planning:
            return planningConfig
        case .executionSupport:
            return executionSupportConfig(subMode: subMode)
        }
    }

    // MARK: - Mode Configurations

    private static let explorationConfig = V2ContextConfiguration(
        mode: .exploration,
        components: [
            Component(kind: .projectOverview, priority: 1),
            Component(kind: .sessionSummaries, priority: 2),
            Component(kind: .documents, priority: 3),
            Component(kind: .projectStructure, priority: 4),
        ],
        tokenBudget: 2000,
        fullSummaryCount: 1,
        condensedSummaryCount: 2
    )

    private static let definitionConfig = V2ContextConfiguration(
        mode: .definition,
        components: [
            Component(kind: .projectOverview, priority: 1),
            Component(kind: .processProfile, priority: 1),
            Component(kind: .sessionSummaries, priority: 2),
            Component(kind: .documents, priority: 2),
        ],
        tokenBudget: 3000,
        fullSummaryCount: 2,
        condensedSummaryCount: 2
    )

    private static let planningConfig = V2ContextConfiguration(
        mode: .planning,
        components: [
            Component(kind: .projectOverview, priority: 1),
            Component(kind: .processProfile, priority: 1),
            Component(kind: .documents, priority: 1),
            Component(kind: .sessionSummaries, priority: 2),
            Component(kind: .projectStructure, priority: 2),
        ],
        tokenBudget: 4000,
        fullSummaryCount: 2,
        condensedSummaryCount: 3
    )

    private static func executionSupportConfig(subMode: SessionSubMode?) -> V2ContextConfiguration {
        switch subMode {
        case .projectReview:
            return V2ContextConfiguration(
                mode: .executionSupport,
                subMode: .projectReview,
                components: [
                    Component(kind: .portfolioSummary, priority: 1),
                    Component(kind: .patternsAndObservations, priority: 2),
                    Component(kind: .sessionSummaries, priority: 2),
                ],
                tokenBudget: 3000,
                fullSummaryCount: 1,
                condensedSummaryCount: 3
            )
        case .retrospective:
            return V2ContextConfiguration(
                mode: .executionSupport,
                subMode: .retrospective,
                components: [
                    Component(kind: .projectOverview, priority: 1),
                    Component(kind: .processProfile, priority: 1),
                    Component(kind: .documents, priority: 2),
                    Component(kind: .sessionSummaries, priority: 1),
                    Component(kind: .projectStructure, priority: 2),
                    Component(kind: .patternsAndObservations, priority: 2),
                ],
                tokenBudget: 5000,
                fullSummaryCount: 3,
                condensedSummaryCount: 5
            )
        default:
            // Check-in and return briefing use the same configuration
            return V2ContextConfiguration(
                mode: .executionSupport,
                subMode: subMode,
                components: [
                    Component(kind: .projectOverview, priority: 1),
                    Component(kind: .processProfile, priority: 2),
                    Component(kind: .documents, priority: 3),
                    Component(kind: .sessionSummaries, priority: 1),
                    Component(kind: .projectStructure, priority: 2),
                    Component(kind: .frequentlyDeferred, priority: 2),
                    Component(kind: .estimateCalibration, priority: 3),
                    Component(kind: .patternsAndObservations, priority: 2),
                ],
                tokenBudget: 5000,
                fullSummaryCount: 3,
                condensedSummaryCount: 3
            )
        }
    }
}
