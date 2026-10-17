import Foundation
import GRDB
import PMDomain

public final class SQLiteCheckInRepository: CheckInRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetchAll(forProject projectId: UUID) async throws -> [CheckInRecord] {
        try await db.read { db in
            try CheckInRecord.filter(Column("projectId") == projectId)
                .order(Column("timestamp").desc)
                .fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> CheckInRecord? {
        try await db.read { db in
            try CheckInRecord.fetchOne(db, key: id)
        }
    }

    public func fetchLatest(forProject projectId: UUID) async throws -> CheckInRecord? {
        try await db.read { db in
            try CheckInRecord.filter(Column("projectId") == projectId)
                .order(Column("timestamp").desc)
                .fetchOne(db)
        }
    }

    public func save(_ record: CheckInRecord) async throws {
        try await db.write { db in
            try record.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try CheckInRecord.deleteOne(db, key: id)
        }
    }
}
