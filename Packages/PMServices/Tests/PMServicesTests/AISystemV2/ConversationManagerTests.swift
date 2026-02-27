import Testing
import Foundation
@testable import PMServices
import PMDomain

@Suite("ConversationManager")
struct ConversationManagerTests {
    let projectId = UUID()
    let mockRepo = MockSessionRepository()
    let mockLLM = MockV2LLMClient()

    var manager: ConversationManager {
        let lifecycle = SessionLifecycleManager(repo: mockRepo)
        let summaryService = SummaryGenerationService(llmClient: mockLLM, repo: mockRepo)
        let store = V2PromptTemplateStore(defaults: UserDefaults(suiteName: "test.convManager.\(UUID().uuidString)")!)
        let composer = PromptComposer(store: store)
        return ConversationManager(
            llmClient: mockLLM,
            sessionRepo: mockRepo,
            lifecycleManager: lifecycle,
            summaryService: summaryService,
            promptComposer: composer
        )
    }

    func makeProjectData(project: Project? = nil) -> V2ContextAssembler.ProjectData {
        V2ContextAssembler.ProjectData(
            project: project ?? TestFixtures.project(id: projectId, name: "Test Project", lifecycleState: .focused)
        )
    }

    // MARK: - Session Initiation

    @Test("Start session creates an active session")
    func startSession() async throws {
        let mgr = manager
        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        #expect(session.status == .active)
        #expect(session.mode == .exploration)
        #expect(session.projectId == projectId)
    }

    @Test("Start session with sub-mode")
    func startSessionWithSubMode() async throws {
        let mgr = manager
        let session = try await mgr.startSession(
            projectId: projectId,
            mode: .executionSupport,
            subMode: .checkIn
        )
        #expect(session.mode == .executionSupport)
        #expect(session.subMode == .checkIn)
    }

    @Test("Start session pauses existing active session")
    func startSessionPausesExisting() async throws {
        let mgr = manager
        let first = try await mgr.startSession(projectId: projectId, mode: .exploration)
        let second = try await mgr.startSession(projectId: projectId, mode: .definition)

        let firstUpdated = try await mockRepo.fetch(id: first.id)
        #expect(firstUpdated?.status == .paused)
        #expect(second.status == .active)
    }

    // MARK: - Session Resumption

    @Test("Resume paused session")
    func resumeSession() async throws {
        let mgr = manager
        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        _ = try await mgr.pauseSession(session.id)

        let resumed = try await mgr.resumeSession(session.id)
        #expect(resumed.status == .active)
    }

    @Test("pausedSession returns the paused session for a project")
    func findPausedSession() async throws {
        let mgr = manager
        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        _ = try await mgr.pauseSession(session.id)

        let paused = try await mgr.pausedSession(forProject: projectId)
        #expect(paused != nil)
        #expect(paused?.id == session.id)
    }

    @Test("pausedSession returns nil when no paused session")
    func noPausedSession() async throws {
        let mgr = manager
        let paused = try await mgr.pausedSession(forProject: projectId)
        #expect(paused == nil)
    }

    // MARK: - Message Sending

    @Test("Send message records user and assistant messages")
    func sendMessage() async throws {
        let mgr = manager
        mockLLM.defaultResponse = MockV2Responses.plain("Hello! Let's explore your project.")

        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        let result = try await mgr.sendMessage(
            "I want to build a task manager",
            sessionId: session.id,
            projectData: makeProjectData()
        )

        #expect(result.naturalLanguage.contains("Hello"))
        #expect(result.actions.isEmpty) // Exploration mode doesn't parse actions

        let messages = try await mgr.messages(forSession: session.id)
        #expect(messages.count == 2) // user + assistant
        #expect(messages[0].role == .user)
        #expect(messages[0].content == "I want to build a task manager")
        #expect(messages[1].role == .assistant)
    }

