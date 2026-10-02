import Foundation
import GRDB
import PMDomain

public final class SQLiteDependencyRepository: DependencyRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetchAll(forSource sourceId: UUID, sourceType: DependableType) async throws -> [Dependency] {
        try await db.read { db in
            try Dependency
                .filter(Column("sourceId") == sourceId && Column("sourceType") == sourceType.rawValue)
                .fetchAll(db)
        }
    }

    public func fetchAll(forTarget targetId: UUID, targetType: DependableType) async throws -> [Dependency] {
        try await db.read { db in
            try Dependency
                .filter(Column("targetId") == targetId && Column("targetType") == targetType.rawValue)
                .fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> Dependency? {
        try await db.read { db in
            try Dependency.fetchOne(db, key: id)
        }
    }

    public func save(_ dependency: Dependency) async throws {
        try await db.write { db in
            try dependency.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try Dependency.deleteOne(db, key: id)
        }
    }
}
