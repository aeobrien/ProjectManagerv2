import Foundation

/// Repository for Milestone CRUD and queries.
public protocol MilestoneRepositoryProtocol: Sendable {
    func fetchAll(forPhase phaseId: UUID) async throws -> [Milestone]
    func fetch(id: UUID) async throws -> Milestone?
    func save(_ milestone: Milestone) async throws
    func delete(id: UUID) async throws
    func reorder(milestones: [Milestone]) async throws
}
