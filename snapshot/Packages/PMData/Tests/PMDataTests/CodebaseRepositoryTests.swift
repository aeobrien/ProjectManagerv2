import Testing
import Foundation
@testable import PMData
import PMDomain

@Suite("CodebaseRepository Tests")
struct CodebaseRepositoryTests {

    private func makeDB() throws -> DatabaseManager {
        try DatabaseManager()
    }

    private func seedProject(db: DatabaseManager) async throws -> Project {
        let categoryRepo = SQLiteCategoryRepository(db: db.dbQueue)
        try db.seedCategoriesIfNeeded()
        let categories = try await categoryRepo.fetchAll()
        let project = Project(
            name: "Test Project",
            categoryId: categories.first!.id
        )
        let projectRepo = SQLiteProjectRepository(db: db.dbQueue)
        try await projectRepo.save(project)
        return project
    }

    @Test("Save and fetch codebase")
    func testSaveAndFetch() async throws {
        let db = try makeDB()
        let project = try await seedProject(db: db)
        let repo = SQLiteCodebaseRepository(db: db.dbQueue)

        let codebase = Codebase(
            projectId: project.id,
            name: "MyRepo",
            sourceType: .github,
            githubURL: "https://github.com/user/repo"
        )
        try await repo.save(codebase)

        let fetched = try await repo.fetch(id: codebase.id)
        #expect(fetched != nil)
        #expect(fetched?.name == "MyRepo")
        #expect(fetched?.sourceType == .github)
        #expect(fetched?.githubURL == "https://github.com/user/repo")
        #expect(fetched?.fileSizeLimitMB == 25)
    }

    @Test("Fetch all for project")
    func testFetchAllForProject() async throws {
        let db = try makeDB()
        let project = try await seedProject(db: db)
        let repo = SQLiteCodebaseRepository(db: db.dbQueue)

        let cb1 = Codebase(projectId: project.id, name: "Repo1", sourceType: .github, githubURL: "https://github.com/user/repo1")
        let cb2 = Codebase(projectId: project.id, name: "Local Dir", sourceType: .local, localPath: "/Users/test/project")
        try await repo.save(cb1)
        try await repo.save(cb2)

        let all = try await repo.fetchAll(forProject: project.id)
        #expect(all.count == 2)
    }

    @Test("Fetch all returns empty for unrelated project")
    func testFetchAllEmpty() async throws {
        let db = try makeDB()
        let project = try await seedProject(db: db)
        let repo = SQLiteCodebaseRepository(db: db.dbQueue)

        let cb = Codebase(projectId: project.id, name: "Repo", sourceType: .local, localPath: "/tmp")
        try await repo.save(cb)

        let otherProjectId = UUID()
        let result = try await repo.fetchAll(forProject: otherProjectId)
        #expect(result.isEmpty)
    }

    @Test("Delete codebase")
    func testDelete() async throws {
        let db = try makeDB()
        let project = try await seedProject(db: db)
        let repo = SQLiteCodebaseRepository(db: db.dbQueue)

        let cb = Codebase(projectId: project.id, name: "ToDelete", sourceType: .local, localPath: "/tmp")
        try await repo.save(cb)
        #expect(try await repo.fetch(id: cb.id) != nil)

        try await repo.delete(id: cb.id)
        #expect(try await repo.fetch(id: cb.id) == nil)
    }

    @Test("Update codebase")
    func testUpdate() async throws {
        let db = try makeDB()
        let project = try await seedProject(db: db)
        let repo = SQLiteCodebaseRepository(db: db.dbQueue)

        var cb = Codebase(projectId: project.id, name: "Original", sourceType: .local, localPath: "/tmp")
        try await repo.save(cb)

        cb.name = "Updated"
        cb.fileSizeLimitMB = 50
        cb.lastIndexedAt = Date()
        cb.updatedAt = Date()
        try await repo.save(cb)

        let fetched = try await repo.fetch(id: cb.id)
        #expect(fetched?.name == "Updated")
        #expect(fetched?.fileSizeLimitMB == 50)
        #expect(fetched?.lastIndexedAt != nil)
    }

    @Test("Save with bookmark data")
    func testBookmarkData() async throws {
        let db = try makeDB()
        let project = try await seedProject(db: db)
        let repo = SQLiteCodebaseRepository(db: db.dbQueue)

        let fakeBookmark = Data([0x01, 0x02, 0x03, 0x04])
        let cb = Codebase(
            projectId: project.id,
            name: "WithBookmark",
            sourceType: .local,
            localPath: "/Users/test",
            bookmarkData: fakeBookmark
        )
        try await repo.save(cb)

        let fetched = try await repo.fetch(id: cb.id)
        #expect(fetched?.bookmarkData == fakeBookmark)
    }

    @Test("Cascade delete with project")
    func testCascadeDelete() async throws {
        let db = try makeDB()
        let project = try await seedProject(db: db)
        let codebaseRepo = SQLiteCodebaseRepository(db: db.dbQueue)
        let projectRepo = SQLiteProjectRepository(db: db.dbQueue)

        let cb = Codebase(projectId: project.id, name: "WillCascade", sourceType: .local, localPath: "/tmp")
        try await codebaseRepo.save(cb)
        #expect(try await codebaseRepo.fetch(id: cb.id) != nil)

        try await projectRepo.delete(id: project.id)
        #expect(try await codebaseRepo.fetch(id: cb.id) == nil)
    }
}
