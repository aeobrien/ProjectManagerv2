import Foundation
import PMDomain
import PMUtilities
import os

/// Configuration for the integration API server.
public struct APIServerConfig: Sendable, Equatable, Codable {
    public var port: UInt16
    public var apiKey: String?
    public var enabled: Bool

    public init(port: UInt16 = 8420, apiKey: String? = nil, enabled: Bool = false) {
        self.port = port
        self.apiKey = apiKey
        self.enabled = enabled
    }
}

/// Audit log entry for write operations.
public struct AuditLogEntry: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let method: String
    public let path: String
    public let handler: String
    public let success: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        method: String,
        path: String,
        handler: String,
        success: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.path = path
        self.handler = handler
        self.success = success
    }
}

/// Protocol for the API request handler, enabling testing without network.
public protocol APIHandlerProtocol: Sendable {
    func handle(_ request: APIRequest) async -> APIResponse
}

/// Handles API requests by routing and executing against repositories.
public final class IntegrationAPIHandler: APIHandlerProtocol, Sendable {
    private let router: APIRouter
    private let config: APIServerConfig
    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let documentRepo: DocumentRepositoryProtocol
    private let _auditLog: ManagedAtomic<[AuditLogEntry]>

    public init(
        config: APIServerConfig,
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        documentRepo: DocumentRepositoryProtocol
    ) {
        self.router = APIRouter()
        self.config = config
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.milestoneRepo = milestoneRepo
        self.taskRepo = taskRepo
        self.documentRepo = documentRepo
        self._auditLog = ManagedAtomic([])
    }

    public func handle(_ request: APIRequest) async -> APIResponse {
        // Check authentication
        if let requiredKey = config.apiKey, !requiredKey.isEmpty {
            let providedKey = request.headers["Authorization"]?.replacingOccurrences(of: "Bearer ", with: "")
            guard providedKey == requiredKey else {
                return .unauthorized
            }
        }

        // Route
        guard let match = router.match(request) else {
            return .notFound
        }

        // Execute
        let response = await execute(handler: match.handler, params: match.pathParams, request: request)

        // Audit write operations
        if request.method != .GET {
            let entry = AuditLogEntry(
                method: request.method.rawValue,
                path: request.path,
                handler: match.handler,
                success: response.statusCode < 400
            )
            var log = _auditLog.load()
            log.append(entry)
            _auditLog.store(log)
        }

        return response
    }

    /// Get the audit log.
    public func auditLog() -> [AuditLogEntry] {
        _auditLog.load()
    }

    // MARK: - Handler Dispatch

    private func execute(handler: String, params: [String: String], request: APIRequest) async -> APIResponse {
        switch handler {
        case "listProjects":
            return await handleListProjects()
        case "getProject":
            guard let id = params["projectId"].flatMap(UUID.init) else {
                return .badRequest("Invalid project ID")
            }
            return await handleGetProject(id)
        case "listTasks":
            guard let id = params["projectId"].flatMap(UUID.init) else {
                return .badRequest("Invalid project ID")
            }
            return await handleListTasks(projectId: id)
        case "completeTask":
            guard let id = params["taskId"].flatMap(UUID.init) else {
                return .badRequest("Invalid task ID")
            }
            return await handleCompleteTask(id)
        case "updateTask":
            guard let id = params["taskId"].flatMap(UUID.init) else {
                return .badRequest("Invalid task ID")
            }
            return await handleUpdateTask(id, body: request.body)
        case "addTaskNotes":
            guard let id = params["taskId"].flatMap(UUID.init) else {
                return .badRequest("Invalid task ID")
            }
            return await handleAddTaskNotes(id, body: request.body)
        case "createTask":
            guard let id = params["projectId"].flatMap(UUID.init) else {
                return .badRequest("Invalid project ID")
            }
            return await handleCreateTask(projectId: id, body: request.body)
        case "reportIssue":
            guard let id = params["projectId"].flatMap(UUID.init) else {
                return .badRequest("Invalid project ID")
            }
            return await handleReportIssue(projectId: id, body: request.body)
        case "listDocuments":
            guard let id = params["projectId"].flatMap(UUID.init) else {
                return .badRequest("Invalid project ID")
            }
            return await handleListDocuments(projectId: id)
        case "updateDocument":
            guard let id = params["documentId"].flatMap(UUID.init) else {
                return .badRequest("Invalid document ID")
            }
            return await handleUpdateDocument(id, body: request.body)
        default:
            return .notFound
        }
    }

    // MARK: - Handlers

    private func handleListProjects() async -> APIResponse {
        do {
            let projects = try await projectRepo.fetchAll()
            return .json(projects)
        } catch {
            return .error("Failed to fetch projects: \(error.localizedDescription)", status: 500)
        }
    }

    private func handleGetProject(_ id: UUID) async -> APIResponse {
        do {
            guard let project = try await projectRepo.fetch(id: id) else {
                return .notFound
            }
            return .json(project)
        } catch {
            return .error("Failed to fetch project: \(error.localizedDescription)", status: 500)
        }
    }

