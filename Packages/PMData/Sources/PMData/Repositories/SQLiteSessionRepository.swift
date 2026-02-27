import Foundation
import GRDB
import PMDomain

public final class SQLiteSessionRepository: SessionRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    // MARK: - Session CRUD

    public func fetch(id: UUID) async throws -> Session? {
        try await db.read { db in
            try Session.fetchOne(db, key: id)
        }
    }

    public func fetchAll(forProject projectId: UUID) async throws -> [Session] {
        try await db.read { db in
            try Session
                .filter(Column("projectId") == projectId)
                .order(Column("lastActiveAt").desc)
                .fetchAll(db)
        }
    }

    public func fetchActive(forProject projectId: UUID) async throws -> [Session] {
        try await db.read { db in
            try Session
                .filter(Column("projectId") == projectId)
                .filter([SessionStatus.active.rawValue, SessionStatus.paused.rawValue].contains(Column("status")))
                .order(Column("lastActiveAt").desc)
                .fetchAll(db)
        }
    }

    public func save(_ session: Session) async throws {
        try await db.write { db in
            try session.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try Session.deleteOne(db, key: id)
        }
    }

    // MARK: - Messages

    public func fetchMessages(forSession sessionId: UUID) async throws -> [SessionMessage] {
        try await db.read { db in
            try SessionMessage
                .filter(Column("sessionId") == sessionId)
                .order(Column("timestamp"))
                .fetchAll(db)
        }
    }

    public func appendMessage(_ message: SessionMessage) async throws {
        try await db.write { db in
            try message.insert(db)
            // Update session's lastActiveAt
            if var session = try Session.fetchOne(db, key: message.sessionId) {
                session.lastActiveAt = message.timestamp
                try session.update(db)
            }
        }
    }

    // MARK: - Summaries

    public func fetchSummary(forSession sessionId: UUID) async throws -> SessionSummary? {
        try await db.read { db in
            try SessionSummary
                .filter(Column("sessionId") == sessionId)
                .fetchOne(db)
        }
    }

    public func saveSummary(_ summary: SessionSummary) async throws {
        try await db.write { db in
            try summary.save(db)
        }
    }

    // MARK: - Auto-Summarisation Queries

    public func fetchSessionsPendingSummarisation(olderThan cutoff: Date) async throws -> [Session] {
        try await db.read { db in
            try Session
                .filter(Column("status") == SessionStatus.paused.rawValue)
                .filter(Column("lastActiveAt") < cutoff)
                .order(Column("lastActiveAt"))
                .fetchAll(db)
        }
    }

    public func fetchSessionsWithStatus(_ status: SessionStatus) async throws -> [Session] {
        try await db.read { db in
            try Session
                .filter(Column("status") == status.rawValue)
                .order(Column("lastActiveAt").desc)
                .fetchAll(db)
        }
    }
}
