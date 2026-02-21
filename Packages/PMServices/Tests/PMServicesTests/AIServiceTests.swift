import Testing
import Foundation
@testable import PMServices
@testable import PMDomain

// MARK: - Mock LLM Client

final class MockLLMClient: LLMClientProtocol, @unchecked Sendable {
    var responses: [String] = []
    var sentMessages: [[LLMMessage]] = []
    var shouldThrow = false
    private var callIndex = 0

    func send(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse {
        sentMessages.append(messages)
        if shouldThrow { throw LLMError.networkError("Mock error") }
        let response = callIndex < responses.count ? responses[callIndex] : "Mock response"
        callIndex += 1
        return LLMResponse(content: response, inputTokens: 100, outputTokens: 50)
    }
}

// MARK: - Mock API Key Provider

struct MockKeyProvider: APIKeyProvider, Sendable {
    let anthropicKey: String?
    let openaiKey: String?

    init(anthropicKey: String? = "test-key", openaiKey: String? = "test-key") {
        self.anthropicKey = anthropicKey
        self.openaiKey = openaiKey
    }

    func key(for provider: LLMProvider) -> String? {
        switch provider {
        case .anthropic: anthropicKey
        case .openai: openaiKey
        }
    }
}

// MARK: - LLM Message Tests

@Suite("LLMMessage")
struct LLMMessageTests {
    @Test("Message creation")
    func messageCreation() {
        let msg = LLMMessage(role: .user, content: "Hello")
        #expect(msg.role == .user)
        #expect(msg.content == "Hello")
    }

    @Test("Message equality")
    func messageEquality() {
        let msg1 = LLMMessage(role: .user, content: "Hello")
        let msg2 = LLMMessage(role: .user, content: "Hello")
        let msg3 = LLMMessage(role: .assistant, content: "Hello")
        #expect(msg1 == msg2)
        #expect(msg1 != msg3)
    }

    @Test("All roles")
    func allRoles() {
        #expect(LLMMessage.Role.system.rawValue == "system")
        #expect(LLMMessage.Role.user.rawValue == "user")
        #expect(LLMMessage.Role.assistant.rawValue == "assistant")
    }
}

// MARK: - LLM Config Tests

@Suite("LLMRequestConfig")
struct LLMRequestConfigTests {
    @Test("Default config")
    func defaultConfig() {
        let config = LLMRequestConfig()
        #expect(config.provider == .anthropic)
        #expect(config.maxTokens == 4096)
        #expect(config.temperature == 0.7)
    }

    @Test("Custom config")
    func customConfig() {
        let config = LLMRequestConfig(model: "gpt-4", maxTokens: 2048, temperature: 0.5, provider: .openai)
        #expect(config.model == "gpt-4")
        #expect(config.provider == .openai)
    }
}

// MARK: - LLM Error Tests

@Suite("LLMError")
struct LLMErrorTests {
    @Test("Error equality")
    func errorEquality() {
        #expect(LLMError.noAPIKey == LLMError.noAPIKey)
        #expect(LLMError.rateLimited == LLMError.rateLimited)
        #expect(LLMError.httpError(400, "Bad") == LLMError.httpError(400, "Bad"))
        #expect(LLMError.httpError(400, "Bad") != LLMError.httpError(500, "Bad"))
    }
}

// MARK: - API Key Provider Tests

@Suite("APIKeyProvider")
struct APIKeyProviderTests {
    @Test("Mock key provider returns keys")
    func mockKeys() {
        let provider = MockKeyProvider(anthropicKey: "abc", openaiKey: "def")
        #expect(provider.key(for: .anthropic) == "abc")
        #expect(provider.key(for: .openai) == "def")
    }

    @Test("Mock key provider returns nil")
    func mockNilKeys() {
        let provider = MockKeyProvider(anthropicKey: nil, openaiKey: nil)
        #expect(provider.key(for: .anthropic) == nil)
        #expect(provider.key(for: .openai) == nil)
    }
}

// MARK: - Prompt Template Tests

@Suite("PromptTemplates")
struct PromptTemplateTests {
    @Test("Behavioural contract exists")
    func behaviouralContract() {
        #expect(PromptTemplates.behaviouralContract.contains("BEHAVIOURAL CONTRACT"))
        #expect(PromptTemplates.behaviouralContract.contains("ADHD"))
        #expect(PromptTemplates.behaviouralContract.contains("Never shame"))
    }

