import Foundation
import PMDomain
import PMDesignSystem
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
    public private(set) var healthByProject: [UUID: ProjectHealthSignals] = [:]
    public private(set) var diversityViolations: [DiversityViolation] = []
    public private(set) var isLoading = false
    public private(set) var error: String?

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
    private let checkInRepo: CheckInRepositoryProtocol

    // MARK: - Init

    public init(
        projectRepo: ProjectRepositoryProtocol,
        categoryRepo: CategoryRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        checkInRepo: CheckInRepositoryProtocol
    ) {
        self.projectRepo = projectRepo
        self.categoryRepo = categoryRepo
        self.taskRepo = taskRepo
        self.milestoneRepo = milestoneRepo
        self.phaseRepo = phaseRepo
        self.checkInRepo = checkInRepo
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

            for project in focusedProjects {
                // Gather all tasks across all milestones in all phases
                let phases = try await phaseRepo.fetchAll(forProject: project.id)
                var allTasks: [PMTask] = []
                for phase in phases {
                    let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
                    for ms in milestones {
                        let tasks = try await taskRepo.fetchAll(forMilestone: ms.id)
                        allTasks.append(contentsOf: tasks)
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
            }

            tasksByProject = tMap
            healthByProject = hMap
            diversityViolations = FocusManager.diversityViolations(focusedProjects: focusedProjects)

            Log.focus.info("Focus Board loaded: \(self.focusedProjects.count) projects")
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

    /// Returns tasks in the In Progress column.
    public func inProgressTasks(for projectId: UUID) -> [PMTask] {
        let all = tasksByProject[projectId] ?? []
        return all.filter { $0.kanbanColumn == .inProgress }
            .sorted { $0.sortOrder < $1.sortOrder }
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
            await load()
        } catch { self.error = error.localizedDescription }
    }

    public func unfocusProject(_ project: Project, to destination: LifecycleState = .queued) async {
        let updated = FocusManager.unfocus(project: project, to: destination)
        do {
            try await projectRepo.save(updated)
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
