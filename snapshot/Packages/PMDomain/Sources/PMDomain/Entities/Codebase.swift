import Foundation

/// A linked codebase (local directory or GitHub repository) associated with a project.
public struct Codebase: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var name: String
    public var sourceType: SourceType
    public var localPath: String?
    public var githubURL: String?
    public var bookmarkData: Data?
    public var clonedPath: String?
    public var lastIndexedAt: Date?
    public var fileSizeLimitMB: Int
    public var createdAt: Date
    public var updatedAt: Date

    public enum SourceType: String, Codable, Sendable {
        case local
        case github
    }

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        name: String,
        sourceType: SourceType,
        localPath: String? = nil,
        githubURL: String? = nil,
        bookmarkData: Data? = nil,
        clonedPath: String? = nil,
        lastIndexedAt: Date? = nil,
        fileSizeLimitMB: Int = 25,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.sourceType = sourceType
        self.localPath = localPath
        self.githubURL = githubURL
        self.bookmarkData = bookmarkData
        self.clonedPath = clonedPath
        self.lastIndexedAt = lastIndexedAt
        self.fileSizeLimitMB = fileSizeLimitMB
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
