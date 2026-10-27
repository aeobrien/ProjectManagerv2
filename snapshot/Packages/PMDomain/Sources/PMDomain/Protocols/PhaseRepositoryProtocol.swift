import Foundation

/// Repository for Phase CRUD and queries.
public protocol PhaseRepositoryProtocol: Sendable {
    func fetchAll(forProject projectId: UUID) async throws -> [Phase]
    func fetch(id: UUID) async throws -> Phase?
    func save(_ phase: Phase) async throws
    func delete(id: UUID) async throws
    func reorder(phases: [Phase]) async throws
}
