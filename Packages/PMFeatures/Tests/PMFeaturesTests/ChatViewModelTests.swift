import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain
@testable import PMServices

// MARK: - Mock LLM Client

final class MockLLMClient: LLMClientProtocol, @unchecked Sendable {
    var responseText: String = "Here is a helpful response."
    var shouldThrow = false

    func send(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse {
        if shouldThrow { throw LLMError.networkError("Mock error") }
        return LLMResponse(content: responseText, inputTokens: 100, outputTokens: 50)
    }
}

// MARK: - Mock Conversation Repository

final class MockConversationRepository: ConversationRepositoryProtocol, @unchecked Sendable {
    var conversations: [Conversation] = []
    var appendedMessages: [(PMDomain.ChatMessage, UUID)] = []

    func fetchAll(forProject projectId: UUID) async throws -> [Conversation] {
        conversations.filter { $0.projectId == projectId }
    }
    func fetchAll(ofType type: ConversationType) async throws -> [Conversation] {
        conversations.filter { $0.conversationType == type }
    }
    func fetch(id: UUID) async throws -> Conversation? {
        conversations.first { $0.id == id }
    }
    func save(_ conversation: Conversation) async throws {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx] = conversation
        } else {
            conversations.append(conversation)
        }
    }
    func delete(id: UUID) async throws {
        conversations.removeAll { $0.id == id }
    }
    func appendMessage(_ message: PMDomain.ChatMessage, toConversation conversationId: UUID) async throws {
        appendedMessages.append((message, conversationId))
    }
}

// MARK: - Chat Test Helper

private let chatCatId = UUID()

@MainActor
func makeChatVM(
    llmClient: MockLLMClient = MockLLMClient(),
    conversationRepo: MockConversationRepository? = nil
) -> (
    ChatViewModel, MockLLMClient, MockProjectRepository, MockPhaseRepository,
    MockMilestoneRepository, MockTaskRepository, MockCheckInRepository, MockConversationRepository?
) {
    let projectRepo = MockProjectRepository()
    let phaseRepo = MockPhaseRepository()
    let milestoneRepo = MockMilestoneRepository()
    let taskRepo = MockTaskRepository()
    let subtaskRepo = MockSubtaskRepository()
    let checkInRepo = MockCheckInRepository()

    let executor = ActionExecutor(
        taskRepo: taskRepo,
        milestoneRepo: milestoneRepo,
        subtaskRepo: subtaskRepo,
        projectRepo: projectRepo
    )

    let vm = ChatViewModel(
        llmClient: llmClient,
        actionExecutor: executor,
        projectRepo: projectRepo,
        phaseRepo: phaseRepo,
        milestoneRepo: milestoneRepo,
        taskRepo: taskRepo,
        checkInRepo: checkInRepo,
        conversationRepo: conversationRepo
    )

    return (vm, llmClient, projectRepo, phaseRepo, milestoneRepo, taskRepo, checkInRepo, conversationRepo)
}

// MARK: - Tests

@Suite("ChatViewModel")
struct ChatViewModelTests {

    @Test("Initial state")
    @MainActor
    func initialState() {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()
        #expect(vm.messages.isEmpty)
        #expect(vm.inputText == "")
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(vm.pendingConfirmation == nil)
        #expect(vm.conversationType == .general)
    }

    @Test("Load projects populates list")
    @MainActor
    func loadProjects() async {
        let (vm, _, projectRepo, _, _, _, _, _) = makeChatVM()
        let project = Project(name: "Test", categoryId: chatCatId)
        projectRepo.projects = [project]

        await vm.loadProjects()

        #expect(vm.projects.count == 1)
        #expect(vm.projects.first?.name == "Test")
    }

    @Test("Send adds user and assistant messages")
    @MainActor
    func sendMessage() async {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()
        vm.inputText = "Hello AI"

        await vm.send()

        #expect(vm.messages.count == 2)
        #expect(vm.messages[0].role == .user)
        #expect(vm.messages[0].content == "Hello AI")
        #expect(vm.messages[1].role == .assistant)
        #expect(vm.inputText == "")
        #expect(vm.isLoading == false)
    }

    @Test("Send clears input text")
    @MainActor
    func sendClearsInput() async {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()
        vm.inputText = "Test"
        await vm.send()
        #expect(vm.inputText == "")
    }

    @Test("Send with empty input does nothing")
    @MainActor
    func sendEmptyDoesNothing() async {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()
        vm.inputText = "  "
        await vm.send()
        #expect(vm.messages.isEmpty)
    }

