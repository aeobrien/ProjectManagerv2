import Testing
import Foundation
@testable import PMData
@testable import PMDomain
import GRDB

// Helper to create an in-memory database for each test
func makeTestDB() throws -> DatabaseManager {
    try DatabaseManager()
}

// Helper to get categories after seeding
func getCategories(_ db: DatabaseManager) async throws -> [PMDomain.Category] {
    try await db.dbQueue.read { db in try PMDomain.Category.fetchAll(db) }
}

// Helper to insert a full entity hierarchy
func insertHierarchy(db: DatabaseManager) async throws -> (Project, Phase, Milestone, PMTask, Subtask) {
    let categories = try await getCategories(db)
    let project = Project(name: "Test", categoryId: categories[0].id)
    let phase = Phase(projectId: project.id, name: "P1")
    let milestone = Milestone(phaseId: phase.id, name: "M1")
    let task = PMTask(milestoneId: milestone.id, name: "T1")
    let subtask = Subtask(taskId: task.id, name: "S1")
    try await db.dbQueue.write { db in
        try project.insert(db)
        try phase.insert(db)
        try milestone.insert(db)
        try task.insert(db)
        try subtask.insert(db)
    }
    return (project, phase, milestone, task, subtask)
}

// Helper to count records
func count<T: TableRecord>(_ type: T.Type, in db: DatabaseManager) async throws -> Int {
    try await db.dbQueue.read { db in try T.fetchCount(db) }
}

// MARK: - Database Setup Tests

@Suite("Database Setup")
struct DatabaseSetupTests {

    @Test("In-memory database creates all tables")
    func tablesCreated() async throws {
        let db = try makeTestDB()
        let tables = try await db.dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        }
        #expect(tables.contains("category"))
        #expect(tables.contains("project"))
        #expect(tables.contains("phase"))
        #expect(tables.contains("milestone"))
        #expect(tables.contains("pmTask"))
        #expect(tables.contains("subtask"))
        #expect(tables.contains("document"))
        #expect(tables.contains("dependency"))
        #expect(tables.contains("checkInRecord"))
        #expect(tables.contains("conversation"))
        #expect(tables.contains("chatMessage"))
    }

    @Test("Seed categories creates built-in categories")
    func seedCategories() async throws {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let c = try await count(PMDomain.Category.self, in: db)
        #expect(c == 6)
    }

    @Test("Seed categories is idempotent")
    func seedIdempotent() async throws {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        try db.seedCategoriesIfNeeded()
        let c = try await count(PMDomain.Category.self, in: db)
        #expect(c == 6)
    }

    @Test("Foreign keys are enabled")
    func foreignKeysEnabled() async throws {
        let db = try makeTestDB()
        let fk = try await db.dbQueue.read { db in
            try Int.fetchOne(db, sql: "PRAGMA foreign_keys")
        }
        #expect(fk == 1)
    }
}

// MARK: - Category Repository Tests

@Suite("CategoryRepository")
struct CategoryRepositoryTests {

    @Test("CRUD operations")
    func categoryCRUD() async throws {
        let db = try makeTestDB()
        let repo = SQLiteCategoryRepository(db: db.dbQueue)

        let cat = PMDomain.Category(name: "Test Category", sortOrder: 0)
        try await repo.save(cat)

        let fetched = try await repo.fetch(id: cat.id)
        #expect(fetched != nil)
        #expect(fetched?.name == "Test Category")

        let all = try await repo.fetchAll()
        #expect(all.count == 1)

        try await repo.delete(id: cat.id)
        let afterDelete = try await repo.fetch(id: cat.id)
        #expect(afterDelete == nil)
    }

    @Test("Seed built-in categories")
    func seedBuiltIn() async throws {
        let db = try makeTestDB()
        let repo = SQLiteCategoryRepository(db: db.dbQueue)
        try await repo.seedBuiltInCategories()
        let all = try await repo.fetchAll()
        #expect(all.count == 6)
        #expect(all[0].name == "Software")
    }
}

// MARK: - Project Repository Tests

@Suite("ProjectRepository")
struct ProjectRepositoryTests {

