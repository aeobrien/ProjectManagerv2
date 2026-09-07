import Foundation
import PMDomain
import PMUtilities
import os

/// A milestone with its parent project info for cross-project display.
public struct CrossProjectMilestone: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let milestoneName: String
    public let projectName: String
    public let projectId: UUID
    public let deadline: Date?
    public let status: ItemStatus
    public let colorIndex: Int  // For project colour-coding
    public let totalTasks: Int
    public let completedTasks: Int
    public let inProgressTasks: Int

    /// Computed status based on task progress rather than the milestone's own status field.
    public var computedStatus: ItemStatus {
        guard totalTasks > 0 else { return status }
        if completedTasks == totalTasks { return .completed }
        if completedTasks > 0 || inProgressTasks > 0 { return .inProgress }
        return .notStarted
    }

    public init(
        id: UUID,
        milestoneName: String,
        projectName: String,
        projectId: UUID,
        deadline: Date?,
        status: ItemStatus,
        colorIndex: Int,
        totalTasks: Int = 0,
        completedTasks: Int = 0,
        inProgressTasks: Int = 0
    ) {
        self.id = id
        self.milestoneName = milestoneName
        self.projectName = projectName
        self.projectId = projectId
        self.deadline = deadline
        self.status = status
        self.colorIndex = colorIndex
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.inProgressTasks = inProgressTasks
    }
}

/// ViewModel for the cross-project roadmap view.
@Observable
@MainActor
public final class CrossProjectRoadmapViewModel {
    // MARK: - State

    public private(set) var milestones: [CrossProjectMilestone] = []
    public private(set) var isLoading = false
    public private(set) var error: String?

    /// Milestones grouped by project.
    public var milestonesByProject: [UUID: [CrossProjectMilestone]] {
        Dictionary(grouping: milestones, by: \.projectId)
    }

    /// Milestones with deadlines, sorted by deadline (soonest first).
    public var upcomingDeadlines: [CrossProjectMilestone] {
        milestones.filter { $0.deadline != nil }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }

    /// Milestones without deadlines.
    public var unscheduled: [CrossProjectMilestone] {
        milestones.filter { $0.deadline == nil }
    }

    /// Count of unique projects.
    public var projectCount: Int {
        Set(milestones.map(\.projectId)).count
    }

    /// Milestones that are overdue (past deadline, not completed).
    public var overdue: [CrossProjectMilestone] {
        milestones.filter { ms in
            guard let deadline = ms.deadline, ms.computedStatus != .completed else { return false }
            return deadline < Date()
        }
    }

    // MARK: - Dependencies

    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol

    // MARK: - Init

    public init(
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol
    ) {
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.milestoneRepo = milestoneRepo
        self.taskRepo = taskRepo
    }

    // MARK: - Loading

    /// Load milestones from all focused projects.
    public func load() async {
        isLoading = true
        error = nil

        do {
            let focusedProjects = try await projectRepo.fetchFocused()
            var allMilestones: [CrossProjectMilestone] = []

            for (index, project) in focusedProjects.enumerated() {
                let phases = try await phaseRepo.fetchAll(forProject: project.id)
                for phase in phases {
                    let projectMilestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
                    for ms in projectMilestones {
                        let tasks = try await taskRepo.fetchAll(forMilestone: ms.id)
                        let completedCount = tasks.filter { $0.status == .completed }.count
                        let inProgressCount = tasks.filter { $0.status == .inProgress }.count
                        allMilestones.append(CrossProjectMilestone(
                            id: ms.id,
                            milestoneName: ms.name,
                            projectName: project.name,
                            projectId: project.id,
                            deadline: ms.deadline,
                            status: ms.status,
                            colorIndex: index % 5,  // Cycle through 5 SlotColours
                            totalTasks: tasks.count,
                            completedTasks: completedCount,
                            inProgressTasks: inProgressCount
                        ))
                    }
                }
            }

            // Sort: deadlines first (ascending), then unscheduled
            milestones = allMilestones.sorted { a, b in
                switch (a.deadline, b.deadline) {
                case let (aDate?, bDate?): return aDate < bDate
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return a.milestoneName < b.milestoneName
                }
            }

            Log.ui.info("Cross-project roadmap loaded: \(self.milestones.count) milestones from \(focusedProjects.count) projects")
        } catch {
            self.error = "Failed to load roadmap: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Filter milestones by computed status (derived from task progress).
    public func milestones(with status: ItemStatus) -> [CrossProjectMilestone] {
        milestones.filter { $0.computedStatus == status }
    }
}
