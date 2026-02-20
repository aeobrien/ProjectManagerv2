import Foundation

extension ClosedRange where Bound: Comparable {
    func clamping(_ value: Bound) -> Bound {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}

/// Pure business logic for Focus Board slot management.
/// No persistence — operates on in-memory collections.
public struct FocusManager: Sendable {

    /// Maximum number of focused projects.
    public static let maxFocusedProjects = 5

    /// Maximum number of projects from the same category on the Focus Board.
    public static let maxPerCategory = 2

    /// Default number of visible tasks per project on the Focus Board.
    public static let defaultMaxVisibleTasks = 3

    /// Valid range for user-configurable maxVisibleTasksPerProject.
    public static let visibleTasksRange = 1...10

    // MARK: - Slot Management

    /// Whether a new project can be added to the Focus Board.
    public static func canFocus(
        project: Project,
        currentFocused: [Project]
    ) -> FocusEligibility {
        // Check slot count
        if currentFocused.count >= maxFocusedProjects {
            return .ineligible(reason: .boardFull)
        }

        // Check category diversity
        let sameCategoryCount = currentFocused.filter { $0.categoryId == project.categoryId }.count
        if sameCategoryCount >= maxPerCategory {
            return .ineligible(reason: .categoryLimitReached)
        }

        // Check project isn't already focused
        if currentFocused.contains(where: { $0.id == project.id }) {
            return .ineligible(reason: .alreadyFocused)
        }

        // Check valid lifecycle state for focusing
        guard project.lifecycleState == .queued || project.lifecycleState == .idea else {
            return .ineligible(reason: .invalidState)
        }

        return .eligible
    }

    /// Assigns a project to the next available focus slot.
    /// Returns the updated project with focusSlotIndex and lifecycle state set to .focused.
    public static func focus(
        project: Project,
        currentFocused: [Project]
    ) -> Project? {
        guard case .eligible = canFocus(project: project, currentFocused: currentFocused) else {
            return nil
        }

        let usedSlots = Set(currentFocused.compactMap(\.focusSlotIndex))
        let nextSlot = (0..<maxFocusedProjects).first { !usedSlots.contains($0) } ?? currentFocused.count

        var updated = project
        updated.focusSlotIndex = nextSlot
        updated.lifecycleState = .focused
        return updated
    }

    /// Removes a project from the Focus Board.
    /// Returns the updated project moved to the given destination state.
    public static func unfocus(
        project: Project,
        to destination: LifecycleState = .queued
    ) -> Project {
        var updated = project
        updated.focusSlotIndex = nil
        updated.lifecycleState = destination
        return updated
    }

    // MARK: - Task Visibility Curation

    /// Curates which tasks to show for a focused project.
    /// Prioritises: in-progress first, then by priority, then by sort order.
    /// Returns at most `maxVisible` tasks.
    public static func curateVisibleTasks(
        tasks: [PMTask],
        maxVisible: Int = defaultMaxVisibleTasks
    ) -> [PMTask] {
        let clampedMax = visibleTasksRange.clamping(maxVisible)
        let actionable = tasks.filter { $0.status != .completed }

        let sorted = actionable.sorted { a, b in
            // In-progress tasks come first
            if a.status == .inProgress && b.status != .inProgress { return true }
            if b.status == .inProgress && a.status != .inProgress { return false }

            // Then by priority (high > normal > low)
            if a.priority != b.priority { return a.priority.sortValue < b.priority.sortValue }

            // Then by sort order
            return a.sortOrder < b.sortOrder
        }

        return Array(sorted.prefix(clampedMax))
    }

    // MARK: - Health Signals

    /// Computes health signals for a focused project.
    public static func healthSignals(
        project: Project,
        tasks: [PMTask],
        lastCheckInDate: Date?,
        now: Date = Date()
    ) -> ProjectHealthSignals {
        let isStale = project.isStale(now: now)
        let daysSinceCheckIn = project.daysSinceCheckIn(lastCheckInDate: lastCheckInDate, now: now)
        let blockedTasks = tasks.filter { $0.status == .blocked }
        let frequentlyDeferred = tasks.filter { $0.isFrequentlyDeferred() }
        let overdueTasks = tasks.filter { $0.isOverdue(milestoneDeadline: nil, now: now) }

        return ProjectHealthSignals(
            isStale: isStale,
            daysSinceCheckIn: daysSinceCheckIn,
            blockedTaskCount: blockedTasks.count,
            frequentlyDeferredCount: frequentlyDeferred.count,
            overdueTaskCount: overdueTasks.count
        )
    }

    // MARK: - Diversity Check

    /// Checks whether the current Focus Board satisfies diversity constraints.
    public static func diversityViolations(focusedProjects: [Project]) -> [DiversityViolation] {
        var violations: [DiversityViolation] = []

        // Group by category
        let grouped = Dictionary(grouping: focusedProjects) { $0.categoryId }
        for (categoryId, projects) in grouped where projects.count > maxPerCategory {
            violations.append(DiversityViolation(
                categoryId: categoryId,
                projectCount: projects.count,
                limit: maxPerCategory
            ))
        }

        return violations
    }
}

// MARK: - Supporting Types

/// Result of checking whether a project can be focused.
public enum FocusEligibility: Equatable, Sendable {
    case eligible
    case ineligible(reason: FocusIneligibilityReason)
}

/// Reason a project cannot be focused.
public enum FocusIneligibilityReason: Equatable, Sendable {
    case boardFull
    case categoryLimitReached
    case alreadyFocused
    case invalidState
}

/// Aggregated health signals for a focused project.
public struct ProjectHealthSignals: Equatable, Sendable {
    public let isStale: Bool
    public let daysSinceCheckIn: Int?
    public let blockedTaskCount: Int
    public let frequentlyDeferredCount: Int
    public let overdueTaskCount: Int

    public var needsAttention: Bool {
        isStale || blockedTaskCount > 0 || frequentlyDeferredCount > 0 || overdueTaskCount > 0
    }
}

/// A violation of the category diversity constraint.
public struct DiversityViolation: Equatable, Sendable {
    public let categoryId: UUID
    public let projectCount: Int
    public let limit: Int
}
