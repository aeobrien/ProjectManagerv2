import Foundation
import PMDomain
import PMUtilities

/// Parsed action from an AI response.
public enum AIAction: Sendable, Equatable {
    case completeTask(taskId: UUID)
    case moveTask(taskId: UUID, column: KanbanColumn)
    case completeSubtask(subtaskId: UUID)
    case flagBlocked(taskId: UUID, blockedType: BlockedType, reason: String)
    case setWaiting(taskId: UUID, reason: String, checkBackDate: Date?)
    case createSubtask(taskId: UUID, name: String)
    case updateDocument(documentId: UUID, content: String)
    case incrementDeferred(taskId: UUID)
    case suggestScopeReduction(projectId: UUID, suggestion: String)
    case createMilestone(phaseId: UUID, name: String, deadline: Date?)
    case createTask(milestoneId: UUID, name: String, priority: Priority, effortType: EffortType?, deadline: Date?)
    case createDocument(projectId: UUID, title: String, content: String)
    case createPhase(projectId: UUID, name: String)
    case deleteTask(taskId: UUID)
    case deleteSubtask(subtaskId: UUID)
    case deleteMilestone(milestoneId: UUID)
    case deletePhase(phaseId: UUID)
    case editDocumentSection(documentIdentifier: String, section: String, newContent: String)
    case updateProject(projectId: UUID, fields: [String: String])
    case updatePhase(phaseId: UUID, fields: [String: String])
    case updateMilestone(milestoneId: UUID, fields: [String: String])
    case updateTask(taskId: UUID, fields: [String: String])
    case updateSubtask(subtaskId: UUID, fields: [String: String])

    /// Human-readable list of all AI capabilities for display in the UI.
    public static let capabilitiesList: [(action: String, description: String, isMajor: Bool)] = [
        ("Complete Task", "Mark a task as completed and move it to Done", false),
        ("Move Task", "Move a task between To Do, In Progress, and Done columns", false),
        ("Complete Subtask", "Mark a subtask as completed", false),
        ("Create Subtask", "Add a new subtask to an existing task", false),
        ("Delete Task", "Permanently delete a task", true),
        ("Delete Subtask", "Permanently delete a subtask", true),
        ("Delete Milestone", "Permanently delete a milestone and its tasks", true),
        ("Delete Phase", "Permanently delete a phase and its milestones", true),
        ("Create Phase", "Create a new phase within a project", true),
        ("Create Milestone", "Create a new milestone within a phase", true),
        ("Create Task", "Create a new task within a milestone", true),
        ("Create Document", "Create a new project document", true),
        ("Update Project", "Modify project fields (name, state, notes, etc.)", true),
        ("Update Phase", "Modify phase fields (name, status, etc.)", true),
        ("Update Milestone", "Modify milestone fields (name, deadline, priority, etc.)", true),
        ("Update Task", "Modify task fields (name, deadline, priority, status, etc.)", true),
        ("Update Subtask", "Modify subtask fields (name, completion, etc.)", true),
        ("Update Document", "Modify an existing document's content", true),
        ("Edit Document Section", "Replace a single section within a document", true),
        ("Flag Blocked", "Mark a task as blocked with a reason", true),
        ("Set Waiting", "Mark a task as waiting on something", true),
        ("Increment Deferred", "Track that a task was deferred again", false),
        ("Suggest Scope Reduction", "Suggest reducing project scope (informational only)", false),
    ]

    /// Whether this action is considered "major" (requires confirmation even at high trust level).
    /// Minor actions: completing tasks/subtasks, moving tasks, creating subtasks, incrementing deferred, scope suggestions.
    /// Major actions: creating milestones/tasks/documents, updating notes/documents, blocking/waiting, deleting.
    public var isMajor: Bool {
        switch self {
        case .completeTask, .moveTask, .completeSubtask, .createSubtask,
             .incrementDeferred, .suggestScopeReduction:
            return false
        case .flagBlocked, .setWaiting, .updateDocument,
             .createPhase, .createMilestone, .createTask, .createDocument,
             .deleteTask, .deleteSubtask, .deleteMilestone, .deletePhase,
             .editDocumentSection,
             .updateProject, .updatePhase, .updateMilestone, .updateTask, .updateSubtask:
            return true
        }
    }
}

