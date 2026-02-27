import Foundation
import PMDomain
import PMUtilities
import os

/// A proposed change for user confirmation.
public struct ProposedChange: Sendable, Identifiable {
    public let id = UUID()
    public let action: AIAction
    public let description: String
    public var accepted: Bool

    public init(action: AIAction, description: String, accepted: Bool = true) {
        self.action = action
        self.description = description
        self.accepted = accepted
    }
}

/// Bundled confirmation model — all proposed changes from an AI response.
public struct BundledConfirmation: Sendable {
    public var changes: [ProposedChange]

    public init(changes: [ProposedChange]) {
        self.changes = changes
    }

    /// Number of accepted changes.
    public var acceptedCount: Int { changes.filter(\.accepted).count }

    /// All accepted actions.
    public var acceptedActions: [AIAction] { changes.filter(\.accepted).map(\.action) }
}

/// Callback for notifying sync layer of entity changes from action execution.
public typealias ChangeTracker = @Sendable (_ entityType: String, _ entityId: UUID, _ changeType: String) -> Void

/// Generates confirmation summaries and executes accepted actions.
public struct ActionExecutor: Sendable {
    private let taskRepo: TaskRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let subtaskRepo: SubtaskRepositoryProtocol
    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let documentRepo: DocumentRepositoryProtocol?

    /// Optional callback invoked after each entity mutation for sync tracking.
    public var onChangeTracked: ChangeTracker?

    /// Optional callback invoked after data mutations to trigger Life Planner export.
    public var onLifePlannerExport: (@Sendable () -> Void)?

    public init(
        taskRepo: TaskRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        subtaskRepo: SubtaskRepositoryProtocol,
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        documentRepo: DocumentRepositoryProtocol? = nil
    ) {
        self.taskRepo = taskRepo
        self.milestoneRepo = milestoneRepo
        self.subtaskRepo = subtaskRepo
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.documentRepo = documentRepo
    }

    /// Generate a bundled confirmation from parsed actions with descriptive names.
    public func generateConfirmation(from actions: [AIAction]) async -> BundledConfirmation {
        var changes: [ProposedChange] = []
        for action in actions {
            let description = await describeAction(action)
            changes.append(ProposedChange(action: action, description: description))
        }
        return BundledConfirmation(changes: changes)
    }

    /// Execute all accepted actions from a confirmation.
    public func execute(_ confirmation: BundledConfirmation) async throws {
        for action in confirmation.acceptedActions {
            try await executeAction(action)
        }
        Log.ai.info("Executed \(confirmation.acceptedCount) AI actions")

        // Trigger debounced Life Planner export after mutations
        if confirmation.acceptedCount > 0 {
            onLifePlannerExport?()
        }
    }

    // MARK: - Action Execution

    private func executeAction(_ action: AIAction) async throws {
        switch action {
        case .completeTask(let taskId):
            if var task = try await taskRepo.fetch(id: taskId) {
                task.status = .completed
                task.kanbanColumn = .done
                task.completedAt = Date()
                try await taskRepo.save(task)
                onChangeTracked?("task", taskId, "update")
            }

        case .moveTask(let taskId, let column):
            if var task = try await taskRepo.fetch(id: taskId) {
                task.kanbanColumn = column
                switch column {
                case .done:
                    task.status = .completed
                    task.completedAt = Date()
                case .inProgress:
                    task.status = .inProgress
                    task.completedAt = nil
                case .toDo:
                    if task.status == .completed {
                        task.status = .notStarted
                        task.completedAt = nil
                    }
                }
                try await taskRepo.save(task)
                onChangeTracked?("task", taskId, "update")
            }

        case .completeSubtask(let subtaskId):
            if var subtask = try await subtaskRepo.fetch(id: subtaskId) {
                subtask.isCompleted = true
                try await subtaskRepo.save(subtask)
                onChangeTracked?("subtask", subtaskId, "update")
            }

        case .updateNotes(let projectId, let notes):
            if var project = try await projectRepo.fetch(id: projectId) {
                project.notes = notes
                try await projectRepo.save(project)
                onChangeTracked?("project", projectId, "update")
            }

        case .flagBlocked(let taskId, let blockedType, let reason):
            if var task = try await taskRepo.fetch(id: taskId) {
                task.status = .blocked
                task.kanbanColumn = ItemStatus.blocked.kanbanColumn
                task.blockedType = blockedType
                task.blockedReason = reason
                try await taskRepo.save(task)
                onChangeTracked?("task", taskId, "update")
            }

        case .setWaiting(let taskId, let reason, let checkBackDate):
            if var task = try await taskRepo.fetch(id: taskId) {
                task.status = .waiting
                task.kanbanColumn = ItemStatus.waiting.kanbanColumn
                task.waitingReason = reason
                task.waitingCheckBackDate = checkBackDate
                try await taskRepo.save(task)
                onChangeTracked?("task", taskId, "update")
            }

        case .createSubtask(let taskId, let name):
            let subtask = Subtask(taskId: taskId, name: name)
            try await subtaskRepo.save(subtask)
            onChangeTracked?("subtask", subtask.id, "create")

        case .updateDocument(let documentId, let content):
            if let documentRepo, var doc = try await documentRepo.fetch(id: documentId) {
                doc.content = content
                doc.version += 1
                doc.updatedAt = Date()
                try await documentRepo.save(doc)
                onChangeTracked?("document", documentId, "update")
            }

        case .incrementDeferred(let taskId):
            if var task = try await taskRepo.fetch(id: taskId) {
                task.timesDeferred += 1
                try await taskRepo.save(task)
                onChangeTracked?("task", taskId, "update")
            }

        case .suggestScopeReduction:
            // This is informational — no database change needed
            break

        case .createPhase(let projectId, let name):
            let existingPhases = try await phaseRepo.fetchAll(forProject: projectId)
            let phase = Phase(projectId: projectId, name: name, sortOrder: existingPhases.count)
            try await phaseRepo.save(phase)
            onChangeTracked?("phase", phase.id, "create")

        case .createMilestone(let phaseId, let name):
            let milestone = Milestone(phaseId: phaseId, name: name)
            try await milestoneRepo.save(milestone)
            onChangeTracked?("milestone", milestone.id, "create")

        case .createTask(let milestoneId, let name, let priority, let effortType):
            let task = PMTask(
                milestoneId: milestoneId,
                name: name,
                priority: priority,
                effortType: effortType ?? .quickWin
            )
            try await taskRepo.save(task)
            onChangeTracked?("task", task.id, "create")

        case .createDocument(let projectId, let title, let content):
            if let documentRepo {
                let doc = Document(projectId: projectId, type: .other, title: title, content: content)
                try await documentRepo.save(doc)
                onChangeTracked?("document", doc.id, "create")
            }

        case .deleteTask(let taskId):
            try await taskRepo.delete(id: taskId)
            onChangeTracked?("task", taskId, "delete")

        case .deleteSubtask(let subtaskId):
            try await subtaskRepo.delete(id: subtaskId)
            onChangeTracked?("subtask", subtaskId, "delete")
        }
    }

