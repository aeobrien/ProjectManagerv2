import Foundation
import PMDomain

/// A context payload assembled for an AI conversation.
public struct ContextPayload: Sendable {
    public let systemPrompt: String
    public let messages: [LLMMessage]
    public let estimatedTokens: Int

    public init(systemPrompt: String, messages: [LLMMessage], estimatedTokens: Int) {
        self.systemPrompt = systemPrompt
        self.messages = messages
        self.estimatedTokens = estimatedTokens
    }
}

/// Project context data for AI conversations.
public struct ProjectContext: Sendable {
    public let project: Project
    public let phases: [Phase]
    public let milestones: [Milestone]
    public let tasks: [PMTask]
    public let subtasksByTaskId: [UUID: [Subtask]]
    public let recentCheckIns: [CheckInRecord]
    public let frequentlyDeferredTasks: [PMTask]
    public let estimateAccuracy: Float?
    public let suggestedMultiplier: Float?
    public let accuracyTrend: (older: Float, newer: Float)?

    public init(
        project: Project,
        phases: [Phase] = [],
        milestones: [Milestone] = [],
        tasks: [PMTask] = [],
        subtasksByTaskId: [UUID: [Subtask]] = [:],
        recentCheckIns: [CheckInRecord] = [],
        frequentlyDeferredTasks: [PMTask] = [],
        estimateAccuracy: Float? = nil,
        suggestedMultiplier: Float? = nil,
        accuracyTrend: (older: Float, newer: Float)? = nil
    ) {
        self.project = project
        self.phases = phases
        self.milestones = milestones
        self.tasks = tasks
        self.subtasksByTaskId = subtasksByTaskId
        self.recentCheckIns = recentCheckIns
        self.frequentlyDeferredTasks = frequentlyDeferredTasks
        self.estimateAccuracy = estimateAccuracy
        self.suggestedMultiplier = suggestedMultiplier
        self.accuracyTrend = accuracyTrend
    }
}

/// Assembles context payloads for AI conversations.
public struct ContextAssembler: Sendable {
    /// Approximate tokens per character ratio (conservative estimate).
    public static let tokensPerChar: Double = 0.3

    /// Maximum token budget for context.
    public let maxTokenBudget: Int

    /// Optional knowledge base for RAG-style context retrieval.
    public let knowledgeBase: KnowledgeBaseManager?

    public init(maxTokenBudget: Int = 8000, knowledgeBase: KnowledgeBaseManager? = nil) {
        self.maxTokenBudget = maxTokenBudget
        self.knowledgeBase = knowledgeBase
    }

    /// Estimate token count for a string.
    public static func estimateTokens(_ text: String) -> Int {
        Int(ceil(Double(text.count) * tokensPerChar))
    }

    /// Assemble a context payload for a conversation.
    ///
    /// - Parameters:
    ///   - conversationType: The type of conversation.
    ///   - projectContext: Optional project context to include.
    ///   - conversationHistory: Prior messages in the conversation.
    ///   - exchangeNumber: Current exchange number for multi-turn flows (1-based).
    ///   - maxExchanges: Maximum number of exchanges for multi-turn flows.
    public func assemble(
        conversationType: ConversationType,
        projectContext: ProjectContext?,
        conversationHistory: [LLMMessage] = [],
        exchangeNumber: Int? = nil,
        maxExchanges: Int? = nil
    ) async throws -> ContextPayload {
        let systemPrompt: String
        switch conversationType {
        case .onboarding where exchangeNumber != nil:
            systemPrompt = PromptTemplates.onboarding(
                exchangeNumber: exchangeNumber ?? 1,
                maxExchanges: maxExchanges ?? 3
            )
        case .visionDiscovery where exchangeNumber != nil:
            systemPrompt = PromptTemplates.visionDiscovery(
                projectName: projectContext?.project.name ?? "Unknown",
                exchangeNumber: exchangeNumber ?? 1,
                maxExchanges: maxExchanges ?? 3
            )
        default:
            systemPrompt = PromptTemplates.systemPrompt(
                for: conversationType,
                projectName: projectContext?.project.name
            )
        }

        var contextSections: [String] = []

        // Add project context if available
        if let ctx = projectContext {
            contextSections.append(formatProjectContext(ctx))

            // Retrieve relevant knowledge base context if available
            if let knowledgeBase, let lastUserMessage = conversationHistory.last(where: { $0.role == .user }) {
                let kbContext = try await knowledgeBase.retrieveContext(
                    query: lastUserMessage.content,
                    projectId: ctx.project.id,
                    maxChars: 1500
                )
                if !kbContext.isEmpty {
                    contextSections.append(kbContext)
                }
            }
        }

        // Build messages list
        var messages: [LLMMessage] = []

        // System message
        let fullSystemPrompt: String
        if contextSections.isEmpty {
            fullSystemPrompt = systemPrompt
        } else {
            fullSystemPrompt = systemPrompt + "\n\n" + contextSections.joined(separator: "\n\n")
        }

        messages.append(LLMMessage(role: .system, content: fullSystemPrompt))

        // Add conversation history with priority truncation
        let systemTokens = Self.estimateTokens(fullSystemPrompt)
        var remainingBudget = maxTokenBudget - systemTokens

        // Reserve space for the response
        remainingBudget -= 1024

        // Add history from most recent, truncating oldest if needed
        var historyMessages: [LLMMessage] = []
        for message in conversationHistory.reversed() {
            let messageTokens = Self.estimateTokens(message.content)
            if remainingBudget - messageTokens < 0 { break }
            remainingBudget -= messageTokens
            historyMessages.insert(message, at: 0)
        }

        if historyMessages.count < conversationHistory.count && !conversationHistory.isEmpty {
            // Add truncation notice
            let notice = LLMMessage(
                role: .system,
                content: "[Earlier conversation history was truncated to fit within token budget]"
            )
            messages.append(notice)
        }

        messages.append(contentsOf: historyMessages)

        let totalTokens = messages.reduce(0) { $0 + Self.estimateTokens($1.content) }

        if totalTokens > maxTokenBudget {
            throw LLMError.tokenBudgetExceeded
        }

        return ContextPayload(
            systemPrompt: fullSystemPrompt,
            messages: messages,
            estimatedTokens: totalTokens
        )
    }

