import Foundation
import GRDB
import PMDomain

public final class SQLiteProjectRepository: ProjectRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetchAll() async throws -> [Project] {
        try await db.read { db in
            try Project.order(Column("updatedAt").desc).fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> Project? {
        try await db.read { db in
            try Project.fetchOne(db, key: id)
        }
    }

    public func fetchByLifecycleState(_ state: LifecycleState) async throws -> [Project] {
        try await db.read { db in
            try Project.filter(Column("lifecycleState") == state.rawValue)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    public func fetchByCategory(_ categoryId: UUID) async throws -> [Project] {
        try await db.read { db in
            try Project.filter(Column("categoryId") == categoryId)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    public func fetchFocused() async throws -> [Project] {
        try await db.read { db in
            try Project.filter(Column("lifecycleState") == LifecycleState.focused.rawValue)
                .order(Column("focusSlotIndex"))
                .fetchAll(db)
        }
    }

    public func save(_ project: Project) async throws {
        try await db.write { db in
            try project.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try Project.deleteOne(db, key: id)
        }
    }

    public func search(query: String) async throws -> [Project] {
        try await db.read { db in
            try Project.filter(Column("name").like("%\(query)%"))
                .order(Column("name"))
                .fetchAll(db)
        }
    }
}
