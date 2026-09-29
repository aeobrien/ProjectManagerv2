import Foundation

/// Repository for CheckInRecord CRUD and queries.
public protocol CheckInRepositoryProtocol: Sendable {
    func fetchAll(forProject projectId: UUID) async throws -> [CheckInRecord]
    func fetch(id: UUID) async throws -> CheckInRecord?
    func fetchLatest(forProject projectId: UUID) async throws -> CheckInRecord?
    func save(_ record: CheckInRecord) async throws
    func delete(id: UUID) async throws
}
