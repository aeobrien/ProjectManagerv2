import Foundation
import GRDB
import PMDomain

public final class SQLiteSubtaskRepository: SubtaskRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetchAll(forTask taskId: UUID) async throws -> [Subtask] {
        try await db.read { db in
            try Subtask.filter(Column("taskId") == taskId)
                .order(Column("sortOrder"))
                .fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> Subtask? {
        try await db.read { db in
            try Subtask.fetchOne(db, key: id)
        }
    }

    public func save(_ subtask: Subtask) async throws {
        try await db.write { db in
            try subtask.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try Subtask.deleteOne(db, key: id)
        }
    }

    public func reorder(subtasks: [Subtask]) async throws {
        try await db.write { db in
            for subtask in subtasks {
                try subtask.update(db)
            }
        }
    }
}