    // MARK: - Descriptions

    private func describeAction(_ action: AIAction) async -> String {
        switch action {
        case .completeTask(let taskId):
            let name = await taskName(taskId)
            return "Mark task '\(name)' as completed"
        case .moveTask(let taskId, let column):
            let name = await taskName(taskId)
            return "Move task '\(name)' to \(column.displayName)"
        case .completeSubtask(let subtaskId):
            let name = await subtaskName(subtaskId)
            return "Mark subtask '\(name)' as completed"
        case .updateNotes(let projectId, let notes):
            let name = await projectName(projectId)
            return "Update notes for '\(name)': \(notes.prefix(50))..."
        case .flagBlocked(let taskId, let type, let reason):
            let name = await taskName(taskId)
            return "Flag task '\(name)' as blocked (\(type.rawValue)): \(reason.prefix(50))"
        case .setWaiting(let taskId, let reason, _):
            let name = await taskName(taskId)
            return "Set task '\(name)' to waiting: \(reason.prefix(50))"
        case .createSubtask(_, let name):
            return "Create subtask: \(name)"
        case .updateDocument(let documentId, let content):
            let name = await documentName(documentId)
            return "Update document '\(name)': \(content.prefix(50))..."
        case .incrementDeferred(let taskId):
            let name = await taskName(taskId)
            return "Increment deferred count for '\(name)'"
        case .suggestScopeReduction(_, let suggestion):
            return "Scope reduction suggestion: \(suggestion.prefix(50))"
        case .createPhase(_, let name):
            return "Create phase: \(name)"
        case .createMilestone(_, let name):
            return "Create milestone: \(name)"
        case .createTask(_, let name, let priority, _):
            return "Create task: \(name) (\(priority.rawValue))"
        case .createDocument(_, let title, _):
            return "Create document: \(title)"
        case .deleteTask(let taskId):
            let name = await taskName(taskId)
            return "Delete task '\(name)'"
        case .deleteSubtask(let subtaskId):
            let name = await subtaskName(subtaskId)
            return "Delete subtask '\(name)'"
        }
    }

    // MARK: - Entity Name Lookups

    private func taskName(_ id: UUID) async -> String {
        (try? await taskRepo.fetch(id: id))?.name ?? id.uuidString.prefix(8).description
    }

    private func subtaskName(_ id: UUID) async -> String {
        (try? await subtaskRepo.fetch(id: id))?.name ?? id.uuidString.prefix(8).description
    }

    private func projectName(_ id: UUID) async -> String {
        (try? await projectRepo.fetch(id: id))?.name ?? id.uuidString.prefix(8).description
    }

    private func documentName(_ id: UUID) async -> String {
        if let documentRepo {
            return (try? await documentRepo.fetch(id: id))?.title ?? id.uuidString.prefix(8).description
        }
        return id.uuidString.prefix(8).description
    }
}
