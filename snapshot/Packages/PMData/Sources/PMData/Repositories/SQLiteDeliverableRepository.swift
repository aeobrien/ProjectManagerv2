import Foundation
import GRDB
import PMDomain

public final class SQLiteDeliverableRepository: DeliverableRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetch(id: UUID) async throws -> Deliverable? {
        try await db.read { db in
            try Deliverable.fetchOne(db, key: id)
        }
    }

    public func fetchAll(forProject projectId: UUID) async throws -> [Deliverable] {
        try await db.read { db in
            try Deliverable
                .filter(Column("projectId") == projectId)
                .order(Column("createdAt"))
                .fetchAll(db)
        }
    }

    public func fetchAll(forProject projectId: UUID, type: DeliverableType) async throws -> [Deliverable] {
        try await db.read { db in
            try Deliverable
                .filter(Column("projectId") == projectId)
                .filter(Column("type") == type.rawValue)
                .order(Column("createdAt"))
                .fetchAll(db)
        }
    }

    public func save(_ deliverable: Deliverable) async throws {
        try await db.write { db in
            try deliverable.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try Deliverable.deleteOne(db, key: id)
        }
    }
}
