import Foundation
@testable import PMServices
import PMDomain

// MARK: - MockV2LLMClient

/// Mock LLM client for V2 AI system tests.
/// Supports queued responses, one-shot errors, and call tracking.
final class MockV2LLMClient: LLMClientProtocol, @unchecked Sendable {
    var queuedResponses: [LLMResponse] = []
    var defaultResponse = LLMResponse(content: "Default mock response")
    var oneShotError: Error?
    private(set) var sentMessages: [[LLMMessage]] = []
    private(set) var sentConfigs: [LLMRequestConfig] = []

    var lastSystemPrompt: String? {
        sentMessages.last?.first(where: { $0.role == .system })?.content
    }

    var lastUserMessage: String? {
        sentMessages.last?.last(where: { $0.role == .user })?.content
    }

    var callCount: Int { sentMessages.count }

    func send(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse {
        sentMessages.append(messages)
        sentConfigs.append(config)

        if let error = oneShotError {
            oneShotError = nil
            throw error
        }

        if !queuedResponses.isEmpty {
            return queuedResponses.removeFirst()
        }

        return defaultResponse
    }

    func reset() {
        queuedResponses.removeAll()
        oneShotError = nil
        sentMessages.removeAll()
        sentConfigs.removeAll()
    }
}

// MARK: - MockV2Responses

/// Static builders for mock LLM responses containing V2 signals.
enum MockV2Responses {
    /// A plain text response with no signals.
    static func plain(_ text: String = "Hello! How can I help with your project?") -> LLMResponse {
        LLMResponse(content: text)
    }

    /// A response containing a MODE_COMPLETE signal.
    static func modeComplete(summary: String = "Session complete.") -> LLMResponse {
        LLMResponse(content: """
            \(summary)

            [SIGNAL:MODE_COMPLETE]
            """)
    }

    /// A response containing a DOCUMENT_DRAFT signal.
    static func documentDraft(title: String = "Project Brief", body: String = "Draft content here.") -> LLMResponse {
        LLMResponse(content: """
            Here's a draft for you:

            [SIGNAL:DOCUMENT_DRAFT]
            title: \(title)
            ---
            \(body)
            [/SIGNAL:DOCUMENT_DRAFT]
            """)
    }

    /// A response containing a STRUCTURE_PROPOSAL signal.
    static func structureProposal(phases: [String] = ["Phase 1: Setup", "Phase 2: Build"]) -> LLMResponse {
        let phaseList = phases.map { "- \($0)" }.joined(separator: "\n")
        return LLMResponse(content: """
            I'd suggest this structure:

            [SIGNAL:STRUCTURE_PROPOSAL]
            \(phaseList)
            [/SIGNAL:STRUCTURE_PROPOSAL]
            """)
    }

    /// A response containing action blocks.
    static func withActions(_ text: String = "I'll create that task for you.", actions: String = "[ACTION:CREATE_TASK] name: \"New Task\"") -> LLMResponse {
        LLMResponse(content: "\(text)\n\n\(actions)")
    }

    /// A response combining multiple signals.
    static func combined(text: String, signals: [String]) -> LLMResponse {
        let signalBlock = signals.joined(separator: "\n\n")
        return LLMResponse(content: "\(text)\n\n\(signalBlock)")
    }
}

// MARK: - MockSessionRepository

/// In-memory mock of SessionRepositoryProtocol for unit tests.
final class MockSessionRepository: SessionRepositoryProtocol, @unchecked Sendable {
    var sessions: [UUID: Session] = [:]
    var messages: [UUID: [SessionMessage]] = [:] // sessionId → messages
    var summaries: [UUID: SessionSummary] = [:] // sessionId → summary

    private(set) var saveCalls: [Session] = []
    private(set) var deleteCalls: [UUID] = []
    private(set) var appendMessageCalls: [SessionMessage] = []
    private(set) var saveSummaryCalls: [SessionSummary] = []

    func fetch(id: UUID) async throws -> Session? {
        sessions[id]
    }

    func fetchAll(forProject projectId: UUID) async throws -> [Session] {
        sessions.values
            .filter { $0.projectId == projectId }
            .sorted { $0.lastActiveAt > $1.lastActiveAt }
    }

