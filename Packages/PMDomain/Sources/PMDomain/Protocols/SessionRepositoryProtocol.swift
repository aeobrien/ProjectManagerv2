import Foundation

/// Repository for Session CRUD, messages, summaries, and auto-summarisation queries.
public protocol SessionRepositoryProtocol: Sendable {
    // Session CRUD
    func fetch(id: UUID) async throws -> Session?
    func fetchAll(forProject projectId: UUID) async throws -> [Session]
    func fetchActive(forProject projectId: UUID) async throws -> [Session]
    func save(_ session: Session) async throws
    func delete(id: UUID) async throws

    // Messages
    func fetchMessages(forSession sessionId: UUID) async throws -> [SessionMessage]
    func appendMessage(_ message: SessionMessage) async throws

    // Summaries
    func fetchSummary(forSession sessionId: UUID) async throws -> SessionSummary?
    func saveSummary(_ summary: SessionSummary) async throws

    // Auto-summarisation queries
    func fetchSessionsPendingSummarisation(olderThan cutoff: Date) async throws -> [Session]
    func fetchSessionsWithStatus(_ status: SessionStatus) async throws -> [Session]
}