    func setup() async throws -> (DatabaseManager, SQLiteProjectRepository, PMDomain.Category) {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let categories = try await getCategories(db)
        return (db, SQLiteProjectRepository(db: db.dbQueue), categories[0])
    }

    @Test("CRUD operations")
    func projectCRUD() async throws {
        let (_, repo, cat) = try await setup()

        let project = Project(name: "My Project", categoryId: cat.id)
        try await repo.save(project)

        let fetched = try await repo.fetch(id: project.id)
        #expect(fetched?.name == "My Project")
        #expect(fetched?.lifecycleState == .idea)

        try await repo.delete(id: project.id)
        let afterDelete = try await repo.fetch(id: project.id)
        #expect(afterDelete == nil)
    }

    @Test("Fetch by lifecycle state")
    func fetchByState() async throws {
        let (_, repo, cat) = try await setup()

        let p1 = Project(name: "P1", categoryId: cat.id, lifecycleState: .focused, focusSlotIndex: 0)
        let p2 = Project(name: "P2", categoryId: cat.id, lifecycleState: .idea)
        let p3 = Project(name: "P3", categoryId: cat.id, lifecycleState: .focused, focusSlotIndex: 1)
        try await repo.save(p1)
        try await repo.save(p2)
        try await repo.save(p3)

        let focused = try await repo.fetchByLifecycleState(.focused)
        #expect(focused.count == 2)

        let ideas = try await repo.fetchByLifecycleState(.idea)
        #expect(ideas.count == 1)
    }

    @Test("Fetch focused projects ordered by slot")
    func fetchFocused() async throws {
        let (_, repo, cat) = try await setup()

        let p1 = Project(name: "Slot2", categoryId: cat.id, lifecycleState: .focused, focusSlotIndex: 2)
        let p2 = Project(name: "Slot0", categoryId: cat.id, lifecycleState: .focused, focusSlotIndex: 0)
        try await repo.save(p1)
        try await repo.save(p2)

        let focused = try await repo.fetchFocused()
        #expect(focused.count == 2)
        #expect(focused[0].name == "Slot0")
        #expect(focused[1].name == "Slot2")
    }

    @Test("Fetch by category")
    func fetchByCategory() async throws {
        let (db, repo, cat) = try await setup()
        let categories = try await getCategories(db)
        let cat2 = categories[1]

        let p1 = Project(name: "P1", categoryId: cat.id)
        let p2 = Project(name: "P2", categoryId: cat2.id)
        try await repo.save(p1)
        try await repo.save(p2)

        let byCat = try await repo.fetchByCategory(cat.id)
        #expect(byCat.count == 1)
        #expect(byCat[0].name == "P1")
    }

    @Test("Search projects by name")
    func searchProjects() async throws {
        let (_, repo, cat) = try await setup()

        try await repo.save(Project(name: "Build iOS App", categoryId: cat.id))
        try await repo.save(Project(name: "Write Music Album", categoryId: cat.id))

        let results = try await repo.search(query: "iOS")
        #expect(results.count == 1)
        #expect(results[0].name == "Build iOS App")
    }

    @Test("Update project")
    func updateProject() async throws {
        let (_, repo, cat) = try await setup()

        var project = Project(name: "Original", categoryId: cat.id)
        try await repo.save(project)

        project.name = "Updated"
        project.lifecycleState = .focused
        project.focusSlotIndex = 0
        try await repo.save(project)

        let fetched = try await repo.fetch(id: project.id)
        #expect(fetched?.name == "Updated")
        #expect(fetched?.lifecycleState == .focused)
    }

    @Test("Empty results")
    func emptyResults() async throws {
        let (_, repo, _) = try await setup()
        let all = try await repo.fetchAll()
        #expect(all.isEmpty)
        let search = try await repo.search(query: "nonexistent")
        #expect(search.isEmpty)
    }
}

// MARK: - Phase Repository Tests

@Suite("PhaseRepository")
struct PhaseRepositoryTests {

    func setup() async throws -> (DatabaseManager, SQLitePhaseRepository, Project) {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let categories = try await getCategories(db)
        let project = Project(name: "Test", categoryId: categories[0].id)
        try await db.dbQueue.write { db in try project.insert(db) }
        return (db, SQLitePhaseRepository(db: db.dbQueue), project)
    }

