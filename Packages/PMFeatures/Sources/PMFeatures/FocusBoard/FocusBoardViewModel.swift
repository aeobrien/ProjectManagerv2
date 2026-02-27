import Foundation
import PMData
import PMDomain
import PMDesignSystem
import PMServices
import PMUtilities
import os

/// ViewModel for the Focus Board — Kanban-style view of focused projects and their tasks.
@Observable
@MainActor
public final class FocusBoardViewModel {
    // MARK: - State

    public private(set) var focusedProjects: [Project] = []
    public private(set) var categories: [PMDomain.Category] = []
    public private(set) var tasksByProject: [UUID: [PMTask]] = [:]
    public private(set) var milestoneNameByTaskId: [UUID: String] = [:]
    public private(set) var healthByProject: [UUID: ProjectHealthSignals] = [:]
    public private(set) var diversityViolations: [DiversityViolation] = []
    public private(set) var subtasksByTaskId: [UUID: [Subtask]] = [:]
    public private(set) var isLoading = false
    public private(set) var error: String?

    /// Per-project check-in urgency computed during load.
    public private(set) var urgencyByProject: [UUID: CheckInUrgency] = [:]
    /// Per-project last check-in record for use by CheckInView.
    public private(set) var lastCheckInByProject: [UUID: CheckInRecord] = [:]

    /// Per-project toggle to show all tasks (bypassing curation).
    public var showAllTasks: Set<UUID> = []

    /// Session-based effort type filter (nil = show all).
    public var effortTypeFilter: EffortType? = nil

    /// User-configurable max visible tasks per project.
    public var maxVisibleTasks: Int = FocusManager.defaultMaxVisibleTasks

    /// Done column retention settings.
    public var doneRetentionDays: Int = 7
    public var doneMaxItems: Int = 20

    // MARK: - Dependencies

    private let projectRepo: ProjectRepositoryProtocol
    private let categoryRepo: CategoryRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let subtaskRepo: SubtaskRepositoryProtocol
    private let checkInRepo: CheckInRepositoryProtocol

    /// Optional check-in flow manager for computing urgency and navigating to check-ins.
    public var checkInFlowManager: CheckInFlowManager?

    /// Optional sync manager for tracking changes.
    public var syncManager: SyncManager?

    /// Optional notification manager for scheduling notifications.
    public var notificationManager: NotificationManager?

    // MARK: - Init

    public init(
        projectRepo: ProjectRepositoryProtocol,
        categoryRepo: CategoryRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        subtaskRepo: SubtaskRepositoryProtocol,
        checkInRepo: CheckInRepositoryProtocol,
        checkInFlowManager: CheckInFlowManager? = nil
    ) {
        self.projectRepo = projectRepo
        self.categoryRepo = categoryRepo
        self.taskRepo = taskRepo
        self.milestoneRepo = milestoneRepo
        self.phaseRepo = phaseRepo
        self.subtaskRepo = subtaskRepo
        self.checkInRepo = checkInRepo
        self.checkInFlowManager = checkInFlowManager
    }

    // MARK: - Loading

    public func load() async {
        isLoading = true
        error = nil
        do {
            focusedProjects = try await projectRepo.fetchFocused()
            categories = try await categoryRepo.fetchAll()

            var tMap: [UUID: [PMTask]] = [:]
            var hMap: [UUID: ProjectHealthSignals] = [:]
            var msNames: [UUID: String] = [:]
            var uMap: [UUID: CheckInUrgency] = [:]
            var ciMap: [UUID: CheckInRecord] = [:]
            var stMap: [UUID: [Subtask]] = [:]

            for project in focusedProjects {
                // Gather all tasks across all milestones in all phases
                let phases = try await phaseRepo.fetchAll(forProject: project.id)
                var allTasks: [PMTask] = []
                for phase in phases {
                    let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
                    for ms in milestones {
                        let tasks = try await taskRepo.fetchAll(forMilestone: ms.id)
                        for task in tasks {
                            msNames[task.id] = ms.name
                        }
                        allTasks.append(contentsOf: tasks)
                    }
                }
                // Load subtasks per task
                for task in allTasks {
                    let subtasks = try await subtaskRepo.fetchAll(forTask: task.id)
                    if !subtasks.isEmpty {
                        stMap[task.id] = subtasks
                    }
                }

                tMap[project.id] = allTasks

                // Health signals
                let lastCheckIn = try await checkInRepo.fetchLatest(forProject: project.id)
                hMap[project.id] = FocusManager.healthSignals(
                    project: project,
                    tasks: allTasks,
                    lastCheckInDate: lastCheckIn?.timestamp
                )

                // Check-in urgency
                if let manager = checkInFlowManager {
                    uMap[project.id] = manager.urgency(for: project, lastCheckIn: lastCheckIn)
                    if let lastCheckIn {
                        ciMap[project.id] = lastCheckIn
                    }
                }
            }

            tasksByProject = tMap
            milestoneNameByTaskId = msNames
            subtasksByTaskId = stMap
            healthByProject = hMap
            urgencyByProject = uMap
            lastCheckInByProject = ciMap
            diversityViolations = FocusManager.diversityViolations(focusedProjects: focusedProjects)

            // Schedule notifications for approaching deadlines and check-in reminders
            if let nm = notificationManager {
                for project in focusedProjects {
                    // Deadline approaching notifications
                    let tasks = tMap[project.id] ?? []
                    for task in tasks {
                        if let deadline = task.deadline {
                            let hoursUntil = Calendar.current.dateComponents([.hour], from: Date(), to: deadline).hour ?? 0
                            if hoursUntil > 0 && hoursUntil <= 24 {
                                let notif = NotificationManager.deadlineApproaching(
                                    name: task.name, projectName: project.name,
                                    deadline: deadline, entityId: task.id
                                )
                                _ = try? await nm.scheduleIfAllowed(notif)
                            }
                        }
                    }

                    // Check-in reminder notifications
                    let urgency = uMap[project.id] ?? .none
                    if urgency != .none {
                        let notif = NotificationManager.checkInReminder(
                            projectName: project.name, projectId: project.id
                        )
                        _ = try? await nm.scheduleIfAllowed(notif)
                    }
                }
            }

            Log.focus.info("Focus Board loaded: \(self.focusedProjects.count) projects")
        } catch is CancellationError {
            // View was dismissed during async load — not a real error
            return
        } catch {
            self.error = error.localizedDescription
            Log.focus.error("Failed to load Focus Board: \(error)")
        }
        isLoading = false
    }

