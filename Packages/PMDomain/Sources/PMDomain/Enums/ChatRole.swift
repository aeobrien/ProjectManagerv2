import Foundation

/// The role of a participant in a chat conversation.
public enum ChatRole: String, Codable, Sendable, CaseIterable {
    case user
    case assistant
}