    @Test("CRUD operations")
    func phaseCRUD() async throws {
        let (_, repo, project) = try await setup()

        let phase = Phase(projectId: project.id, name: "Research", sortOrder: 0)
        try await repo.save(phase)

        let fetched = try await repo.fetch(id: phase.id)
        #expect(fetched?.name == "Research")

        let all = try await repo.fetchAll(forProject: project.id)
        #expect(all.count == 1)

        try await repo.delete(id: phase.id)
        let afterDelete = try await repo.fetchAll(forProject: project.id)
        #expect(afterDelete.isEmpty)
    }

    @Test("Reorder phases")
    func reorderPhases() async throws {
        let (_, repo, project) = try await setup()

        var p1 = Phase(projectId: project.id, name: "First", sortOrder: 0)
        var p2 = Phase(projectId: project.id, name: "Second", sortOrder: 1)
        try await repo.save(p1)
        try await repo.save(p2)

        p1.sortOrder = 1
        p2.sortOrder = 0
        try await repo.reorder(phases: [p1, p2])

        let fetched = try await repo.fetchAll(forProject: project.id)
        #expect(fetched[0].name == "Second")
        #expect(fetched[1].name == "First")
    }
}

// MARK: - Milestone Repository Tests

@Suite("MilestoneRepository")
struct MilestoneRepositoryTests {

    func setup() async throws -> (DatabaseManager, SQLiteMilestoneRepository, Phase) {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let categories = try await getCategories(db)
        let project = Project(name: "Test", categoryId: categories[0].id)
        let phase = Phase(projectId: project.id, name: "P1")
        try await db.dbQueue.write { db in
            try project.insert(db)
            try phase.insert(db)
        }
        return (db, SQLiteMilestoneRepository(db: db.dbQueue), phase)
    }

    @Test("CRUD operations")
    func milestoneCRUD() async throws {
        let (_, repo, phase) = try await setup()

        let milestone = Milestone(phaseId: phase.id, name: "v1.0", priority: .high)
        try await repo.save(milestone)

        let fetched = try await repo.fetch(id: milestone.id)
        #expect(fetched?.name == "v1.0")
        #expect(fetched?.priority == .high)

        try await repo.delete(id: milestone.id)
        #expect(try await repo.fetch(id: milestone.id) == nil)
    }
}

// MARK: - Task Repository Tests

@Suite("TaskRepository")
struct TaskRepositoryTests {

    func setup() async throws -> (DatabaseManager, SQLiteTaskRepository, Milestone) {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let categories = try await getCategories(db)
        let project = Project(name: "Test", categoryId: categories[0].id)
        let phase = Phase(projectId: project.id, name: "P1")
        let milestone = Milestone(phaseId: phase.id, name: "M1")
        try await db.dbQueue.write { db in
            try project.insert(db)
            try phase.insert(db)
            try milestone.insert(db)
        }
        return (db, SQLiteTaskRepository(db: db.dbQueue), milestone)
    }

    @Test("CRUD operations")
    func taskCRUD() async throws {
        let (_, repo, milestone) = try await setup()

        let task = PMTask(milestoneId: milestone.id, name: "Write tests", effortType: .deepFocus)
        try await repo.save(task)

        let fetched = try await repo.fetch(id: task.id)
        #expect(fetched?.name == "Write tests")
        #expect(fetched?.effortType == .deepFocus)

        try await repo.delete(id: task.id)
        #expect(try await repo.fetch(id: task.id) == nil)
    }

    @Test("Fetch by status")
    func fetchByStatus() async throws {
        let (_, repo, milestone) = try await setup()

        try await repo.save(PMTask(milestoneId: milestone.id, name: "T1", status: .inProgress))
        try await repo.save(PMTask(milestoneId: milestone.id, name: "T2", status: .blocked, blockedType: .tooLarge))
        try await repo.save(PMTask(milestoneId: milestone.id, name: "T3", status: .inProgress))

        let inProgress = try await repo.fetchByStatus(.inProgress)
        #expect(inProgress.count == 2)

        let blocked = try await repo.fetchByStatus(.blocked)
        #expect(blocked.count == 1)
    }