/// Result of parsing an AI response — natural language and structured actions.
public struct ParsedResponse: Sendable {
    public let naturalLanguage: String
    public let actions: [AIAction]

    public init(naturalLanguage: String, actions: [AIAction]) {
        self.naturalLanguage = naturalLanguage
        self.actions = actions
    }
}

/// Parses AI responses to extract natural language and structured action blocks.
public struct ActionParser: Sendable {
    public init() {}

    /// Parse an AI response string into natural language and action blocks.
    public func parse(_ response: String) -> ParsedResponse {
        var naturalText = response
        var actions: [AIAction] = []

        // Find all action blocks
        let pattern = #"\[ACTION:\s*(\w+)\](.*?)\[/ACTION\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            Log.ai.debug("ActionParser: regex compilation failed")
            return ParsedResponse(naturalLanguage: response, actions: [])
        }

        let matches = regex.matches(in: response, range: NSRange(response.startIndex..., in: response))
        Log.ai.debug("ActionParser: found \(matches.count) ACTION block(s) in response (\(response.count) chars)")

        // Process matches in reverse to maintain string indices while removing
        for match in matches.reversed() {
            guard let typeRange = Range(match.range(at: 1), in: response),
                  let bodyRange = Range(match.range(at: 2), in: response),
                  let fullRange = Range(match.range, in: response) else { continue }

            let actionType = String(response[typeRange])
            let body = String(response[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            if let action = parseAction(type: actionType, body: body) {
                actions.insert(action, at: 0)
                Log.ai.debug("ActionParser: parsed \(actionType) -> \(String(describing: action))")
            } else {
                Log.ai.notice("ActionParser: FAILED to parse \(actionType), body: \(body.prefix(200))")
            }

            // Remove the action block from natural text
            naturalText.removeSubrange(fullRange)
        }

        // Strip unclosed action blocks (truncated by token limit)
        let unclosedPattern = #"\[ACTION:[\s\S]*$"#
        naturalText = naturalText.replacingOccurrences(of: unclosedPattern, with: "", options: .regularExpression)
        // Strip orphaned closing tags
        naturalText = naturalText.replacingOccurrences(of: "[/ACTION]", with: "")

        // Clean up natural text
        naturalText = naturalText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)

        Log.ai.info("ActionParser: result — \(actions.count) valid action(s) from \(matches.count) block(s)")
        return ParsedResponse(naturalLanguage: naturalText, actions: actions)
    }

    // MARK: - Individual Action Parsing

