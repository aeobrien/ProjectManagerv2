import Foundation

/// An optional further breakdown of a task into atomic steps.
public struct Subtask: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var taskId: UUID
    public var name: String
    public var sortOrder: Int
    public var isCompleted: Bool
    public var definitionOfDone: String

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        name: String,
        sortOrder: Int = 0,
        isCompleted: Bool = false,
        definitionOfDone: String = ""
    ) {
        self.id = id
        self.taskId = taskId
        self.name = name
        self.sortOrder = sortOrder
        self.isCompleted = isCompleted
        self.definitionOfDone = definitionOfDone
    }
}
