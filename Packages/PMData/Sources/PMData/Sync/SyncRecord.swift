import Foundation

/// Represents a local change that needs to be synced to CloudKit.
public struct SyncChange: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let entityType: SyncEntityType
    public let entityId: UUID
    public let changeType: SyncChangeType
    public let timestamp: Date
    public var synced: Bool

    public init(
        id: UUID = UUID(),
        entityType: SyncEntityType,
        entityId: UUID,
        changeType: SyncChangeType,
        timestamp: Date = Date(),
        synced: Bool = false
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.changeType = changeType
        self.timestamp = timestamp
        self.synced = synced
    }
}

/// Types of entities that can be synced.
public enum SyncEntityType: String, Sendable, Codable, CaseIterable {
    case project
    case phase
    case milestone
    case task
    case subtask
    case checkIn
    case document
    case category
    case conversation
    case dependency
}

/// Types of changes to sync.
public enum SyncChangeType: String, Sendable, Codable {
    case create
    case update
    case delete
}

/// Tracks the last sync state for incremental sync.
public struct SyncState: Equatable, Sendable, Codable {
    public var lastSyncDate: Date?
    public var serverChangeToken: Data?
    public var pendingChangeCount: Int

    public init(
        lastSyncDate: Date? = nil,
        serverChangeToken: Data? = nil,
        pendingChangeCount: Int = 0
    ) {
        self.lastSyncDate = lastSyncDate
        self.serverChangeToken = serverChangeToken
        self.pendingChangeCount = pendingChangeCount
    }
}

/// Represents a conflict between local and remote versions.
public struct SyncConflict: Identifiable, Sendable {
    public let id: UUID
    public let entityType: SyncEntityType
    public let entityId: UUID
    public let localTimestamp: Date
    public let remoteTimestamp: Date
    public let resolution: ConflictResolution

    public init(
        id: UUID = UUID(),
        entityType: SyncEntityType,
        entityId: UUID,
        localTimestamp: Date,
        remoteTimestamp: Date,
        resolution: ConflictResolution = .lastWriteWins
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.localTimestamp = localTimestamp
        self.remoteTimestamp = remoteTimestamp
        self.resolution = resolution
    }
}

/// How to resolve a sync conflict.
public enum ConflictResolution: String, Sendable, Codable {
    case lastWriteWins       // Default for most fields
    case keepLocal           // User explicitly chose local
    case keepRemote          // User explicitly chose remote
    case manualMerge         // For document content with close timestamps
}

/// Errors from the sync system.
public enum SyncError: Error, Sendable, Equatable {
    case notAuthenticated
    case networkUnavailable
    case recordNotFound(String)
    case conflictDetected(String)
    case quotaExceeded
    case serverError(String)
    case encodingError(String)
}
