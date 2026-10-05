import Foundation
import GRDB
import PMDomain

/// A ChatMessage with its parent conversationId for database storage.
/// The domain ChatMessage doesn't store conversationId (it's implicit via Conversation.messages).
/// This wrapper adds it for the relational schema.
struct ChatMessageRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "chatMessage"

    var id: UUID
    var conversationId: UUID
    var role: ChatRole
    var content: String
    var timestamp: Date
    var rawVoiceTranscript: String?

    init(message: ChatMessage, conversationId: UUID) {
        self.id = message.id
        self.conversationId = conversationId
        self.role = message.role
        self.content = message.content
        self.timestamp = message.timestamp
        self.rawVoiceTranscript = message.rawVoiceTranscript
    }

    func toDomain() -> ChatMessage {
        ChatMessage(
            id: id,
            role: role,
            content: content,
            timestamp: timestamp,
            rawVoiceTranscript: rawVoiceTranscript
        )
    }
}
