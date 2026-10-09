import Foundation

/// Errors from the V2 conversation pipeline.
public enum ConversationError: Error, Sendable, Equatable {
    /// No active session exists for this project.
    case noActiveSession
    /// A session is already in progress.
    case sessionAlreadyActive
    /// The session could not be found.
    case sessionNotFound(UUID)
    /// The message could not be sent because the session is not active.
    case sessionNotActive(UUID)
    /// The AI response could not be processed.
    case responseParseFailed(String)
    /// Context assembly failed.
    case contextAssemblyFailed(String)
}
