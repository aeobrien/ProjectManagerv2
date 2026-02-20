import Testing
import Foundation
@testable import PMData

// MARK: - Mock Sync Backend

final class MockSyncBackend: SyncBackendProtocol, @unchecked Sendable {
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

// MARK: - SyncRecord Tests

@Suite("SyncRecord")
struct SyncRecordTests {

    @Test("SyncChange creation")
    func syncChangeCreation() {
        let change = SyncChange(
            entityType: .project,
            entityId: UUID(),
            changeType: .create
        )
        #expect(change.synced == false)
        #expect(change.entityType == .project)
        #expect(change.changeType == .create)
    }

    @Test("SyncEntityType all cases")
    func entityTypes() {
        let types = SyncEntityType.allCases
        #expect(types.count == 10)
        #expect(types.contains(.project))
        #expect(types.contains(.phase))
        #expect(types.contains(.milestone))
        #expect(types.contains(.task))
        #expect(types.contains(.subtask))
        #expect(types.contains(.checkIn))
        #expect(types.contains(.document))
        #expect(types.contains(.category))
        #expect(types.contains(.conversation))
        #expect(types.contains(.dependency))
    }

    @Test("SyncChangeType raw values")
    func changeTypes() {
        #expect(SyncChangeType.create.rawValue == "create")
        #expect(SyncChangeType.update.rawValue == "update")
        #expect(SyncChangeType.delete.rawValue == "delete")
    }

    @Test("SyncState defaults")
    func syncStateDefaults() {
        let state = SyncState()
        #expect(state.lastSyncDate == nil)
        #expect(state.serverChangeToken == nil)
        #expect(state.pendingChangeCount == 0)
    }

    @Test("ConflictResolution raw values")
    func conflictResolution() {
        #expect(ConflictResolution.lastWriteWins.rawValue == "lastWriteWins")
        #expect(ConflictResolution.keepLocal.rawValue == "keepLocal")
        #expect(ConflictResolution.keepRemote.rawValue == "keepRemote")
        #expect(ConflictResolution.manualMerge.rawValue == "manualMerge")
    }

    @Test("SyncError equality")
    func syncErrorEquality() {
        #expect(SyncError.notAuthenticated == SyncError.notAuthenticated)
        #expect(SyncError.networkUnavailable == SyncError.networkUnavailable)
        #expect(SyncError.quotaExceeded == SyncError.quotaExceeded)
        #expect(SyncError.recordNotFound("A") == SyncError.recordNotFound("A"))
        #expect(SyncError.recordNotFound("A") != SyncError.recordNotFound("B"))
    }

    @Test("SyncChange equatable")
    func syncChangeEquatable() {
        let id = UUID()
        let entityId = UUID()
        let a = SyncChange(id: id, entityType: .project, entityId: entityId, changeType: .create)
        let b = SyncChange(id: id, entityType: .project, entityId: entityId, changeType: .create)
        #expect(a == b)
    }
}

// MARK: - InMemorySyncQueue Tests

@Suite("InMemorySyncQueue")
struct InMemorySyncQueueTests {

    @Test("Enqueue and retrieve pending")
    func enqueueAndPending() async throws {
        let queue = InMemorySyncQueue()
        let change = SyncChange(entityType: .project, entityId: UUID(), changeType: .create)

        try await queue.enqueue(change)

        let pending = try await queue.pendingChanges()
        #expect(pending.count == 1)
        #expect(pending.first?.id == change.id)
    }

    @Test("Mark synced removes from pending")
    func markSynced() async throws {
        let queue = InMemorySyncQueue()
        let change = SyncChange(entityType: .task, entityId: UUID(), changeType: .update)

        try await queue.enqueue(change)
        try await queue.markSynced(ids: [change.id])

        let pending = try await queue.pendingChanges()
        #expect(pending.isEmpty)
    }

    @Test("Pending count")
    func pendingCount() async throws {
        let queue = InMemorySyncQueue()

        try await queue.enqueue(SyncChange(entityType: .project, entityId: UUID(), changeType: .create))
        try await queue.enqueue(SyncChange(entityType: .task, entityId: UUID(), changeType: .update))

        #expect(try await queue.pendingCount() == 2)

        let all = try await queue.pendingChanges()
        try await queue.markSynced(ids: [all[0].id])

        #expect(try await queue.pendingCount() == 1)
    }

    @Test("Purge old synced changes")
    func purge() async throws {
        let queue = InMemorySyncQueue()
        let oldDate = Date(timeIntervalSinceNow: -3600)
        let change = SyncChange(
            entityType: .project, entityId: UUID(), changeType: .create,
            timestamp: oldDate
        )

        try await queue.enqueue(change)
        try await queue.markSynced(ids: [change.id])
        try await queue.purge(before: Date())

        let all = try await queue.allChanges()
        #expect(all.isEmpty)
    }

    @Test("Purge keeps unsynced changes")
    func purgeKeepsUnsynced() async throws {
        let queue = InMemorySyncQueue()
        let change = SyncChange(
            entityType: .project, entityId: UUID(), changeType: .create,
            timestamp: Date(timeIntervalSinceNow: -3600)
        )

        try await queue.enqueue(change)
        try await queue.purge(before: Date())

        let all = try await queue.allChanges()
        #expect(all.count == 1)
    }
}

// MARK: - ConflictResolver Tests

@Suite("ConflictResolver")
struct ConflictResolverTests {

    @Test("Last write wins — local newer")
    func localNewer() {
        let resolver = ConflictResolver()
        let conflict = SyncConflict(
            entityType: .project,
            entityId: UUID(),
            localTimestamp: Date(),
            remoteTimestamp: Date(timeIntervalSinceNow: -100)
        )
        let resolution = resolver.resolve(conflict)
        #expect(resolution == .keepLocal)
    }

