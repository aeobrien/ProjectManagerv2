import Foundation

/// Repository for Document CRUD and queries.
public protocol DocumentRepositoryProtocol: Sendable {
    func fetchAll(forProject projectId: UUID) async throws -> [Document]
    func fetch(id: UUID) async throws -> Document?
    func fetchByType(_ type: DocumentType, projectId: UUID) async throws -> [Document]
    func save(_ document: Document) async throws
    func delete(id: UUID) async throws
    func search(query: String) async throws -> [Document]
}
