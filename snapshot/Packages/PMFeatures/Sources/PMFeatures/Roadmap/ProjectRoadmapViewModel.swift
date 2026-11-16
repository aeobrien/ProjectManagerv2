import Foundation
import PMDomain
import PMDesignSystem
import PMUtilities
import os

/// A flattened roadmap item for display in the timeline.
public struct RoadmapItem: Identifiable, Sendable {
    public enum Kind: Sendable { case phase, milestone, task }

    public let id: UUID
    public let kind: Kind
    public let name: String
    public let status: ItemStatus
    public let phaseStatus: PhaseStatus?
    public let priority: Priority
    public let effortType: EffortType?
    public let deadline: Date?
    public let progress: Double // 0...1
    public let depth: Int // 0 = phase, 1 = milestone, 2 = task
    public let hasUnmetDependencies: Bool
    public let parentId: UUID? // phase or milestone parent
}

/// ViewModel for the project roadmap — loads hierarchy and computes dependency state.
@Observable
@MainActor
public final class ProjectRoadmapViewModel {
    // MARK: - State

    public private(set) var project: Project
    public private(set) var items: [RoadmapItem] = []
    public private(set) var dependencies: [Dependency] = []
    public private(set) var isLoading = false
    public private(set) var error: String?

    /// Map from target ID to source IDs for dependency arrows.
    public private(set) var dependencyTargets: [UUID: [UUID]] = [:]

    // MARK: - Dependencies

    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let subtaskRepo: SubtaskRepositoryProtocol?
    private let dependencyRepo: DependencyRepositoryProtocol

    // MARK: - Init

    public init(
        project: Project,
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        subtaskRepo: SubtaskRepositoryProtocol? = nil,
        dependencyRepo: DependencyRepositoryProtocol
    ) {
        self.project = project
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.milestoneRepo = milestoneRepo
        self.taskRepo = taskRepo
        self.subtaskRepo = subtaskRepo
        self.dependencyRepo = dependencyRepo
    }

    // MARK: - Loading

