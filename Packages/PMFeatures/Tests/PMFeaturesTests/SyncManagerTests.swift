import Testing
import Foundation
@testable import PMFeatures
@testable import PMData

// MARK: - SyncManager Tests

@Suite("SyncManager")
struct SyncManagerTests {

    private func makeSyncEngine(backend: MockSyncBackendForManager = MockSyncBackendForManager(), queue: InMemorySyncQueue = InMemorySyncQueue()) -> (SyncEngine, MockSyncBackendForManager, InMemorySyncQueue) {
        let engine = SyncEngine(backend: backend, queue: queue, minSyncInterval: 0)
        return (engine, backend, queue)
    }

    @Test("SyncManager initializes with default state")
    @MainActor
    func defaultState() {
        let (engine, _, _) = makeSyncEngine()
        let manager = SyncManager(syncEngine: engine)

        #expect(manager.isSyncing == false)
        #expect(manager.lastSyncDate == nil)
        #expect(manager.pendingChangeCount == 0)
        #expect(manager.error == nil)
        #expect(manager.syncEnabled == true)
    }

    @Test("SyncManager syncNow updates state on success")
    @MainActor
    func syncNowSuccess() async {
        let (engine, _, _) = makeSyncEngine()
        let manager = SyncManager(syncEngine: engine)

        await manager.syncNow()

        #expect(manager.isSyncing == false)
        #expect(manager.lastSyncDate != nil)
        #expect(manager.error == nil)
    }

    @Test("SyncManager syncNow reports authentication error")
    @MainActor
    func syncNowNotAuthenticated() async {
        let backend = MockSyncBackendForManager()
        backend.authenticated = false
        let (engine, _, _) = makeSyncEngine(backend: backend)
        let manager = SyncManager(syncEngine: engine)

        await manager.syncNow()

        #expect(manager.error == "Not signed in to iCloud")
    }

    @Test("SyncManager syncNow reports network error")
    @MainActor
    func syncNowNetworkError() async {
        let backend = MockSyncBackendForManager()
        backend.shouldThrow = true
        let (engine, _, _) = makeSyncEngine(backend: backend)
        let manager = SyncManager(syncEngine: engine)

        await manager.syncNow()

        #expect(manager.error == "Network unavailable")
    }

    @Test("SyncManager trackChange does nothing when disabled")
    @MainActor
    func trackChangeDisabled() async throws {
        let queue = InMemorySyncQueue()
        let (engine, _, _) = makeSyncEngine(queue: queue)
        let manager = SyncManager(syncEngine: engine)
        manager.syncEnabled = false

        manager.trackChange(entityType: .project, entityId: UUID(), changeType: .create)

        // Give the detached task a moment
        try await Task.sleep(for: .milliseconds(50))

        let pending = try await queue.pendingCount()
        #expect(pending == 0)
    }

    @Test("SyncManager trackChange enqueues when enabled")
    @MainActor
    func trackChangeEnabled() async throws {
        let queue = InMemorySyncQueue()
        let (engine, _, _) = makeSyncEngine(queue: queue)
        let manager = SyncManager(syncEngine: engine)

        manager.trackChange(entityType: .task, entityId: UUID(), changeType: .update)

        // Give the detached task a moment
        try await Task.sleep(for: .milliseconds(100))

        let pending = try await queue.pendingCount()
        #expect(pending == 1)
    }

    @Test("SyncManager refreshState reads from engine")
    @MainActor
    func refreshState() async {
        let (engine, _, _) = makeSyncEngine()
        let manager = SyncManager(syncEngine: engine)

        // Do a sync first to set state
        await manager.syncNow()
        // Clear local state
        let savedDate = manager.lastSyncDate

        await manager.refreshState()

        #expect(manager.lastSyncDate == savedDate)
        #expect(manager.isSyncing == false)
    }

    @Test("SyncManager syncNow skips when disabled")
    @MainActor
    func syncNowDisabled() async {
        let (engine, _, _) = makeSyncEngine()
        let manager = SyncManager(syncEngine: engine)
        manager.syncEnabled = false

        await manager.syncNow()

        #expect(manager.lastSyncDate == nil)
    }
}

// MARK: - Mock Backend for SyncManager tests

final class MockSyncBackendForManager: SyncBackendProtocol, @unchecked Sendable {
    var authenticated = true
    var shouldThrow = false
    var pushedChanges: [SyncChange] = []
    var remoteChanges: [SyncChange] = []
    var remotePayloads: [UUID: Data] = [:]
    var newToken: Data? = nil

    func push(changes: [SyncChange], payloads: [UUID: Data]) async throws {
        if shouldThrow { throw SyncError.networkUnavailable }
        pushedChanges.append(contentsOf: changes)
    }

    func pull(since token: Data?) async throws -> (changes: [SyncChange], payloads: [UUID: Data], newToken: Data?) {
        if shouldThrow { throw SyncError.networkUnavailable }
        return (remoteChanges, remotePayloads, newToken)
    }

    func isAuthenticated() async -> Bool {
        authenticated
    }
}
