import Foundation

/// The type of AI conversation.
public enum ConversationType: String, Codable, Sendable, CaseIterable {
    case brainDump
    case checkIn
    case checkInQuickLog
    case checkInFull
    case planning
    case onboarding
    case review
    case retrospective
    case reEntry
    case general
}
