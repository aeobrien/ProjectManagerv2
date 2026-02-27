import Foundation
import PMDomain
import PMUtilities

/// The result of processing a user message through the conversation pipeline.
public struct ConversationResult: Sendable {
    /// The natural language portion of the AI's response.
    public let naturalLanguage: String
    /// Any parsed actions from the response (only for modes that support actions).
    public let actions: [AIAction]
    /// Token usage from the API call.
    public let inputTokens: Int?
    public let outputTokens: Int?

    public init(
        naturalLanguage: String,
        actions: [AIAction] = [],
        inputTokens: Int? = nil,
        outputTokens: Int? = nil
    ) {
        self.naturalLanguage = naturalLanguage
        self.actions = actions
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// Configuration for a conversation session.
public struct ConversationConfig: Sendable {
    /// Whether action blocks should be parsed from responses.
    public let parseActions: Bool
    /// LLM request configuration.
    public let llmConfig: LLMRequestConfig

    public init(
        parseActions: Bool = false,
        llmConfig: LLMRequestConfig = LLMRequestConfig()
    ) {
        self.parseActions = parseActions
        self.llmConfig = llmConfig
    }

    /// Default configurations per mode.
    public static func forMode(_ mode: SessionMode, subMode: SessionSubMode? = nil) -> ConversationConfig {
        switch mode {
        case .exploration:
            return ConversationConfig(parseActions: false)
        case .definition:
            return ConversationConfig(parseActions: false)
        case .planning:
            return ConversationConfig(parseActions: true)
        case .executionSupport:
            switch subMode {
            case .checkIn, .projectReview:
                return ConversationConfig(parseActions: true)
            default:
                return ConversationConfig(parseActions: false)
            }
        }
    }
}

/// The core conversation pipeline for the v2 AI system.
/// Orchestrates the six-step process: session initiation → context assembly →
/// message handling → response processing → session completion → auto-summarisation.
public final class ConversationManager: Sendable {
    private let llmClient: LLMClientProtocol
    private let sessionRepo: SessionRepositoryProtocol
    private let lifecycleManager: SessionLifecycleManager
    private let summaryService: SummaryGenerationService
    private let promptComposer: PromptComposer
    private let contextAssembler: V2ContextAssembler
    private let actionParser: ActionParser

    public init(
        llmClient: LLMClientProtocol,
        sessionRepo: SessionRepositoryProtocol,
        lifecycleManager: SessionLifecycleManager,
        summaryService: SummaryGenerationService,
        promptComposer: PromptComposer,
        contextAssembler: V2ContextAssembler = V2ContextAssembler(),
        actionParser: ActionParser = ActionParser()
    ) {
        self.llmClient = llmClient
        self.sessionRepo = sessionRepo
        self.lifecycleManager = lifecycleManager
        self.summaryService = summaryService
        self.promptComposer = promptComposer
        self.contextAssembler = contextAssembler
        self.actionParser = actionParser
    }

    // MARK: - Step 1: Session Initiation

    /// Start a new session for a project, pausing any existing active session.
    public func startSession(
        projectId: UUID,
        mode: SessionMode,
        subMode: SessionSubMode? = nil
    ) async throws -> Session {
        try await lifecycleManager.startSession(
            projectId: projectId,
            mode: mode,
            subMode: subMode
        )
    }

    /// Resume a paused session.
    public func resumeSession(_ sessionId: UUID) async throws -> Session {
        try await lifecycleManager.resumeSession(sessionId)
    }

    /// Check if a project has a paused session that can be resumed.
    public func pausedSession(forProject projectId: UUID) async throws -> Session? {
        let active = try await sessionRepo.fetchActive(forProject: projectId)
        return active.first { $0.status == .paused }
    }

    // MARK: - Steps 2-4: Context Assembly → Message Handling → Response Processing

    /// Send a user message and get the AI's response.
    /// This is the main pipeline method that handles context assembly, LLM call, and response parsing.
    public func sendMessage(
        _ content: String,
        sessionId: UUID,
        projectData: V2ContextAssembler.ProjectData,
        portfolioData: V2ContextAssembler.PortfolioData? = nil,
        config: ConversationConfig? = nil,
        rawVoiceTranscript: String? = nil
    ) async throws -> ConversationResult {
        // Validate session is active
        guard let session = try await sessionRepo.fetch(id: sessionId) else {
            throw ConversationError.sessionNotFound(sessionId)
        }
        guard session.status == .active else {
            throw ConversationError.sessionNotActive(sessionId)
        }

        let effectiveConfig = config ?? ConversationConfig.forMode(session.mode, subMode: session.subMode)

        // Step 2: Record user message
        let userMessage = try await lifecycleManager.addMessage(
            to: sessionId,
            role: .user,
            content: content,
            rawVoiceTranscript: rawVoiceTranscript
        )
        _ = userMessage

        // Step 3: Assemble context
        let systemPrompt = composeSystemPrompt(mode: session.mode, subMode: session.subMode, projectData: projectData)

        let existingMessages = try await sessionRepo.fetchMessages(forSession: sessionId)
        let conversationHistory = existingMessages.map { msg in
            LLMMessage(
                role: msg.role == .user ? .user : .assistant,
                content: msg.content
            )
        }

        let payload = contextAssembler.assemblePayload(
            systemPrompt: systemPrompt,
            mode: session.mode,
            subMode: session.subMode,
            projectData: projectData,
            portfolioData: portfolioData,
            conversationHistory: conversationHistory
        )

        // Step 4: Call LLM
        let response = try await llmClient.send(
            messages: payload.messages,
            config: effectiveConfig.llmConfig
        )

        // Step 5: Parse response
        let parsed: ParsedResponse
        if effectiveConfig.parseActions {
            parsed = actionParser.parse(response.content)
        } else {
            parsed = ParsedResponse(naturalLanguage: response.content, actions: [])
        }

        // Record assistant message
        _ = try await lifecycleManager.addMessage(
            to: sessionId,
            role: .assistant,
            content: response.content
        )

        return ConversationResult(
            naturalLanguage: parsed.naturalLanguage,
            actions: parsed.actions,
            inputTokens: response.inputTokens,
            outputTokens: response.outputTokens
        )
    }

    // MARK: - Step 5: Session Completion

    /// Complete a session, generating a summary.
    public func completeSession(
        _ sessionId: UUID,
        completionStatus: SessionCompletionStatus = .completed
    ) async throws -> SessionSummary {
        // Transition to completed
        _ = try await lifecycleManager.transitionSession(sessionId, to: .completed)

        // Generate summary
        let summary = try await summaryService.generateSummary(
            for: sessionId,
            completionStatus: completionStatus
        )

        return summary
    }

    /// Pause a session (can be resumed later or auto-summarised).
    public func pauseSession(_ sessionId: UUID) async throws -> Session {
        try await lifecycleManager.transitionSession(sessionId, to: .paused)
    }

    /// End a session without completing it (user manually ended).
    public func endSession(
        _ sessionId: UUID
    ) async throws -> SessionSummary {
        _ = try await lifecycleManager.transitionSession(sessionId, to: .completed)

        let summary = try await summaryService.generateSummary(
            for: sessionId,
            completionStatus: .incompleteUserEnded
        )

        return summary
    }

    // MARK: - Conversation History

    /// Get all messages for a session.
    public func messages(forSession sessionId: UUID) async throws -> [SessionMessage] {
        try await sessionRepo.fetchMessages(forSession: sessionId)
    }

    // MARK: - Private

    private func composeSystemPrompt(
        mode: SessionMode,
        subMode: SessionSubMode?,
        projectData: V2ContextAssembler.ProjectData
    ) -> String {
        var variables: [String: String] = [:]

        // Inject mode-specific variables
        switch mode {
        case .exploration:
            let catalogue = DeliverableTemplateRegistry.catalogueSummary()
            variables["deliverable_catalogue"] = catalogue

        case .definition:
            // Inject deliverable template info
            let completedTypes = projectData.deliverables
                .filter { $0.status == .completed || $0.status == .revised }
                .map(\.type.rawValue)
            let pendingTypes = projectData.deliverables
                .filter { $0.status == .pending || $0.status == .inProgress }
                .map(\.type.rawValue)
            let allTypes = (completedTypes + pendingTypes)
            variables["deliverable_list"] = allTypes.isEmpty ? "None specified" : allTypes.joined(separator: ", ")

            // Current deliverable (the first in-progress one, or first pending)
            if let current = projectData.deliverables.first(where: { $0.status == .inProgress })
                ?? projectData.deliverables.first(where: { $0.status == .pending }) {
                variables["current_deliverable"] = current.type.rawValue

                let template = DeliverableTemplateRegistry.template(for: current.type)
                variables["deliverable_template_info_requirements"] = template.formattedRequirements()
                variables["deliverable_template_structure"] = template.formattedStructure()
            } else {
                variables["current_deliverable"] = "None"
                variables["deliverable_template_info_requirements"] = "N/A"
                variables["deliverable_template_structure"] = "N/A"
            }

        case .executionSupport:
            if let subMode {
                variables["sub_mode"] = subMode.rawValue
            }

        case .planning:
            break
        }

        return promptComposer.compose(mode: mode, subMode: subMode, variables: variables)
    }
}
