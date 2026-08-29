import Foundation

/// A per-project process recommendation: which deliverables to produce, how much planning, and the suggested mode path.
public struct ProcessProfile: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var recommendedDeliverables: [RecommendedDeliverable]
    public var planningDepth: PlanningDepth
    public var suggestedModePath: [String]
    public var modificationHistory: [ProfileModification]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        recommendedDeliverables: [RecommendedDeliverable] = [],
        planningDepth: PlanningDepth = .fullRoadmap,
        suggestedModePath: [String] = [],
        modificationHistory: [ProfileModification] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.recommendedDeliverables = recommendedDeliverables
        self.planningDepth = planningDepth
        self.suggestedModePath = suggestedModePath
        self.modificationHistory = modificationHistory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// A deliverable recommendation with its current status.
    public struct RecommendedDeliverable: Equatable, Codable, Sendable {
        public var type: DeliverableType
        public var status: DeliverableStatus
        public var rationale: String?

        public init(
            type: DeliverableType,
            status: DeliverableStatus = .pending,
            rationale: String? = nil
        ) {
            self.type = type
            self.status = status
            self.rationale = rationale
        }
    }

    /// A record of a modification to the process profile.
    public struct ProfileModification: Equatable, Codable, Sendable {
        public var timestamp: Date
        public var description: String
        public var source: ModificationSource

        public init(
            timestamp: Date = Date(),
            description: String,
            source: ModificationSource
        ) {
            self.timestamp = timestamp
            self.description = description
            self.source = source
        }
    }

    /// Where a profile modification originated.
    public enum ModificationSource: String, Codable, Sendable, CaseIterable {
        case exploration
        case userConversation
        case userDirect
    }
}
