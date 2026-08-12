import Testing
import Foundation
@testable import PMData
@testable import PMDomain
import GRDB

@Suite("SQLiteProcessProfileRepository")
struct SQLiteProcessProfileRepositoryTests {

    func setup() async throws -> (DatabaseManager, SQLiteProcessProfileRepository, Project) {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let categories = try await getCategories(db)
        let project = Project(name: "ProfileTest", categoryId: categories[0].id)
        try await db.dbQueue.write { db in try project.insert(db) }
        return (db, SQLiteProcessProfileRepository(db: db.dbQueue), project)
    }

    @Test("Save and fetch profile round-trip")
    func saveAndFetch() async throws {
        let (_, repo, project) = try await setup()
        let profile = ProcessProfile(
            projectId: project.id,
            recommendedDeliverables: [
                .init(type: .visionStatement, status: .completed, rationale: "Always useful"),
                .init(type: .technicalBrief, status: .pending)
            ],
            planningDepth: .milestonePlan,
            suggestedModePath: ["exploration", "definition"],
            modificationHistory: [
                .init(description: "Initial", source: .exploration)
            ]
        )

        try await repo.save(profile)
        let fetched = try await repo.fetch(forProject: project.id)

        #expect(fetched != nil)
        #expect(fetched?.planningDepth == .milestonePlan)
        #expect(fetched?.recommendedDeliverables.count == 2)
        #expect(fetched?.recommendedDeliverables[0].type == .visionStatement)
        #expect(fetched?.recommendedDeliverables[0].status == .completed)
        #expect(fetched?.suggestedModePath == ["exploration", "definition"])
        #expect(fetched?.modificationHistory.count == 1)
    }

    @Test("Update profile replaces existing")
    func updateProfile() async throws {
        let (_, repo, project) = try await setup()
        var profile = ProcessProfile(projectId: project.id, planningDepth: .fullRoadmap)
        try await repo.save(profile)

        profile.planningDepth = .taskList
        profile.recommendedDeliverables = [.init(type: .creativeBrief)]
        try await repo.save(profile)

        let fetched = try await repo.fetch(forProject: project.id)
        #expect(fetched?.planningDepth == .taskList)
        #expect(fetched?.recommendedDeliverables.count == 1)
    }

    @Test("Delete profile")
    func deleteProfile() async throws {
        let (_, repo, project) = try await setup()
        let profile = ProcessProfile(projectId: project.id)
        try await repo.save(profile)

        try await repo.delete(forProject: project.id)

        let fetched = try await repo.fetch(forProject: project.id)
        #expect(fetched == nil)
    }

    @Test("Cascade delete from project")
    func cascadeDelete() async throws {
        let (db, repo, project) = try await setup()
        let profile = ProcessProfile(projectId: project.id)
        try await repo.save(profile)

        _ = try await db.dbQueue.write { db in
            try Project.deleteOne(db, key: project.id)
        }

        let fetched = try await repo.fetch(forProject: project.id)
        #expect(fetched == nil)
    }

    @Test("Fetch for nonexistent project returns nil")
    func fetchNonexistent() async throws {
        let (_, repo, _) = try await setup()
        let fetched = try await repo.fetch(forProject: UUID())
        #expect(fetched == nil)
    }
}

@Suite("SQLiteDeliverableRepository")
struct SQLiteDeliverableRepositoryTests {

    func setup() async throws -> (DatabaseManager, SQLiteDeliverableRepository, Project) {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let categories = try await getCategories(db)
        let project = Project(name: "DeliverableTest", categoryId: categories[0].id)
        try await db.dbQueue.write { db in try project.insert(db) }
        return (db, SQLiteDeliverableRepository(db: db.dbQueue), project)
    }

    @Test("Save and fetch deliverable round-trip")
    func saveAndFetch() async throws {
        let (_, repo, project) = try await setup()
        let deliverable = Deliverable(
            projectId: project.id,
            type: .technicalBrief,
            status: .inProgress,
            title: "Tech Brief",
            content: "Architecture..."
        )

        try await repo.save(deliverable)
        let fetched = try await repo.fetch(id: deliverable.id)

        #expect(fetched != nil)
        #expect(fetched?.type == .technicalBrief)
        #expect(fetched?.status == .inProgress)
        #expect(fetched?.title == "Tech Brief")
    }

    @Test("FetchAll by project")
    func fetchAllForProject() async throws {
        let (_, repo, project) = try await setup()
        let d1 = Deliverable(projectId: project.id, type: .visionStatement, title: "Vision")
        let d2 = Deliverable(projectId: project.id, type: .technicalBrief, title: "Brief")

        try await repo.save(d1)
        try await repo.save(d2)

        let all = try await repo.fetchAll(forProject: project.id)
        #expect(all.count == 2)
    }

    @Test("FetchAll by project and type")
    func fetchByType() async throws {
        let (_, repo, project) = try await setup()
        let d1 = Deliverable(projectId: project.id, type: .visionStatement)
        let d2 = Deliverable(projectId: project.id, type: .technicalBrief)
        let d3 = Deliverable(projectId: project.id, type: .visionStatement)

        try await repo.save(d1)
        try await repo.save(d2)
        try await repo.save(d3)

        let visions = try await repo.fetchAll(forProject: project.id, type: .visionStatement)
        #expect(visions.count == 2)

        let briefs = try await repo.fetchAll(forProject: project.id, type: .technicalBrief)
        #expect(briefs.count == 1)
    }

    @Test("Version history preserved in round-trip")
    func versionHistory() async throws {
        let (_, repo, project) = try await setup()
        let deliverable = Deliverable(
            projectId: project.id,
            type: .visionStatement,
            status: .revised,
            title: "Vision v2",
            content: "Revised content",
            versionHistory: [
                .init(version: 1, content: "Original content", changeNote: "Initial draft",
                      savedAt: Date(timeIntervalSince1970: 1000))
            ]
        )

        try await repo.save(deliverable)
        let fetched = try await repo.fetch(id: deliverable.id)

        #expect(fetched?.versionHistory.count == 1)
        #expect(fetched?.versionHistory[0].version == 1)
        #expect(fetched?.versionHistory[0].content == "Original content")
        #expect(fetched?.versionHistory[0].changeNote == "Initial draft")
    }

    @Test("Delete deliverable")
    func deleteDeliverable() async throws {
        let (_, repo, project) = try await setup()
        let d = Deliverable(projectId: project.id, type: .researchPlan)
        try await repo.save(d)

        try await repo.delete(id: d.id)

        let fetched = try await repo.fetch(id: d.id)
        #expect(fetched == nil)
    }

    @Test("Status update")
    func statusUpdate() async throws {
        let (_, repo, project) = try await setup()
        var d = Deliverable(projectId: project.id, type: .creativeBrief, status: .pending)
        try await repo.save(d)

        d.status = .inProgress
        try await repo.save(d)

        let fetched = try await repo.fetch(id: d.id)
        #expect(fetched?.status == .inProgress)
    }

    @Test("Cascade delete from project")
    func cascadeDelete() async throws {
        let (db, repo, project) = try await setup()
        let d = Deliverable(projectId: project.id, type: .visionStatement)
        try await repo.save(d)

        _ = try await db.dbQueue.write { db in
            try Project.deleteOne(db, key: project.id)
        }

        let fetched = try await repo.fetch(id: d.id)
        #expect(fetched == nil)
    }
}
