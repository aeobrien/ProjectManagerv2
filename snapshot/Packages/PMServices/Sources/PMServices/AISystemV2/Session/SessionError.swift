import Foundation

/// Errors related to session lifecycle operations.
public enum SessionError: Error, LocalizedError, Sendable {
    case sessionNotFound
    case invalidTransition(from: String, to: String)
    case activeSessionExists(sessionId: UUID)

    public var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "The requested session was not found."
        case .invalidTransition(let from, let to):
            return "Cannot transition session from '\(from)' to '\(to)'."
        case .activeSessionExists(let sessionId):
            return "An active session already exists (ID: \(sessionId))."
        }
    }
}

/// Errors related to summary generation.
public enum SummaryError: Error, Sendable {
    case noMessages
    case parseFailed(String)
}
