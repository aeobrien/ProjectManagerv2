import Foundation

/// A project document (vision statement, technical brief, or other).
public struct Document: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var type: DocumentType
    public var title: String
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        type: DocumentType,
        title: String,
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.projectId = projectId
        self.type = type
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }
}
