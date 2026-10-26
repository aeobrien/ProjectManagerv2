import Foundation

/// Repository for advisory Dependency CRUD and queries.
public protocol DependencyRepositoryProtocol: Sendable {
    func fetchAll(forSource sourceId: UUID, sourceType: DependableType) async throws -> [Dependency]
    func fetchAll(forTarget targetId: UUID, targetType: DependableType) async throws -> [Dependency]
    func fetch(id: UUID) async throws -> Dependency?
    func save(_ dependency: Dependency) async throws
    func delete(id: UUID) async throws
}