    @Test("Send message throws when session not found")
    func sendMessageSessionNotFound() async throws {
        let mgr = manager
        let fakeId = UUID()
        do {
            _ = try await mgr.sendMessage(
                "Hello",
                sessionId: fakeId,
                projectData: makeProjectData()
            )
            Issue.record("Should have thrown")
        } catch let error as ConversationError {
            #expect(error == .sessionNotFound(fakeId))
        }
    }

    @Test("Send message throws when session not active")
    func sendMessageSessionNotActive() async throws {
        let mgr = manager
        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        _ = try await mgr.pauseSession(session.id)

        do {
            _ = try await mgr.sendMessage(
                "Hello",
                sessionId: session.id,
                projectData: makeProjectData()
            )
            Issue.record("Should have thrown")
        } catch let error as ConversationError {
            #expect(error == .sessionNotActive(session.id))
        }
    }

    @Test("Send message includes system prompt in LLM call")
    func systemPromptIncluded() async throws {
        let mgr = manager
        mockLLM.defaultResponse = MockV2Responses.plain("Response")

        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        _ = try await mgr.sendMessage(
            "Hello",
            sessionId: session.id,
            projectData: makeProjectData()
        )

        // The system prompt should contain the foundation prompt
        let systemPrompt = mockLLM.lastSystemPrompt
        #expect(systemPrompt != nil)
        #expect(systemPrompt?.contains("collaborative thinking partner") == true)
        #expect(systemPrompt?.contains("Exploration mode") == true)
    }

    @Test("Send message passes conversation history to LLM")
    func conversationHistoryIncluded() async throws {
        let mgr = manager
        mockLLM.queuedResponses = [
            MockV2Responses.plain("First response"),
            MockV2Responses.plain("Second response"),
        ]

        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        _ = try await mgr.sendMessage("First message", sessionId: session.id, projectData: makeProjectData())
        _ = try await mgr.sendMessage("Second message", sessionId: session.id, projectData: makeProjectData())

        // The second call should have 4 conversation messages (user, assistant, user, assistant)
        // plus system message
        let lastMessages = mockLLM.sentMessages.last!
        let nonSystemMessages = lastMessages.filter { $0.role != .system }
        #expect(nonSystemMessages.count >= 3) // at least user1, assistant1, user2
    }

    // MARK: - Action Parsing

    @Test("Actions parsed in planning mode")
    func actionsParsedInPlanning() async throws {
        let mgr = manager
        mockLLM.defaultResponse = MockV2Responses.withActions(
            "I'll create that phase for you.",
            actions: "[ACTION: CREATE_PHASE] projectId: \(projectId.uuidString), name: \"Phase 1: Setup\" [/ACTION]"
        )

        let session = try await mgr.startSession(projectId: projectId, mode: .planning)
        let result = try await mgr.sendMessage(
            "Let's create the first phase",
            sessionId: session.id,
            projectData: makeProjectData()
        )

        #expect(result.naturalLanguage.contains("create that phase"))
        #expect(!result.actions.isEmpty)
    }

    @Test("Actions not parsed in exploration mode")
    func actionsNotParsedInExploration() async throws {
        let mgr = manager
        mockLLM.defaultResponse = MockV2Responses.withActions(
            "Let me create something.",
            actions: "[ACTION: CREATE_PHASE] projectId: \(projectId.uuidString), name: \"Phase 1\" [/ACTION]"
        )

        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        let result = try await mgr.sendMessage(
            "Hello",
            sessionId: session.id,
            projectData: makeProjectData()
        )

        // In exploration mode, actions are not parsed — the full text is returned as natural language
        #expect(result.actions.isEmpty)
    }

    // MARK: - Session Completion

    @Test("Complete session generates summary")
    func completeSession() async throws {
        let mgr = manager
        mockLLM.queuedResponses = [
            MockV2Responses.plain("Let's explore your idea."),
            // Summary generation response
            LLMResponse(content: """
                {
                    "contentEstablished": {"decisions": ["Decided to build a task manager"], "factsLearned": [], "progressMade": ["Explored the concept"]},
                    "contentObserved": {"patterns": [], "concerns": [], "strengths": ["Clear vision"]},
                    "whatComesNext": {"nextActions": ["Create vision statement"], "openQuestions": [], "suggestedMode": "definition"}
                }
                """),
        ]

        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        _ = try await mgr.sendMessage("I want to build a task manager", sessionId: session.id, projectData: makeProjectData())

        let summary = try await mgr.completeSession(session.id)
        #expect(summary.sessionId == session.id)
        #expect(summary.mode == .exploration)
        #expect(!summary.contentEstablished.decisions.isEmpty)
    }

