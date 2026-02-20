import Foundation

/// Repository for Conversation CRUD and queries.
public protocol ConversationRepositoryProtocol: Sendable {
    func fetchAll(forProject projectId: UUID) async throws -> [Conversation]
    func fetchAll(ofType type: ConversationType) async throws -> [Conversation]
    func fetch(id: UUID) async throws -> Conversation?
    func save(_ conversation: Conversation) async throws
    func delete(id: UUID) async throws
    func appendMessage(_ message: ChatMessage, toConversation conversationId: UUID) async throws
}
