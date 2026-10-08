import Foundation

/// The kind of energy a task requires. Used for AI suggestions
/// and Focus Board filtering.
public enum EffortType: String, Codable, Sendable, CaseIterable {
    /// Sustained concentration, problem-solving, coding, writing
    case deepFocus
    /// Open-ended, generative, exploratory
    case creative
    /// Emails, forms, organising, scheduling
    case administrative
    /// Phone calls, messages, reaching out
    case communication
    /// Hands-on work, building, cleaning
    case physical
    /// Small, low-effort, momentum tasks
    case quickWin
}
