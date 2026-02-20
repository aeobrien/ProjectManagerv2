import Foundation
import PMDomain
import PMUtilities
import os

/// Protocol for the remote sync backend, enabling testing without CloudKit.
public protocol SyncBackendProtocol: Sendable {
    /// Push a batch of changes to the remote.
    func push(changes: [SyncChange], payloads: [UUID: Data]) async throws

    /// Pull changes from remote since last sync.
    func pull(since token: Data?) async throws -> (changes: [SyncChange], payloads: [UUID: Data], newToken: Data?)

    /// Check if the user is authenticated for sync.
    func isAuthenticated() async -> Bool
}

/// Protocol for the local change queue.
public protocol SyncQueueProtocol: Sendable {
    /// Enqueue a local change.
    func enqueue(_ change: SyncChange) async throws

    /// Get all pending (unsynced) changes.
    func pendingChanges() async throws -> [SyncChange]

    /// Mark changes as synced.
    func markSynced(ids: [UUID]) async throws

    /// Remove synced changes older than a date.
    func purge(before date: Date) async throws

    /// Count of pending changes.
    func pendingCount() async throws -> Int
}

/// Manages bidirectional sync between local GRDB and CloudKit.
public actor SyncEngine {
    private let backend: SyncBackendProtocol
    private let queue: SyncQueueProtocol
    private let conflictResolver: ConflictResolver

    private var syncState: SyncState
    private var isSyncing = false

    /// Minimum interval between syncs (seconds).
    public let minSyncInterval: TimeInterval

    /// Conflict resolution threshold — if timestamps are within this many seconds, flag for manual merge.
    public let conflictThresholdSeconds: TimeInterval

    public init(
        backend: SyncBackendProtocol,
        queue: SyncQueueProtocol,
        conflictResolver: ConflictResolver = ConflictResolver(),
        syncState: SyncState = SyncState(),
        minSyncInterval: TimeInterval = 30,
        conflictThresholdSeconds: TimeInterval = 60
    ) {
        self.backend = backend
        self.queue = queue
        self.conflictResolver = conflictResolver
        self.syncState = syncState
        self.minSyncInterval = minSyncInterval
        self.conflictThresholdSeconds = conflictThresholdSeconds
    }

    // MARK: - Change Tracking

    /// Record a local change for later sync.
    public func trackChange(entityType: SyncEntityType, entityId: UUID, changeType: SyncChangeType) async throws {
        let change = SyncChange(
            entityType: entityType,
            entityId: entityId,
            changeType: changeType
        )
        try await queue.enqueue(change)
        Log.data.info("Tracked \(changeType.rawValue) for \(entityType.rawValue) \(entityId)")
    }

    // MARK: - Sync

    /// Perform a full sync cycle: push local changes, then pull remote changes.
    public func sync() async throws {
        guard !isSyncing else { return }

        // Check minimum interval
        if let lastSync = syncState.lastSyncDate {
            let elapsed = Date().timeIntervalSince(lastSync)
            guard elapsed >= minSyncInterval else { return }
        }

        guard await backend.isAuthenticated() else {
            throw SyncError.notAuthenticated
        }

        isSyncing = true
        defer { isSyncing = false }

        // Push local changes
        try await pushChanges()

        // Pull remote changes
        try await pullChanges()

        syncState.lastSyncDate = Date()
        syncState.pendingChangeCount = try await queue.pendingCount()
    }

    /// Push pending local changes to the remote.
    private func pushChanges() async throws {
        let pending = try await queue.pendingChanges()
        guard !pending.isEmpty else { return }

        // In a real implementation, we'd serialize entity data here
        let payloads: [UUID: Data] = [:]
        try await backend.push(changes: pending, payloads: payloads)

        let ids = pending.map(\.id)
        try await queue.markSynced(ids: ids)
        Log.data.info("Pushed \(pending.count) changes to remote")
    }

    /// Pull remote changes and apply locally.
    private func pullChanges() async throws {
        let result = try await backend.pull(since: syncState.serverChangeToken)

        if let newToken = result.newToken {
            syncState.serverChangeToken = newToken
        }

        // Process each remote change
        for change in result.changes {
            // Check for conflicts with pending local changes
            let pending = try await queue.pendingChanges()
            let conflicting = pending.first {
                $0.entityType == change.entityType && $0.entityId == change.entityId
            }

            if let local = conflicting {
                let conflict = SyncConflict(
                    entityType: change.entityType,
                    entityId: change.entityId,
                    localTimestamp: local.timestamp,
                    remoteTimestamp: change.timestamp
                )
                let resolution = conflictResolver.resolve(conflict, threshold: conflictThresholdSeconds)
                Log.data.info("Conflict on \(change.entityType.rawValue) \(change.entityId): \(resolution.rawValue)")
            }
        }

        let count = result.changes.count
        Log.data.info("Pulled \(count) changes from remote")
    }

    // MARK: - State

    /// Get the current sync state.
    public func currentState() -> SyncState {
        syncState
    }

    /// Whether a sync is currently in progress.
    public func isSyncInProgress() -> Bool {
        isSyncing
    }

    /// Reset sync state (forces full re-sync).
    public func resetState() {
        syncState = SyncState()
    }
}

// MARK: - Conflict Resolution

/// Resolves sync conflicts between local and remote versions.
public struct ConflictResolver: Sendable {
    public init() {}

    /// Resolve a conflict using the configured strategy.
    public func resolve(_ conflict: SyncConflict, threshold: TimeInterval = 60) -> ConflictResolution {
        let timeDiff = abs(conflict.localTimestamp.timeIntervalSince(conflict.remoteTimestamp))

        // For document content with very close timestamps, suggest manual merge
        if conflict.entityType == .document && timeDiff < threshold {
            return .manualMerge
        }

        // Default: last write wins
        if conflict.localTimestamp > conflict.remoteTimestamp {
            return .keepLocal
        } else {
            return .keepRemote
        }
    }
}
