import Foundation
import GRDB
import PMUtilities

/// Persistent SQLite-backed implementation of SyncQueueProtocol.
/// Changes survive app restarts, unlike InMemorySyncQueue.
public final class SQLiteSyncQueue: SyncQueueProtocol, @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func enqueue(_ change: SyncChange) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO syncChange (id, entityType, entityId, changeType, timestamp, synced)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    change.id.uuidString,
                    change.entityType.rawValue,
                    change.entityId.uuidString,
                    change.changeType.rawValue,
                    change.timestamp,
                    change.synced
                ]
            )
        }
    }

    public func pendingChanges() async throws -> [SyncChange] {
        try await dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM syncChange WHERE synced = 0 ORDER BY timestamp ASC")
            return rows.compactMap { Self.syncChange(from: $0) }
        }
    }

    public func markSynced(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        let idStrings = ids.map { $0.uuidString }
        let placeholders = idStrings.map { _ in "?" }.joined(separator: ", ")
        try await dbQueue.write { [idStrings] db in
            try db.execute(
                sql: "UPDATE syncChange SET synced = 1 WHERE id IN (\(placeholders))",
                arguments: StatementArguments(idStrings)
            )
        }
    }

    public func purge(before date: Date) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM syncChange WHERE synced = 1 AND timestamp < ?",
                arguments: [date]
            )
        }
    }

    public func pendingCount() async throws -> Int {
        try await dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM syncChange WHERE synced = 0") ?? 0
        }
    }

    // MARK: - Row Mapping

    private static func syncChange(from row: Row) -> SyncChange? {
        guard let idStr: String = row["id"],
              let id = UUID(uuidString: idStr),
              let entityTypeStr: String = row["entityType"],
              let entityType = SyncEntityType(rawValue: entityTypeStr),
              let entityIdStr: String = row["entityId"],
              let entityId = UUID(uuidString: entityIdStr),
              let changeTypeStr: String = row["changeType"],
              let changeType = SyncChangeType(rawValue: changeTypeStr),
              let timestamp: Date = row["timestamp"] else {
            return nil
        }
        let synced: Bool = row["synced"]
        return SyncChange(
            id: id,
            entityType: entityType,
            entityId: entityId,
            changeType: changeType,
            timestamp: timestamp,
            synced: synced
        )
    }
}
