import Foundation
import PMData
import PMUtilities
import os

/// Notification posted when network connectivity is restored after being offline.
public extension Notification.Name {
    static let networkReconnected = Notification.Name("com.projectmanager.networkReconnected")
}

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

    /// Whether the device has a network connection.
    public var isNetworkAvailable: Bool { networkMonitor.isConnected }

    // MARK: - Dependencies

    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor

    /// Timer for periodic sync.
    private var syncTimer: Timer?

    /// Interval in seconds between periodic syncs.
    public var syncIntervalSeconds: TimeInterval = 300 // 5 minutes

    // MARK: - Retry State

    private var retryCount: Int = 0
    private static let maxRetries = 5
    private static let baseRetryInterval: TimeInterval = 5
    private var retryTimer: Timer?

    // MARK: - Init

    public init(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine
        self.networkMonitor = NetworkMonitor()

        // Start monitoring and wire reconnect handler
        networkMonitor.onReconnect = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.syncEnabled else { return }
                self.retryCount = 0
                self.retryTimer?.invalidate()
                self.retryTimer = nil
                Log.sync.info("Network reconnected — triggering immediate sync")
                await self.syncNow()
                NotificationCenter.default.post(name: .networkReconnected, object: nil)
            }
        }
        networkMonitor.start()
    }

    // MARK: - Manual Sync

    /// Trigger a sync cycle manually.
    public func syncNow() async {
        guard syncEnabled else { return }
        guard networkMonitor.isConnected else {
            error = "Waiting for network"
            Log.sync.info("Sync skipped: no network")
            return
        }

        isSyncing = true
        error = nil

        do {
            try await syncEngine.sync()
            let state = await syncEngine.currentState()
            lastSyncDate = state.lastSyncDate
            pendingChangeCount = state.pendingChangeCount
            retryCount = 0
            retryTimer?.invalidate()
            retryTimer = nil
            Log.sync.info("Sync completed. Pending: \(self.pendingChangeCount)")

            // If changes are still pending, schedule an urgent follow-up
            if pendingChangeCount > 0 {
                scheduleFollowUpSync(in: 30)
            }
        } catch SyncError.notAuthenticated {
            error = "Not signed in to iCloud"
            Log.sync.error("Sync failed: not authenticated")
        } catch SyncError.networkUnavailable {
            error = "Network unavailable"
            Log.sync.error("Sync failed: network unavailable")
            scheduleRetry()
        } catch {
            self.error = "Sync failed: \(error.localizedDescription)"
            Log.sync.error("Sync failed: \(error)")
            scheduleRetry()
        }

        isSyncing = false
    }

    // MARK: - Retry with Exponential Backoff

    private func scheduleRetry() {
        guard retryCount < Self.maxRetries else {
            Log.sync.error("Max retries (\(Self.maxRetries)) reached, waiting for reconnect")
            return
        }

        let delay = Self.baseRetryInterval * pow(2.0, Double(retryCount))
        retryCount += 1
        Log.sync.info("Scheduling retry \(self.retryCount)/\(Self.maxRetries) in \(delay)s")

        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.syncNow()
            }
        }
    }

    private func scheduleFollowUpSync(in seconds: TimeInterval) {
        // Don't override an existing retry timer
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.syncNow()
            }
        }
    }

    // MARK: - Force Full Sync

    /// Re-enqueue every entity in the database and sync.
    /// Use when data was created before sync tracking was in place.
    public func forceFullSync() async {
        guard syncEnabled else { return }
        guard networkMonitor.isConnected else {
            error = "Waiting for network"
            return
        }

        isSyncing = true
        error = nil

        do {
            try await syncEngine.forceReenqueueAll()
            try await syncEngine.sync()
            let state = await syncEngine.currentState()
            lastSyncDate = state.lastSyncDate
            pendingChangeCount = state.pendingChangeCount
            Log.sync.info("Force full sync completed. Pending: \(self.pendingChangeCount)")
        } catch {
            self.error = "Full sync failed: \(error.localizedDescription)"
            Log.sync.error("Force full sync failed: \(error)")
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

        // Enqueue all existing entities if the queue is empty (first sync or migration)
        Task {
            do {
                try await syncEngine.enqueueAllExistingEntities()
            } catch {
                Log.sync.error("Failed to enqueue existing entities: \(error)")
            }
            await syncNow()
        }

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
        retryTimer?.invalidate()
        retryTimer = nil
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