    @Test("Fetch by effort type")
    func fetchByEffortType() async throws {
        let (_, repo, milestone) = try await setup()

        try await repo.save(PMTask(milestoneId: milestone.id, name: "T1", effortType: .quickWin))
        try await repo.save(PMTask(milestoneId: milestone.id, name: "T2", effortType: .deepFocus))
        try await repo.save(PMTask(milestoneId: milestone.id, name: "T3", effortType: .quickWin))

        let quickWins = try await repo.fetchByEffortType(.quickWin)
        #expect(quickWins.count == 2)
    }

    @Test("Fetch by kanban column")
    func fetchByKanban() async throws {
        let (_, repo, milestone) = try await setup()

        try await repo.save(PMTask(milestoneId: milestone.id, name: "T1", kanbanColumn: .toDo))
        try await repo.save(PMTask(milestoneId: milestone.id, name: "T2", kanbanColumn: .inProgress))
        try await repo.save(PMTask(milestoneId: milestone.id, name: "T3", kanbanColumn: .done))

        let toDo = try await repo.fetchByKanbanColumn(.toDo, milestoneId: milestone.id)
        #expect(toDo.count == 1)
    }

    @Test("Search tasks by name")
    func searchTasks() async throws {
        let (_, repo, milestone) = try await setup()

        try await repo.save(PMTask(milestoneId: milestone.id, name: "Build login page"))
        try await repo.save(PMTask(milestoneId: milestone.id, name: "Fix signup bug"))

        let results = try await repo.search(query: "login")
        #expect(results.count == 1)
    }
}

// MARK: - Subtask Repository Tests

@Suite("SubtaskRepository")
struct SubtaskRepositoryTests {

    @Test("CRUD operations")
    func subtaskCRUD() async throws {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let (_, _, milestone, task, _) = try await insertHierarchy(db: db)
        // Delete the auto-created subtask so we start clean
        let subtaskRepo = SQLiteSubtaskRepository(db: db.dbQueue)

        let subtask = Subtask(taskId: task.id, name: "New Step")
        try await subtaskRepo.save(subtask)

        let fetched = try await subtaskRepo.fetchAll(forTask: task.id)
        // includes the one from insertHierarchy + the new one
        #expect(fetched.contains { $0.name == "New Step" })

        try await subtaskRepo.delete(id: subtask.id)
        let afterDelete = try await subtaskRepo.fetchAll(forTask: task.id)
        #expect(!afterDelete.contains { $0.name == "New Step" })
    }
}

// MARK: - Document Repository Tests

@Suite("DocumentRepository")
struct DocumentRepositoryTests {

    func setup() async throws -> (DatabaseManager, SQLiteDocumentRepository, Project) {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let categories = try await getCategories(db)
        let project = Project(name: "Test", categoryId: categories[0].id)
        try await db.dbQueue.write { db in try project.insert(db) }
        return (db, SQLiteDocumentRepository(db: db.dbQueue), project)
    }

    @Test("CRUD operations")
    func documentCRUD() async throws {
        let (_, repo, project) = try await setup()

        let doc = Document(projectId: project.id, type: .visionStatement, title: "Vision", content: "Build something great")
        try await repo.save(doc)

        let fetched = try await repo.fetch(id: doc.id)
        #expect(fetched?.title == "Vision")
        #expect(fetched?.content == "Build something great")

        try await repo.delete(id: doc.id)
        #expect(try await repo.fetch(id: doc.id) == nil)
    }

    @Test("Fetch by type")
    func fetchByType() async throws {
        let (_, repo, project) = try await setup()

        try await repo.save(Document(projectId: project.id, type: .visionStatement, title: "Vision"))
        try await repo.save(Document(projectId: project.id, type: .technicalBrief, title: "Brief"))
        try await repo.save(Document(projectId: project.id, type: .other, title: "Notes"))

        let visions = try await repo.fetchByType(.visionStatement, projectId: project.id)
        #expect(visions.count == 1)
        #expect(visions[0].title == "Vision")
    }

