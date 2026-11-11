import Foundation

/// A typed, status-tracked deliverable produced through the Definition mode.
public struct Deliverable: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var type: DeliverableType
    public var status: DeliverableStatus
    public var title: String
    public var content: String
    public var versionHistory: [DeliverableVersion]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        type: DeliverableType,
        status: DeliverableStatus = .pending,
        title: String = "",
        content: String = "",
        versionHistory: [DeliverableVersion] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.type = type
        self.status = status
        self.title = title
        self.content = content
        self.versionHistory = versionHistory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// A snapshot of a previous version.
    public struct DeliverableVersion: Equatable, Codable, Sendable {
        public var version: Int
        public var content: String
        public var changeNote: String?
        public var savedAt: Date

        public init(
            version: Int,
            content: String,
            changeNote: String? = nil,
            savedAt: Date = Date()
        ) {
            self.version = version
            self.content = content
            self.changeNote = changeNote
            self.savedAt = savedAt
        }
    }
}
