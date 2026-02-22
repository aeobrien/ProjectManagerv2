import Foundation
import GRDB
import PMDomain

// MARK: - GRDB Record Conformances
// Domain entities are already Codable. GRDB provides automatic
// FetchableRecord and PersistableRecord for Codable types.
// We just declare conformance and set table names.
// @retroactive silences warnings about cross-module conformances
// (we own both modules, so this is safe).

extension PMDomain.Category: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "category"
}

extension Project: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "project"
}

extension Phase: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "phase"
}

extension Milestone: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "milestone"
}

extension PMTask: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "pmTask"
}

extension Subtask: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "subtask"
}

extension Document: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "document"
}

extension DocumentVersion: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "documentVersion"
}

extension Dependency: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "dependency"
}

extension CheckInRecord: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "checkInRecord"
}

extension Conversation: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "conversation"

    // Conversation stores messages separately in chatMessage table,
    // not inline. Override encoding to exclude the messages array.
    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["projectId"] = projectId
        container["conversationType"] = conversationType.rawValue
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }

    // Override decoding to load without messages (loaded separately).
    public init(row: Row) throws {
        let typeString: String = row["conversationType"]
        self.init(
            id: row["id"],
            projectId: row["projectId"],
            conversationType: ConversationType(rawValue: typeString) ?? .general,
            messages: [],
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }
}

extension ChatMessage: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "chatMessage"
}
