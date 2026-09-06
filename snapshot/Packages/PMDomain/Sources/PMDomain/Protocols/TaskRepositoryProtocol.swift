import Foundation

/// Repository for PMTask CRUD and queries.
public protocol TaskRepositoryProtocol: Sendable {
    func fetchAll(forMilestone milestoneId: UUID) async throws -> [PMTask]
    func fetch(id: UUID) async throws -> PMTask?
    func fetchByStatus(_ status: ItemStatus) async throws -> [PMTask]
    func fetchByEffortType(_ effortType: EffortType) async throws -> [PMTask]
    func fetchByKanbanColumn(_ column: KanbanColumn, milestoneId: UUID) async throws -> [PMTask]
    func save(_ task: PMTask) async throws
    func delete(id: UUID) async throws
    func reorder(tasks: [PMTask]) async throws
    func search(query: String) async throws -> [PMTask]
}