    @Test("Pause session transitions to paused")
    func pauseSession() async throws {
        let mgr = manager
        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        let paused = try await mgr.pauseSession(session.id)
        #expect(paused.status == .paused)
    }

    @Test("End session generates summary with incompleteUserEnded status")
    func endSession() async throws {
        let mgr = manager
        mockLLM.queuedResponses = [
            MockV2Responses.plain("Let me help."),
            LLMResponse(content: """
                {
                    "contentEstablished": {"decisions": [], "factsLearned": [], "progressMade": ["Started discussion"]},
                    "contentObserved": {"patterns": [], "concerns": [], "strengths": []},
                    "whatComesNext": {"nextActions": ["Continue later"], "openQuestions": [], "suggestedMode": null}
                }
                """),
        ]

        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        _ = try await mgr.sendMessage("Hello", sessionId: session.id, projectData: makeProjectData())

        let summary = try await mgr.endSession(session.id)
        #expect(summary.completionStatus == .incompleteUserEnded)
    }

    // MARK: - Voice Transcript

    @Test("Voice transcript is preserved on message")
    func voiceTranscript() async throws {
        let mgr = manager
        mockLLM.defaultResponse = MockV2Responses.plain("Got it.")

        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        _ = try await mgr.sendMessage(
            "Build a task manager app",
            sessionId: session.id,
            projectData: makeProjectData(),
            rawVoiceTranscript: "Build a task manager app, like, you know"
        )

        let messages = try await mgr.messages(forSession: session.id)
        let userMsg = messages.first { $0.role == .user }
        #expect(userMsg?.rawVoiceTranscript == "Build a task manager app, like, you know")
    }

    // MARK: - Context Variables

    @Test("Exploration mode injects deliverable catalogue")
    func explorationCatalogueInjected() async throws {
        let mgr = manager
        mockLLM.defaultResponse = MockV2Responses.plain("Response")

        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)
        _ = try await mgr.sendMessage("Hello", sessionId: session.id, projectData: makeProjectData())

        let systemPrompt = mockLLM.lastSystemPrompt!
        // The catalogue should have been substituted
        #expect(systemPrompt.contains("visionStatement"))
        #expect(!systemPrompt.contains("{{deliverable_catalogue}}"))
    }

    @Test("Execution support mode injects sub_mode variable")
    func executionSupportSubModeInjected() async throws {
        let mgr = manager
        mockLLM.defaultResponse = MockV2Responses.plain("Response")

        let session = try await mgr.startSession(
            projectId: projectId,
            mode: .executionSupport,
            subMode: .checkIn
        )
        _ = try await mgr.sendMessage("How's it going?", sessionId: session.id, projectData: makeProjectData())

        let systemPrompt = mockLLM.lastSystemPrompt!
        #expect(systemPrompt.contains("checkIn"))
    }

    // MARK: - ConversationConfig

    @Test("Default config for exploration has no action parsing")
    func explorationConfig() {
        let config = ConversationConfig.forMode(.exploration)
        #expect(!config.parseActions)
    }

    @Test("Default config for planning has action parsing")
    func planningConfig() {
        let config = ConversationConfig.forMode(.planning)
        #expect(config.parseActions)
    }

    @Test("Default config for check-in has action parsing")
    func checkInConfig() {
        let config = ConversationConfig.forMode(.executionSupport, subMode: .checkIn)
        #expect(config.parseActions)
    }

    @Test("Default config for retrospective has no action parsing")
    func retrospectiveConfig() {
        let config = ConversationConfig.forMode(.executionSupport, subMode: .retrospective)
        #expect(!config.parseActions)
    }
}
