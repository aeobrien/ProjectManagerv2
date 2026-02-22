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
    public func assemble(
        conversationType: ConversationType,
        projectContext: ProjectContext?,
        conversationHistory: [LLMMessage] = []
    ) async throws -> ContextPayload {
        let systemPrompt = PromptTemplates.systemPrompt(
            for: conversationType,
            projectName: projectContext?.project.name
        )

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
        var sections: [String] = []

        // Project overview
        sections.append("""
        PROJECT: \(ctx.project.name)
        State: \(ctx.project.lifecycleState.rawValue)
        Definition of Done: \(ctx.project.definitionOfDone ?? "Not defined")
        """)

        // Phases
        if !ctx.phases.isEmpty {
            let phaseList = ctx.phases.map { "- \($0.name) (\($0.status.rawValue))" }.joined(separator: "\n")
            sections.append("PHASES:\n\(phaseList)")
        }

        // Active milestones (limit to keep context manageable)
        let activeMilestones = ctx.milestones.filter { $0.status != .completed }.prefix(10)
        if !activeMilestones.isEmpty {
            let msList = activeMilestones.map { ms in
                var line = "- \(ms.name) (\(ms.status.rawValue))"
                if let deadline = ms.deadline {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    line += " due: \(formatter.string(from: deadline))"
                }
                return line
            }.joined(separator: "\n")
            sections.append("ACTIVE MILESTONES:\n\(msList)")
        }

        // In-progress and blocked tasks (limit)
        let relevantTasks = ctx.tasks.filter {
            $0.status == .inProgress || $0.blockedType != nil
        }.prefix(15)
        if !relevantTasks.isEmpty {
            let taskList = relevantTasks.map { task in
                var line = "- \(task.name) (\(task.status.rawValue))"
                if let blocked = task.blockedType {
                    line += " [BLOCKED: \(blocked.rawValue) - \(task.blockedReason ?? "")]"
                }
                if task.timesDeferred > 0 {
                    line += " [deferred \(task.timesDeferred)x]"
                }
                return line
            }.joined(separator: "\n")
            sections.append("CURRENT TASKS:\n\(taskList)")
        }

        // Frequently deferred tasks
        if !ctx.frequentlyDeferredTasks.isEmpty {
            let deferredList = ctx.frequentlyDeferredTasks.map {
                "- \($0.name) (deferred \($0.timesDeferred)x)"
            }.joined(separator: "\n")
            sections.append("FREQUENTLY DEFERRED:\n\(deferredList)")
        }

        // Recent check-ins
        if !ctx.recentCheckIns.isEmpty {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            let checkInList = ctx.recentCheckIns.prefix(3).map {
                "- \(formatter.string(from: $0.timestamp)) (\($0.depth.rawValue)): \($0.aiSummary.isEmpty ? "No summary" : $0.aiSummary)"
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