    @Test("Action block docs lists all actions")
    func actionBlockDocs() {
        let docs = PromptTemplates.actionBlockDocs
        #expect(docs.contains("COMPLETE_TASK"))
        #expect(docs.contains("UPDATE_NOTES"))
        #expect(docs.contains("FLAG_BLOCKED"))
        #expect(docs.contains("SET_WAITING"))
        #expect(docs.contains("CREATE_SUBTASK"))
        #expect(docs.contains("INCREMENT_DEFERRED"))
        #expect(docs.contains("SUGGEST_SCOPE_REDUCTION"))
        #expect(docs.contains("CREATE_MILESTONE"))
        #expect(docs.contains("CREATE_TASK"))
        #expect(docs.contains("CREATE_DOCUMENT"))
    }

    @Test("Quick log prompt includes project name")
    func quickLogPrompt() {
        let prompt = PromptTemplates.checkInQuickLog(projectName: "My App")
        #expect(prompt.contains("My App"))
        #expect(prompt.contains("Quick Log"))
    }

    @Test("Full check-in prompt includes project name")
    func fullCheckInPrompt() {
        let prompt = PromptTemplates.checkInFull(projectName: "My App")
        #expect(prompt.contains("My App"))
        #expect(prompt.contains("Full check-in"))
    }

    @Test("System prompt dispatch for all types")
    func systemPromptDispatch() {
        for type in [ConversationType.checkInQuickLog, .checkInFull, .onboarding, .review, .retrospective, .reEntry, .general] {
            let prompt = PromptTemplates.systemPrompt(for: type, projectName: "Test")
            #expect(!prompt.isEmpty)
            #expect(prompt.contains("BEHAVIOURAL CONTRACT"))
        }
    }

    @Test("Onboarding prompt has project questions")
    func onboardingPrompt() {
        let prompt = PromptTemplates.onboarding()
        #expect(prompt.contains("core goal"))
        #expect(prompt.contains("done"))
    }

    @Test("Retrospective prompt normalises abandonment")
    func retrospectivePrompt() {
        let prompt = PromptTemplates.retrospective(projectName: "Dead Project")
        #expect(prompt.contains("Dead Project"))
        #expect(prompt.contains("not failure"))
    }
}

// MARK: - Context Assembler Tests

@Suite("ContextAssembler")
struct ContextAssemblerTests {
    @Test("Token estimation")
    func tokenEstimation() {
        let tokens = ContextAssembler.estimateTokens("Hello world")
        #expect(tokens > 0)
        #expect(tokens == Int(ceil(11.0 * 0.3)))
    }

    @Test("Assemble without project context")
    func assembleNoContext() async throws {
        let assembler = ContextAssembler()
        let payload = try await assembler.assemble(
            conversationType: .general,
            projectContext: nil,
            conversationHistory: [LLMMessage(role: .user, content: "Hi")]
        )
        #expect(!payload.messages.isEmpty)
        #expect(payload.estimatedTokens > 0)
    }

    @Test("Assemble with project context")
    func assembleWithContext() async throws {
        let assembler = ContextAssembler()
        let project = Project(name: "Test Project", categoryId: UUID())
        let ctx = ProjectContext(project: project)
        let payload = try await assembler.assemble(
            conversationType: .checkInQuickLog,
            projectContext: ctx,
            conversationHistory: []
        )
        #expect(payload.systemPrompt.contains("Test Project"))
    }

    @Test("History truncation respects token budget")
    func historyTruncation() async throws {
        // Budget large enough for system prompt but not all history
        let assembler = ContextAssembler(maxTokenBudget: 3000)
        let longMessage = String(repeating: "word ", count: 2000)
        let history = [
            LLMMessage(role: .user, content: longMessage),
            LLMMessage(role: .assistant, content: longMessage),
            LLMMessage(role: .user, content: "Recent message")
        ]
        let payload = try await assembler.assemble(
            conversationType: .general,
            projectContext: nil,
            conversationHistory: history
        )
        // Should have truncated older messages — not all 3 history messages fit
        let historyInPayload = payload.messages.filter { $0.role != .system }
        #expect(historyInPayload.count < history.count)
    }

