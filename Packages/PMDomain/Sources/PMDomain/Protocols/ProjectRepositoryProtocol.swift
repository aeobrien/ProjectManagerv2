import Foundation

/// Repository for Project CRUD and queries.
public protocol ProjectRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Project]
    func fetch(id: UUID) async throws -> Project?
    func fetchByLifecycleState(_ state: LifecycleState) async throws -> [Project]
    func fetchByCategory(_ categoryId: UUID) async throws -> [Project]
    func fetchFocused() async throws -> [Project]
    func save(_ project: Project) async throws
    func delete(id: UUID) async throws
    func search(query: String) async throws -> [Project]
}