    private func parseAction(type: String, body: String) -> AIAction? {
        let params = parseParams(body)

        switch type {
        case "COMPLETE_TASK":
            guard let taskId = params["taskId"].flatMap(UUID.init) else { return nil }
            return .completeTask(taskId: taskId)

        case "MOVE_TASK":
            guard let taskId = params["taskId"].flatMap(UUID.init),
                  let columnStr = params["column"],
                  let column = KanbanColumn(rawValue: columnStr) else { return nil }
            return .moveTask(taskId: taskId, column: column)

        case "COMPLETE_SUBTASK":
            guard let subtaskId = params["subtaskId"].flatMap(UUID.init) else { return nil }
            return .completeSubtask(subtaskId: subtaskId)

        // Backward compat: translate UPDATE_NOTES → updateProject
        case "UPDATE_NOTES":
            guard let projectId = params["projectId"].flatMap(UUID.init),
                  let notes = params["notes"] else { return nil }
            return .updateProject(projectId: projectId, fields: ["notes": notes])

        case "FLAG_BLOCKED":
            guard let taskId = params["taskId"].flatMap(UUID.init),
                  let typeStr = params["blockedType"],
                  let blockedType = BlockedType(rawValue: typeStr),
                  let reason = params["reason"] else { return nil }
            return .flagBlocked(taskId: taskId, blockedType: blockedType, reason: reason)

        case "SET_WAITING":
            guard let taskId = params["taskId"].flatMap(UUID.init),
                  let reason = params["reason"] else { return nil }
            let checkBackDate = params["checkBackDate"].flatMap { dateFromString($0) }
            return .setWaiting(taskId: taskId, reason: reason, checkBackDate: checkBackDate)

        case "CREATE_SUBTASK":
            guard let taskId = params["taskId"].flatMap(UUID.init),
                  let name = params["name"] else { return nil }
            return .createSubtask(taskId: taskId, name: name)

        case "UPDATE_DOCUMENT":
            guard let documentId = params["documentId"].flatMap(UUID.init),
                  let content = params["content"] else { return nil }
            return .updateDocument(documentId: documentId, content: content)

        case "INCREMENT_DEFERRED":
            guard let taskId = params["taskId"].flatMap(UUID.init) else { return nil }
            return .incrementDeferred(taskId: taskId)

        case "SUGGEST_SCOPE_REDUCTION":
            guard let projectId = params["projectId"].flatMap(UUID.init),
                  let suggestion = params["suggestion"] else { return nil }
            return .suggestScopeReduction(projectId: projectId, suggestion: suggestion)

        case "CREATE_PHASE":
            guard let name = params["name"] else { return nil }
            let projectId = resolveId(params["projectId"])
            return .createPhase(projectId: projectId, name: name)

        case "CREATE_MILESTONE":
            guard let name = params["name"] else { return nil }
            let phaseId = resolveId(params["phaseId"])
            let deadline = params["deadline"].flatMap { dateFromString($0) }
            return .createMilestone(phaseId: phaseId, name: name, deadline: deadline)

        case "CREATE_TASK":
            guard let name = params["name"] else { return nil }
            let milestoneId = resolveId(params["milestoneId"])
            let priority = params["priority"].flatMap { Priority(rawValue: $0) } ?? .normal
            let effortType = params["effortType"].flatMap { EffortType(rawValue: $0) }
            let deadline = params["deadline"].flatMap { dateFromString($0) }
            return .createTask(milestoneId: milestoneId, name: name, priority: priority, effortType: effortType, deadline: deadline)

        case "CREATE_DOCUMENT":
            guard let title = params["title"],
                  let content = params["content"] else { return nil }
            let projectId = resolveId(params["projectId"])
            return .createDocument(projectId: projectId, title: title, content: content)

        case "DELETE_TASK":
            guard let taskId = params["taskId"].flatMap(UUID.init) else { return nil }
            return .deleteTask(taskId: taskId)

        case "DELETE_SUBTASK":
            guard let subtaskId = params["subtaskId"].flatMap(UUID.init) else { return nil }
            return .deleteSubtask(subtaskId: subtaskId)

        case "DELETE_MILESTONE":
            guard let milestoneId = params["milestoneId"].flatMap(UUID.init) else { return nil }
            return .deleteMilestone(milestoneId: milestoneId)

        case "DELETE_PHASE":
            guard let phaseId = params["phaseId"].flatMap(UUID.init) else { return nil }
            return .deletePhase(phaseId: phaseId)

        // Backward compat: translate MOVE_TASK_TO_MILESTONE → updateTask
        case "MOVE_TASK_TO_MILESTONE":
            guard let taskId = params["taskId"].flatMap(UUID.init),
                  let milestoneId = params["milestoneId"] else { return nil }
            return .updateTask(taskId: taskId, fields: ["milestoneId": milestoneId])

        // Backward compat: translate MOVE_MILESTONE_TO_PHASE → updateMilestone
        case "MOVE_MILESTONE_TO_PHASE":
            guard let milestoneId = params["milestoneId"].flatMap(UUID.init),
                  let phaseId = params["phaseId"] else { return nil }
            return .updateMilestone(milestoneId: milestoneId, fields: ["phaseId": phaseId])

        // Backward compat: translate SET_DEADLINE → updateTask/updateMilestone
        case "SET_DEADLINE":
            guard let entityType = params["entityType"],
                  let entityId = params["entityId"].flatMap(UUID.init) else { return nil }
            let deadlineValue = params["deadline"] ?? "none"
            switch entityType.lowercased() {
            case "task":
                return .updateTask(taskId: entityId, fields: ["deadline": deadlineValue])
            case "milestone":
                return .updateMilestone(milestoneId: entityId, fields: ["deadline": deadlineValue])
            default:
                return nil
            }

        // Generic update actions
        case "UPDATE_PROJECT":
            guard let projectId = params["projectId"].flatMap(UUID.init) else { return nil }
            var fields = params
            fields.removeValue(forKey: "projectId")
            return .updateProject(projectId: projectId, fields: fields)

        case "UPDATE_PHASE":
            guard let phaseId = params["phaseId"].flatMap(UUID.init) else { return nil }
            var fields = params
            fields.removeValue(forKey: "phaseId")
            return .updatePhase(phaseId: phaseId, fields: fields)

        case "UPDATE_MILESTONE":
            guard let milestoneId = params["milestoneId"].flatMap(UUID.init) else { return nil }
            var fields = params
            fields.removeValue(forKey: "milestoneId")
            return .updateMilestone(milestoneId: milestoneId, fields: fields)

        case "UPDATE_TASK":
            guard let taskId = params["taskId"].flatMap(UUID.init) else { return nil }
            var fields = params
            fields.removeValue(forKey: "taskId")
            return .updateTask(taskId: taskId, fields: fields)

        case "UPDATE_SUBTASK":
            guard let subtaskId = params["subtaskId"].flatMap(UUID.init) else { return nil }
            var fields = params
            fields.removeValue(forKey: "subtaskId")
            return .updateSubtask(subtaskId: subtaskId, fields: fields)

        case "EDIT_DOCUMENT_SECTION":
            // Extract params only from the portion before <<<CONTENT to avoid
            // the key-value parser consuming markdown content as param values.
            let paramBody: String
            if let delimiterRange = body.range(of: "<<<CONTENT") {
                paramBody = String(body[body.startIndex..<delimiterRange.lowerBound])
            } else {
                paramBody = body
            }
            let localParams = parseParams(paramBody)
            guard let docIdentifier = localParams["documentId"],
                  let section = localParams["section"],
                  let newContent = parseDelimitedContent(body) else { return nil }
            return .editDocumentSection(documentIdentifier: docIdentifier, section: section, newContent: newContent)

        default:
            return nil
        }
    }

