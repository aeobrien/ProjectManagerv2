import Testing
import Foundation
@testable import PMServices
@testable import PMDomain

// MARK: - Mock Repositories for API Tests

final class APITestProjectRepo: ProjectRepositoryProtocol, @unchecked Sendable {
    var projects: [Project] = []
    func fetchAll() async throws -> [Project] { projects }
    func fetch(id: UUID) async throws -> Project? { projects.first { $0.id == id } }
    func fetchByLifecycleState(_ state: LifecycleState) async throws -> [Project] { projects.filter { $0.lifecycleState == state } }
    func fetchByCategory(_ categoryId: UUID) async throws -> [Project] { projects.filter { $0.categoryId == categoryId } }
    func fetchFocused() async throws -> [Project] { projects.filter { $0.focusSlotIndex != nil } }
    func save(_ project: Project) async throws {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) { projects[idx] = project }
        else { projects.append(project) }
    }
    func delete(id: UUID) async throws { projects.removeAll { $0.id == id } }
    func search(query: String) async throws -> [Project] { projects.filter { $0.name.contains(query) } }
}

final class APITestTaskRepo: TaskRepositoryProtocol, @unchecked Sendable {
    var tasks: [PMTask] = []
    func fetchAll(forMilestone milestoneId: UUID) async throws -> [PMTask] { tasks.filter { $0.milestoneId == milestoneId } }
    func fetch(id: UUID) async throws -> PMTask? { tasks.first { $0.id == id } }
    func fetchByKanbanColumn(_ column: KanbanColumn, milestoneId: UUID) async throws -> [PMTask] { tasks.filter { $0.kanbanColumn == column && $0.milestoneId == milestoneId } }
    func fetchByStatus(_ status: ItemStatus) async throws -> [PMTask] { tasks.filter { $0.status == status } }
    func fetchByEffortType(_ type: EffortType) async throws -> [PMTask] { tasks.filter { $0.effortType == type } }
    func save(_ task: PMTask) async throws {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) { tasks[idx] = task }
        else { tasks.append(task) }
    }
    func delete(id: UUID) async throws { tasks.removeAll { $0.id == id } }
    func reorder(tasks: [PMTask]) async throws { self.tasks = tasks }
    func search(query: String) async throws -> [PMTask] { tasks.filter { $0.name.contains(query) } }
}

final class APITestDocRepo: DocumentRepositoryProtocol, @unchecked Sendable {
    var documents: [Document] = []
    func fetchAll(forProject projectId: UUID) async throws -> [Document] { documents.filter { $0.projectId == projectId } }
    func fetch(id: UUID) async throws -> Document? { documents.first { $0.id == id } }
    func fetchByType(_ type: DocumentType, projectId: UUID) async throws -> [Document] { documents.filter { $0.type == type && $0.projectId == projectId } }
    func save(_ document: Document) async throws {
        if let idx = documents.firstIndex(where: { $0.id == document.id }) { documents[idx] = document }
        else { documents.append(document) }
    }
    func delete(id: UUID) async throws { documents.removeAll { $0.id == id } }
    func search(query: String) async throws -> [Document] { documents.filter { $0.title.contains(query) } }
}

final class APITestPhaseRepo: PhaseRepositoryProtocol, @unchecked Sendable {
    var phases: [Phase] = []
    func fetchAll(forProject projectId: UUID) async throws -> [Phase] { phases.filter { $0.projectId == projectId } }
    func fetch(id: UUID) async throws -> Phase? { phases.first { $0.id == id } }
    func save(_ phase: Phase) async throws {
        if let idx = phases.firstIndex(where: { $0.id == phase.id }) { phases[idx] = phase }
        else { phases.append(phase) }
    }
    func delete(id: UUID) async throws { phases.removeAll { $0.id == id } }
    func reorder(phases: [Phase]) async throws { self.phases = phases }
}

