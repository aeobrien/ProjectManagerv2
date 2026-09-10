import Foundation

/// Domain validation rules for entities.
public enum Validation {

    // MARK: - Focus Slot

    /// Valid range for focus slot indices.
    public static let focusSlotRange = 0..<FocusManager.maxFocusedProjects

    /// Whether a focus slot index is valid.
    public static func isValidFocusSlot(_ index: Int?) -> Bool {
        guard let index else { return true } // nil is valid (not focused)
        return focusSlotRange.contains(index)
    }

    // MARK: - Lifecycle State Transitions

    /// Valid transitions from a given lifecycle state.
    public static func validTransitions(from state: LifecycleState) -> Set<LifecycleState> {
        switch state {
        case .idea:
            return [.queued, .abandoned]
        case .queued:
            return [.focused, .idea, .paused, .abandoned]
        case .focused:
            return [.queued, .paused, .completed, .abandoned]
        case .paused:
            return [.queued, .abandoned]
        case .completed:
            return [.queued] // can reopen
        case .abandoned:
            return [.idea, .queued] // can revive
        }
    }

    /// Whether a lifecycle state transition is valid.
    public static func canTransition(from: LifecycleState, to: LifecycleState) -> Bool {
        validTransitions(from: from).contains(to)
    }

    // MARK: - Category Diversity

    /// Whether adding a project with the given category would violate diversity constraints.
    public static func wouldViolateDiversity(
        categoryId: UUID,
        currentFocused: [Project]
    ) -> Bool {
        let sameCategoryCount = currentFocused.filter { $0.categoryId == categoryId }.count
        return sameCategoryCount >= FocusManager.maxPerCategory
    }

    // MARK: - Entity Validation

    /// Validates a project for data integrity.
    public static func validate(project: Project) -> [ValidationError] {
        var errors: [ValidationError] = []

        if project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName(entity: "Project"))
        }

        if !isValidFocusSlot(project.focusSlotIndex) {
            errors.append(.invalidFocusSlot(index: project.focusSlotIndex ?? -1))
        }

        if project.lifecycleState == .focused && project.focusSlotIndex == nil {
            errors.append(.focusedWithoutSlot)
        }

        if project.lifecycleState != .focused && project.focusSlotIndex != nil {
            errors.append(.slotWithoutFocused)
        }

        if project.lifecycleState == .paused && (project.pauseReason ?? "").isEmpty {
            errors.append(.pausedWithoutReason)
        }

        if project.lifecycleState == .abandoned && (project.abandonmentReflection ?? "").isEmpty {
            errors.append(.abandonedWithoutReflection)
        }

        return errors
    }

    /// Validates a task for data integrity.
    public static func validate(task: PMTask) -> [ValidationError] {
        var errors: [ValidationError] = []

        if task.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName(entity: "Task"))
        }

        if task.status == .blocked && task.blockedType == nil {
            errors.append(.blockedWithoutType)
        }

        if task.status == .waiting && (task.waitingReason ?? "").isEmpty {
            errors.append(.waitingWithoutReason)
        }

        if let estimate = task.timeEstimateMinutes, estimate <= 0 {
            errors.append(.invalidTimeEstimate)
        }

        if let actual = task.actualMinutes, actual < 0 {
            errors.append(.invalidActualTime)
        }

        return errors
    }
}

/// Validation errors for domain entities.
public enum ValidationError: Equatable, Sendable {
    case emptyName(entity: String)
    case invalidFocusSlot(index: Int)
    case focusedWithoutSlot
    case slotWithoutFocused
    case pausedWithoutReason
    case abandonedWithoutReflection
    case blockedWithoutType
    case waitingWithoutReason
    case invalidTimeEstimate
    case invalidActualTime
}