    @Test("Full-text search")
    func ftsSearch() async throws {
        let (_, repo, project) = try await setup()

        try await repo.save(Document(projectId: project.id, type: .visionStatement, title: "Vision Statement", content: "Build an amazing project manager with ADHD support"))
        try await repo.save(Document(projectId: project.id, type: .technicalBrief, title: "Technical Brief", content: "SwiftUI architecture with GRDB persistence"))

        let results = try await repo.search(query: "ADHD")
        #expect(results.count == 1)
        #expect(results[0].title == "Vision Statement")
    }
}

// MARK: - CheckIn Repository Tests

@Suite("CheckInRepository")
struct CheckInRepositoryTests {

    @Test("CRUD and fetchLatest")
    func checkInCRUD() async throws {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let categories = try await getCategories(db)
        let project = Project(name: "Test", categoryId: categories[0].id)
        try await db.dbQueue.write { db in try project.insert(db) }

        let repo = SQLiteCheckInRepository(db: db.dbQueue)

        let older = CheckInRecord(projectId: project.id, timestamp: Date().addingTimeInterval(-3600), depth: .quickLog, transcript: "Quick update")
        let newer = CheckInRecord(projectId: project.id, timestamp: Date(), depth: .fullConversation, transcript: "Full conversation")
        try await repo.save(older)
        try await repo.save(newer)

        let all = try await repo.fetchAll(forProject: project.id)
        #expect(all.count == 2)
        #expect(all[0].depth == .fullConversation) // newest first

        let latest = try await repo.fetchLatest(forProject: project.id)
        #expect(latest?.depth == .fullConversation)
    }
}

// MARK: - Dependency Repository Tests

@Suite("DependencyRepository")
struct DependencyRepositoryTests {

    @Test("CRUD and fetch by source/target")
    func dependencyCRUD() async throws {
        let db = try makeTestDB()
        let repo = SQLiteDependencyRepository(db: db.dbQueue)

        let milestoneId = UUID()
        let taskId = UUID()
        let dep = Dependency(sourceType: .milestone, sourceId: milestoneId, targetType: .task, targetId: taskId)
        try await repo.save(dep)

        let bySource = try await repo.fetchAll(forSource: milestoneId, sourceType: .milestone)
        #expect(bySource.count == 1)

        let byTarget = try await repo.fetchAll(forTarget: taskId, targetType: .task)
        #expect(byTarget.count == 1)

        try await repo.delete(id: dep.id)
        #expect(try await repo.fetch(id: dep.id) == nil)
    }
}

// MARK: - Conversation Repository Tests

@Suite("ConversationRepository")
struct ConversationRepositoryTests {

    func setup() async throws -> (DatabaseManager, SQLiteConversationRepository, Project) {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let categories = try await getCategories(db)
        let project = Project(name: "Test", categoryId: categories[0].id)
        try await db.dbQueue.write { db in try project.insert(db) }
        return (db, SQLiteConversationRepository(db: db.dbQueue), project)
    }

    @Test("Save and fetch conversation with messages")
    func conversationWithMessages() async throws {
        let (_, repo, project) = try await setup()

        let msg1 = ChatMessage(role: .user, content: "Hello")
        let msg2 = ChatMessage(role: .assistant, content: "Hi there!")
        let convo = Conversation(projectId: project.id, conversationType: .general, messages: [msg1, msg2])
        try await repo.save(convo)

        let fetched = try await repo.fetch(id: convo.id)
        #expect(fetched != nil)
        #expect(fetched?.messages.count == 2)
        #expect(fetched?.messages[0].role == .user)
        #expect(fetched?.messages[1].content == "Hi there!")
    }

    @Test("Fetch by type")
    func fetchByType() async throws {
        let (_, repo, project) = try await setup()

        try await repo.save(Conversation(projectId: project.id, conversationType: .brainDump))
        try await repo.save(Conversation(projectId: project.id, conversationType: .checkIn))
        try await repo.save(Conversation(projectId: project.id, conversationType: .brainDump))

        let brainDumps = try await repo.fetchAll(ofType: .brainDump)
        #expect(brainDumps.count == 2)
    }

