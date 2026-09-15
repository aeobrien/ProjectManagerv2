import Foundation

/// A persisted AI session, replacing Conversation for the v2 AI system.
public struct Session: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var mode: SessionMode
    public var subMode: SessionSubMode?
    public var status: SessionStatus
    public var createdAt: Date
    public var lastActiveAt: Date
    public var completedAt: Date?
    public var summaryId: UUID?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        mode: SessionMode,
        subMode: SessionSubMode? = nil,
        status: SessionStatus = .active,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        completedAt: Date? = nil,
        summaryId: UUID? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.mode = mode
        self.subMode = subMode
        self.status = status
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.completedAt = completedAt
        self.summaryId = summaryId
    }
}