    private func handleListTasks(projectId: UUID) async -> APIResponse {
        do {
            var allTasks: [PMTask] = []
            let phases = try await phaseRepo.fetchAll(forProject: projectId)
            for phase in phases {
                let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
                for ms in milestones {
                    let tasks = try await taskRepo.fetchAll(forMilestone: ms.id)
                    allTasks.append(contentsOf: tasks)
                }
            }
            return .json(allTasks)
        } catch {
            return .error("Failed to fetch tasks: \(error.localizedDescription)", status: 500)
        }
    }

    private func handleCompleteTask(_ id: UUID) async -> APIResponse {
        do {
            guard var task = try await taskRepo.fetch(id: id) else {
                return .notFound
            }
            task.status = .completed
            task.completedAt = Date()
            try await taskRepo.save(task)
            return .json(task)
        } catch {
            return .error("Failed to complete task: \(error.localizedDescription)", status: 500)
        }
    }

    private func handleAddTaskNotes(_ id: UUID, body: Data?) async -> APIResponse {
        guard let body, let payload = try? JSONDecoder().decode(NotesPayload.self, from: body) else {
            return .badRequest("Invalid request body")
        }
        do {
            guard var task = try await taskRepo.fetch(id: id) else {
                return .notFound
            }
            let existing = task.notes ?? ""
            task.notes = existing.isEmpty ? payload.notes : "\(existing)\n\(payload.notes)"
            try await taskRepo.save(task)
            return .json(task)
        } catch {
            return .error("Failed to add notes: \(error.localizedDescription)", status: 500)
        }
    }

    private func handleUpdateTask(_ id: UUID, body: Data?) async -> APIResponse {
        guard let body, let payload = try? JSONDecoder().decode(TaskUpdatePayload.self, from: body) else {
            return .badRequest("Invalid request body")
        }
        do {
            guard var task = try await taskRepo.fetch(id: id) else {
                return .notFound
            }
            if let name = payload.name { task.name = name }
            if let status = payload.status { task.status = status }
            if let priority = payload.priority { task.priority = priority }
            if let dod = payload.definitionOfDone { task.definitionOfDone = dod }
            if let notes = payload.notes { task.notes = notes }
            try await taskRepo.save(task)
            Log.api.info("Updated task \(id) via API")
            return .json(task)
        } catch {
            return .error("Failed to update task: \(error.localizedDescription)", status: 500)
        }
    }

    private func handleCreateTask(projectId: UUID, body: Data?) async -> APIResponse {
        guard let body, let payload = try? JSONDecoder().decode(CreateTaskPayload.self, from: body) else {
            return .badRequest("Invalid request body — requires milestoneId and name")
        }
        do {
            let task = PMTask(
                milestoneId: payload.milestoneId,
                name: payload.name,
                priority: payload.priority ?? .normal,
                effortType: payload.effortType ?? .quickWin
            )
            try await taskRepo.save(task)
            Log.api.info("Created task '\(task.name)' via API")
            return .json(task, status: 201)
        } catch {
            return .error("Failed to create task: \(error.localizedDescription)", status: 500)
        }
    }

    private func handleReportIssue(projectId: UUID, body: Data?) async -> APIResponse {
        guard let body, let payload = try? JSONDecoder().decode(IssuePayload.self, from: body) else {
            return .badRequest("Invalid request body — requires description")
        }
        do {
            guard var project = try await projectRepo.fetch(id: projectId) else {
                return .notFound
            }
            let existing = project.notes ?? ""
            let issueEntry = "[Issue] \(payload.description)"
            project.notes = existing.isEmpty ? issueEntry : "\(existing)\n\(issueEntry)"
            try await projectRepo.save(project)
            Log.api.info("Reported issue for project \(projectId) via API")
            return .json(["status": "recorded", "projectId": projectId.uuidString], status: 201)
        } catch {
            return .error("Failed to report issue: \(error.localizedDescription)", status: 500)
        }
    }

    private func handleListDocuments(projectId: UUID) async -> APIResponse {
        do {
            let docs = try await documentRepo.fetchAll(forProject: projectId)
            return .json(docs)
        } catch {
            return .error("Failed to fetch documents: \(error.localizedDescription)", status: 500)
        }
    }

    private func handleUpdateDocument(_ id: UUID, body: Data?) async -> APIResponse {
        guard let body, let payload = try? JSONDecoder().decode(DocumentUpdatePayload.self, from: body) else {
            return .badRequest("Invalid request body")
        }
        do {
            guard var doc = try await documentRepo.fetch(id: id) else {
                return .notFound
            }
            if let title = payload.title { doc.title = title }
            if let content = payload.content { doc.content = content }
            doc.updatedAt = Date()
            doc.version += 1
            try await documentRepo.save(doc)
            Log.api.info("Updated document \(id) via API")
            return .json(doc)
        } catch {
            return .error("Failed to update document: \(error.localizedDescription)", status: 500)
        }
    }
}

// MARK: - Request Payloads

struct NotesPayload: Codable, Sendable {
    let notes: String
}

struct TaskUpdatePayload: Codable, Sendable {
    let name: String?
    let status: ItemStatus?
    let priority: Priority?
    let definitionOfDone: String?
    let notes: String?
}

struct CreateTaskPayload: Codable, Sendable {
    let milestoneId: UUID
    let name: String
    let priority: Priority?
    let effortType: EffortType?
}

struct IssuePayload: Codable, Sendable {
    let description: String
}

struct DocumentUpdatePayload: Codable, Sendable {
    let title: String?
    let content: String?
}
