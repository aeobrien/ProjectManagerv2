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

// MARK: - Session Conformances

extension Session: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "session"

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["projectId"] = projectId
        container["mode"] = mode.rawValue
        container["subMode"] = subMode?.rawValue
        container["status"] = status.rawValue
        container["createdAt"] = createdAt
        container["lastActiveAt"] = lastActiveAt
        container["completedAt"] = completedAt
        container["summaryId"] = summaryId
    }

    public init(row: Row) throws {
        let modeString: String = row["mode"]
        let subModeString: String? = row["subMode"]
        let statusString: String = row["status"]
        self.init(
            id: row["id"],
            projectId: row["projectId"],
            mode: SessionMode(rawValue: modeString) ?? .exploration,
            subMode: subModeString.flatMap { SessionSubMode(rawValue: $0) },
            status: SessionStatus(rawValue: statusString) ?? .active,
            createdAt: row["createdAt"],
            lastActiveAt: row["lastActiveAt"],
            completedAt: row["completedAt"],
            summaryId: row["summaryId"]
        )
    }
}

extension SessionMessage: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "sessionMessage"

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["sessionId"] = sessionId
        container["role"] = role.rawValue
        container["content"] = content
        container["timestamp"] = timestamp
        container["rawVoiceTranscript"] = rawVoiceTranscript
    }

    public init(row: Row) throws {
        let roleString: String = row["role"]
        self.init(
            id: row["id"],
            sessionId: row["sessionId"],
            role: ChatRole(rawValue: roleString) ?? .user,
            content: row["content"],
            timestamp: row["timestamp"],
            rawVoiceTranscript: row["rawVoiceTranscript"]
        )
    }
}
