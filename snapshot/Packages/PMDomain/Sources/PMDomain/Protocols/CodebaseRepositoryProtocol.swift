import Foundation

/// Repository protocol for codebase CRUD operations.
public protocol CodebaseRepositoryProtocol: Sendable {
    func fetchAll(forProject projectId: UUID) async throws -> [Codebase]
    func fetch(id: UUID) async throws -> Codebase?
    func save(_ codebase: Codebase) async throws
    func delete(id: UUID) async throws
}