    func fetchActive(forProject projectId: UUID) async throws -> [Session] {
        sessions.values
            .filter { $0.projectId == projectId && ($0.status == .active || $0.status == .paused) }
            .sorted { $0.lastActiveAt > $1.lastActiveAt }
    }

    func save(_ session: Session) async throws {
        sessions[session.id] = session
        saveCalls.append(session)
    }

    func delete(id: UUID) async throws {
        sessions.removeValue(forKey: id)
        messages.removeValue(forKey: id)
        summaries.removeValue(forKey: id)
        deleteCalls.append(id)
    }

    func fetchMessages(forSession sessionId: UUID) async throws -> [SessionMessage] {
        (messages[sessionId] ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    func appendMessage(_ message: SessionMessage) async throws {
        messages[message.sessionId, default: []].append(message)
        appendMessageCalls.append(message)
        // Update lastActiveAt
        if var session = sessions[message.sessionId] {
            session.lastActiveAt = message.timestamp
            sessions[session.id] = session
        }
    }

    func fetchSummary(forSession sessionId: UUID) async throws -> SessionSummary? {
        summaries[sessionId]
    }

    func saveSummary(_ summary: SessionSummary) async throws {
        summaries[summary.sessionId] = summary
        saveSummaryCalls.append(summary)
    }

    func fetchSessionsPendingSummarisation(olderThan cutoff: Date) async throws -> [Session] {
        sessions.values
            .filter { $0.status == .paused && $0.lastActiveAt < cutoff }
            .sorted { $0.lastActiveAt < $1.lastActiveAt }
    }

    func fetchSessionsWithStatus(_ status: SessionStatus) async throws -> [Session] {
        sessions.values
            .filter { $0.status == status }
            .sorted { $0.lastActiveAt > $1.lastActiveAt }
    }

    func reset() {
        sessions.removeAll()
        messages.removeAll()
        summaries.removeAll()
        saveCalls.removeAll()
        deleteCalls.removeAll()
        appendMessageCalls.removeAll()
        saveSummaryCalls.removeAll()
    }
}

// MARK: - TestFixtures

/// Factory methods for creating domain objects in tests.
enum TestFixtures {
    static func project(
        id: UUID = UUID(),
        name: String = "Test Project",
        categoryId: UUID = UUID(),
        lifecycleState: LifecycleState = .idea,
        focusSlotIndex: Int? = nil,
        definitionOfDone: String? = nil,
        notes: String? = nil
    ) -> Project {
        Project(
            id: id,
            name: name,
            categoryId: categoryId,
            lifecycleState: lifecycleState,
            focusSlotIndex: focusSlotIndex,
            definitionOfDone: definitionOfDone,
            notes: notes
        )
    }

    static func session(
        id: UUID = UUID(),
        projectId: UUID = UUID(),
        mode: SessionMode = .exploration,
        subMode: SessionSubMode? = nil,
        status: SessionStatus = .active,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        completedAt: Date? = nil
    ) -> Session {
        Session(
            id: id,
            projectId: projectId,
            mode: mode,
            subMode: subMode,
            status: status,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            completedAt: completedAt
        )
    }

    static func sessionMessage(
        id: UUID = UUID(),
        sessionId: UUID,
        role: ChatRole = .user,
        content: String = "Test message",
        timestamp: Date = Date()
    ) -> SessionMessage {
        SessionMessage(
            id: id,
            sessionId: sessionId,
            role: role,
            content: content,
            timestamp: timestamp
        )
    }

    static func sessionSummary(
        id: UUID = UUID(),
        sessionId: UUID,
        mode: SessionMode = .exploration,
        subMode: SessionSubMode? = nil,
        completionStatus: SessionCompletionStatus = .completed
    ) -> SessionSummary {
        SessionSummary(
            id: id,
            sessionId: sessionId,
            mode: mode,
            subMode: subMode,
            completionStatus: completionStatus,
            startedAt: Date(),
            endedAt: Date(),
            duration: 100,
            messageCount: 5
        )
    }
}
