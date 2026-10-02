import Foundation
import GRDB
import PMDomain

public final class SQLitePhaseRepository: PhaseRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetchAll(forProject projectId: UUID) async throws -> [Phase] {
        try await db.read { db in
            try Phase.filter(Column("projectId") == projectId)
                .order(Column("sortOrder"))
                .fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> Phase? {
        try await db.read { db in
            try Phase.fetchOne(db, key: id)
        }
    }

    public func save(_ phase: Phase) async throws {
        try await db.write { db in
            try phase.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try Phase.deleteOne(db, key: id)
        }
    }

    public func reorder(phases: [Phase]) async throws {
        try await db.write { db in
            for phase in phases {
                try phase.update(db)
            }
        }
    }
}
