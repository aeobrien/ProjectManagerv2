import Foundation
import GRDB
import PMDomain

public final class SQLiteProcessProfileRepository: ProcessProfileRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetch(forProject projectId: UUID) async throws -> ProcessProfile? {
        try await db.read { db in
            try ProcessProfile
                .filter(Column("projectId") == projectId)
                .fetchOne(db)
        }
    }

    public func save(_ profile: ProcessProfile) async throws {
        try await db.write { db in
            try profile.save(db)
        }
    }

    public func delete(forProject projectId: UUID) async throws {
        _ = try await db.write { db in
            try ProcessProfile
                .filter(Column("projectId") == projectId)
                .deleteAll(db)
        }
    }
}