    @Test("Append message to conversation")
    func appendMessage() async throws {
        let (_, repo, project) = try await setup()

        let convo = Conversation(projectId: project.id, conversationType: .general)
        try await repo.save(convo)

        let msg = ChatMessage(role: .user, content: "New message")
        try await repo.appendMessage(msg, toConversation: convo.id)

        let fetched = try await repo.fetch(id: convo.id)
        #expect(fetched?.messages.count == 1)
        #expect(fetched?.messages[0].content == "New message")
    }

    @Test("Delete conversation cascades messages")
    func deleteCascadesMessages() async throws {
        let (db, repo, project) = try await setup()

        let msg = ChatMessage(role: .user, content: "Hello")
        let convo = Conversation(projectId: project.id, conversationType: .general, messages: [msg])
        try await repo.save(convo)

        try await repo.delete(id: convo.id)

        let messageCount = try await count(ChatMessageRecord.self, in: db)
        #expect(messageCount == 0)
    }
}

// MARK: - Cascading Delete Tests

@Suite("Cascading Deletes")
struct CascadingDeleteTests {

    @Test("Deleting project cascades to phases, milestones, tasks, subtasks, documents, check-ins")
    func projectCascade() async throws {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let (project, _, _, _, _) = try await insertHierarchy(db: db)

        // Also add a document and check-in
        let doc = Document(projectId: project.id, type: .other, title: "Notes")
        let checkIn = CheckInRecord(projectId: project.id, depth: .quickLog)
        try await db.dbQueue.write { db in
            try doc.insert(db)
            try checkIn.insert(db)
        }

        // Delete the project
        try await db.dbQueue.write { db in
            _ = try Project.deleteOne(db, key: project.id)
        }

        // Verify everything cascaded
        #expect(try await count(Phase.self, in: db) == 0)
        #expect(try await count(Milestone.self, in: db) == 0)
        #expect(try await count(PMTask.self, in: db) == 0)
        #expect(try await count(Subtask.self, in: db) == 0)
        #expect(try await count(Document.self, in: db) == 0)
        #expect(try await count(CheckInRecord.self, in: db) == 0)
    }

    @Test("Deleting phase cascades to milestones, tasks, subtasks")
    func phaseCascade() async throws {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let (_, phase, _, _, _) = try await insertHierarchy(db: db)

        try await db.dbQueue.write { db in
            _ = try Phase.deleteOne(db, key: phase.id)
        }

        #expect(try await count(Project.self, in: db) == 1) // project survives
        #expect(try await count(Milestone.self, in: db) == 0)
        #expect(try await count(PMTask.self, in: db) == 0)
        #expect(try await count(Subtask.self, in: db) == 0)
    }

    @Test("Deleting milestone cascades to tasks and subtasks")
    func milestoneCascade() async throws {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let (_, _, milestone, _, _) = try await insertHierarchy(db: db)

        try await db.dbQueue.write { db in
            _ = try Milestone.deleteOne(db, key: milestone.id)
        }

        #expect(try await count(Phase.self, in: db) == 1)
        #expect(try await count(PMTask.self, in: db) == 0)
        #expect(try await count(Subtask.self, in: db) == 0)
    }

    @Test("Deleting task cascades to subtasks")
    func taskCascade() async throws {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let (_, _, _, task, _) = try await insertHierarchy(db: db)

        try await db.dbQueue.write { db in
            _ = try PMTask.deleteOne(db, key: task.id)
        }

        #expect(try await count(Subtask.self, in: db) == 0)
        #expect(try await count(Milestone.self, in: db) == 1)
    }

    @Test("Cannot delete category with projects (restrict)")
    func categoryRestrict() async throws {
        let db = try makeTestDB()
        try db.seedCategoriesIfNeeded()
        let categories = try await getCategories(db)
        let cat = categories[0]

        let project = Project(name: "Test", categoryId: cat.id)
        try await db.dbQueue.write { db in try project.insert(db) }

        do {
            try await db.dbQueue.write { db in
                _ = try PMDomain.Category.deleteOne(db, key: cat.id)
            }
            Issue.record("Expected foreign key violation")
        } catch {
            // Expected — category has projects referencing it
        }
    }
}
