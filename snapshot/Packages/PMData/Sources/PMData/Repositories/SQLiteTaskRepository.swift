import Foundation
import GRDB
import PMDomain

public final class SQLiteTaskRepository: TaskRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetchAll(forMilestone milestoneId: UUID) async throws -> [PMTask] {
        try await db.read { db in
            try PMTask.filter(Column("milestoneId") == milestoneId)
                .order(Column("sortOrder"))
                .fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> PMTask? {
        try await db.read { db in
            try PMTask.fetchOne(db, key: id)
        }
    }

    public func fetchByStatus(_ status: ItemStatus) async throws -> [PMTask] {
        try await db.read { db in
            try PMTask.filter(Column("status") == status.rawValue)
                .order(Column("sortOrder"))
                .fetchAll(db)
        }
    }

    public func fetchByEffortType(_ effortType: EffortType) async throws -> [PMTask] {
        try await db.read { db in
            try PMTask.filter(Column("effortType") == effortType.rawValue)
                .order(Column("sortOrder"))
                .fetchAll(db)
        }
    }

    public func fetchByKanbanColumn(_ column: KanbanColumn, milestoneId: UUID) async throws -> [PMTask] {
        try await db.read { db in
            try PMTask.filter(Column("kanbanColumn") == column.rawValue && Column("milestoneId") == milestoneId)
                .order(Column("sortOrder"))
                .fetchAll(db)
        }
    }

    public func save(_ task: PMTask) async throws {
        try await db.write { db in
            try task.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try PMTask.deleteOne(db, key: id)
        }
    }

    public func reorder(tasks: [PMTask]) async throws {
        try await db.write { db in
            for task in tasks {
                try task.update(db)
            }
        }
    }

    public func search(query: String) async throws -> [PMTask] {
        try await db.read { db in
            try PMTask.filter(Column("name").like("%\(query)%"))
                .order(Column("name"))
                .fetchAll(db)
        }
    }
}