    /// Parse key: value pairs from an action body.
    private func parseParams(_ body: String) -> [String: String] {
        var params: [String: String] = [:]
        // Match key: value pairs, where value continues until the next key: or end
        let pattern = #"(\w+):\s*((?:(?!\w+:).)*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return params
        }

        let matches = regex.matches(in: body, range: NSRange(body.startIndex..., in: body))
        for match in matches {
            guard let keyRange = Range(match.range(at: 1), in: body),
                  let valueRange = Range(match.range(at: 2), in: body) else { continue }
            let key = String(body[keyRange])
            let value = String(body[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            params[key] = value
        }

        return params
    }

    /// Resolve an ID string to a UUID. Accepts valid UUIDs directly, or generates a
    /// placeholder UUID for human-readable IDs (e.g. "phase-2-001") that the AI uses
    /// during onboarding when no real entities exist yet.
    private func resolveId(_ string: String?) -> UUID {
        guard let string else { return UUID() }
        return UUID(uuidString: string) ?? UUID()
    }

    /// Extract content from a heredoc-style `<<<CONTENT` / `CONTENT` delimiter block.
    private func parseDelimitedContent(_ body: String) -> String? {
        guard let startRange = body.range(of: "<<<CONTENT\n"),
              let endRange = body.range(of: "\nCONTENT", range: startRange.upperBound..<body.endIndex)
        else { return nil }
        return String(body[startRange.upperBound..<endRange.lowerBound])
    }

    private func dateFromString(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
