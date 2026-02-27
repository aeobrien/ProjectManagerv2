import Foundation

/// Repository for ProcessProfile CRUD operations.
public protocol ProcessProfileRepositoryProtocol: Sendable {
    func fetch(forProject projectId: UUID) async throws -> ProcessProfile?
    func save(_ profile: ProcessProfile) async throws
    func delete(forProject projectId: UUID) async throws
}
