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

/// Generates confirmation summaries and executes accepted actions.
public struct ActionExecutor: Sendable {
    private let taskRepo: TaskRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let subtaskRepo: SubtaskRepositoryProtocol
    private let projectRepo: ProjectRepositoryProtocol

    public init(
        taskRepo: TaskRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        subtaskRepo: SubtaskRepositoryProtocol,
        projectRepo: ProjectRepositoryProtocol
    ) {
        self.taskRepo = taskRepo
        self.milestoneRepo = milestoneRepo
        self.subtaskRepo = subtaskRepo
        self.projectRepo = projectRepo
    }

    /// Generate a bundled confirmation from parsed actions.
    public func generateConfirmation(from actions: [AIAction]) -> BundledConfirmation {
        let changes = actions.map { action in
            ProposedChange(action: action, description: describeAction(action))
        }
        return BundledConfirmation(changes: changes)
    }

    /// Execute all accepted actions from a confirmation.
    public func execute(_ confirmation: BundledConfirmation) async throws {
        for action in confirmation.acceptedActions {
            try await executeAction(action)
        }
        Log.ai.info("Executed \(confirmation.acceptedCount) AI actions")
    }

    // MARK: - Action Execution

    private func executeAction(_ action: AIAction) async throws {
        switch action {
        case .completeTask(let taskId):
            if var task = try await taskRepo.fetch(id: taskId) {
                task.status = .completed
                try await taskRepo.save(task)
            }

        case .updateNotes(let projectId, let notes):
            if var project = try await projectRepo.fetch(id: projectId) {
                project.notes = notes
                try await projectRepo.save(project)
            }

        case .flagBlocked(let taskId, let blockedType, let reason):
            if var task = try await taskRepo.fetch(id: taskId) {
                task.blockedType = blockedType
                task.blockedReason = reason
                try await taskRepo.save(task)
            }

        case .setWaiting(let taskId, let reason, let checkBackDate):
            if var task = try await taskRepo.fetch(id: taskId) {
                task.blockedType = .missingResource
                task.blockedReason = reason
                task.waitingCheckBackDate = checkBackDate
                try await taskRepo.save(task)
            }

        case .createSubtask(let taskId, let name):
            let subtask = Subtask(taskId: taskId, name: name)
            try await subtaskRepo.save(subtask)

        case .updateDocument:
            // Document repository not yet implemented — no-op for now
            break

        case .incrementDeferred(let taskId):
            if var task = try await taskRepo.fetch(id: taskId) {
                task.timesDeferred += 1
                try await taskRepo.save(task)
            }

        case .suggestScopeReduction:
            // This is informational — no database change needed
            break

        case .createMilestone(let phaseId, let name):
            let milestone = Milestone(phaseId: phaseId, name: name)
            try await milestoneRepo.save(milestone)

        case .createTask(let milestoneId, let name, let priority, let effortType):
            let task = PMTask(
                milestoneId: milestoneId,
                name: name,
                priority: priority,
                effortType: effortType ?? .quickWin
            )
            try await taskRepo.save(task)

        case .createDocument:
            // Document repository not yet implemented — no-op for now
            break
        }
    }

    // MARK: - Descriptions

    private func describeAction(_ action: AIAction) -> String {
        switch action {
        case .completeTask:
            "Mark task as completed"
        case .updateNotes(_, let notes):
            "Update project notes: \(notes.prefix(50))..."
        case .flagBlocked(_, let type, let reason):
            "Flag task as blocked (\(type.rawValue)): \(reason.prefix(50))"
        case .setWaiting(_, let reason, _):
            "Set task to waiting: \(reason.prefix(50))"
        case .createSubtask(_, let name):
            "Create subtask: \(name)"
        case .updateDocument(_, let content):
            "Update document: \(content.prefix(50))..."
        case .incrementDeferred:
            "Increment deferred count"
        case .suggestScopeReduction(_, let suggestion):
            "Scope reduction suggestion: \(suggestion.prefix(50))"
        case .createMilestone(_, let name):
            "Create milestone: \(name)"
        case .createTask(_, let name, let priority, _):
            "Create task: \(name) (\(priority.rawValue))"
        case .createDocument(_, let title, _):
            "Create document: \(title)"
        }
    }
}
