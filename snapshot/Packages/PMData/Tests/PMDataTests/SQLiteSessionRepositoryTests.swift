import Testing
import Foundation
@testable import PMData
@testable import PMDomain
import GRDB

@Suite("SQLiteSessionRepository")
struct SQLiteSessionRepositoryTests {

    func setup() async throws -> (DatabaseManager, SQLiteSessionRepository, Project) {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let categories = try await getCategories(db)
        let project = Project(name: "SessionTest", categoryId: categories[0].id)
        try await db.dbQueue.write { db in try project.insert(db) }
        return (db, SQLiteSessionRepository(db: db.dbQueue), project)
    }

    // MARK: - Session CRUD

    @Test("Save and fetch session round-trip")
    func saveAndFetch() async throws {
        let (_, repo, project) = try await setup()
        let session = Session(projectId: project.id, mode: .exploration, subMode: nil)

        try await repo.save(session)
        let fetched = try await repo.fetch(id: session.id)

        #expect(fetched != nil)
        #expect(fetched?.id == session.id)
        #expect(fetched?.projectId == project.id)
        #expect(fetched?.mode == .exploration)
        #expect(fetched?.subMode == nil)
        #expect(fetched?.status == .active)
    }

    @Test("Save session with subMode")
    func saveWithSubMode() async throws {
        let (_, repo, project) = try await setup()
        let session = Session(projectId: project.id, mode: .executionSupport, subMode: .checkIn)

        try await repo.save(session)
        let fetched = try await repo.fetch(id: session.id)

        #expect(fetched?.subMode == .checkIn)
    }

    @Test("FetchAll returns sessions for project ordered by lastActiveAt desc")
    func fetchAllForProject() async throws {
        let (_, repo, project) = try await setup()
        let older = Session(
            projectId: project.id, mode: .exploration,
            lastActiveAt: Date().addingTimeInterval(-3600)
        )
        let newer = Session(
            projectId: project.id, mode: .definition,
            lastActiveAt: Date()
        )

        try await repo.save(older)
        try await repo.save(newer)

        let all = try await repo.fetchAll(forProject: project.id)
        #expect(all.count == 2)
        #expect(all[0].id == newer.id)
        #expect(all[1].id == older.id)
    }

    @Test("FetchActive returns only active and paused sessions")
    func fetchActiveOnly() async throws {
        let (_, repo, project) = try await setup()
        let active = Session(projectId: project.id, mode: .exploration, status: .active)
        let paused = Session(projectId: project.id, mode: .definition, status: .paused)
        let completed = Session(projectId: project.id, mode: .planning, status: .completed)

        try await repo.save(active)
        try await repo.save(paused)
        try await repo.save(completed)

        let result = try await repo.fetchActive(forProject: project.id)
        #expect(result.count == 2)
        let ids = result.map(\.id)
        #expect(ids.contains(active.id))
        #expect(ids.contains(paused.id))
        #expect(!ids.contains(completed.id))
    }

    @Test("Delete removes session")
    func deleteSession() async throws {
        let (_, repo, project) = try await setup()
        let session = Session(projectId: project.id, mode: .exploration)
        try await repo.save(session)

        try await repo.delete(id: session.id)

        let fetched = try await repo.fetch(id: session.id)
        #expect(fetched == nil)
    }

    // MARK: - Messages

    @Test("Append and fetch messages")
    func appendAndFetchMessages() async throws {
        let (_, repo, project) = try await setup()
        let session = Session(projectId: project.id, mode: .exploration)
        try await repo.save(session)

        let msg1 = SessionMessage(sessionId: session.id, role: .user, content: "Hello")
        let msg2 = SessionMessage(
            sessionId: session.id, role: .assistant, content: "Hi there",
            timestamp: Date().addingTimeInterval(1)
        )
        try await repo.appendMessage(msg1)
        try await repo.appendMessage(msg2)

        let messages = try await repo.fetchMessages(forSession: session.id)
        #expect(messages.count == 2)
        #expect(messages[0].role == .user)
        #expect(messages[1].role == .assistant)
    }

    @Test("AppendMessage updates session lastActiveAt")
    func appendUpdatesLastActive() async throws {
        let (_, repo, project) = try await setup()
        let originalTime = Date().addingTimeInterval(-3600)
        let session = Session(
            projectId: project.id, mode: .exploration,
            lastActiveAt: originalTime
        )
        try await repo.save(session)

        let msgTime = Date()
        let msg = SessionMessage(
            sessionId: session.id, role: .user, content: "Update",
            timestamp: msgTime
        )
        try await repo.appendMessage(msg)

        let fetched = try await repo.fetch(id: session.id)
        #expect(fetched!.lastActiveAt.timeIntervalSince1970 >= msgTime.timeIntervalSince1970 - 1)
    }

    // MARK: - Summaries