    @Test("Send with LLM error sets error")
    @MainActor
    func sendError() async {
        let client = MockLLMClient()
        client.shouldThrow = true
        let (vm, _, _, _, _, _, _, _) = makeChatVM(llmClient: client)
        vm.inputText = "Hello"

        await vm.send()

        #expect(vm.error != nil)
        #expect(vm.messages.count == 1) // Only user message added
    }

    @Test("Send voice transcript works")
    @MainActor
    func sendVoiceTranscript() async {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()

        await vm.sendVoiceTranscript("Voice message")

        #expect(vm.messages.count == 2)
        #expect(vm.messages[0].content == "Voice message")
    }

    @Test("canSend requires non-empty input")
    @MainActor
    func canSend() {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()
        #expect(vm.canSend == false)
        vm.inputText = "Hello"
        #expect(vm.canSend == true)
    }

    @Test("Clear chat removes all messages")
    @MainActor
    func clearChat() async {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()
        vm.inputText = "Hi"
        await vm.send()

        vm.clearChat()

        #expect(vm.messages.isEmpty)
        #expect(vm.error == nil)
        #expect(vm.pendingConfirmation == nil)
    }

    @Test("Selected project resolves from list")
    @MainActor
    func selectedProject() async {
        let (vm, _, projectRepo, _, _, _, _, _) = makeChatVM()
        let project = Project(name: "My Project", categoryId: chatCatId)
        projectRepo.projects = [project]
        await vm.loadProjects()

        vm.selectedProjectId = project.id
        #expect(vm.selectedProject?.name == "My Project")
    }

    @Test("Selected project nil when no ID")
    @MainActor
    func selectedProjectNil() {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()
        #expect(vm.selectedProject == nil)
    }

    @Test("Response with actions creates confirmation")
    @MainActor
    func responseWithActions() async {
        let client = MockLLMClient()
        let taskId = UUID()
        client.responseText = "Done! [ACTION: COMPLETE_TASK] taskId: \(taskId) [/ACTION]"
        let (vm, _, _, _, _, _, _, _) = makeChatVM(llmClient: client)
        vm.inputText = "Mark task done"

        await vm.send()

        #expect(vm.pendingConfirmation != nil)
        #expect(vm.pendingConfirmation?.changes.count == 1)
    }

    @Test("Cancel confirmation clears it")
    @MainActor
    func cancelConfirmation() async {
        let client = MockLLMClient()
        let taskId = UUID()
        client.responseText = "[ACTION: COMPLETE_TASK] taskId: \(taskId) [/ACTION]"
        let (vm, _, _, _, _, _, _, _) = makeChatVM(llmClient: client)
        vm.inputText = "Do something"
        await vm.send()

        vm.cancelConfirmation()

        #expect(vm.pendingConfirmation == nil)
    }

    @Test("Toggle change acceptance")
    @MainActor
    func toggleChange() async {
        let client = MockLLMClient()
        let taskId = UUID()
        client.responseText = "[ACTION: COMPLETE_TASK] taskId: \(taskId) [/ACTION]"
        let (vm, _, _, _, _, _, _, _) = makeChatVM(llmClient: client)
        vm.inputText = "Test"
        await vm.send()

        #expect(vm.pendingConfirmation?.changes[0].accepted == true)
        vm.toggleChange(at: 0)
        #expect(vm.pendingConfirmation?.changes[0].accepted == false)
    }

    @Test("ChatMessage creation")
    func chatMessageCreation() {
        let msg = ChatMessage(role: LLMMessage.Role.user, content: "Test")
        #expect(msg.role == LLMMessage.Role.user)
        #expect(msg.content == "Test")
        #expect(msg.actions.isEmpty)
    }

    @Test("Conversation type can be changed")
    @MainActor
    func conversationTypeChange() {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()
        vm.conversationType = .checkInQuickLog
        #expect(vm.conversationType == .checkInQuickLog)
    }

    // MARK: - Persistence Tests

    @Test("Persist message creates conversation on first send")
    @MainActor
    func persistMessageCreatesConversation() async {
        let convRepo = MockConversationRepository()
        let (vm, _, _, _, _, _, _, _) = makeChatVM(conversationRepo: convRepo)
        vm.inputText = "Hello"

        await vm.send()

        #expect(convRepo.conversations.count == 1)
        #expect(vm.activeConversation != nil)
    }

    @Test("Persist message appends to existing conversation")
    @MainActor
    func persistMessageAppendsToExisting() async {
        let convRepo = MockConversationRepository()
        let (vm, _, _, _, _, _, _, _) = makeChatVM(conversationRepo: convRepo)
        vm.inputText = "First message"
        await vm.send()

        vm.inputText = "Second message"
        await vm.send()

        // First send creates conversation, subsequent sends append
        #expect(convRepo.conversations.count == 1)
        #expect(convRepo.appendedMessages.count >= 1)
    }

