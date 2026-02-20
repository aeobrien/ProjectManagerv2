import Foundation

/// Which column a task occupies on the Focus Board.
public enum KanbanColumn: String, Codable, Sendable, CaseIterable {
    case toDo
    case inProgress
    case done
}
