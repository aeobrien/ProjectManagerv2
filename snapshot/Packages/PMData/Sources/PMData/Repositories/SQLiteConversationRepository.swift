import Foundation
import GRDB
import PMDomain

public final class SQLiteConversationRepository: ConversationRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetchAll(forProject projectId: UUID) async throws -> [Conversation] {
        try await db.read { db in
            var conversations = try Conversation
                .filter(Column("projectId") == projectId)
                .order(Column("updatedAt").desc)
                .fetchAll(db)

            for i in conversations.indices {
                conversations[i].messages = try ChatMessageRecord
                    .filter(Column("conversationId") == conversations[i].id)
                    .order(Column("timestamp"))
                    .fetchAll(db)
                    .map { $0.toDomain() }
            }
            return conversations
        }
    }

    public func fetchAll(ofType type: ConversationType) async throws -> [Conversation] {
        try await db.read { db in
            var conversations = try Conversation
                .filter(Column("conversationType") == type.rawValue)
                .order(Column("updatedAt").desc)
                .fetchAll(db)

            for i in conversations.indices {
                conversations[i].messages = try ChatMessageRecord
                    .filter(Column("conversationId") == conversations[i].id)
                    .order(Column("timestamp"))
                    .fetchAll(db)
                    .map { $0.toDomain() }
            }
            return conversations
        }
    }

    public func fetch(id: UUID) async throws -> Conversation? {
        try await db.read { db in
            guard var conversation = try Conversation.fetchOne(db, key: id) else {
                return nil
            }
            conversation.messages = try ChatMessageRecord
                .filter(Column("conversationId") == id)
                .order(Column("timestamp"))
                .fetchAll(db)
                .map { $0.toDomain() }
            return conversation
        }
    }

    public func save(_ conversation: Conversation) async throws {
        try await db.write { db in
            try conversation.save(db)

            // Delete existing messages and re-insert
            try ChatMessageRecord.filter(Column("conversationId") == conversation.id).deleteAll(db)
            for message in conversation.messages {
                let record = ChatMessageRecord(message: message, conversationId: conversation.id)
                try record.insert(db)
            }
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try Conversation.deleteOne(db, key: id)
        }
    }

    public func appendMessage(_ message: ChatMessage, toConversation conversationId: UUID) async throws {
        try await db.write { db in
            let record = ChatMessageRecord(message: message, conversationId: conversationId)
            try record.insert(db)
            // Update conversation's updatedAt
            if var conversation = try Conversation.fetchOne(db, key: conversationId) {
                conversation.updatedAt = Date()
                try conversation.update(db)
            }
        }
    }
}
