import Foundation
import PMDomain
import PMUtilities

/// Manages session lifecycle: creation, resumption, transitions, and message appending.
public final class SessionLifecycleManager: Sendable {
    private let repo: SessionRepositoryProtocol

    public init(repo: SessionRepositoryProtocol) {
        self.repo = repo
    }

    /// Starts a new session for a project. If an active/paused session exists, pauses it first.
    @discardableResult
    public func startSession(
        projectId: UUID,
        mode: SessionMode,
        subMode: SessionSubMode? = nil
    ) async throws -> Session {
        // Check for existing active sessions and pause them
        let existing = try await repo.fetchActive(forProject: projectId)
        for var session in existing where session.status == .active {
            session.status = .paused
            session.lastActiveAt = Date()
            try await repo.save(session)
            Log.ai.info("Paused existing active session \(session.id) for project \(projectId)")
        }

        let session = Session(
            projectId: projectId,
            mode: mode,
            subMode: subMode,
            status: .active
        )
        try await repo.save(session)
        Log.ai.info("Started new session \(session.id) in mode \(mode.rawValue) for project \(projectId)")
        return session
    }

    /// Resumes a paused session, transitioning it back to active.
    @discardableResult
    public func resumeSession(_ sessionId: UUID) async throws -> Session {
        guard var session = try await repo.fetch(id: sessionId) else {
            throw SessionError.sessionNotFound
        }
        guard let newStatus = SessionStateMachine.transition(from: session.status, to: .active) else {
            throw SessionError.invalidTransition(
                from: session.status.rawValue,
                to: SessionStatus.active.rawValue
            )
        }
        session.status = newStatus
        session.lastActiveAt = Date()
        try await repo.save(session)
        Log.ai.info("Resumed session \(sessionId)")
        return session
    }

    /// Transitions a session to a new status, validating via the state machine.
    @discardableResult
    public func transitionSession(_ sessionId: UUID, to target: SessionStatus) async throws -> Session {
        guard var session = try await repo.fetch(id: sessionId) else {
            throw SessionError.sessionNotFound
        }
        guard let newStatus = SessionStateMachine.transition(from: session.status, to: target) else {
            throw SessionError.invalidTransition(
                from: session.status.rawValue,
                to: target.rawValue
            )
        }
        session.status = newStatus

        // Set completedAt for terminal states
        if SessionStateMachine.validTransitions(from: newStatus).isEmpty {
            session.completedAt = Date()
        }

        try await repo.save(session)
        Log.ai.info("Transitioned session \(sessionId) to \(target.rawValue)")
        return session
    }

    /// Adds a message to a session.
    @discardableResult
    public func addMessage(
        to sessionId: UUID,
        role: ChatRole,
        content: String,
        rawVoiceTranscript: String? = nil
    ) async throws -> SessionMessage {
        guard try await repo.fetch(id: sessionId) != nil else {
            throw SessionError.sessionNotFound
        }
        let message = SessionMessage(
            sessionId: sessionId,
            role: role,
            content: content,
            rawVoiceTranscript: rawVoiceTranscript
        )
        try await repo.appendMessage(message)
        return message
    }
}