    @Test("Project context includes phases")
    func contextIncludesPhases() async throws {
        let assembler = ContextAssembler()
        let project = Project(name: "Test", categoryId: UUID())
        let phase = Phase(projectId: project.id, name: "Design")
        let ctx = ProjectContext(project: project, phases: [phase])
        let payload = try await assembler.assemble(
            conversationType: .general,
            projectContext: ctx,
            conversationHistory: []
        )
        #expect(payload.systemPrompt.contains("Design"))
    }

    @Test("Frequently deferred tasks included in context")
    func deferredInContext() async throws {
        let assembler = ContextAssembler()
        let project = Project(name: "Test", categoryId: UUID())
        var task = PMTask(milestoneId: UUID(), name: "Avoided Task")
        task.timesDeferred = 5
        let ctx = ProjectContext(project: project, frequentlyDeferredTasks: [task])
        let payload = try await assembler.assemble(
            conversationType: .general,
            projectContext: ctx,
            conversationHistory: []
        )
        #expect(payload.systemPrompt.contains("Avoided Task"))
        #expect(payload.systemPrompt.contains("deferred 5x"))
    }
}

// MARK: - Action Parser Tests

@Suite("ActionParser")
struct ActionParserTests {
    let parser = ActionParser()

    @Test("Parse COMPLETE_TASK")
    func parseCompleteTask() {
        let id = UUID()
        let response = "Great work! [ACTION: COMPLETE_TASK] taskId: \(id) [/ACTION] Keep it up!"
        let result = parser.parse(response)
        #expect(result.actions.count == 1)
        #expect(result.actions.first == .completeTask(taskId: id))
        #expect(result.naturalLanguage.contains("Great work!"))
        #expect(!result.naturalLanguage.contains("[ACTION"))
    }

    @Test("Parse UPDATE_NOTES")
    func parseUpdateNotes() {
        let id = UUID()
        let response = "[ACTION: UPDATE_NOTES] projectId: \(id) notes: Updated progress notes [/ACTION]"
        let result = parser.parse(response)
        #expect(result.actions.count == 1)
        if case .updateNotes(let projectId, let notes) = result.actions.first {
            #expect(projectId == id)
            #expect(notes.contains("Updated progress"))
        } else {
            #expect(Bool(false), "Expected updateNotes action")
        }
    }

    @Test("Parse FLAG_BLOCKED")
    func parseFlagBlocked() {
        let id = UUID()
        let response = "[ACTION: FLAG_BLOCKED] taskId: \(id) blockedType: missingInfo reason: Need API docs [/ACTION]"
        let result = parser.parse(response)
        #expect(result.actions.count == 1)
        if case .flagBlocked(let taskId, let type, _) = result.actions.first {
            #expect(taskId == id)
            #expect(type == .missingInfo)
        } else {
            #expect(Bool(false), "Expected flagBlocked action")
        }
    }

    @Test("Parse CREATE_SUBTASK")
    func parseCreateSubtask() {
        let id = UUID()
        let response = "[ACTION: CREATE_SUBTASK] taskId: \(id) name: Write unit tests [/ACTION]"
        let result = parser.parse(response)
        #expect(result.actions.count == 1)
        if case .createSubtask(let taskId, let name) = result.actions.first {
            #expect(taskId == id)
            #expect(name.contains("Write unit tests"))
        } else {
            #expect(Bool(false), "Expected createSubtask action")
        }
    }

    @Test("Parse INCREMENT_DEFERRED")
    func parseIncrementDeferred() {
        let id = UUID()
        let response = "[ACTION: INCREMENT_DEFERRED] taskId: \(id) [/ACTION]"
        let result = parser.parse(response)
        #expect(result.actions.count == 1)
        #expect(result.actions.first == .incrementDeferred(taskId: id))
    }

    @Test("Parse CREATE_MILESTONE")
    func parseCreateMilestone() {
        let id = UUID()
        let response = "[ACTION: CREATE_MILESTONE] phaseId: \(id) name: Beta Release [/ACTION]"
        let result = parser.parse(response)
        #expect(result.actions.count == 1)
        if case .createMilestone(let phaseId, let name) = result.actions.first {
            #expect(phaseId == id)
            #expect(name.contains("Beta Release"))
        } else {
            #expect(Bool(false), "Expected createMilestone action")
        }
    }

