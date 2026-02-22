import Foundation
import PMData
import PMDomain
import PMServices
import PMUtilities
import os

/// ViewModel for viewing and editing a project's full hierarchy.
@Observable
@MainActor
public final class ProjectDetailViewModel {
    // MARK: - State

    public private(set) var project: Project
    public private(set) var phases: [Phase] = []
    public private(set) var milestonesByPhase: [UUID: [Milestone]] = [:]
    public private(set) var tasksByMilestone: [UUID: [PMTask]] = [:]
    public private(set) var subtasksByTask: [UUID: [Subtask]] = [:]
    public private(set) var dependencies: [Dependency] = []
    public private(set) var isLoading = false
    public private(set) var error: String?

    /// Expansion state for the roadmap hierarchy — persisted across tab switches.
    public var expandedPhases: Set<UUID> = []
    public var expandedMilestones: Set<UUID> = []
    public var expandedTasks: Set<UUID> = []

    /// Phase that just completed all milestones and needs a retrospective.
    public private(set) var phaseNeedingRetrospective: Phase?

    /// Optional retrospective flow manager for phase completion detection.
    public var retrospectiveManager: RetrospectiveFlowManager?

    /// Optional knowledge base manager for incremental indexing of task notes.
    public var knowledgeBaseManager: KnowledgeBaseManager?

    /// Optional sync manager for tracking changes to CloudKit.
    public var syncManager: SyncManager?

    /// Optional notification manager for scheduling notifications.
    public var notificationManager: NotificationManager?

    // MARK: - Dependencies

    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let subtaskRepo: SubtaskRepositoryProtocol
    private let dependencyRepo: DependencyRepositoryProtocol

    // MARK: - Init

