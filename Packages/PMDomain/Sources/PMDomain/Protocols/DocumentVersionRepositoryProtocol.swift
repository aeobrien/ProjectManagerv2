import Foundation

/// Repository for document version history.
public protocol DocumentVersionRepositoryProtocol: Sendable {
    func fetch(id: UUID) async throws -> DocumentVersion?
    func fetchAll(forDocument documentId: UUID) async throws -> [DocumentVersion]
    func save(_ version: DocumentVersion) async throws
    func delete(id: UUID) async throws
    func deleteAll(forDocument documentId: UUID) async throws
}
