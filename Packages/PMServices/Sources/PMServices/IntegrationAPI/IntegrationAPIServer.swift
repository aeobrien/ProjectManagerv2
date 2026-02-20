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
    private let taskRepo: TaskRepositoryProtocol
    private let documentRepo: DocumentRepositoryProtocol
    private let _auditLog: ManagedAtomic<[AuditLogEntry]>

    public init(
        config: APIServerConfig,
        projectRepo: ProjectRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        documentRepo: DocumentRepositoryProtocol
    ) {
        self.router = APIRouter()
        self.config = config
        self.projectRepo = projectRepo
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
        case "addTaskNotes":
            guard let id = params["taskId"].flatMap(UUID.init) else {
                return .badRequest("Invalid task ID")
            }
            return await handleAddTaskNotes(id, body: request.body)
        case "listDocuments":
            guard let id = params["projectId"].flatMap(UUID.init) else {
                return .badRequest("Invalid project ID")
            }
            return await handleListDocuments(projectId: id)
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
            // This is simplified — in production, we'd traverse phases→milestones→tasks
            let tasks = try await taskRepo.fetchAll(forMilestone: projectId)
            return .json(tasks)
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

    private func handleListDocuments(projectId: UUID) async -> APIResponse {
        do {
            let docs = try await documentRepo.fetchAll(forProject: projectId)
            return .json(docs)
        } catch {
            return .error("Failed to fetch documents: \(error.localizedDescription)", status: 500)
        }
    }
}

// MARK: - Request Payloads

struct NotesPayload: Codable, Sendable {
    let notes: String
}
