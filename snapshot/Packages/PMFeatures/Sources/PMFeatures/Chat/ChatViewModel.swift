import Foundation
import PMDomain
import PMServices
import PMUtilities
import os

/// A single chat message for display.
public struct ChatMessage: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let role: LLMMessage.Role
    public let content: String
    public let timestamp: Date
    public let actions: [AIAction]

    public init(
        id: UUID = UUID(),
        role: LLMMessage.Role,
        content: String,
        timestamp: Date = Date(),
        actions: [AIAction] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.actions = actions
    }
}

/// ViewModel for the AI chat interface.
@Observable
@MainActor
public final class ChatViewModel {
    // MARK: - State

    public private(set) var messages: [ChatMessage] = []
    public var inputText: String = ""
    public var selectedProjectId: UUID? {
        didSet {
            if selectedProjectId != oldValue {
                clearChat()
                Task {
                    await loadConversations()
                    await checkReturnBriefing()
                }
            }
        }
    }
    public private(set) var projects: [Project] = []
    public var conversationType: ConversationType = .general
    public private(set) var isLoading = false
    public private(set) var error: String?
    public private(set) var pendingConfirmation: BundledConfirmation?
    public private(set) var returnBriefing: String?

    // MARK: - Dependencies

    private let llmClient: LLMClientProtocol
    private let actionParser: ActionParser
    private let actionExecutor: ActionExecutor
    private let contextAssembler: ContextAssembler
    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let subtaskRepo: SubtaskRepositoryProtocol
    private let checkInRepo: CheckInRepositoryProtocol
    private let conversationRepo: ConversationRepositoryProtocol?

    /// The currently active conversation for persistence.
    public private(set) var activeConversation: Conversation?
    public private(set) var savedConversations: [Conversation] = []

    /// Days since last check-in before showing a return briefing (configurable from settings).
    public var returnBriefingThresholdDays: Int = 14

    /// Trust level for AI actions: "confirmAll" (default), "autoMinor", "autoAll".
    public var aiTrustLevel: String = "confirmAll"

    // MARK: - Init

    public init(
        llmClient: LLMClientProtocol,
        actionExecutor: ActionExecutor,
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        subtaskRepo: SubtaskRepositoryProtocol,
        checkInRepo: CheckInRepositoryProtocol,
        conversationRepo: ConversationRepositoryProtocol? = nil,
        contextAssembler: ContextAssembler = ContextAssembler()
    ) {
        self.llmClient = llmClient
        self.actionParser = ActionParser()
        self.actionExecutor = actionExecutor
        self.contextAssembler = contextAssembler
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.milestoneRepo = milestoneRepo
        self.taskRepo = taskRepo
        self.subtaskRepo = subtaskRepo
        self.checkInRepo = checkInRepo
        self.conversationRepo = conversationRepo
    }

    // MARK: - Loading

    public func loadProjects() async {
        do {
            projects = try await projectRepo.fetchAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Send Message

    /// Send the current input text as a user message.
    public func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        await persistMessage(userMessage)
        inputText = ""
        isLoading = true
        error = nil

        do {
            // Build context
            let projectContext = try await buildProjectContext()
            let history = messages.map { LLMMessage(role: $0.role, content: $0.content) }
            let payload = try await contextAssembler.assemble(
                conversationType: conversationType,
                projectContext: projectContext,
                conversationHistory: history
            )

            // Send to LLM
            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: payload.messages, config: config)

            // Parse response
            let parsed = actionParser.parse(response.content)

            // Add assistant message
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: parsed.naturalLanguage,
                actions: parsed.actions
            )
            messages.append(assistantMessage)
            await persistMessage(assistantMessage)

            // If there are actions, handle based on trust level
            if !parsed.actions.isEmpty {
                if aiTrustLevel == "autoAll" {
                    // Auto-apply all actions
                    let confirmation = await actionExecutor.generateConfirmation(from: parsed.actions)
                    try await actionExecutor.execute(confirmation)
                    Log.ai.info("Auto-applied \(confirmation.acceptedCount) actions (trust: autoAll)")
                } else if aiTrustLevel == "autoMinor" {
                    // Auto-apply minor actions, confirm major ones
                    let minorActions = parsed.actions.filter { !$0.isMajor }
                    let majorActions = parsed.actions.filter { $0.isMajor }

                    if !minorActions.isEmpty {
                        let minorConfirmation = await actionExecutor.generateConfirmation(from: minorActions)
                        try await actionExecutor.execute(minorConfirmation)
                        Log.ai.info("Auto-applied \(minorConfirmation.acceptedCount) minor actions")
                    }

                    if !majorActions.isEmpty {
                        pendingConfirmation = await actionExecutor.generateConfirmation(from: majorActions)
                    }
                } else {
                    // confirmAll — show all actions for confirmation
                    pendingConfirmation = await actionExecutor.generateConfirmation(from: parsed.actions)
                }
            }

            Log.ai.info("Chat: received response with \(parsed.actions.count) actions")
        } catch {
            self.error = "Failed to get response: \(error.localizedDescription)"
            Log.ai.error("Chat send failed: \(error)")
        }

