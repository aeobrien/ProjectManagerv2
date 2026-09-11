import Foundation
import GRDB
import PMDomain

public final class SQLiteCategoryRepository: CategoryRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetchAll() async throws -> [Category] {
        try await db.read { db in
            try Category.order(Column("sortOrder")).fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> Category? {
        try await db.read { db in
            try Category.fetchOne(db, key: id)
        }
    }

    public func save(_ category: Category) async throws {
        try await db.write { db in
            try category.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try Category.deleteOne(db, key: id)
        }
    }

    public func seedBuiltInCategories() async throws {
        try await db.write { db in
            let count = try Category.fetchCount(db)
            guard count == 0 else { return }
            for category in Category.builtInCategories {
                try category.insert(db)
            }
        }
    }
}
