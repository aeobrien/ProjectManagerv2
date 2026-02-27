import Testing
import Foundation
@testable import PMServices
import PMDomain

@Suite("SessionLifecycleManager")
struct SessionLifecycleManagerTests {
    let mockRepo = MockSessionRepository()

    var manager: SessionLifecycleManager {
        SessionLifecycleManager(repo: mockRepo)
    }

    // MARK: - startSession

    @Test("startSession creates an active session")
    func startCreatesActive() async throws {
        let mgr = manager
        let projectId = UUID()

        let session = try await mgr.startSession(projectId: projectId, mode: .exploration)

        #expect(session.status == .active)
        #expect(session.projectId == projectId)
        #expect(session.mode == .exploration)
        #expect(session.subMode == nil)
        #expect(mockRepo.sessions[session.id] != nil)
    }

    @Test("startSession with subMode sets it correctly")
    func startWithSubMode() async throws {
        let mgr = manager

        let session = try await mgr.startSession(
            projectId: UUID(), mode: .executionSupport, subMode: .checkIn
        )

        #expect(session.subMode == .checkIn)
    }

    @Test("startSession pauses existing active session")
    func startPausesExisting() async throws {
        let mgr = manager
        let projectId = UUID()

        let first = try await mgr.startSession(projectId: projectId, mode: .exploration)
        let second = try await mgr.startSession(projectId: projectId, mode: .definition)

        let firstUpdated = mockRepo.sessions[first.id]
        #expect(firstUpdated?.status == .paused)
        #expect(second.status == .active)
    }

    // MARK: - resumeSession

    @Test("resumeSession from paused succeeds")
    func resumeFromPaused() async throws {
        let mgr = manager
        let session = TestFixtures.session(status: .paused)
        await { mockRepo.sessions[session.id] = session }()

        let resumed = try await mgr.resumeSession(session.id)

        #expect(resumed.status == .active)
    }

    @Test("resumeSession from completed throws invalidTransition")
    func resumeFromCompletedThrows() async throws {
        let mgr = manager
        let session = TestFixtures.session(status: .completed)
        await { mockRepo.sessions[session.id] = session }()

        await #expect(throws: SessionError.self) {
            try await mgr.resumeSession(session.id)
        }
    }

    @Test("resumeSession for nonexistent session throws sessionNotFound")
    func resumeNonexistent() async throws {
        let mgr = manager

        await #expect(throws: SessionError.self) {
            try await mgr.resumeSession(UUID())
        }
    }

    // MARK: - transitionSession

    @Test("Valid transition active → paused succeeds")
    func validTransition() async throws {
        let mgr = manager
        let session = TestFixtures.session(status: .active)
        await { mockRepo.sessions[session.id] = session }()

        let updated = try await mgr.transitionSession(session.id, to: .paused)

        #expect(updated.status == .paused)
    }

    @Test("Invalid transition completed → active throws")
    func invalidTransition() async throws {
        let mgr = manager
        let session = TestFixtures.session(status: .completed)
        await { mockRepo.sessions[session.id] = session }()

        await #expect(throws: SessionError.self) {
            try await mgr.transitionSession(session.id, to: .active)
        }
    }

    @Test("Transition to terminal state sets completedAt")
    func terminalSetsCompletedAt() async throws {
        let mgr = manager
        let session = TestFixtures.session(status: .active)
        await { mockRepo.sessions[session.id] = session }()

        let updated = try await mgr.transitionSession(session.id, to: .completed)

        #expect(updated.completedAt != nil)
    }

    @Test("Transition to non-terminal state does not set completedAt")
    func nonTerminalNoCompletedAt() async throws {
        let mgr = manager
        let session = TestFixtures.session(status: .active)
        await { mockRepo.sessions[session.id] = session }()

        let updated = try await mgr.transitionSession(session.id, to: .paused)

        #expect(updated.completedAt == nil)
    }

    // MARK: - addMessage

    @Test("addMessage appends and returns message")
    func addMessageAppends() async throws {
        let mgr = manager
        let session = TestFixtures.session(status: .active)
        await { mockRepo.sessions[session.id] = session }()

        let msg = try await mgr.addMessage(to: session.id, role: .user, content: "Hello")

        #expect(msg.role == .user)
        #expect(msg.content == "Hello")
        #expect(msg.sessionId == session.id)
        #expect(mockRepo.appendMessageCalls.count == 1)
    }

    @Test("addMessage with voice transcript stores it")
    func addMessageWithVoice() async throws {
        let mgr = manager
        let session = TestFixtures.session(status: .active)
        await { mockRepo.sessions[session.id] = session }()

        let msg = try await mgr.addMessage(
            to: session.id, role: .user, content: "Hello",
            rawVoiceTranscript: "Raw audio text"
        )

        #expect(msg.rawVoiceTranscript == "Raw audio text")
    }

    @Test("addMessage to nonexistent session throws")
    func addMessageNonexistent() async throws {
        let mgr = manager

        await #expect(throws: SessionError.self) {
            try await mgr.addMessage(to: UUID(), role: .user, content: "Hello")
        }
    }
}
