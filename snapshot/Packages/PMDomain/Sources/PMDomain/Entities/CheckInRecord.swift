import Foundation

/// A record of a check-in conversation with the AI.
public struct CheckInRecord: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var timestamp: Date
    public var depth: CheckInDepth
    public var transcript: String
    public var aiSummary: String
    public var tasksCompleted: [UUID]
    public var issuesFlagged: [String]

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        timestamp: Date = Date(),
        depth: CheckInDepth,
        transcript: String = "",
        aiSummary: String = "",
        tasksCompleted: [UUID] = [],
        issuesFlagged: [String] = []
    ) {
        self.id = id
        self.projectId = projectId
        self.timestamp = timestamp
        self.depth = depth
        self.transcript = transcript
        self.aiSummary = aiSummary
        self.tasksCompleted = tasksCompleted
        self.issuesFlagged = issuesFlagged
    }
}
