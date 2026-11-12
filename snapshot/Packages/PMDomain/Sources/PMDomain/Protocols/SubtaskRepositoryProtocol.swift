import Foundation

/// Repository for Subtask CRUD.
public protocol SubtaskRepositoryProtocol: Sendable {
    func fetchAll(forTask taskId: UUID) async throws -> [Subtask]
    func fetch(id: UUID) async throws -> Subtask?
    func save(_ subtask: Subtask) async throws
    func delete(id: UUID) async throws
    func reorder(subtasks: [Subtask]) async throws
}
