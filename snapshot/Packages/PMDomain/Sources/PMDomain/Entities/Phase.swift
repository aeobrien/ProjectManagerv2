import Foundation

/// A broad stage of a project's lifecycle, representing a meaningful chapter of work.
public struct Phase: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var name: String
    public var sortOrder: Int
    public var status: PhaseStatus
    public var definitionOfDone: String
    public var retrospectiveNotes: String?
    public var retrospectiveCompletedAt: Date?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        name: String,
        sortOrder: Int = 0,
        status: PhaseStatus = .notStarted,
        definitionOfDone: String = "",
        retrospectiveNotes: String? = nil,
        retrospectiveCompletedAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.sortOrder = sortOrder
        self.status = status
        self.definitionOfDone = definitionOfDone
        self.retrospectiveNotes = retrospectiveNotes
        self.retrospectiveCompletedAt = retrospectiveCompletedAt
    }
}
