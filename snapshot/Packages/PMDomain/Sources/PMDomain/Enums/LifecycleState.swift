import Foundation

/// The lifecycle state of a project.
public enum LifecycleState: String, Codable, Sendable, CaseIterable {
    /// On the Focus Board, actively being worked on
    case focused
    /// Planned, structured, and ready for a focus slot
    case queued
    /// Captured (possibly via Quick Capture) but not yet planned
    case idea
    /// All work done (or current work cycle done for ongoing projects)
    case completed
    /// Temporarily shelved with a recorded reason
    case paused
    /// Honestly shelved with optional reflection
    case abandoned
}
