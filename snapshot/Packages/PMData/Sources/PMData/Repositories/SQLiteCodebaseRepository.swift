import Foundation
import GRDB
import PMDomain

public final class SQLiteCodebaseRepository: CodebaseRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) {
        self.db = db
    }

    public func fetchAll(forProject projectId: UUID) async throws -> [Codebase] {
        try await db.read { db in
            try Codebase
                .filter(Column("projectId") == projectId)
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> Codebase? {
        try await db.read { db in
            try Codebase.fetchOne(db, key: id)
        }
    }

    public func save(_ codebase: Codebase) async throws {
        try await db.write { db in
            try codebase.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try Codebase.deleteOne(db, key: id)
        }
    }
}
