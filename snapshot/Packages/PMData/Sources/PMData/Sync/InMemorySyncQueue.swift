import Foundation

/// In-memory implementation of the sync queue for testing.
public actor InMemorySyncQueue: SyncQueueProtocol {
    private var changes: [SyncChange] = []

    public init() {}

    public func enqueue(_ change: SyncChange) throws {
        changes.append(change)
    }

    public func pendingChanges() throws -> [SyncChange] {
        changes.filter { !$0.synced }
    }

    public func markSynced(ids: [UUID]) throws {
        for i in changes.indices {
            if ids.contains(changes[i].id) {
                changes[i].synced = true
            }
        }
    }

    public func purge(before date: Date) throws {
        changes.removeAll { $0.synced && $0.timestamp < date }
    }

    public func pendingCount() throws -> Int {
        changes.filter { !$0.synced }.count
    }

    /// All changes (for testing).
    public func allChanges() -> [SyncChange] {
        changes
    }
}
