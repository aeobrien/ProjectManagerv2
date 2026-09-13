import Foundation

/// The status of a milestone or task.
public enum ItemStatus: String, Codable, Sendable, CaseIterable {
    case notStarted
    case inProgress
    case blocked
    case waiting
    case completed

    public var displayName: String {
        switch self {
        case .notStarted: "Not Started"
        case .inProgress: "In Progress"
        case .blocked: "Blocked"
        case .waiting: "Waiting"
        case .completed: "Completed"
        }
    }

    /// The kanban column this status maps to.
    /// Blocked/waiting tasks stay in To Do (they're not actively being worked on).
    public var kanbanColumn: KanbanColumn {
        switch self {
        case .notStarted, .blocked, .waiting: .toDo
        case .inProgress: .inProgress
        case .completed: .done
        }
    }
}