    @Test("Resume conversation restores messages")
    @MainActor
    func resumeConversation() {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()
        let msg = PMDomain.ChatMessage(role: .user, content: "Previous message")
        let conversation = Conversation(
            conversationType: .checkInFull,
            messages: [msg]
        )

        vm.resumeConversation(conversation)

        #expect(vm.messages.count == 1)
        #expect(vm.messages[0].content == "Previous message")
        #expect(vm.conversationType == .checkInFull)
        #expect(vm.activeConversation?.id == conversation.id)
    }

    @Test("Load conversations by project")
    @MainActor
    func loadConversationsByProject() async {
        let convRepo = MockConversationRepository()
        let projectId = UUID()
        let conv = Conversation(projectId: projectId, conversationType: .general)
        convRepo.conversations = [conv]

        let (vm, _, projectRepo, _, _, _, _, _) = makeChatVM(conversationRepo: convRepo)
        let project = Project(name: "Test", categoryId: chatCatId)
        projectRepo.projects = [project]
        await vm.loadProjects()
        vm.selectedProjectId = projectId

        await vm.loadConversations()

        #expect(vm.savedConversations.count == 1)
    }

    // MARK: - Trust Level Tests

    @Test("Trust level autoMinor auto-applies minor actions")
    @MainActor
    func trustLevelAutoMinor() async {
        let client = MockLLMClient()
        let taskId = UUID()
        // COMPLETE_TASK is a minor action
        client.responseText = "Done! [ACTION: COMPLETE_TASK] taskId: \(taskId) [/ACTION]"
        let (vm, _, _, _, _, _, _, _) = makeChatVM(llmClient: client)
        vm.aiTrustLevel = "autoMinor"
        vm.inputText = "Mark task done"

        await vm.send()

        // Minor action should be auto-applied, no pending confirmation
        #expect(vm.pendingConfirmation == nil)
    }

    @Test("Trust level autoMinor confirms major actions")
    @MainActor
    func trustLevelAutoMinorConfirmsMajor() async {
        let client = MockLLMClient()
        let phaseId = UUID()
        // CREATE_MILESTONE is a major action
        client.responseText = "Created! [ACTION: CREATE_MILESTONE] phaseId: \(phaseId)\nname: New Milestone [/ACTION]"
        let (vm, _, _, _, _, _, _, _) = makeChatVM(llmClient: client)
        vm.aiTrustLevel = "autoMinor"
        vm.inputText = "Create a milestone"

        await vm.send()

        // Major action should require confirmation
        #expect(vm.pendingConfirmation != nil)
        #expect(vm.pendingConfirmation?.changes.count == 1)
    }

    @Test("Trust level confirmAll shows all actions for confirmation")
    @MainActor
    func trustLevelConfirmAll() async {
        let client = MockLLMClient()
        let taskId = UUID()
        client.responseText = "Done! [ACTION: COMPLETE_TASK] taskId: \(taskId) [/ACTION]"
        let (vm, _, _, _, _, _, _, _) = makeChatVM(llmClient: client)
        vm.aiTrustLevel = "confirmAll"
        vm.inputText = "Mark task done"

        await vm.send()

        #expect(vm.pendingConfirmation != nil)
    }

    // MARK: - Return Briefing Tests

    @Test("Return briefing nil initially")
    @MainActor
    func returnBriefingNilInitially() {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()
        #expect(vm.returnBriefing == nil)
    }

    @Test("Clear chat clears return briefing")
    @MainActor
    func clearChatClearsBriefing() {
        let (vm, _, _, _, _, _, _, _) = makeChatVM()
        vm.clearChat()
        #expect(vm.returnBriefing == nil)
    }

    @Test("AIAction isMajor classification")
    func actionMajorClassification() {
        #expect(AIAction.completeTask(taskId: UUID()).isMajor == false)
        #expect(AIAction.createSubtask(taskId: UUID(), name: "test").isMajor == false)
        #expect(AIAction.incrementDeferred(taskId: UUID()).isMajor == false)
        #expect(AIAction.suggestScopeReduction(projectId: UUID(), suggestion: "test").isMajor == false)
        #expect(AIAction.createMilestone(phaseId: UUID(), name: "test").isMajor == true)
        #expect(AIAction.createTask(milestoneId: UUID(), name: "test", priority: .normal, effortType: nil).isMajor == true)
        #expect(AIAction.updateNotes(projectId: UUID(), notes: "test").isMajor == true)
        #expect(AIAction.flagBlocked(taskId: UUID(), blockedType: .poorlyDefined, reason: "test").isMajor == true)
    }
}
