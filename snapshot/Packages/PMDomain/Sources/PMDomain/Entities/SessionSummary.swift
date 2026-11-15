import Foundation

/// A structured summary generated for a completed or auto-summarised session.
public struct SessionSummary: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var sessionId: UUID
    public var mode: SessionMode
    public var subMode: SessionSubMode?
    public var completionStatus: SessionCompletionStatus
    public var deliverableType: String?

    // Structured sections
    public var contentEstablished: ContentEstablished
    public var contentObserved: ContentObserved
    public var whatComesNext: WhatComesNext
    public var modeSpecific: ModeSpecificData?

    // Storage metadata
    public var startedAt: Date
    public var endedAt: Date
    public var duration: Int // seconds
    public var messageCount: Int
    public var inputTokens: Int?
    public var outputTokens: Int?

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        mode: SessionMode,
        subMode: SessionSubMode? = nil,
        completionStatus: SessionCompletionStatus,
        deliverableType: String? = nil,
        contentEstablished: ContentEstablished = ContentEstablished(),
        contentObserved: ContentObserved = ContentObserved(),
        whatComesNext: WhatComesNext = WhatComesNext(),
        modeSpecific: ModeSpecificData? = nil,
        startedAt: Date = Date(),
        endedAt: Date = Date(),
        duration: Int = 0,
        messageCount: Int = 0,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.mode = mode
        self.subMode = subMode
        self.completionStatus = completionStatus
        self.deliverableType = deliverableType
        self.contentEstablished = contentEstablished
        self.contentObserved = contentObserved
        self.whatComesNext = whatComesNext
        self.modeSpecific = modeSpecific
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.messageCount = messageCount
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    // MARK: - Section Structs

    public struct ContentEstablished: Equatable, Codable, Sendable {
        public var decisions: [String]
        public var factsLearned: [String]
        public var progressMade: [String]

        public init(
            decisions: [String] = [],
            factsLearned: [String] = [],
            progressMade: [String] = []
        ) {
            self.decisions = decisions
            self.factsLearned = factsLearned
            self.progressMade = progressMade
        }
    }

    public struct ContentObserved: Equatable, Codable, Sendable {
        public var patterns: [String]
        public var concerns: [String]
        public var strengths: [String]

        public init(
            patterns: [String] = [],
            concerns: [String] = [],
            strengths: [String] = []
        ) {
            self.patterns = patterns
            self.concerns = concerns
            self.strengths = strengths
        }
    }

    public struct WhatComesNext: Equatable, Codable, Sendable {
        public var nextActions: [String]
        public var openQuestions: [String]
        public var suggestedMode: String?

        public init(
            nextActions: [String] = [],
            openQuestions: [String] = [],
            suggestedMode: String? = nil
        ) {
            self.nextActions = nextActions
            self.openQuestions = openQuestions
            self.suggestedMode = suggestedMode
        }
    }

    // MARK: - Mode-Specific Data

    public enum ModeSpecificData: Equatable, Codable, Sendable {
        case exploration(ExplorationData)
        case definition(DefinitionData)
        case planning(PlanningData)
        case executionSupport(ExecutionSupportData)
    }

    public struct ExplorationData: Equatable, Codable, Sendable {
        public var projectSummary: String?
        public var recommendedDeliverables: [String]
        public var suggestedPlanningDepth: String?

        public init(
            projectSummary: String? = nil,
            recommendedDeliverables: [String] = [],
            suggestedPlanningDepth: String? = nil
        ) {
            self.projectSummary = projectSummary
            self.recommendedDeliverables = recommendedDeliverables
            self.suggestedPlanningDepth = suggestedPlanningDepth
        }
    }

    public struct DefinitionData: Equatable, Codable, Sendable {
        public var deliverableType: String?
        public var deliverableStatus: String?
        public var revisionsCount: Int

        public init(
            deliverableType: String? = nil,
            deliverableStatus: String? = nil,
            revisionsCount: Int = 0
        ) {
            self.deliverableType = deliverableType
            self.deliverableStatus = deliverableStatus
            self.revisionsCount = revisionsCount
        }
    }

    public struct PlanningData: Equatable, Codable, Sendable {
        public var structureSummary: String?
        public var firstAction: String?
        public var phasesCreated: Int

        public init(
            structureSummary: String? = nil,
            firstAction: String? = nil,
            phasesCreated: Int = 0
        ) {
            self.structureSummary = structureSummary
            self.firstAction = firstAction
            self.phasesCreated = phasesCreated
        }
    }

    public struct ExecutionSupportData: Equatable, Codable, Sendable {
        public var tasksCompleted: [String]
        public var tasksDeferred: [String]
        public var issuesFlagged: [String]

        public init(
            tasksCompleted: [String] = [],
            tasksDeferred: [String] = [],
            issuesFlagged: [String] = []
        ) {
            self.tasksCompleted = tasksCompleted
            self.tasksDeferred = tasksDeferred
            self.issuesFlagged = issuesFlagged
        }
    }
}