    @Test("Parse CREATE_TASK")
    func parseCreateTask() {
        let id = UUID()
        let response = "[ACTION: CREATE_TASK] milestoneId: \(id) name: Design mockups priority: high effortType: creative [/ACTION]"
        let result = parser.parse(response)
        #expect(result.actions.count == 1)
        if case .createTask(let msId, let name, let priority, let effort) = result.actions.first {
            #expect(msId == id)
            #expect(name.contains("Design mockups"))
            #expect(priority == .high)
            #expect(effort == .creative)
        } else {
            #expect(Bool(false), "Expected createTask action")
        }
    }

    @Test("Parse multiple actions")
    func parseMultipleActions() {
        let id1 = UUID()
        let id2 = UUID()
        let response = """
        Good progress! [ACTION: COMPLETE_TASK] taskId: \(id1) [/ACTION]
        Let's also track this. [ACTION: INCREMENT_DEFERRED] taskId: \(id2) [/ACTION]
        """
        let result = parser.parse(response)
        #expect(result.actions.count == 2)
        #expect(result.naturalLanguage.contains("Good progress!"))
    }

    @Test("No actions in plain text")
    func noActions() {
        let response = "Just a regular response with no action blocks."
        let result = parser.parse(response)
        #expect(result.actions.isEmpty)
        #expect(result.naturalLanguage == response)
    }

    @Test("Invalid action type ignored")
    func invalidActionType() {
        let response = "[ACTION: INVALID_TYPE] foo: bar [/ACTION]"
        let result = parser.parse(response)
        #expect(result.actions.isEmpty)
    }

    @Test("Malformed action missing required fields")
    func malformedAction() {
        let response = "[ACTION: COMPLETE_TASK] name: something [/ACTION]"
        let result = parser.parse(response)
        #expect(result.actions.isEmpty)
    }

    @Test("Parse SUGGEST_SCOPE_REDUCTION")
    func parseScopeReduction() {
        let id = UUID()
        let response = "[ACTION: SUGGEST_SCOPE_REDUCTION] projectId: \(id) suggestion: Drop the mobile version [/ACTION]"
        let result = parser.parse(response)
        #expect(result.actions.count == 1)
        if case .suggestScopeReduction(let projectId, let suggestion) = result.actions.first {
            #expect(projectId == id)
            #expect(suggestion.contains("Drop the mobile"))
        } else {
            #expect(Bool(false), "Expected suggestScopeReduction action")
        }
    }
}

// MARK: - Bundled Confirmation Tests

@Suite("BundledConfirmation")
struct BundledConfirmationTests {
    @Test("Accepted count")
    func acceptedCount() {
        let id1 = UUID()
        let id2 = UUID()
        let changes = [
            ProposedChange(action: .completeTask(taskId: id1), description: "Complete task", accepted: true),
            ProposedChange(action: .incrementDeferred(taskId: id2), description: "Defer", accepted: false)
        ]
        let confirmation = BundledConfirmation(changes: changes)
        #expect(confirmation.acceptedCount == 1)
        #expect(confirmation.acceptedActions.count == 1)
    }

    @Test("All accepted")
    func allAccepted() {
        let id = UUID()
        let changes = [
            ProposedChange(action: .completeTask(taskId: id), description: "Complete", accepted: true),
            ProposedChange(action: .completeTask(taskId: id), description: "Complete", accepted: true)
        ]
        let confirmation = BundledConfirmation(changes: changes)
        #expect(confirmation.acceptedCount == 2)
    }