    // MARK: - Task Curation

    /// Returns curated tasks for a project's ToDo column.
    public func toDoTasks(for projectId: UUID) -> [PMTask] {
        let all = tasksByProject[projectId] ?? []
        var tasks = all.filter { $0.kanbanColumn == .toDo }

        // Apply effort type filter
        if let filter = effortTypeFilter {
            tasks = tasks.filter { $0.effortType == filter }
        }

        // Curate unless "show all" is toggled for this project
        if showAllTasks.contains(projectId) {
            return tasks.sorted { $0.sortOrder < $1.sortOrder }
        }

        return FocusManager.curateVisibleTasks(tasks: tasks, maxVisible: maxVisibleTasks)
    }

    /// Returns tasks in the In Progress column, respecting effort type filter.
    public func inProgressTasks(for projectId: UUID) -> [PMTask] {
        let all = tasksByProject[projectId] ?? []
        var tasks = all.filter { $0.kanbanColumn == .inProgress }

        if let filter = effortTypeFilter {
            tasks = tasks.filter { $0.effortType == filter }
        }

        return tasks.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Returns tasks in the Done column, respecting retention settings.
    public func doneTasks(for projectId: UUID) -> [PMTask] {
        let all = tasksByProject[projectId] ?? []
        let now = Date()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -doneRetentionDays, to: now) ?? now

        var done = all.filter { $0.kanbanColumn == .done }
            .filter { task in
                guard let completedAt = task.completedAt else { return true }
                return completedAt >= cutoffDate
            }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

        if done.count > doneMaxItems {
            done = Array(done.prefix(doneMaxItems))
        }

        return done
    }

    /// Total task count for a project's ToDo column (before curation).
    public func totalToDoCount(for projectId: UUID) -> Int {
        let all = tasksByProject[projectId] ?? []
        return all.filter { $0.kanbanColumn == .toDo && $0.status != .completed }.count
    }

    // MARK: - Focus/Unfocus

