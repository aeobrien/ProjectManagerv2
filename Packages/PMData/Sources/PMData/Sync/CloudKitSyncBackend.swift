import Foundation
import CloudKit
import PMUtilities
import os

/// CloudKit-based implementation of SyncBackendProtocol.
public final class CloudKitSyncBackend: SyncBackendProtocol, @unchecked Sendable {
    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    /// The record zone name used for sync.
    public static let zoneName = "ProjectManagerSync"

    public init(containerIdentifier: String? = nil) {
        if let id = containerIdentifier {
            self.container = CKContainer(identifier: id)
        } else {
            self.container = CKContainer.default()
        }
        self.database = container.privateCloudDatabase
        self.zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Zone Setup

    /// Ensure the custom record zone exists.
    public func ensureZoneExists() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        let _ = try await database.modifyRecordZones(saving: [zone], deleting: [])
    }

    // MARK: - SyncBackendProtocol

    public func push(changes: [SyncChange], payloads: [UUID: Data]) async throws {
        var recordsToSave: [CKRecord] = []
        var recordIDsToDelete: [CKRecord.ID] = []

        for change in changes {
            let recordID = CKRecord.ID(recordName: change.entityId.uuidString, zoneID: zoneID)

            switch change.changeType {
            case .create, .update:
                let record = CKRecord(recordType: change.entityType.rawValue, recordID: recordID)
                record["entityType"] = change.entityType.rawValue
                record["changeType"] = change.changeType.rawValue
                record["timestamp"] = change.timestamp as CKRecordValue

                if let payload = payloads[change.entityId] {
                    record["payload"] = payload as CKRecordValue
                }

                recordsToSave.append(record)
            case .delete:
                recordIDsToDelete.append(recordID)
            }
        }

        let _ = try await database.modifyRecords(
            saving: recordsToSave,
            deleting: recordIDsToDelete,
            savePolicy: .changedKeys
        )

        Log.data.info("CloudKit: pushed \(recordsToSave.count) saves, \(recordIDsToDelete.count) deletes")
    }

    public func pull(since token: Data?) async throws -> (changes: [SyncChange], payloads: [UUID: Data], newToken: Data?) {
        var serverChangeToken: CKServerChangeToken?
        if let tokenData = token {
            serverChangeToken = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: tokenData
            )
        }

        var fetchedChanges: [SyncChange] = []
        var fetchedPayloads: [UUID: Data] = [:]

        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        config.previousServerChangeToken = serverChangeToken

        let results = try await database.recordZoneChanges(
            inZoneWith: zoneID,
            since: serverChangeToken
        )
        let modificationResultsByID = results.modificationResultsByID
        let newChangeToken = results.changeToken

        for result in modificationResultsByID {
            guard let record = try? result.value.get().record else { continue }

            let entityId = UUID(uuidString: record.recordID.recordName) ?? UUID()
            let entityType = SyncEntityType(rawValue: record.recordType) ?? .project
            let changeType: SyncChangeType = .update
            let timestamp = (record["timestamp"] as? Date) ?? record.modificationDate ?? Date()

            let change = SyncChange(
                entityType: entityType,
                entityId: entityId,
                changeType: changeType,
                timestamp: timestamp,
                synced: true
            )
            fetchedChanges.append(change)

            if let payload = record["payload"] as? Data {
                fetchedPayloads[entityId] = payload
            }
        }

        let newTokenData = try NSKeyedArchiver.archivedData(
            withRootObject: newChangeToken,
            requiringSecureCoding: true
        )

        Log.data.info("CloudKit: pulled \(fetchedChanges.count) changes")
        return (fetchedChanges, fetchedPayloads, newTokenData)
    }

    public func isAuthenticated() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }
}
