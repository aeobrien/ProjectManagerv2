import Testing
import Foundation
@testable import PMServices
import PMDomain

@Suite("AutoSummarisationService")
struct AutoSummarisationServiceTests {

    func makeServices() -> (MockSessionRepository, MockV2LLMClient, SessionLifecycleManager, SummaryGenerationService) {
        let repo = MockSessionRepository()
        let llm = MockV2LLMClient()
        let lifecycle = SessionLifecycleManager(repo: repo)
        let summaryService = SummaryGenerationService(llmClient: llm, repo: repo)
        return (repo, llm, lifecycle, summaryService)
    }

    func validSummaryJSON() -> String {
        """
        {
          "contentEstablished": {
            "decisions": ["Decision A"],
            "factsLearned": ["Fact B"],
            "progressMade": ["Progress C"]
          },
          "contentObserved": {
            "patterns": ["Pattern D"],
            "concerns": [],
            "strengths": ["Strength E"]
          },
          "whatComesNext": {
            "nextActions": ["Action F"],
            "openQuestions": [],
            "suggestedMode": null
          }
        }
        """
    }

    // MARK: - processPendingSessions

    @Test("processPendingSessions summarises eligible paused sessions")
    func summarisesEligible() async throws {
        let (repo, llm, lifecycle, summaryService) = makeServices()
        llm.defaultResponse = LLMResponse(content: validSummaryJSON())

        let projectId = UUID()
        let session = TestFixtures.session(
            projectId: projectId,
            mode: .exploration,
            status: .paused,
            lastActiveAt: Date().addingTimeInterval(-48 * 3600) // 48 hours ago
        )
        repo.sessions[session.id] = session

        // Add a message so summary generation doesn't fail with noMessages
        let msg = TestFixtures.sessionMessage(sessionId: session.id, content: "Hello")
        repo.messages[session.id] = [msg]

        let service = AutoSummarisationService(
            repo: repo, summaryService: summaryService, lifecycleManager: lifecycle,
            timeoutInterval: 24 * 3600, maxRetries: 1, checkInterval: 60
        )

        await service.processPendingSessions()

        let updated = repo.sessions[session.id]
        #expect(updated?.status == .autoSummarised)
        #expect(updated?.completedAt != nil)
        #expect(repo.summaries[session.id] != nil)
    }

    @Test("processPendingSessions retries pendingAutoSummary sessions")
    func retriesPending() async throws {
        let (repo, llm, lifecycle, summaryService) = makeServices()
        llm.defaultResponse = LLMResponse(content: validSummaryJSON())

        let session = TestFixtures.session(
            status: .pendingAutoSummary,
            lastActiveAt: Date().addingTimeInterval(-48 * 3600)
        )
        repo.sessions[session.id] = session
        repo.messages[session.id] = [TestFixtures.sessionMessage(sessionId: session.id)]

        let service = AutoSummarisationService(
            repo: repo, summaryService: summaryService, lifecycleManager: lifecycle,
            timeoutInterval: 24 * 3600, maxRetries: 1, checkInterval: 60
        )

        await service.processPendingSessions()

        let updated = repo.sessions[session.id]
        #expect(updated?.status == .autoSummarised)
    }

    @Test("processPendingSessions is no-op when nothing eligible")
    func noOpWhenNothingEligible() async throws {
        let (repo, llm, lifecycle, summaryService) = makeServices()
        llm.defaultResponse = LLMResponse(content: validSummaryJSON())

        // Only an active session — not eligible
        let session = TestFixtures.session(status: .active)
        repo.sessions[session.id] = session

        let service = AutoSummarisationService(
            repo: repo, summaryService: summaryService, lifecycleManager: lifecycle,
            timeoutInterval: 24 * 3600, maxRetries: 1, checkInterval: 60
        )

        await service.processPendingSessions()

        #expect(repo.saveSummaryCalls.isEmpty)
    }

    // MARK: - summariseWithRetry

    @Test("Marks session as pendingAutoSummary after all retries fail")
    func marksPendingAfterFailure() async throws {
        let (repo, llm, lifecycle, summaryService) = makeServices()

        // Make LLM always fail
        struct MockError: Error {}
        llm.oneShotError = MockError()
        llm.queuedResponses = [] // empty queue forces default which will also error after first
        // Actually we need all calls to fail. Let's use a different approach:
        // Set up a client that always fails
        let alwaysFailLLM = AlwaysFailLLMClient()
        let failSummaryService = SummaryGenerationService(llmClient: alwaysFailLLM, repo: repo)

        let session = TestFixtures.session(
            status: .paused,
            lastActiveAt: Date().addingTimeInterval(-48 * 3600)
        )
        repo.sessions[session.id] = session
        repo.messages[session.id] = [TestFixtures.sessionMessage(sessionId: session.id)]

        let service = AutoSummarisationService(
            repo: repo, summaryService: failSummaryService, lifecycleManager: lifecycle,
            timeoutInterval: 24 * 3600, maxRetries: 2, checkInterval: 60
        )

        await service.processPendingSessions()

        let updated = repo.sessions[session.id]
        #expect(updated?.status == .pendingAutoSummary)
    }
}

// MARK: - Helper

private final class AlwaysFailLLMClient: LLMClientProtocol, @unchecked Sendable {
    struct AlwaysFail: Error {}
    func send(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse {
        throw AlwaysFail()
    }
}
