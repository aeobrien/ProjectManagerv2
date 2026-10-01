import Foundation

/// A single message in an AI session.
public struct SessionMessage: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var sessionId: UUID
    public var role: ChatRole
    public var content: String
    public var timestamp: Date
    public var rawVoiceTranscript: String?

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        role: ChatRole,
        content: String,
        timestamp: Date = Date(),
        rawVoiceTranscript: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.rawVoiceTranscript = rawVoiceTranscript
    }
}
