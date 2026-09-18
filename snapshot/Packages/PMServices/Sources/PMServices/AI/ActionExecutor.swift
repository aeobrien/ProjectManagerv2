import Foundation
import PMDomain
import PMUtilities
import os

/// A line-level diff for a document section edit.
public struct SectionDiff: Sendable {
    public struct Line: Sendable, Identifiable {
        public let id = UUID()
        public enum Kind: Sendable { case context, removed, added }
        public let kind: Kind
        public let text: String

        public init(kind: Kind, text: String) {
            self.kind = kind
            self.text = text
        }
    }
    public let documentTitle: String
    public let sectionHeader: String
    public let lines: [Line]

    public init(documentTitle: String, sectionHeader: String, lines: [Line]) {
        self.documentTitle = documentTitle
        self.sectionHeader = sectionHeader
        self.lines = lines
    }
}

/// A proposed change for user confirmation.
public struct ProposedChange: Sendable, Identifiable {
    public let id = UUID()
    public let action: AIAction
    public let description: String
    public var accepted: Bool
    public let diff: SectionDiff?

    public init(action: AIAction, description: String, accepted: Bool = true, diff: SectionDiff? = nil) {
        self.action = action
        self.description = description
        self.accepted = accepted
        self.diff = diff
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

/// Result of executing a batch of actions — includes feedback about created entities.
public struct ExecutionResult: Sendable {
    /// Created entity mappings: (type, name, assigned UUID).
    public let createdEntities: [(type: String, name: String, id: UUID)]
    public let succeeded: Int
    public let failed: Int

    /// Format as a feedback message for the AI's conversation history.
    public var feedbackMessage: String? {
        guard !createdEntities.isEmpty else { return nil }
        var lines = ["Actions executed. Created entities:"]
        for entity in createdEntities {
            lines.append("- \(entity.type) \"\(entity.name)\" [id: \(entity.id.uuidString)]")
        }
        return lines.joined(separator: "\n")
    }
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

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    /// Fallback project ID for create actions when the AI provides a non-existent project ID.
    /// Set this to the current session's project ID so that phases and documents land in the
    /// correct project even when the AI hallucinates or uses placeholder project references.
    public var sessionProjectId: UUID?

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
        documentRepo: DocumentRepositoryProtocol? = nil,
        sessionProjectId: UUID? = nil
    ) {
        self.taskRepo = taskRepo
        self.milestoneRepo = milestoneRepo
        self.subtaskRepo = subtaskRepo
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.documentRepo = documentRepo
        self.sessionProjectId = sessionProjectId
    }

    /// Generate a bundled confirmation from parsed actions with descriptive names.
    /// For `editDocumentSection` actions, a line-level diff is computed and attached.
    public func generateConfirmation(from actions: [AIAction]) async -> BundledConfirmation {
        var changes: [ProposedChange] = []
        for action in actions {
            let description = await describeAction(action)
            let diff = await computeSectionDiff(for: action)
            changes.append(ProposedChange(action: action, description: description, diff: diff))
        }
        return BundledConfirmation(changes: changes)
    }

    /// Execute all accepted actions from a confirmation, sorted by dependency order.
    /// Phases are created first, then milestones, then tasks/subtasks, then other operations.
    ///
    /// **Batch ID mapping:** When the AI creates a hierarchy (phases → milestones → tasks) in a
    /// single batch, it uses AI-invented UUIDs as parent references. These don't exist in the DB.
    /// A pre-scan walks the original action order (reversed, since the AI outputs bottom-up) to
    /// build an `idMap` that connects each child's parent reference to the real UUID that will be
    /// assigned to the parent entity. This lets the sorted execution (phases first, then milestones,
    /// then tasks) use correct foreign keys.
    ///
    /// Individual action failures are collected rather than aborting the batch.
    @discardableResult
    public func execute(_ confirmation: BundledConfirmation) async throws -> ExecutionResult {
        let actions = confirmation.acceptedActions

        // Pre-scan to build parent-child ID mappings and pre-assign entity IDs.
        let plan = buildBatchPlan(actions)

        // Sort by execution priority, preserving original indices for plan lookup.
        let indexed = actions.enumerated().map { ($0.offset, $0.element) }
        let sorted = indexed.sorted { executionPriority($0.1) < executionPriority($1.1) }

        var failures: [(AIAction, Error)] = []
        var succeeded = 0
        var createdEntities: [(type: String, name: String, id: UUID)] = []

        for (originalIndex, action) in sorted {
            do {
                try await executeAction(
                    action,
                    idMap: plan.idMap,
                    entityId: plan.entityIds[originalIndex]
                )
                succeeded += 1

                // Track created entities for feedback
                let entityId = plan.entityIds[originalIndex]
                switch action {
                case .createPhase(_, let name):
                    if let id = entityId { createdEntities.append(("Phase", name, id)) }
                case .createMilestone(_, let name, _):
                    if let id = entityId { createdEntities.append(("Milestone", name, id)) }
                case .createTask(_, let name, _, _, _):
                    if let id = entityId { createdEntities.append(("Task", name, id)) }
                case .createSubtask(_, let name):
                    createdEntities.append(("Subtask", name, UUID())) // subtasks don't use pre-assigned IDs
                case .createDocument(_, let title, _):
                    createdEntities.append(("Document", title, UUID()))
                default:
                    break
                }
            } catch {
                failures.append((action, error))
                Log.ai.error("Action failed: \(error)")
            }
        }

        Log.ai.info("Executed \(succeeded)/\(sorted.count) AI actions (\(failures.count) failed)")

        // Trigger debounced Life Planner export after mutations
        if succeeded > 0 {
            onLifePlannerExport?()
        }

        // If all actions failed, throw the first error
        if succeeded == 0, let first = failures.first {
            throw first.1
        }

        return ExecutionResult(
            createdEntities: createdEntities,
            succeeded: succeeded,
            failed: failures.count
        )
    }

    /// Priority order for execution: lower = earlier. Phases before milestones before tasks.
    /// Priority order for execution: lower = earlier.
    /// Creates first (parents before children), then moves, then other ops, then deletes (children before parents).
    private func executionPriority(_ action: AIAction) -> Int {
        switch action {
        case .createPhase: return 0
        case .createMilestone: return 1
        case .createTask: return 2
        case .createSubtask: return 3
        case .createDocument: return 4
        case .updateProject, .updatePhase: return 5
        case .updateMilestone: return 6
        case .updateTask, .updateSubtask: return 7
        case .deleteSubtask: return 90
        case .deleteTask: return 91
        case .deleteMilestone: return 92
        case .deletePhase: return 93
        default: return 10
        }
    }

    // MARK: - Batch Plan

    /// Result of pre-scanning a batch of actions for parent-child ID relationships.
    private struct BatchPlan {
        /// Maps AI-invented parent UUIDs → real pre-assigned entity UUIDs.
        /// e.g. a milestone's `phaseId` (AI-invented) → the real UUID assigned to that phase.
        let idMap: [UUID: UUID]
        /// Pre-assigned entity UUIDs keyed by original action index.
        /// Only set for create actions (phase, milestone, task, subtask).
        let entityIds: [Int: UUID]
    }

    /// Pre-scan the batch to build parent-child ID mappings.
    ///
    /// The AI outputs actions top-down: phase → milestones → tasks → subtasks. Each create action
    /// for a child references its parent via a placeholder UUID that doesn't exist in the DB.
    /// Walking **forward** lets us track the most recently created parent at each level and map
    /// children's placeholder parent IDs to the real UUID pre-assigned to that parent.
    private func buildBatchPlan(_ actions: [AIAction]) -> BatchPlan {
        var idMap: [UUID: UUID] = [:]
        var entityIds: [Int: UUID] = [:]

        var currentPhaseRealId: UUID?
        var currentMilestoneRealId: UUID?
        var currentTaskRealId: UUID?

        for index in actions.indices {
            switch actions[index] {
            case .createPhase:
                let realId = UUID()
                entityIds[index] = realId
                currentPhaseRealId = realId
                currentMilestoneRealId = nil
                currentTaskRealId = nil

            case .createMilestone(let phaseId, _, _):
                let realId = UUID()
                entityIds[index] = realId
                if let parentId = currentPhaseRealId {
                    idMap[phaseId] = parentId
                }
                currentMilestoneRealId = realId
                currentTaskRealId = nil

            case .createTask(let milestoneId, _, _, _, _):
                let realId = UUID()
                entityIds[index] = realId
                if let parentId = currentMilestoneRealId {
                    idMap[milestoneId] = parentId
                }
                currentTaskRealId = realId

            case .createSubtask(let taskId, _):
                if let parentId = currentTaskRealId {
                    idMap[taskId] = parentId
                }

            default:
                break
            }
        }

        Log.ai.debug("BatchPlan: \(entityIds.count) entity IDs pre-assigned, \(idMap.count) parent refs mapped")
        return BatchPlan(idMap: idMap, entityIds: entityIds)
    }

    // MARK: - Action Execution

    /// Resolve an ID through the placeholder map — returns the mapped ID if one exists,
    /// otherwise returns the original.
    private func resolve(_ id: UUID, in idMap: [UUID: UUID]) -> UUID {
        idMap[id] ?? id
    }

    private func executeAction(
        _ action: AIAction,
        idMap: [UUID: UUID],
        entityId: UUID?
    ) async throws {
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

        case .updateProject(let projectId, let fields):
            if var project = try await projectRepo.fetch(id: projectId) {
                applyProjectFields(fields, to: &project)
                try await projectRepo.save(project)
                onChangeTracked?("project", projectId, "update")
            }

        case .updatePhase(let phaseId, let fields):
            if var phase = try await phaseRepo.fetch(id: phaseId) {
                applyPhaseFields(fields, to: &phase)
                try await phaseRepo.save(phase)
                onChangeTracked?("phase", phaseId, "update")
            }

        case .updateMilestone(let milestoneId, let fields):
            if var milestone = try await milestoneRepo.fetch(id: milestoneId) {
                applyMilestoneFields(fields, to: &milestone)
                try await milestoneRepo.save(milestone)
                onChangeTracked?("milestone", milestoneId, "update")
            }

        case .updateTask(let taskId, let fields):
            if var task = try await taskRepo.fetch(id: taskId) {
                applyTaskFields(fields, to: &task)
                try await taskRepo.save(task)
                onChangeTracked?("task", taskId, "update")
            }

        case .updateSubtask(let subtaskId, let fields):
            if var subtask = try await subtaskRepo.fetch(id: subtaskId) {
                applySubtaskFields(fields, to: &subtask)
                try await subtaskRepo.save(subtask)
                onChangeTracked?("subtask", subtaskId, "update")
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
            let resolvedTaskId = resolve(taskId, in: idMap)
            let subtask = Subtask(taskId: resolvedTaskId, name: name)
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
            let resolvedProjectId = resolve(projectId, in: idMap)
            // Fall back to the session's project if the AI's projectId doesn't exist in the DB.
            let finalProjectId: UUID
            if (try? await projectRepo.fetch(id: resolvedProjectId)) != nil {
                finalProjectId = resolvedProjectId
            } else if let fallback = sessionProjectId {
                Log.ai.notice("CREATE_PHASE: projectId \(resolvedProjectId) not found, using session project \(fallback)")
                finalProjectId = fallback
            } else {
                finalProjectId = resolvedProjectId // let it fail with FK error naturally
            }
            let existingPhases = try await phaseRepo.fetchAll(forProject: finalProjectId)
            let phase = Phase(
                id: entityId ?? UUID(),
                projectId: finalProjectId,
                name: name,
                sortOrder: existingPhases.count
            )
            try await phaseRepo.save(phase)
            onChangeTracked?("phase", phase.id, "create")

        case .createMilestone(let phaseId, let name, let deadline):
            let resolvedPhaseId = resolve(phaseId, in: idMap)
            // Verify phase exists; fall back to first phase in session project if not.
            let finalPhaseId: UUID
            if (try? await phaseRepo.fetch(id: resolvedPhaseId)) != nil {
                finalPhaseId = resolvedPhaseId
            } else if let projectId = sessionProjectId,
                      let firstPhase = try await phaseRepo.fetchAll(forProject: projectId).first {
                Log.ai.notice("CREATE_MILESTONE: phaseId \(resolvedPhaseId) not found, using first phase \(firstPhase.id) of session project")
                finalPhaseId = firstPhase.id
            } else {
                finalPhaseId = resolvedPhaseId // let it fail with FK error naturally
            }
            let milestone = Milestone(
                id: entityId ?? UUID(),
                phaseId: finalPhaseId,
                name: name,
                deadline: deadline
            )
            try await milestoneRepo.save(milestone)
            onChangeTracked?("milestone", milestone.id, "create")

        case .createTask(let milestoneId, let name, let priority, let effortType, let deadline):
            let resolvedMilestoneId = resolve(milestoneId, in: idMap)
            // Verify milestone exists; fall back to first milestone in session project if not.
            let finalMilestoneId: UUID
            if (try? await milestoneRepo.fetch(id: resolvedMilestoneId)) != nil {
                finalMilestoneId = resolvedMilestoneId
            } else if let projectId = sessionProjectId,
                      let firstPhase = try await phaseRepo.fetchAll(forProject: projectId).first,
                      let firstMilestone = try await milestoneRepo.fetchAll(forPhase: firstPhase.id).first {
                Log.ai.notice("CREATE_TASK: milestoneId \(resolvedMilestoneId) not found, using first milestone \(firstMilestone.id) of session project")
                finalMilestoneId = firstMilestone.id
            } else {
                finalMilestoneId = resolvedMilestoneId // let it fail with FK error naturally
            }
            let task = PMTask(
                id: entityId ?? UUID(),
                milestoneId: finalMilestoneId,
                name: name,
                deadline: deadline,
                priority: priority,
                effortType: effortType ?? .quickWin
            )
            try await taskRepo.save(task)
            onChangeTracked?("task", task.id, "create")

        case .createDocument(let projectId, let title, let content):
            if let documentRepo {
                let resolvedProjectId = resolve(projectId, in: idMap)
                let finalProjectId: UUID
                if (try? await projectRepo.fetch(id: resolvedProjectId)) != nil {
                    finalProjectId = resolvedProjectId
                } else if let fallback = sessionProjectId {
                    Log.ai.notice("CREATE_DOCUMENT: projectId \(resolvedProjectId) not found, using session project \(fallback)")
                    finalProjectId = fallback
                } else {
                    finalProjectId = resolvedProjectId
                }
                let doc = Document(projectId: finalProjectId, type: .other, title: title, content: content)
                try await documentRepo.save(doc)
                onChangeTracked?("document", doc.id, "create")
            }

        case .deleteTask(let taskId):
            try await taskRepo.delete(id: taskId)
            onChangeTracked?("task", taskId, "delete")

        case .deleteSubtask(let subtaskId):
            try await subtaskRepo.delete(id: subtaskId)
            onChangeTracked?("subtask", subtaskId, "delete")

        case .deleteMilestone(let milestoneId):
            try await milestoneRepo.delete(id: milestoneId)
            onChangeTracked?("milestone", milestoneId, "delete")

        case .deletePhase(let phaseId):
            try await phaseRepo.delete(id: phaseId)
            onChangeTracked?("phase", phaseId, "delete")

        case .editDocumentSection(let documentIdentifier, let section, let newContent):
            guard let documentRepo else {
                throw ActionExecutorError.documentRepoUnavailable
            }
            guard var doc = try await resolveDocument(identifier: documentIdentifier, repo: documentRepo) else {
                throw ActionExecutorError.documentNotResolved(documentIdentifier)
            }
            let editor = DocumentSectionEditor()
            guard let updated = editor.replaceSection(in: doc.content, headerText: section, newContent: newContent) else {
                throw ActionExecutorError.sectionNotFound(section, doc.title)
            }
            doc.content = updated
            doc.version += 1
            doc.updatedAt = Date()
            try await documentRepo.save(doc)
            onChangeTracked?("document", doc.id, "update")
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
        case .updateProject(let projectId, let fields):
            let name = await projectName(projectId)
            return "Update project '\(name)': \(describeFields(fields))"
        case .updatePhase(let phaseId, let fields):
            let name = await phaseName(phaseId)
            return "Update phase '\(name)': \(describeFields(fields))"
        case .updateMilestone(let milestoneId, let fields):
            let name = await milestoneName(milestoneId)
            return "Update milestone '\(name)': \(describeFields(fields))"
        case .updateTask(let taskId, let fields):
            let name = await taskName(taskId)
            return "Update task '\(name)': \(describeFields(fields))"
        case .updateSubtask(let subtaskId, let fields):
            let name = await subtaskName(subtaskId)
            return "Update subtask '\(name)': \(describeFields(fields))"
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
        case .createMilestone(_, let name, let deadline):
            var desc = "Create milestone: \(name)"
            if let deadline { desc += " (due: \(dateFormatter.string(from: deadline)))" }
            return desc
        case .createTask(_, let name, let priority, _, let deadline):
            var desc = "Create task: \(name) (\(priority.rawValue))"
            if let deadline { desc += " (due: \(dateFormatter.string(from: deadline)))" }
            return desc
        case .createDocument(_, let title, _):
            return "Create document: \(title)"
        case .deleteTask(let taskId):
            let name = await taskName(taskId)
            return "Delete task '\(name)'"
        case .deleteSubtask(let subtaskId):
            let name = await subtaskName(subtaskId)
            return "Delete subtask '\(name)'"
        case .deleteMilestone(let milestoneId):
            let name = await milestoneName(milestoneId)
            return "Delete milestone '\(name)' and all its tasks"
        case .deletePhase(let phaseId):
            let name = await phaseName(phaseId)
            return "Delete phase '\(name)' and all its milestones"
        case .editDocumentSection(let documentIdentifier, let section, _):
            if let documentRepo, let doc = try? await resolveDocument(identifier: documentIdentifier, repo: documentRepo) {
                return "Edit section '\(section)' in '\(doc.title)'"
            }
            return "Edit section '\(section)' in '\(documentIdentifier)'"
        }
    }

    // MARK: - Field Application Helpers

    private func describeFields(_ fields: [String: String]) -> String {
        fields.map { "\($0.key) = \($0.value)" }.joined(separator: ", ")
    }

    private func dateFromString(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    private func applyProjectFields(_ fields: [String: String], to project: inout Project) {
        for (key, value) in fields {
            switch key {
            case "name":
                project.name = value
            case "lifecycleState":
                if let state = LifecycleState(rawValue: value) {
                    project.lifecycleState = state
                }
            case "definitionOfDone":
                project.definitionOfDone = value == "none" ? (nil as String?) : value
            case "pauseReason":
                project.pauseReason = value == "none" ? (nil as String?) : value
            case "abandonmentReflection":
                project.abandonmentReflection = value == "none" ? (nil as String?) : value
            case "notes":
                project.notes = value == "none" ? (nil as String?) : value
            default:
                Log.ai.notice("UPDATE_PROJECT: unknown field '\(key)'")
            }
        }
    }

    private func applyPhaseFields(_ fields: [String: String], to phase: inout Phase) {
        for (key, value) in fields {
            switch key {
            case "name":
                phase.name = value
            case "status":
                if let status = PhaseStatus(rawValue: value) {
                    phase.status = status
                }
            case "sortOrder":
                if let order = Int(value) {
                    phase.sortOrder = order
                }
            case "definitionOfDone":
                phase.definitionOfDone = value == "none" ? "" : value
            default:
                Log.ai.notice("UPDATE_PHASE: unknown field '\(key)'")
            }
        }
    }

    private func applyMilestoneFields(_ fields: [String: String], to milestone: inout Milestone) {
        for (key, value) in fields {
            switch key {
            case "name":
                milestone.name = value
            case "phaseId":
                if let id = UUID(uuidString: value) {
                    milestone.phaseId = id
                }
            case "sortOrder":
                if let order = Int(value) {
                    milestone.sortOrder = order
                }
            case "status":
                if let status = ItemStatus(rawValue: value) {
                    milestone.status = status
                }
            case "definitionOfDone":
                milestone.definitionOfDone = value == "none" ? "" : value
            case "deadline":
                milestone.deadline = value == "none" ? nil : dateFromString(value)
            case "priority":
                if let p = Priority(rawValue: value) {
                    milestone.priority = p
                }
            case "waitingReason":
                milestone.waitingReason = value == "none" ? (nil as String?) : value
            case "waitingCheckBackDate":
                milestone.waitingCheckBackDate = value == "none" ? nil : dateFromString(value)
            case "notes":
                milestone.notes = value == "none" ? (nil as String?) : value
            default:
                Log.ai.notice("UPDATE_MILESTONE: unknown field '\(key)'")
            }
        }
    }

    private func applyTaskFields(_ fields: [String: String], to task: inout PMTask) {
        for (key, value) in fields {
            switch key {
            case "name":
                task.name = value
            case "milestoneId":
                if let id = UUID(uuidString: value) {
                    task.milestoneId = id
                }
            case "sortOrder":
                if let order = Int(value) {
                    task.sortOrder = order
                }
            case "status":
                if let status = ItemStatus(rawValue: value) {
                    task.status = status
                    task.kanbanColumn = status.kanbanColumn
                    if status == .completed {
                        task.completedAt = Date()
                    } else {
                        task.completedAt = nil
                    }
                }
            case "definitionOfDone":
                task.definitionOfDone = value == "none" ? "" : value
            case "isTimeboxed":
                task.isTimeboxed = value == "true"
            case "timeEstimateMinutes":
                task.timeEstimateMinutes = value == "none" ? nil : Int(value)
            case "adjustedEstimateMinutes":
                task.adjustedEstimateMinutes = value == "none" ? nil : Int(value)
            case "actualMinutes":
                task.actualMinutes = value == "none" ? nil : Int(value)
            case "timeboxMinutes":
                task.timeboxMinutes = value == "none" ? nil : Int(value)
            case "deadline":
                task.deadline = value == "none" ? nil : dateFromString(value)
            case "priority":
                if let p = Priority(rawValue: value) {
                    task.priority = p
                }
            case "effortType":
                task.effortType = value == "none" ? nil : EffortType(rawValue: value)
            case "blockedType":
                task.blockedType = value == "none" ? nil : BlockedType(rawValue: value)
            case "blockedReason":
                task.blockedReason = value == "none" ? (nil as String?) : value
            case "waitingReason":
                task.waitingReason = value == "none" ? (nil as String?) : value
            case "waitingCheckBackDate":
                task.waitingCheckBackDate = value == "none" ? nil : dateFromString(value)
            case "notes":
                task.notes = value == "none" ? (nil as String?) : value
            case "kanbanColumn":
                if let col = KanbanColumn(rawValue: value) {
                    task.kanbanColumn = col
                }
            default:
                Log.ai.notice("UPDATE_TASK: unknown field '\(key)'")
            }
        }
    }

    private func applySubtaskFields(_ fields: [String: String], to subtask: inout Subtask) {
        for (key, value) in fields {
            switch key {
            case "name":
                subtask.name = value
            case "isCompleted":
                subtask.isCompleted = value == "true"
            case "definitionOfDone":
                subtask.definitionOfDone = value == "none" ? "" : value
            case "sortOrder":
                if let order = Int(value) {
                    subtask.sortOrder = order
                }
            default:
                Log.ai.notice("UPDATE_SUBTASK: unknown field '\(key)'")
            }
        }
    }

    // MARK: - Entity Name Lookups

    private func taskName(_ id: UUID) async -> String {
        (try? await taskRepo.fetch(id: id))?.name ?? id.uuidString.prefix(8).description
    }

    private func subtaskName(_ id: UUID) async -> String {
        (try? await subtaskRepo.fetch(id: id))?.name ?? id.uuidString.prefix(8).description
    }

    private func milestoneName(_ id: UUID) async -> String {
        (try? await milestoneRepo.fetch(id: id))?.name ?? id.uuidString.prefix(8).description
    }

    private func phaseName(_ id: UUID) async -> String {
        (try? await phaseRepo.fetch(id: id))?.name ?? id.uuidString.prefix(8).description
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

    // MARK: - Section Diff Computation

    private func computeSectionDiff(for action: AIAction) async -> SectionDiff? {
        guard case .editDocumentSection(let documentIdentifier, let section, let newContent) = action else {
            return nil
        }
        guard let documentRepo,
              let doc = try? await resolveDocument(identifier: documentIdentifier, repo: documentRepo) else {
            return nil
        }
        let editor = DocumentSectionEditor()
        guard let (_, range) = editor.findSection(in: doc.content, headerText: section) else {
            return nil
        }
        let oldSection = String(doc.content[range])
        let diffComputer = DiffComputer()
        let diffLines = diffComputer.computeDiff(old: oldSection, new: newContent)
        return SectionDiff(
            documentTitle: doc.title,
            sectionHeader: section,
            lines: diffLines.map { SectionDiff.Line(kind: mapKind($0.kind), text: $0.text) }
        )
    }

    /// Resolve a document identifier — tries UUID first, then document type name within the session project,
    /// then title search as a last resort.
    private func resolveDocument(identifier: String, repo: DocumentRepositoryProtocol) async -> Document? {
        // 1. Try as UUID
        if let uuid = UUID(uuidString: identifier),
           let doc = try? await repo.fetch(id: uuid) {
            return doc
        }
        // 2. Try as DocumentType raw value within the session project
        if let docType = DocumentType(rawValue: identifier),
           let projectId = sessionProjectId,
           let docs = try? await repo.fetchByType(docType, projectId: projectId),
           let doc = docs.first {
            Log.ai.notice("Resolved document identifier '\(identifier)' to '\(doc.title)' (id: \(doc.id))")
            return doc
        }
        // 3. Try title search as fallback
        if let docs = try? await repo.search(query: identifier),
           let doc = docs.first {
            Log.ai.notice("Resolved document identifier '\(identifier)' via search to '\(doc.title)' (id: \(doc.id))")
            return doc
        }
        return nil
    }

    private func mapKind(_ kind: DiffComputer.DiffLine.Kind) -> SectionDiff.Line.Kind {
        switch kind {
        case .context: return .context
        case .removed: return .removed
        case .added: return .added
        }
    }
}

/// Errors specific to action execution.
public enum ActionExecutorError: LocalizedError {
    case documentRepoUnavailable
    case entityNotFound(String, UUID)
    case documentNotResolved(String)
    case sectionNotFound(String, String)

    public var errorDescription: String? {
        switch self {
        case .documentRepoUnavailable:
            return "Document repository is not available"
        case .entityNotFound(let type, let id):
            return "\(type.capitalized) not found: \(id)"
        case .documentNotResolved(let identifier):
            return "Could not resolve document '\(identifier)' — not a valid UUID, document type, or title"
        case .sectionNotFound(let section, let docTitle):
            return "Section '\(section)' not found in document '\(docTitle)'"
        }
    }
}