    public func load() async {
        isLoading = true
        error = nil
        do {
            if let updated = try await projectRepo.fetch(id: project.id) {
                project = updated
            }

            let phases = try await phaseRepo.fetchAll(forProject: project.id)
            var flatItems: [RoadmapItem] = []
            var allMilestoneIds: [UUID] = []
            var allTaskIds: [UUID] = []
            var milestoneStatusMap: [UUID: ItemStatus] = [:]
            var taskStatusMap: [UUID: ItemStatus] = [:]

            // First pass: collect all IDs and statuses for dependency resolution
            for phase in phases {
                let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
                for ms in milestones {
                    allMilestoneIds.append(ms.id)
                    milestoneStatusMap[ms.id] = ms.status
                    let tasks = try await taskRepo.fetchAll(forMilestone: ms.id)
                    for task in tasks {
                        allTaskIds.append(task.id)
                        taskStatusMap[task.id] = task.status
                    }
                }
            }

            // Load dependencies
            var allDeps: [Dependency] = []
            var depTargetMap: [UUID: [UUID]] = [:]

            for msId in allMilestoneIds {
                let deps = try await dependencyRepo.fetchAll(forTarget: msId, targetType: .milestone)
                allDeps.append(contentsOf: deps)
                if !deps.isEmpty {
                    depTargetMap[msId] = deps.map(\.sourceId)
                }
            }
            for taskId in allTaskIds {
                let deps = try await dependencyRepo.fetchAll(forTarget: taskId, targetType: .task)
                allDeps.append(contentsOf: deps)
                if !deps.isEmpty {
                    depTargetMap[taskId] = deps.map(\.sourceId)
                }
            }

            dependencies = allDeps
            dependencyTargets = depTargetMap

            // Second pass: build flattened items
            for phase in phases {
                let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)

                // Phase progress
                let msCompleted = milestones.filter { $0.status == .completed }.count
                let phaseProgress = milestones.isEmpty ? 0.0 : Double(msCompleted) / Double(milestones.count)

                flatItems.append(RoadmapItem(
                    id: phase.id,
                    kind: .phase,
                    name: phase.name,
                    status: phaseStatusToItemStatus(phase.status),
                    phaseStatus: phase.status,
                    priority: .normal,
                    effortType: nil,
                    deadline: nil,
                    progress: phaseProgress,
                    depth: 0,
                    hasUnmetDependencies: false,
                    parentId: nil
                ))

                for ms in milestones {
                    let tasks = try await taskRepo.fetchAll(forMilestone: ms.id)
                    let taskCompleted = tasks.filter { $0.status == .completed }.count
                    let msProgress = tasks.isEmpty ? 0.0 : Double(taskCompleted) / Double(tasks.count)

                    let msUnmet = hasUnmetDeps(
                        targetId: ms.id,
                        depTargetMap: depTargetMap,
                        milestoneStatuses: milestoneStatusMap,
                        taskStatuses: taskStatusMap
                    )

                    flatItems.append(RoadmapItem(
                        id: ms.id,
                        kind: .milestone,
                        name: ms.name,
                        status: ms.status,
                        phaseStatus: nil,
                        priority: ms.priority,
                        effortType: nil,
                        deadline: ms.deadline,
                        progress: msProgress,
                        depth: 1,
                        hasUnmetDependencies: msUnmet,
                        parentId: phase.id
                    ))

                    for task in tasks {
                        let taskUnmet = hasUnmetDeps(
                            targetId: task.id,
                            depTargetMap: depTargetMap,
                            milestoneStatuses: milestoneStatusMap,
                            taskStatuses: taskStatusMap
                        )

                        // Compute task progress from subtasks if available
                        var taskProgress: Double
                        if task.status == .completed {
                            taskProgress = 1.0
                        } else if let subtaskRepo {
                            let subtasks = (try? await subtaskRepo.fetchAll(forTask: task.id)) ?? []
                            if subtasks.isEmpty {
                                taskProgress = 0.0
                            } else {
                                let done = subtasks.filter(\.isCompleted).count
                                taskProgress = Double(done) / Double(subtasks.count)
                            }
                        } else {
                            taskProgress = 0.0
                        }

                        flatItems.append(RoadmapItem(
                            id: task.id,
                            kind: .task,
                            name: task.name,
                            status: task.status,
                            phaseStatus: nil,
                            priority: task.priority,
                            effortType: task.effortType,
                            deadline: task.deadline,
                            progress: taskProgress,
                            depth: 2,
                            hasUnmetDependencies: taskUnmet,
                            parentId: ms.id
                        ))
                    }
                }
            }

            items = flatItems
            Log.ui.info("Roadmap loaded: \(flatItems.count) items, \(allDeps.count) dependencies")
        } catch {
            self.error = error.localizedDescription
            Log.ui.error("Failed to load roadmap: \(error)")
        }
        isLoading = false
    }

    // MARK: - Computed

    /// Returns dependency source names for a given target item.
    public func dependencySourceNames(for targetId: UUID) -> [String] {
        guard let sourceIds = dependencyTargets[targetId] else { return [] }
        return sourceIds.compactMap { sourceId in
            items.first { $0.id == sourceId }?.name
        }
    }

    /// Number of items per kind.
    public var phaseCount: Int { items.filter { $0.kind == .phase }.count }
    public var milestoneCount: Int { items.filter { $0.kind == .milestone }.count }
    public var taskCount: Int { items.filter { $0.kind == .task }.count }

    /// Overall project progress based on milestone completion.
    public var overallProgress: Double {
        let milestones = items.filter { $0.kind == .milestone }
        guard !milestones.isEmpty else { return 0 }
        let completed = milestones.filter { $0.status == .completed }.count
        return Double(completed) / Double(milestones.count)
    }

    // MARK: - Helpers

    private func phaseStatusToItemStatus(_ status: PhaseStatus) -> ItemStatus {
        switch status {
        case .notStarted: .notStarted
        case .inProgress: .inProgress
        case .completed: .completed
        }
    }

    private func hasUnmetDeps(
        targetId: UUID,
        depTargetMap: [UUID: [UUID]],
        milestoneStatuses: [UUID: ItemStatus],
        taskStatuses: [UUID: ItemStatus]
    ) -> Bool {
        guard let sourceIds = depTargetMap[targetId] else { return false }
        for sourceId in sourceIds {
            if let status = milestoneStatuses[sourceId], status != .completed { return true }
            if let status = taskStatuses[sourceId], status != .completed { return true }
        }
        return false
    }
}
