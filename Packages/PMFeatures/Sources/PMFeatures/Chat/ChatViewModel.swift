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
    public var selectedProjectId: UUID?
    public private(set) var projects: [Project] = []
    public var conversationType: ConversationType = .general
    public private(set) var isLoading = false
    public private(set) var error: String?
    public private(set) var pendingConfirmation: BundledConfirmation?

    // MARK: - Dependencies

    private let llmClient: LLMClientProtocol
    private let actionParser: ActionParser
    private let actionExecutor: ActionExecutor
    private let contextAssembler: ContextAssembler
    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let checkInRepo: CheckInRepositoryProtocol
    private let conversationRepo: ConversationRepositoryProtocol?

    /// The currently active conversation for persistence.
    public private(set) var activeConversation: Conversation?
    public private(set) var savedConversations: [Conversation] = []

    // MARK: - Init

    public init(
        llmClient: LLMClientProtocol,
        actionExecutor: ActionExecutor,
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
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

            // If there are actions, create confirmation
            if !parsed.actions.isEmpty {
                pendingConfirmation = actionExecutor.generateConfirmation(from: parsed.actions)
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

    // MARK: - Helpers

    public func clearChat() {
        messages = []
        pendingConfirmation = nil
        error = nil
        activeConversation = nil
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

        for phase in phases {
            let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
            allMilestones.append(contentsOf: milestones)
            for ms in milestones {
                let tasks = try await taskRepo.fetchAll(forMilestone: ms.id)
                allTasks.append(contentsOf: tasks)
            }
        }

        let recentCheckIns = try await checkInRepo.fetchAll(forProject: project.id)
        let frequentlyDeferred = allTasks.filter { $0.timesDeferred >= 3 }

        return ProjectContext(
            project: project,
            phases: phases,
            milestones: allMilestones,
            tasks: allTasks,
            recentCheckIns: Array(recentCheckIns.prefix(5)),
            frequentlyDeferredTasks: frequentlyDeferred
        )
    }
}