        isLoading = false
    }

    /// Send a voice transcript as a message.
    public func sendVoiceTranscript(_ transcript: String) async {
        inputText = transcript
        await send()
    }

    // MARK: - Action Confirmation

    /// Apply all accepted actions from the pending confirmation.
    public func applyConfirmation() async {
        guard let confirmation = pendingConfirmation else { return }
        do {
            try await actionExecutor.execute(confirmation)
            pendingConfirmation = nil
            Log.ai.info("Applied \(confirmation.acceptedCount) actions")
        } catch {
            self.error = "Failed to apply actions: \(error.localizedDescription)"
        }
    }

    /// Cancel the pending confirmation.
    public func cancelConfirmation() {
        pendingConfirmation = nil
    }

    /// Toggle acceptance of a specific change.
    public func toggleChange(at index: Int) {
        guard var confirmation = pendingConfirmation,
              index < confirmation.changes.count else { return }
        confirmation.changes[index].accepted.toggle()
        pendingConfirmation = confirmation
    }

    // MARK: - Return Briefing

    /// Check if the selected project needs a return briefing (dormant for > threshold days).
    private func checkReturnBriefing() async {
        returnBriefing = nil
        guard let projectId = selectedProjectId,
              let project = projects.first(where: { $0.id == projectId }) else { return }

        do {
            let lastCheckIn = try await checkInRepo.fetchLatest(forProject: projectId)
            let daysSinceCheckIn: Int
            if let checkIn = lastCheckIn {
                daysSinceCheckIn = Calendar.current.dateComponents([.day], from: checkIn.timestamp, to: Date()).day ?? 0
            } else {
                // No check-ins — only treat as dormant if project isn't brand new
                let daysSinceCreation = Calendar.current.dateComponents([.day], from: project.createdAt, to: Date()).day ?? 0
                if daysSinceCreation < returnBriefingThresholdDays {
                    return  // New project, not dormant
                }
                daysSinceCheckIn = returnBriefingThresholdDays + 1
            }

            guard daysSinceCheckIn >= returnBriefingThresholdDays else { return }

            // Generate a return briefing via the LLM
            isLoading = true
            let projectContext = try await buildProjectContext()
            let systemPrompt = PromptTemplates.reEntry(projectName: project.name)
            let userPrompt = "I'm returning to this project after \(daysSinceCheckIn) days. Give me a brief re-entry summary."
            let payload = [
                LLMMessage(role: .system, content: systemPrompt),
                LLMMessage(role: .user, content: userPrompt + (projectContext.map { "\n\n" + formatContext($0) } ?? ""))
            ]

            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: payload, config: config)
            let parsed = actionParser.parse(response.content)
            returnBriefing = parsed.naturalLanguage
            conversationType = .reEntry

            Log.ai.info("Generated return briefing for '\(project.name)' (dormant \(daysSinceCheckIn) days)")
        } catch {
            Log.ai.error("Failed to check return briefing: \(error)")
        }
        isLoading = false
    }

    /// Dismiss the return briefing card.
    public func dismissReturnBriefing() {
        returnBriefing = nil
    }

    /// Format project context as a text summary for the LLM.
    private func formatContext(_ ctx: ProjectContext) -> String {
        var lines: [String] = []
        lines.append("Project: \(ctx.project.name) (\(ctx.project.lifecycleState.rawValue))")
        lines.append("Phases: \(ctx.phases.count), Milestones: \(ctx.milestones.count), Tasks: \(ctx.tasks.count)")
        let blocked = ctx.tasks.filter { $0.status == .blocked }
        if !blocked.isEmpty {
            lines.append("Blocked tasks: \(blocked.map(\.name).joined(separator: ", "))")
        }
        let inProgress = ctx.tasks.filter { $0.status == .inProgress }
        if !inProgress.isEmpty {
            lines.append("In progress: \(inProgress.map(\.name).joined(separator: ", "))")
        }
        if !ctx.frequentlyDeferredTasks.isEmpty {
            lines.append("Frequently deferred: \(ctx.frequentlyDeferredTasks.map(\.name).joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    public func clearChat() {
        messages = []
        pendingConfirmation = nil
        error = nil
        activeConversation = nil
        returnBriefing = nil
    }

    // MARK: - Conversation Persistence

    /// Load saved conversations for the selected project.
    public func loadConversations() async {
        guard let conversationRepo else { return }
        do {
            if let projectId = selectedProjectId {
                savedConversations = try await conversationRepo.fetchAll(forProject: projectId)
            } else {
                savedConversations = try await conversationRepo.fetchAll(ofType: .general)
            }
        } catch {
            Log.ai.error("Failed to load conversations: \(error)")
        }
    }

    /// Resume a previously saved conversation.
    public func resumeConversation(_ conversation: Conversation) {
        activeConversation = conversation
        messages = conversation.messages.map { msg in
            ChatMessage(
                id: msg.id,
                role: msg.role == .user ? .user : .assistant,
                content: msg.content,
                timestamp: msg.timestamp
            )
        }
        conversationType = conversation.conversationType
    }

    /// Delete a saved conversation.
    public func deleteConversation(id: UUID) async {
        guard let conversationRepo else { return }
        do {
            try await conversationRepo.delete(id: id)
            savedConversations.removeAll { $0.id == id }
            if activeConversation?.id == id {
                clearChat()
            }
            Log.ai.info("Deleted conversation \(id)")
        } catch {
            Log.ai.error("Failed to delete conversation: \(error)")
        }
    }

    /// Convert a display ChatMessage to a domain ChatMessage for persistence.
    private func toDomainMessage(_ message: ChatMessage) -> PMDomain.ChatMessage {
        let role: ChatRole = message.role == .user ? .user : .assistant
        return PMDomain.ChatMessage(
            id: message.id,
            role: role,
            content: message.content,
            timestamp: message.timestamp
        )
    }

    /// Persist the current message to the active conversation.
    private func persistMessage(_ message: ChatMessage) async {
        guard let conversationRepo else { return }
        guard message.role == .user || message.role == .assistant else { return }

        let domainMessage = toDomainMessage(message)

        do {
            if activeConversation == nil {
                // Create a new conversation
                var conversation = Conversation(
                    projectId: selectedProjectId,
                    conversationType: conversationType
                )
                conversation.messages = [domainMessage]
                try await conversationRepo.save(conversation)
                activeConversation = conversation
            } else {
                try await conversationRepo.appendMessage(domainMessage, toConversation: activeConversation!.id)
            }
        } catch {
            Log.ai.error("Failed to persist message: \(error)")
        }
    }

    public var selectedProject: Project? {
        guard let id = selectedProjectId else { return nil }
        return projects.first { $0.id == id }
    }

    public var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    private func buildProjectContext() async throws -> ProjectContext? {
        guard let project = selectedProject else { return nil }

        let phases = try await phaseRepo.fetchAll(forProject: project.id)
        var allMilestones: [Milestone] = []
        var allTasks: [PMTask] = []
        var subtaskMap: [UUID: [Subtask]] = [:]

        for phase in phases {
            let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
            allMilestones.append(contentsOf: milestones)
            for ms in milestones {
                let tasks = try await taskRepo.fetchAll(forMilestone: ms.id)
                allTasks.append(contentsOf: tasks)
                for task in tasks {
                    let subtasks = try await subtaskRepo.fetchAll(forTask: task.id)
                    if !subtasks.isEmpty {
                        subtaskMap[task.id] = subtasks
                    }
                }
            }
        }

        let recentCheckIns = try await checkInRepo.fetchAll(forProject: project.id)
        let frequentlyDeferred = allTasks.filter { $0.timesDeferred >= 3 }

        // Compute estimate calibration data for AI awareness
        let completedTasks = allTasks.filter { $0.status == .completed }
        let tracker = EstimateTracker()
        let accuracy = tracker.averageAccuracy(tasks: completedTasks)
        let multiplier = tracker.suggestedMultiplier(tasks: completedTasks)
        let trend = tracker.accuracyTrend(tasks: completedTasks)

        return ProjectContext(
            project: project,
            phases: phases,
            milestones: allMilestones,
            tasks: allTasks,
            subtasksByTaskId: subtaskMap,
            recentCheckIns: Array(recentCheckIns.prefix(5)),
            frequentlyDeferredTasks: frequentlyDeferred,
            estimateAccuracy: accuracy,
            suggestedMultiplier: multiplier,
            accuracyTrend: trend
        )
    }
}
