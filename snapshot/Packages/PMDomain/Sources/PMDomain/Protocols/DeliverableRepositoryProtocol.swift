import Foundation

/// Repository for Deliverable CRUD and queries.
public protocol DeliverableRepositoryProtocol: Sendable {
    func fetch(id: UUID) async throws -> Deliverable?
    func fetchAll(forProject projectId: UUID) async throws -> [Deliverable]
    func fetchAll(forProject projectId: UUID, type: DeliverableType) async throws -> [Deliverable]
    func save(_ deliverable: Deliverable) async throws
    func delete(id: UUID) async throws
}
