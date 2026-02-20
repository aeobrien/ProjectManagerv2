import Foundation

/// The depth of a check-in conversation.
public enum CheckInDepth: String, Codable, Sendable, CaseIterable {
    /// Brief update, AI confirms and applies. Under 2 minutes.
    case quickLog
    /// Deeper discussion with probing, pattern detection. 10-20 minutes.
    case fullConversation
}