    // MARK: - Formatting

    private func formatProjectContext(_ ctx: ProjectContext) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        var sections: [String] = []

        // Project overview
        var overview = """
        PROJECT: \(ctx.project.name) (id: \(ctx.project.id.uuidString))
        State: \(ctx.project.lifecycleState.rawValue)
        Definition of Done: \(ctx.project.definitionOfDone ?? "Not defined")
        """
        if let transcript = ctx.project.quickCaptureTranscript, !transcript.isEmpty {
            overview += "\nOriginal Capture: \(transcript)"
        }
        if let notes = ctx.project.notes, !notes.isEmpty {
            overview += "\nNotes: \(notes)"
        }
        sections.append(overview)

        // Build task lookup by milestone
        let tasksByMilestone = Dictionary(grouping: ctx.tasks, by: \.milestoneId)

        // Full project hierarchy: Phase > Milestone > Task > Subtask
        if !ctx.phases.isEmpty {
            var hierarchyLines: [String] = []
            let milestonesForPhase = Dictionary(grouping: ctx.milestones, by: \.phaseId)

            for phase in ctx.phases {
                hierarchyLines.append("PHASE: \(phase.name) (\(phase.status.rawValue)) [id: \(phase.id.uuidString)]")
                let phaseMilestones = milestonesForPhase[phase.id] ?? []
                if phaseMilestones.isEmpty {
                    hierarchyLines.append("  (no milestones)")
                }
                for ms in phaseMilestones {
                    var msLine = "  MILESTONE: \(ms.name) (\(ms.status.rawValue)) [id: \(ms.id.uuidString)]"
                    if let deadline = ms.deadline {
                        msLine += " due: \(dateFormatter.string(from: deadline))"
                    }
                    hierarchyLines.append(msLine)

                    let msTasks = tasksByMilestone[ms.id] ?? []
                    if msTasks.isEmpty {
                        hierarchyLines.append("    (no tasks)")
                    }
                    for task in msTasks {
                        var taskLine = "    TASK: \(task.name) (\(task.status.rawValue)) [id: \(task.id.uuidString)]"
                        if task.priority == .high { taskLine += " [HIGH PRIORITY]" }
                        if let effort = task.effortType { taskLine += " [\(effort.rawValue)]" }
                        if let deadline = task.deadline {
                            taskLine += " due: \(dateFormatter.string(from: deadline))"
                        }
                        if let blocked = task.blockedType {
                            taskLine += " [BLOCKED: \(blocked.rawValue) - \(task.blockedReason ?? "")]"
                        }
                        if task.status == .waiting, let reason = task.waitingReason {
                            taskLine += " [WAITING: \(reason)]"
                        }
                        if task.timesDeferred > 0 {
                            taskLine += " [deferred \(task.timesDeferred)x]"
                        }
                        hierarchyLines.append(taskLine)

                        // Subtasks
                        if let subtasks = ctx.subtasksByTaskId[task.id] {
                            for subtask in subtasks {
                                let check = subtask.isCompleted ? "x" : " "
                                hierarchyLines.append("      [\(check)] \(subtask.name) [id: \(subtask.id.uuidString)]")
                            }
                        }
                    }
                }
            }
            sections.append("PROJECT STRUCTURE:\n" + hierarchyLines.joined(separator: "\n"))
        }

        // Frequently deferred tasks (highlight separately for pattern awareness)
        if !ctx.frequentlyDeferredTasks.isEmpty {
            let deferredList = ctx.frequentlyDeferredTasks.map {
                "- \($0.name) (deferred \($0.timesDeferred)x) [id: \($0.id.uuidString)]"
            }.joined(separator: "\n")
            sections.append("FREQUENTLY DEFERRED:\n\(deferredList)")
        }

        // Recent check-ins
        if !ctx.recentCheckIns.isEmpty {
            let checkInList = ctx.recentCheckIns.prefix(3).map {
                "- \(dateFormatter.string(from: $0.timestamp)) (\($0.depth.rawValue)): \($0.aiSummary.isEmpty ? "No summary" : $0.aiSummary)"
            }.joined(separator: "\n")
            sections.append("RECENT CHECK-INS:\n\(checkInList)")
        }

        // Estimate calibration data
        if let accuracy = ctx.estimateAccuracy {
            var estimateLines: [String] = []
            estimateLines.append("Average accuracy ratio: \(String(format: "%.0f", accuracy * 100))% (actual vs estimated)")
            if let multiplier = ctx.suggestedMultiplier {
                estimateLines.append("Suggested pessimism multiplier: \(String(format: "%.1f", multiplier))x")
            }
            if let trend = ctx.accuracyTrend {
                let direction = trend.newer >= trend.older ? "improving" : "declining"
                estimateLines.append("Trend: \(direction) (\(String(format: "%.0f", trend.older * 100))% → \(String(format: "%.0f", trend.newer * 100))%)")
            }
            sections.append("ESTIMATE CALIBRATION:\n" + estimateLines.joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n")
    }
}