final class APITestMilestoneRepo: MilestoneRepositoryProtocol, @unchecked Sendable {
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

// MARK: - APIRouter Tests

@Suite("APIRouter")
struct APIRouterTests {

    @Test("Match GET projects")
    func matchGetProjects() {
        let router = APIRouter()
        let request = APIRequest(method: .GET, path: "/api/v1/projects")
        let match = router.match(request)
        #expect(match?.handler == "listProjects")
    }

    @Test("Match GET project by ID")
    func matchGetProject() {
        let router = APIRouter()
        let id = UUID().uuidString
        let request = APIRequest(method: .GET, path: "/api/v1/projects/\(id)")
        let match = router.match(request)
        #expect(match?.handler == "getProject")
        #expect(match?.pathParams["projectId"] == id)
    }

    @Test("Match GET tasks for project")
    func matchGetTasks() {
        let router = APIRouter()
        let id = UUID().uuidString
        let request = APIRequest(method: .GET, path: "/api/v1/projects/\(id)/tasks")
        let match = router.match(request)
        #expect(match?.handler == "listTasks")
        #expect(match?.pathParams["projectId"] == id)
    }

    @Test("Match POST complete task")
    func matchCompleteTask() {
        let router = APIRouter()
        let id = UUID().uuidString
        let request = APIRequest(method: .POST, path: "/api/v1/tasks/\(id)/complete")
        let match = router.match(request)
        #expect(match?.handler == "completeTask")
        #expect(match?.pathParams["taskId"] == id)
    }

    @Test("Match PATCH task")
    func matchPatchTask() {
        let router = APIRouter()
        let id = UUID().uuidString
        let request = APIRequest(method: .PATCH, path: "/api/v1/tasks/\(id)")
        let match = router.match(request)
        #expect(match?.handler == "updateTask")
    }

    @Test("Match POST task notes")
    func matchPostNotes() {
        let router = APIRouter()
        let id = UUID().uuidString
        let request = APIRequest(method: .POST, path: "/api/v1/tasks/\(id)/notes")
        let match = router.match(request)
        #expect(match?.handler == "addTaskNotes")
    }

    @Test("Match GET documents")
    func matchGetDocuments() {
        let router = APIRouter()
        let id = UUID().uuidString
        let request = APIRequest(method: .GET, path: "/api/v1/projects/\(id)/documents")
        let match = router.match(request)
        #expect(match?.handler == "listDocuments")
    }

    @Test("No match for unknown path")
    func noMatch() {
        let router = APIRouter()
        let request = APIRequest(method: .GET, path: "/api/v1/unknown")
        let match = router.match(request)
        #expect(match == nil)
    }

    @Test("No match for wrong method")
    func wrongMethod() {
        let router = APIRouter()
        let request = APIRequest(method: .DELETE, path: "/api/v1/projects")
        let match = router.match(request)
        #expect(match == nil)
    }
}

// MARK: - APIResponse Tests

@Suite("APIResponse")
struct APIResponseTests {

    @Test("JSON response")
    func jsonResponse() {
        let response = APIResponse.json(["key": "value"])
        #expect(response.statusCode == 200)
        #expect(response.body != nil)
    }

    @Test("Error response")
    func errorResponse() {
        let response = APIResponse.error("Something went wrong", status: 500)
        #expect(response.statusCode == 500)
        #expect(response.body != nil)
    }

    @Test("Bad request")
    func badRequest() {
        let response = APIResponse.badRequest("Invalid input")
        #expect(response.statusCode == 400)
    }

    @Test("Static responses")
    func staticResponses() {
        #expect(APIResponse.ok.statusCode == 200)
        #expect(APIResponse.created.statusCode == 201)
        #expect(APIResponse.notFound.statusCode == 404)
        #expect(APIResponse.unauthorized.statusCode == 401)
    }
}

// MARK: - IntegrationAPIHandler Tests

@Suite("IntegrationAPIHandler")
struct IntegrationAPIHandlerTests {

