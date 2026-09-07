import Foundation

/// A persisted AI conversation.
public struct Conversation: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var projectId: UUID?
    public var conversationType: ConversationType
    public var messages: [ChatMessage]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        projectId: UUID? = nil,
        conversationType: ConversationType,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.conversationType = conversationType
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// A single message in an AI conversation.
public struct ChatMessage: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var role: ChatRole
    public var content: String
    public var timestamp: Date
    public var rawVoiceTranscript: String?

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        timestamp: Date = Date(),
        rawVoiceTranscript: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.rawVoiceTranscript = rawVoiceTranscript
    }
}
