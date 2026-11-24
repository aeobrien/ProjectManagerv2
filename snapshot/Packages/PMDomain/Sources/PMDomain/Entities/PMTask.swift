import Foundation

/// A concrete, practical action that advances a milestone.
/// Named `PMTask` to avoid conflict with Swift's `Task` type.
public struct PMTask: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var milestoneId: UUID
    public var name: String
    public var sortOrder: Int
    public var status: ItemStatus
    public var definitionOfDone: String
    public var isTimeboxed: Bool
    public var timeEstimateMinutes: Int?
    public var adjustedEstimateMinutes: Int?
    public var actualMinutes: Int?
    public var timeboxMinutes: Int?
    public var deadline: Date?
    public var priority: Priority
    public var effortType: EffortType?
    public var blockedType: BlockedType?
    public var blockedReason: String?
    public var waitingReason: String?
    public var waitingCheckBackDate: Date?
    public var completedAt: Date?
    public var timesDeferred: Int
    public var notes: String?
    public var kanbanColumn: KanbanColumn

    public init(
        id: UUID = UUID(),
        milestoneId: UUID,
        name: String,
        sortOrder: Int = 0,
        status: ItemStatus = .notStarted,
        definitionOfDone: String = "",
        isTimeboxed: Bool = false,
        timeEstimateMinutes: Int? = nil,
        adjustedEstimateMinutes: Int? = nil,
        actualMinutes: Int? = nil,
        timeboxMinutes: Int? = nil,
        deadline: Date? = nil,
        priority: Priority = .normal,
        effortType: EffortType? = nil,
        blockedType: BlockedType? = nil,
        blockedReason: String? = nil,
        waitingReason: String? = nil,
        waitingCheckBackDate: Date? = nil,
        completedAt: Date? = nil,
        timesDeferred: Int = 0,
        notes: String? = nil,
        kanbanColumn: KanbanColumn = .toDo
    ) {
        self.id = id
        self.milestoneId = milestoneId
        self.name = name
        self.sortOrder = sortOrder
        self.status = status
        self.definitionOfDone = definitionOfDone
        self.isTimeboxed = isTimeboxed
        self.timeEstimateMinutes = timeEstimateMinutes
        self.adjustedEstimateMinutes = adjustedEstimateMinutes
        self.actualMinutes = actualMinutes
        self.timeboxMinutes = timeboxMinutes
        self.deadline = deadline
        self.priority = priority
        self.effortType = effortType
        self.blockedType = blockedType
        self.blockedReason = blockedReason
        self.waitingReason = waitingReason
        self.waitingCheckBackDate = waitingCheckBackDate
        self.completedAt = completedAt
        self.timesDeferred = timesDeferred
        self.notes = notes
        self.kanbanColumn = kanbanColumn
    }
}

extension PMTask {
    /// Returns the effective deadline: the task's own deadline, or a fallback from the milestone.
    public func effectiveDeadline(milestoneDeadline: Date?) -> Date? {
        deadline ?? milestoneDeadline
    }

    /// Whether the task is approaching its deadline (within the given number of days).
    public func isApproachingDeadline(milestoneDeadline: Date?, withinDays: Int = 3, now: Date = Date()) -> Bool {
        guard let effective = effectiveDeadline(milestoneDeadline: milestoneDeadline) else { return false }
        guard status != .completed else { return false }
        let daysUntil = Calendar.current.dateComponents([.day], from: now, to: effective).day ?? 0
        return daysUntil >= 0 && daysUntil <= withinDays
    }

    /// Whether the task is overdue.
    public func isOverdue(milestoneDeadline: Date?, now: Date = Date()) -> Bool {
        guard let effective = effectiveDeadline(milestoneDeadline: milestoneDeadline) else { return false }
        guard status != .completed else { return false }
        return effective < now
    }

    /// Whether this task has been deferred enough times to flag as frequently deferred.
    public func isFrequentlyDeferred(threshold: Int = 3) -> Bool {
        timesDeferred >= threshold
    }
}