    public func focusProject(_ project: Project) async {
        guard let updated = FocusManager.focus(project: project, currentFocused: focusedProjects) else {
            error = "Cannot focus project: eligibility check failed"
            return
        }
        do {
            try await projectRepo.save(updated)
            syncManager?.trackChange(entityType: .project, entityId: project.id, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func unfocusProject(_ project: Project, to destination: LifecycleState = .queued) async {
        let updated = FocusManager.unfocus(project: project, to: destination)
        do {
            try await projectRepo.save(updated)
            syncManager?.trackChange(entityType: .project, entityId: project.id, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    /// Force-focus a project despite diversity violation (override).
    public func forceFocusProject(_ project: Project) async {
        var updated = project
        let usedSlots = Set(focusedProjects.compactMap(\.focusSlotIndex))
        let nextSlot = (0..<FocusManager.maxFocusedProjects).first { !usedSlots.contains($0) }
        guard let slot = nextSlot else {
            error = "No available focus slots"
            return
        }
        updated.focusSlotIndex = slot
        updated.lifecycleState = .focused
        do {
            try await projectRepo.save(updated)
            syncManager?.trackChange(entityType: .project, entityId: project.id, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    // MARK: - Task Column Movement

    public func moveTask(_ task: PMTask, to column: KanbanColumn) async {
        var updated = task
        updated.kanbanColumn = column

        if column == .done {
            updated.status = .completed
            updated.completedAt = Date()
        } else if column == .inProgress {
            updated.status = .inProgress
            updated.completedAt = nil
        } else {
            if updated.status == .completed {
                updated.status = .notStarted
                updated.completedAt = nil
            }
        }

        do {
            try await taskRepo.save(updated)
            syncManager?.trackChange(entityType: .task, entityId: task.id, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    /// Move a task identified by UUID to the given kanban column (used by drag-and-drop).
    public func moveTaskById(_ taskId: UUID, to column: KanbanColumn) async {
        // Search raw task list (not filtered) to ensure we find the task
        for project in focusedProjects {
            let allTasks = tasksByProject[project.id] ?? []
            if let task = allTasks.first(where: { $0.id == taskId }) {
                Log.focus.info("moveTaskById: found task '\(task.name)' in project '\(project.name)', moving to \(column.displayName)")
                await moveTask(task, to: column)
                return
            }
        }
        Log.focus.error("moveTaskById: task \(taskId) not found in any project")
    }

    // MARK: - Task Status Actions

    /// Block a task with a type and reason.
    public func blockTask(_ task: PMTask, type: BlockedType, reason: String) async {
        var updated = task
        updated.status = .blocked
        updated.kanbanColumn = ItemStatus.blocked.kanbanColumn
        updated.blockedType = type
        updated.blockedReason = reason
        do {
            try await taskRepo.save(updated)
            syncManager?.trackChange(entityType: .task, entityId: task.id, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    /// Set a task to waiting with a reason.
    public func setWaiting(_ task: PMTask, reason: String) async {
        var updated = task
        updated.status = .waiting
        updated.kanbanColumn = ItemStatus.waiting.kanbanColumn
        updated.waitingReason = reason
        do {
            try await taskRepo.save(updated)
            syncManager?.trackChange(entityType: .task, entityId: task.id, changeType: .update)

            // Schedule waiting check-back notification
            if let nm = notificationManager {
                let projectName = focusedProjects.first(where: { tasksByProject[$0.id]?.contains(where: { $0.id == task.id }) == true })?.name ?? "Project"
                let notif = NotificationManager.waitingCheckBack(taskName: task.name, projectName: projectName, taskId: task.id)
                _ = try? await nm.scheduleIfAllowed(notif)
            }

            await load()
        } catch { self.error = error.localizedDescription }
    }

    /// Unblock a task, returning it to the To Do column.
    public func unblockTask(_ task: PMTask) async {
        var updated = task
        updated.status = .notStarted
        updated.kanbanColumn = .toDo
        updated.blockedType = nil
        updated.blockedReason = nil
        updated.waitingReason = nil
        updated.waitingCheckBackDate = nil
        do {
            try await taskRepo.save(updated)
            syncManager?.trackChange(entityType: .task, entityId: task.id, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    // MARK: - Task Editing

    /// Update a task's properties (name, deadline, priority, effort, etc).
    public func updateTask(_ task: PMTask) async {
        do {
            try await taskRepo.save(task)
            syncManager?.trackChange(entityType: .task, entityId: task.id, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    // MARK: - Subtask Actions

    /// Toggle a subtask's completion state.
    public func toggleSubtask(_ subtask: Subtask) async {
        var updated = subtask
        updated.isCompleted.toggle()
        do {
            try await subtaskRepo.save(updated)
            syncManager?.trackChange(entityType: .task, entityId: subtask.taskId, changeType: .update)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    // MARK: - Health Signal Badges

    public func healthBadges(for projectId: UUID) -> [HealthSignalType] {
        guard let health = healthByProject[projectId] else { return [] }
        var badges: [HealthSignalType] = []

        if health.isStale, let days = health.daysSinceCheckIn {
            badges.append(.stale(days: days))
        }
        if health.blockedTaskCount > 0 {
            badges.append(.blockedTasks(count: health.blockedTaskCount))
        }
        if health.overdueTaskCount > 0 {
            badges.append(.overdueTasks(count: health.overdueTaskCount))
        }
        if health.frequentlyDeferredCount > 0 {
            badges.append(.frequentlyDeferred(count: health.frequentlyDeferredCount))
        }
        if let days = health.daysSinceCheckIn, days > 7 {
            badges.append(.checkInOverdue(days: days))
        }

        return badges
    }

    // MARK: - Helpers

    public func categoryName(for project: Project) -> String {
        categories.first { $0.id == project.categoryId }?.name ?? "Unknown"
    }

    public func toggleShowAll(for projectId: UUID) {
        if showAllTasks.contains(projectId) {
            showAllTasks.remove(projectId)
        } else {
            showAllTasks.insert(projectId)
        }
    }
}