    @Test("Save and fetch summary with JSON sections")
    func summaryRoundTrip() async throws {
        let (_, repo, project) = try await setup()
        let session = Session(projectId: project.id, mode: .exploration)
        try await repo.save(session)

        let summary = SessionSummary(
            sessionId: session.id,
            mode: .exploration,
            completionStatus: .completed,
            contentEstablished: .init(
                decisions: ["Use SwiftUI"],
                factsLearned: ["Scope is medium"],
                progressMade: ["Architecture defined"]
            ),
            contentObserved: .init(
                patterns: ["Iterative approach"],
                concerns: ["Timeline"],
                strengths: ["Clear vision"]
            ),
            whatComesNext: .init(
                nextActions: ["Create brief"],
                openQuestions: ["CI provider?"],
                suggestedMode: "definition"
            ),
            modeSpecific: .exploration(.init(
                projectSummary: "A PM app",
                recommendedDeliverables: ["visionStatement"],
                suggestedPlanningDepth: "fullRoadmap"
            )),
            startedAt: Date(timeIntervalSince1970: 1000),
            endedAt: Date(timeIntervalSince1970: 2000),
            duration: 1000,
            messageCount: 10,
            inputTokens: 5000,
            outputTokens: 3000
        )

        try await repo.saveSummary(summary)
        let fetched = try await repo.fetchSummary(forSession: session.id)

        #expect(fetched != nil)
        #expect(fetched?.contentEstablished.decisions == ["Use SwiftUI"])
        #expect(fetched?.contentObserved.patterns == ["Iterative approach"])
        #expect(fetched?.whatComesNext.suggestedMode == "definition")
        #expect(fetched?.duration == 1000)
        #expect(fetched?.inputTokens == 5000)

        if case .exploration(let data) = fetched?.modeSpecific {
            #expect(data.projectSummary == "A PM app")
            #expect(data.recommendedDeliverables == ["visionStatement"])
        } else {
            #expect(Bool(false), "Expected exploration mode-specific data")
        }
    }

    // MARK: - Auto-Summarisation Queries

    @Test("FetchSessionsPendingSummarisation respects cutoff")
    func pendingSummarisationQuery() async throws {
        let (_, repo, project) = try await setup()
        let old = Session(
            projectId: project.id, mode: .exploration, status: .paused,
            lastActiveAt: Date().addingTimeInterval(-48 * 3600)
        )
        let recent = Session(
            projectId: project.id, mode: .definition, status: .paused,
            lastActiveAt: Date()
        )
        let active = Session(
            projectId: project.id, mode: .planning, status: .active,
            lastActiveAt: Date().addingTimeInterval(-48 * 3600)
        )

        try await repo.save(old)
        try await repo.save(recent)
        try await repo.save(active)

        let cutoff = Date().addingTimeInterval(-24 * 3600)
        let pending = try await repo.fetchSessionsPendingSummarisation(olderThan: cutoff)

        #expect(pending.count == 1)
        #expect(pending[0].id == old.id)
    }

    @Test("FetchSessionsWithStatus returns matching sessions")
    func fetchByStatus() async throws {
        let (_, repo, project) = try await setup()
        let s1 = Session(projectId: project.id, mode: .exploration, status: .pendingAutoSummary)
        let s2 = Session(projectId: project.id, mode: .definition, status: .pendingAutoSummary)
        let s3 = Session(projectId: project.id, mode: .planning, status: .completed)

        try await repo.save(s1)
        try await repo.save(s2)
        try await repo.save(s3)

        let pending = try await repo.fetchSessionsWithStatus(.pendingAutoSummary)
        #expect(pending.count == 2)

        let completed = try await repo.fetchSessionsWithStatus(.completed)
        #expect(completed.count == 1)
    }

    // MARK: - Cascade Delete

    @Test("Deleting project cascades to sessions, messages, and summaries")
    func cascadeDelete() async throws {
        let (db, repo, project) = try await setup()
        let session = Session(projectId: project.id, mode: .exploration)
        try await repo.save(session)

        let msg = SessionMessage(sessionId: session.id, role: .user, content: "Hello")
        try await repo.appendMessage(msg)

        let summary = SessionSummary(
            sessionId: session.id, mode: .exploration,
            completionStatus: .completed,
            startedAt: Date(), endedAt: Date(),
            duration: 100, messageCount: 1
        )
        try await repo.saveSummary(summary)

        // Delete the project
        _ = try await db.dbQueue.write { db in
            try Project.deleteOne(db, key: project.id)
        }

        let fetchedSession = try await repo.fetch(id: session.id)
        let fetchedMessages = try await repo.fetchMessages(forSession: session.id)
        let fetchedSummary = try await repo.fetchSummary(forSession: session.id)

        #expect(fetchedSession == nil)
        #expect(fetchedMessages.isEmpty)
        #expect(fetchedSummary == nil)
    }

    // MARK: - Update Session

    @Test("Update session status")
    func updateStatus() async throws {
        let (_, repo, project) = try await setup()
        var session = Session(projectId: project.id, mode: .exploration, status: .active)
        try await repo.save(session)

        session.status = .paused
        try await repo.save(session)

        let fetched = try await repo.fetch(id: session.id)
        #expect(fetched?.status == .paused)
    }
}
