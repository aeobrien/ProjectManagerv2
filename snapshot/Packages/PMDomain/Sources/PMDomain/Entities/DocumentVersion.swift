import Foundation

/// A snapshot of a document at a specific version.
public struct DocumentVersion: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var documentId: UUID
    public var version: Int
    public var title: String
    public var content: String
    public var savedAt: Date

    public init(
        id: UUID = UUID(),
        documentId: UUID,
        version: Int,
        title: String,
        content: String,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.documentId = documentId
        self.version = version
        self.title = title
        self.content = content
        self.savedAt = savedAt
    }
}