    @Test("None accepted")
    func noneAccepted() {
        let id = UUID()
        let changes = [
            ProposedChange(action: .completeTask(taskId: id), description: "Complete", accepted: false)
        ]
        let confirmation = BundledConfirmation(changes: changes)
        #expect(confirmation.acceptedCount == 0)
        #expect(confirmation.acceptedActions.isEmpty)
    }
}

// MARK: - Action Executor Tests

@Suite("ActionExecutor")
struct ActionExecutorTests {
    @Test("Generate confirmation describes actions")
    @MainActor
    func generateConfirmation() {
        let taskRepo = MockTaskRepository()
        let milestoneRepo = MockMilestoneRepository()
        let subtaskRepo = MockSubtaskRepository()
        let projectRepo = MockProjectRepository()
        let executor = ActionExecutor(
            taskRepo: taskRepo,
            milestoneRepo: milestoneRepo,
            subtaskRepo: subtaskRepo,
            projectRepo: projectRepo
        )

        let actions: [AIAction] = [
            .completeTask(taskId: UUID()),
            .createSubtask(taskId: UUID(), name: "Write tests")
        ]
        let confirmation = executor.generateConfirmation(from: actions)
        #expect(confirmation.changes.count == 2)
        #expect(confirmation.changes[0].description.contains("completed"))
        #expect(confirmation.changes[1].description.contains("Write tests"))
    }
}

// MARK: - Mock Repositories for Action Executor

private final class MockTaskRepository: TaskRepositoryProtocol, @unchecked Sendable {
    var tasks: [PMTask] = []
    func fetchAll(forMilestone milestoneId: UUID) async throws -> [PMTask] { tasks.filter { $0.milestoneId == milestoneId } }
    func fetch(id: UUID) async throws -> PMTask? { tasks.first { $0.id == id } }
    func fetchByStatus(_ status: ItemStatus) async throws -> [PMTask] { tasks.filter { $0.status == status } }
    func fetchByEffortType(_ effortType: EffortType) async throws -> [PMTask] { tasks.filter { $0.effortType == effortType } }
    func fetchByKanbanColumn(_ column: KanbanColumn, milestoneId: UUID) async throws -> [PMTask] { [] }
    func save(_ task: PMTask) async throws {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) { tasks[idx] = task }
        else { tasks.append(task) }
    }
    func delete(id: UUID) async throws { tasks.removeAll { $0.id == id } }
    func reorder(tasks: [PMTask]) async throws { self.tasks = tasks }
    func search(query: String) async throws -> [PMTask] { tasks.filter { $0.name.contains(query) } }
}

private final class MockMilestoneRepository: MilestoneRepositoryProtocol, @unchecked Sendable {
    var milestones: [Milestone] = []
    func fetchAll(forPhase phaseId: UUID) async throws -> [Milestone] { milestones.filter { $0.phaseId == phaseId } }
    func fetch(id: UUID) async throws -> Milestone? { milestones.first { $0.id == id } }
    func save(_ milestone: Milestone) async throws {
        if let idx = milestones.firstIndex(where: { $0.id == milestone.id }) { milestones[idx] = milestone }
        else { milestones.append(milestone) }
    }
    func delete(id: UUID) async throws { milestones.removeAll { $0.id == id } }
    func reorder(milestones: [Milestone]) async throws { self.milestones = milestones }
}

private final class MockSubtaskRepository: SubtaskRepositoryProtocol, @unchecked Sendable {
    var subtasks: [Subtask] = []
    func fetchAll(forTask taskId: UUID) async throws -> [Subtask] { subtasks.filter { $0.taskId == taskId } }
    func fetch(id: UUID) async throws -> Subtask? { subtasks.first { $0.id == id } }
    func save(_ subtask: Subtask) async throws {
        if let idx = subtasks.firstIndex(where: { $0.id == subtask.id }) { subtasks[idx] = subtask }
        else { subtasks.append(subtask) }
    }
    func delete(id: UUID) async throws { subtasks.removeAll { $0.id == id } }
    func reorder(subtasks: [Subtask]) async throws { self.subtasks = subtasks }
}

private final class MockProjectRepository: ProjectRepositoryProtocol, @unchecked Sendable {
    var projects: [Project] = []
    func fetchAll() async throws -> [Project] { projects }
    func fetch(id: UUID) async throws -> Project? { projects.first { $0.id == id } }
    func fetchByLifecycleState(_ state: LifecycleState) async throws -> [Project] { projects.filter { $0.lifecycleState == state } }
    func fetchByCategory(_ categoryId: UUID) async throws -> [Project] { projects.filter { $0.categoryId == categoryId } }
    func fetchFocused() async throws -> [Project] { projects.filter { $0.lifecycleState == .focused } }
    func save(_ project: Project) async throws {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) { projects[idx] = project }
        else { projects.append(project) }
    }
    func delete(id: UUID) async throws { projects.removeAll { $0.id == id } }
    func search(query: String) async throws -> [Project] { projects.filter { $0.name.contains(query) } }
}
