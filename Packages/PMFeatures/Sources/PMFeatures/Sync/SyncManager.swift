import Foundation
import PMData
import PMUtilities
import os

/// Observable manager for CloudKit sync, providing UI-visible state and periodic sync.
@Observable
@MainActor
public final class SyncManager {
    // MARK: - State

    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var pendingChangeCount: Int = 0
    public private(set) var error: String?

    /// Whether sync is enabled. Controlled from Settings.
    public var syncEnabled: Bool = true

    // MARK: - Dependencies

    private let syncEngine: SyncEngine

    /// Timer for periodic sync.
    private var syncTimer: Timer?

    /// Interval in seconds between periodic syncs.
    public var syncIntervalSeconds: TimeInterval = 300 // 5 minutes

    // MARK: - Init

    public init(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine
    }

    // MARK: - Manual Sync

    /// Trigger a sync cycle manually.
    public func syncNow() async {
        guard syncEnabled else { return }
        isSyncing = true
        error = nil

        do {
            try await syncEngine.sync()
            let state = await syncEngine.currentState()
            lastSyncDate = state.lastSyncDate
            pendingChangeCount = state.pendingChangeCount
            Log.sync.info("Sync completed. Pending: \(self.pendingChangeCount)")
        } catch SyncError.notAuthenticated {
            error = "Not signed in to iCloud"
            Log.sync.error("Sync failed: not authenticated")
        } catch SyncError.networkUnavailable {
            error = "Network unavailable"
            Log.sync.error("Sync failed: network unavailable")
        } catch {
            self.error = "Sync failed: \(error.localizedDescription)"
            Log.sync.error("Sync failed: \(error)")
        }

        isSyncing = false
    }

    // MARK: - Change Tracking

    /// Track a local entity change for sync.
    public func trackChange(entityType: SyncEntityType, entityId: UUID, changeType: SyncChangeType) {
        guard syncEnabled else { return }
        Task.detached { [syncEngine] in
            do {
                try await syncEngine.trackChange(entityType: entityType, entityId: entityId, changeType: changeType)
            } catch {
                Log.sync.error("Failed to track change: \(error)")
            }
        }
    }

    // MARK: - Periodic Sync

    /// Start periodic sync on a timer.
    public func startPeriodicSync() {
        stopPeriodicSync()
        guard syncEnabled else { return }

        // Initial sync on start
        Task { await syncNow() }

        syncTimer = Timer.scheduledTimer(withTimeInterval: syncIntervalSeconds, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.syncNow()
            }
        }
        Log.sync.info("Started periodic sync (interval: \(self.syncIntervalSeconds)s)")
    }

    /// Stop periodic sync.
    public func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - State Refresh

    /// Refresh the displayed state from the engine.
    public func refreshState() async {
        let state = await syncEngine.currentState()
        lastSyncDate = state.lastSyncDate
        pendingChangeCount = state.pendingChangeCount
        isSyncing = await syncEngine.isSyncInProgress()
    }
}