    public init(
        project: Project,
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        subtaskRepo: SubtaskRepositoryProtocol,
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
            // Reload project in case it changed
            if let updated = try await projectRepo.fetch(id: project.id) {
                project = updated
            }

            phases = try await phaseRepo.fetchAll(forProject: project.id)

            var msMap: [UUID: [Milestone]] = [:]
            var tMap: [UUID: [PMTask]] = [:]
            var sMap: [UUID: [Subtask]] = [:]

            for phase in phases {
                let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
                msMap[phase.id] = milestones

                for milestone in milestones {
                    let tasks = try await taskRepo.fetchAll(forMilestone: milestone.id)
                    tMap[milestone.id] = tasks

                    for task in tasks {
                        let subtasks = try await subtaskRepo.fetchAll(forTask: task.id)
                        sMap[task.id] = subtasks
                    }
                }
            }

            milestonesByPhase = msMap
            tasksByMilestone = tMap
            subtasksByTask = sMap

            // Load dependencies for this project's hierarchy
            dependencies = []
            for phase in phases {
                for milestone in msMap[phase.id] ?? [] {
                    let msDeps = try await dependencyRepo.fetchAll(forTarget: milestone.id, targetType: .milestone)
                    dependencies.append(contentsOf: msDeps)
                    for task in tMap[milestone.id] ?? [] {
                        let tDeps = try await dependencyRepo.fetchAll(forTarget: task.id, targetType: .task)
                        dependencies.append(contentsOf: tDeps)
                    }
                }
            }

            Log.ui.info("Loaded hierarchy for '\(self.project.name)': \(self.phases.count) phases")

            // Check for phases needing retrospective
            await checkForCompletedPhases()
        } catch {
            self.error = error.localizedDescription
            Log.ui.error("Failed to load project hierarchy: \(error)")
        }
        isLoading = false
    }

    /// Scan phases for one that has all milestones completed and no retrospective yet.
    public func checkForCompletedPhases() async {
        guard let manager = retrospectiveManager else { return }
        phaseNeedingRetrospective = nil
        for phase in phases {
            if await manager.checkPhaseCompletion(phase) {
                phaseNeedingRetrospective = phase
                manager.promptRetrospective(for: phase)

                // Schedule phase completion notification
                if let nm = notificationManager {
                    let notif = NotificationManager.phaseCompleted(
                        phaseName: phase.name, projectName: project.name, phaseId: phase.id
                    )
                    _ = try? await nm.scheduleIfAllowed(notif)
                }

                Log.ui.info("Phase '\(phase.name)' needs retrospective")
                break
            }
        }
    }

    /// Dismiss the retrospective prompt (user chose to skip or snooze was handled by the manager).
    public func dismissRetrospectivePrompt() {
        phaseNeedingRetrospective = nil
    }

    // MARK: - Phase CRUD

    public func createPhase(name: String) async {
        let sortOrder = phases.count
        let phase = Phase(projectId: project.id, name: name, sortOrder: sortOrder)
        do {
            try await phaseRepo.save(phase)
            syncManager?.trackChange(entityType: .phase, entityId: phase.id, changeType: .create)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func updatePhase(_ phase: Phase) async {
        do {
            try await phaseRepo.save(phase)
            syncManager?.trackChange(entityType: .phase, entityId: phase.id, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func deletePhase(_ phase: Phase) async {
        do {
            try await phaseRepo.delete(id: phase.id)
            syncManager?.trackChange(entityType: .phase, entityId: phase.id, changeType: .delete)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func reorderPhases(_ reordered: [Phase]) async {
        var updated = reordered
        for i in updated.indices { updated[i].sortOrder = i }
        do {
            try await phaseRepo.reorder(phases: updated)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    // MARK: - Milestone CRUD

    public func createMilestone(in phaseId: UUID, name: String, priority: Priority = .normal, deadline: Date? = nil) async {
        let existing = milestonesByPhase[phaseId] ?? []
        let milestone = Milestone(phaseId: phaseId, name: name, sortOrder: existing.count, deadline: deadline, priority: priority)
        do {
            try await milestoneRepo.save(milestone)
            syncManager?.trackChange(entityType: .milestone, entityId: milestone.id, changeType: .create)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func updateMilestone(_ milestone: Milestone) async {
        do {
            try await milestoneRepo.save(milestone)
            syncManager?.trackChange(entityType: .milestone, entityId: milestone.id, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func deleteMilestone(_ milestone: Milestone) async {
        do {
            try await milestoneRepo.delete(id: milestone.id)
            syncManager?.trackChange(entityType: .milestone, entityId: milestone.id, changeType: .delete)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func reorderMilestones(_ reordered: [Milestone]) async {
        var updated = reordered
        for i in updated.indices { updated[i].sortOrder = i }
        do {
            try await milestoneRepo.reorder(milestones: updated)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    // MARK: - Task CRUD

    public func createTask(
        in milestoneId: UUID,
        name: String,
        effortType: EffortType? = nil,
        priority: Priority = .normal,
        timeEstimateMinutes: Int? = nil,
        isTimeboxed: Bool = false,
        timeboxMinutes: Int? = nil
    ) async {
        let existing = tasksByMilestone[milestoneId] ?? []
        let task = PMTask(
            milestoneId: milestoneId,
            name: name,
            sortOrder: existing.count,
            timeEstimateMinutes: timeEstimateMinutes,
            timeboxMinutes: isTimeboxed ? timeboxMinutes : nil,
            priority: priority,
            effortType: effortType
        )
        do {
            try await taskRepo.save(task)
            syncManager?.trackChange(entityType: .task, entityId: task.id, changeType: .create)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func updateTask(_ task: PMTask) async {
        let errors = Validation.validate(task: task)
        guard errors.isEmpty else {
            self.error = "Validation failed: \(errors)"
            return
        }
        do {
            try await taskRepo.save(task)
            syncManager?.trackChange(entityType: .task, entityId: task.id, changeType: .update)

            // Index task notes in knowledge base if present
            if let kb = knowledgeBaseManager, task.notes != nil {
                let projectId = project.id
                Task.detached {
                    do {
                        try await kb.indexTaskNotes(projectId: projectId, task: task)
                    } catch {
                        Log.ai.error("Failed to index task notes in KB: \(error)")
                    }
                }
            }

            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func deleteTask(_ task: PMTask) async {
        do {
            try await taskRepo.delete(id: task.id)
            syncManager?.trackChange(entityType: .task, entityId: task.id, changeType: .delete)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func reorderTasks(_ reordered: [PMTask]) async {
        var updated = reordered
        for i in updated.indices { updated[i].sortOrder = i }
        do {
            try await taskRepo.reorder(tasks: updated)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    /// Mark a task as blocked with a type and reason.
    public func blockTask(_ task: PMTask, type: BlockedType, reason: String) async {
        var updated = task
        updated.status = .blocked
        updated.kanbanColumn = ItemStatus.blocked.kanbanColumn
        updated.blockedType = type
        updated.blockedReason = reason
        await updateTask(updated)
    }

    /// Mark a task as waiting with a reason and optional check-back date.
    public func waitTask(_ task: PMTask, reason: String, checkBackDate: Date?) async {
        var updated = task
        updated.status = .waiting
        updated.kanbanColumn = ItemStatus.waiting.kanbanColumn
        updated.waitingReason = reason
        updated.waitingCheckBackDate = checkBackDate
        await updateTask(updated)

        // Schedule waiting check-back notification
        if let nm = notificationManager {
            let notif = NotificationManager.waitingCheckBack(taskName: task.name, projectName: project.name, taskId: task.id)
            _ = try? await nm.scheduleIfAllowed(notif)
        }
    }

    /// Unblock a task, returning it to in-progress.
    public func unblockTask(_ task: PMTask) async {
        var updated = task
        updated.status = .inProgress
        updated.kanbanColumn = ItemStatus.inProgress.kanbanColumn
        updated.blockedType = nil
        updated.blockedReason = nil
        updated.waitingReason = nil
        updated.waitingCheckBackDate = nil
        await updateTask(updated)
    }

    // MARK: - Subtask CRUD

    public func createSubtask(in taskId: UUID, name: String) async {
        let existing = subtasksByTask[taskId] ?? []
        let subtask = Subtask(taskId: taskId, name: name, sortOrder: existing.count)
        do {
            try await subtaskRepo.save(subtask)
            syncManager?.trackChange(entityType: .subtask, entityId: subtask.id, changeType: .create)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func toggleSubtask(_ subtask: Subtask) async {
        var updated = subtask
        updated.isCompleted.toggle()
        do {
            try await subtaskRepo.save(updated)
            syncManager?.trackChange(entityType: .subtask, entityId: updated.id, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func updateSubtask(_ subtask: Subtask) async {
        do {
            try await subtaskRepo.save(subtask)
            syncManager?.trackChange(entityType: .subtask, entityId: subtask.id, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func deleteSubtask(_ subtask: Subtask) async {
        do {
            try await subtaskRepo.delete(id: subtask.id)
            syncManager?.trackChange(entityType: .subtask, entityId: subtask.id, changeType: .delete)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    // MARK: - Dependencies

    public func addDependency(sourceType: DependableType, sourceId: UUID, targetType: DependableType, targetId: UUID) async {
        let dep = Dependency(sourceType: sourceType, sourceId: sourceId, targetType: targetType, targetId: targetId)
        do {
            try await dependencyRepo.save(dep)
            syncManager?.trackChange(entityType: .dependency, entityId: dep.id, changeType: .create)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func removeDependency(_ dep: Dependency) async {
        do {
            try await dependencyRepo.delete(id: dep.id)
            syncManager?.trackChange(entityType: .dependency, entityId: dep.id, changeType: .delete)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    /// Check if a milestone or task has unmet dependencies (advisory warning).
    public func hasUnmetDependencies(targetId: UUID) -> Bool {
        let deps = dependencies.filter { $0.targetId == targetId }
        guard !deps.isEmpty else { return false }

        for dep in deps {
            switch dep.sourceType {
            case .milestone:
                let allMilestones = milestonesByPhase.values.flatMap { $0 }
                if let source = allMilestones.first(where: { $0.id == dep.sourceId }),
                   source.status != .completed {
                    return true
                }
            case .task:
                let allTasks = tasksByMilestone.values.flatMap { $0 }
                if let source = allTasks.first(where: { $0.id == dep.sourceId }),
                   source.status != .completed {
                    return true
                }
            }
        }
        return false
    }
}