    @Test("Last write wins — remote newer")
    func remoteNewer() {
        let resolver = ConflictResolver()
        let conflict = SyncConflict(
            entityType: .project,
            entityId: UUID(),
            localTimestamp: Date(timeIntervalSinceNow: -100),
            remoteTimestamp: Date()
        )
        let resolution = resolver.resolve(conflict)
        #expect(resolution == .keepRemote)
    }

    @Test("Document close timestamps trigger manual merge")
    func documentManualMerge() {
        let resolver = ConflictResolver()
        let now = Date()
        let conflict = SyncConflict(
            entityType: .document,
            entityId: UUID(),
            localTimestamp: now,
            remoteTimestamp: now.addingTimeInterval(30) // 30 seconds apart
        )
        let resolution = resolver.resolve(conflict, threshold: 60)
        #expect(resolution == .manualMerge)
    }

    @Test("Document far timestamps use last write wins")
    func documentFarTimestamps() {
        let resolver = ConflictResolver()
        let conflict = SyncConflict(
            entityType: .document,
            entityId: UUID(),
            localTimestamp: Date(),
            remoteTimestamp: Date(timeIntervalSinceNow: -3600)
        )
        let resolution = resolver.resolve(conflict, threshold: 60)
        #expect(resolution == .keepLocal)
    }
}

// MARK: - SyncEngine Tests

@Suite("SyncEngine")
struct SyncEngineTests {

    @Test("Track change enqueues to queue")
    func trackChange() async throws {
        let backend = MockSyncBackend()
        let queue = InMemorySyncQueue()
        let engine = SyncEngine(backend: backend, queue: queue)

        try await engine.trackChange(entityType: .project, entityId: UUID(), changeType: .create)

        let pending = try await queue.pendingCount()
        #expect(pending == 1)
    }

    @Test("Sync pushes pending changes")
    func syncPushes() async throws {
        let backend = MockSyncBackend()
        let queue = InMemorySyncQueue()
        let engine = SyncEngine(backend: backend, queue: queue, minSyncInterval: 0)

        try await engine.trackChange(entityType: .project, entityId: UUID(), changeType: .create)
        try await engine.sync()

        #expect(backend.pushedChanges.count == 1)
        let pending = try await queue.pendingCount()
        #expect(pending == 0)
    }

    @Test("Sync fails when not authenticated")
    func syncNotAuthenticated() async throws {
        let backend = MockSyncBackend()
        backend.authenticated = false
        let queue = InMemorySyncQueue()
        let engine = SyncEngine(backend: backend, queue: queue, minSyncInterval: 0)

        await #expect(throws: SyncError.self) {
            try await engine.sync()
        }
    }

    @Test("Sync updates server change token")
    func syncUpdatesToken() async throws {
        let backend = MockSyncBackend()
        backend.newToken = Data([1, 2, 3])
        let queue = InMemorySyncQueue()
        let engine = SyncEngine(backend: backend, queue: queue, minSyncInterval: 0)

        try await engine.sync()

        let state = await engine.currentState()
        #expect(state.serverChangeToken == Data([1, 2, 3]))
    }

    @Test("Sync respects minimum interval")
    func syncRespectsInterval() async throws {
        let backend = MockSyncBackend()
        let queue = InMemorySyncQueue()
        let engine = SyncEngine(backend: backend, queue: queue, minSyncInterval: 60)

        // First sync succeeds
        try await engine.sync()

        // Track a change and try to sync again immediately
        try await engine.trackChange(entityType: .task, entityId: UUID(), changeType: .update)
        try await engine.sync() // Should be skipped due to interval

        // The change should still be pending (not pushed)
        let pending = try await queue.pendingCount()
        #expect(pending == 1)
    }

    @Test("Sync pulls remote changes")
    func syncPulls() async throws {
        let backend = MockSyncBackend()
        backend.remoteChanges = [
            SyncChange(entityType: .project, entityId: UUID(), changeType: .update, synced: true)
        ]
        let queue = InMemorySyncQueue()
        let engine = SyncEngine(backend: backend, queue: queue, minSyncInterval: 0)

        try await engine.sync()

        let state = await engine.currentState()
        #expect(state.lastSyncDate != nil)
    }

    @Test("Network error propagates")
    func networkError() async throws {
        let backend = MockSyncBackend()
        backend.shouldThrow = true
        let queue = InMemorySyncQueue()
        let engine = SyncEngine(backend: backend, queue: queue, minSyncInterval: 0)

        try await engine.trackChange(entityType: .project, entityId: UUID(), changeType: .create)

        await #expect(throws: SyncError.self) {
            try await engine.sync()
        }
    }

    @Test("Reset state clears sync state")
    func resetState() async {
        let backend = MockSyncBackend()
        let queue = InMemorySyncQueue()
        let engine = SyncEngine(
            backend: backend, queue: queue,
            syncState: SyncState(lastSyncDate: Date(), serverChangeToken: Data([1]))
        )

        await engine.resetState()

        let state = await engine.currentState()
        #expect(state.lastSyncDate == nil)
        #expect(state.serverChangeToken == nil)
    }

    @Test("isSyncInProgress reports false when idle")
    func syncNotInProgress() async {
        let backend = MockSyncBackend()
        let queue = InMemorySyncQueue()
        let engine = SyncEngine(backend: backend, queue: queue)

        let inProgress = await engine.isSyncInProgress()
        #expect(inProgress == false)
    }
}