    @Test("Authentication required when API key set")
    func authRequired() async {
        let config = APIServerConfig(apiKey: "secret123")
        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: APITestProjectRepo(),
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: APITestTaskRepo(),
            documentRepo: APITestDocRepo()
        )

        // No auth header
        let request = APIRequest(method: .GET, path: "/api/v1/projects")
        let response = await handler.handle(request)
        #expect(response.statusCode == 401)
    }

    @Test("Authentication succeeds with correct key")
    func authSucceeds() async {
        let config = APIServerConfig(apiKey: "secret123")
        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: APITestProjectRepo(),
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: APITestTaskRepo(),
            documentRepo: APITestDocRepo()
        )

        let request = APIRequest(
            method: .GET,
            path: "/api/v1/projects",
            headers: ["Authorization": "Bearer secret123"]
        )
        let response = await handler.handle(request)
        #expect(response.statusCode == 200)
    }

    @Test("No auth required when key not set")
    func noAuthRequired() async {
        let config = APIServerConfig()
        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: APITestProjectRepo(),
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: APITestTaskRepo(),
            documentRepo: APITestDocRepo()
        )

        let request = APIRequest(method: .GET, path: "/api/v1/projects")
        let response = await handler.handle(request)
        #expect(response.statusCode == 200)
    }

    @Test("List projects returns projects")
    func listProjects() async {
        let config = APIServerConfig()
        let projectRepo = APITestProjectRepo()
        projectRepo.projects = [
            Project(name: "App", categoryId: UUID()),
            Project(name: "Website", categoryId: UUID())
        ]
        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: projectRepo,
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: APITestTaskRepo(),
            documentRepo: APITestDocRepo()
        )

        let request = APIRequest(method: .GET, path: "/api/v1/projects")
        let response = await handler.handle(request)
        #expect(response.statusCode == 200)
        #expect(response.body != nil)
    }

    @Test("Get project by ID")
    func getProject() async {
        let config = APIServerConfig()
        let projectRepo = APITestProjectRepo()
        let project = Project(name: "App", categoryId: UUID())
        projectRepo.projects = [project]

        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: projectRepo,
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: APITestTaskRepo(),
            documentRepo: APITestDocRepo()
        )

        let request = APIRequest(method: .GET, path: "/api/v1/projects/\(project.id.uuidString)")
        let response = await handler.handle(request)
        #expect(response.statusCode == 200)
    }

    @Test("Get project not found")
    func getProjectNotFound() async {
        let config = APIServerConfig()
        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: APITestProjectRepo(),
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: APITestTaskRepo(),
            documentRepo: APITestDocRepo()
        )

        let request = APIRequest(method: .GET, path: "/api/v1/projects/\(UUID().uuidString)")
        let response = await handler.handle(request)
        #expect(response.statusCode == 404)
    }

    @Test("Audit log records write operations")
    func auditLog() async {
        let config = APIServerConfig()
        let taskRepo = APITestTaskRepo()
        let task = PMTask(milestoneId: UUID(), name: "Test")
        taskRepo.tasks = [task]

        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: APITestProjectRepo(),
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: taskRepo,
            documentRepo: APITestDocRepo()
        )

        let request = APIRequest(method: .POST, path: "/api/v1/tasks/\(task.id.uuidString)/complete")
        _ = await handler.handle(request)

        let log = handler.auditLog()
        #expect(log.count == 1)
        #expect(log.first?.method == "POST")
        #expect(log.first?.handler == "completeTask")
        #expect(log.first?.success == true)
    }

    @Test("Update task via PATCH")
    func updateTask() async {
        let config = APIServerConfig()
        let taskRepo = APITestTaskRepo()
        let task = PMTask(milestoneId: UUID(), name: "Original")
        taskRepo.tasks = [task]

        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: APITestProjectRepo(),
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: taskRepo,
            documentRepo: APITestDocRepo()
        )

        let body = try! JSONEncoder().encode(["name": "Updated"])
        let request = APIRequest(method: .PATCH, path: "/api/v1/tasks/\(task.id.uuidString)", body: body)
        let response = await handler.handle(request)
        #expect(response.statusCode == 200)
        #expect(taskRepo.tasks.first?.name == "Updated")
    }

    @Test("Create task via POST")
    func createTask() async {
        let config = APIServerConfig()
        let projectId = UUID()
        let phaseId = UUID()
        let msId = UUID()
        let taskRepo = APITestTaskRepo()

        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: APITestProjectRepo(),
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: taskRepo,
            documentRepo: APITestDocRepo()
        )

        let body = try! JSONEncoder().encode(["milestoneId": msId.uuidString, "name": "New Task"])
        let request = APIRequest(method: .POST, path: "/api/v1/projects/\(projectId.uuidString)/tasks", body: body)
        let response = await handler.handle(request)
        #expect(response.statusCode == 201)
        #expect(taskRepo.tasks.count == 1)
        #expect(taskRepo.tasks.first?.name == "New Task")
    }

    @Test("Report issue via POST")
    func reportIssue() async {
        let config = APIServerConfig()
        let projectRepo = APITestProjectRepo()
        let project = Project(name: "App", categoryId: UUID())
        projectRepo.projects = [project]

        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: projectRepo,
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: APITestTaskRepo(),
            documentRepo: APITestDocRepo()
        )

        let body = try! JSONEncoder().encode(["description": "Something broke"])
        let request = APIRequest(method: .POST, path: "/api/v1/projects/\(project.id.uuidString)/issues", body: body)
        let response = await handler.handle(request)
        #expect(response.statusCode == 201)
        #expect(projectRepo.projects.first?.notes?.contains("[Issue]") == true)
    }

    @Test("Update document via PATCH")
    func updateDocument() async {
        let config = APIServerConfig()
        let docRepo = APITestDocRepo()
        let doc = Document(projectId: UUID(), type: .other, title: "Old", content: "old content")
        docRepo.documents = [doc]

        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: APITestProjectRepo(),
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: APITestTaskRepo(),
            documentRepo: docRepo
        )

        let body = try! JSONEncoder().encode(["title": "New Title", "content": "new content"])
        let request = APIRequest(method: .PATCH, path: "/api/v1/documents/\(doc.id.uuidString)", body: body)
        let response = await handler.handle(request)
        #expect(response.statusCode == 200)
        #expect(docRepo.documents.first?.title == "New Title")
        #expect(docRepo.documents.first?.content == "new content")
    }

    @Test("Unknown route returns 404")
    func unknownRoute() async {
        let config = APIServerConfig()
        let handler = IntegrationAPIHandler(
            config: config,
            projectRepo: APITestProjectRepo(),
            phaseRepo: APITestPhaseRepo(),
            milestoneRepo: APITestMilestoneRepo(),
            taskRepo: APITestTaskRepo(),
            documentRepo: APITestDocRepo()
        )

        let request = APIRequest(method: .GET, path: "/api/v1/nonexistent")
        let response = await handler.handle(request)
        #expect(response.statusCode == 404)
    }
}

// MARK: - APIServerConfig Tests

@Suite("APIServerConfig")
struct APIServerConfigTests {

    @Test("Default config")
    func defaults() {
        let config = APIServerConfig()
        #expect(config.port == 8420)
        #expect(config.apiKey == nil)
        #expect(config.enabled == false)
    }

    @Test("Equality")
    func equality() {
        let a = APIServerConfig(port: 8080, apiKey: "key")
        let b = APIServerConfig(port: 8080, apiKey: "key")
        #expect(a == b)
    }
}

// MARK: - AuditLogEntry Tests

@Suite("AuditLogEntry")
struct AuditLogEntryTests {

    @Test("Creation")
    func creation() {
        let entry = AuditLogEntry(method: "POST", path: "/api/v1/tasks/123/complete", handler: "completeTask", success: true)
        #expect(entry.method == "POST")
        #expect(entry.success == true)
    }
}
