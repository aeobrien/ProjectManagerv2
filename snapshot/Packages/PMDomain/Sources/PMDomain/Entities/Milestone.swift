import Foundation

/// A meaningful, concrete deliverable or achievement within a phase.
public struct Milestone: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var phaseId: UUID
    public var name: String
    public var sortOrder: Int
    public var status: ItemStatus
    public var definitionOfDone: String
    public var deadline: Date?
    public var priority: Priority
    public var waitingReason: String?
    public var waitingCheckBackDate: Date?
    public var notes: String?

    public init(
        id: UUID = UUID(),
        phaseId: UUID,
        name: String,
        sortOrder: Int = 0,
        status: ItemStatus = .notStarted,
        definitionOfDone: String = "",
        deadline: Date? = nil,
        priority: Priority = .normal,
        waitingReason: String? = nil,
        waitingCheckBackDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.phaseId = phaseId
        self.name = name
        self.sortOrder = sortOrder
        self.status = status
        self.definitionOfDone = definitionOfDone
        self.deadline = deadline
        self.priority = priority
        self.waitingReason = waitingReason
        self.waitingCheckBackDate = waitingCheckBackDate
        self.notes = notes
    }
}
