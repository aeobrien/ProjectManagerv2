import Foundation
import GRDB
import PMDomain

/// Exportable snapshot of the full database or a single project.
public struct ExportPayload: Codable, Sendable {
    public var metadata: ExportMetadata
    public var categories: [PMDomain.Category]
    public var projects: [ProjectExport]
    public var dependencies: [Dependency]
}

public struct ExportMetadata: Codable, Sendable {
    public var exportDate: Date
    public var appVersion: String
    public var formatVersion: Int

    public init(appVersion: String = "1.0.0") {
        self.exportDate = Date()
        self.appVersion = appVersion
        self.formatVersion = 1
    }
}

public struct ProjectExport: Codable, Sendable {
    public var project: Project
    public var phases: [PhaseExport]
    public var documents: [Document]
    public var checkIns: [CheckInRecord]
    public var conversations: [ConversationExport]
}

public struct PhaseExport: Codable, Sendable {
    public var phase: Phase
    public var milestones: [MilestoneExport]
}

public struct MilestoneExport: Codable, Sendable {
    public var milestone: Milestone
    public var tasks: [TaskExport]
}

public struct TaskExport: Codable, Sendable {
    public var task: PMTask
    public var subtasks: [Subtask]
}

public struct ConversationExport: Codable, Sendable {
    public var conversation: Conversation
    public var messages: [ChatMessage]
}

/// Exports data from the database to JSON.
public final class DataExporter: Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    /// Exports all data in the database.
    public func exportAll(appVersion: String = "1.0.0") async throws -> Data {
        let payload = try await db.read { db in
            try self.buildFullPayload(db: db, appVersion: appVersion)
        }
        return try Self.encode(payload)
    }

    /// Exports a single project with all its child entities.
    public func exportProject(id: UUID, appVersion: String = "1.0.0") async throws -> Data {
        let payload = try await db.read { db in
            guard let project = try Project.fetchOne(db, key: id) else {
                throw ExportError.projectNotFound(id)
            }
            let projectExport = try self.buildProjectExport(db: db, project: project)
            // Include only categories referenced by this project
            let category = try PMDomain.Category.fetchOne(db, key: project.categoryId)
            let deps = try Dependency.fetchAll(db)
                .filter { dep in
                    // Include dependencies where source or target belongs to this project's hierarchy
                    true // simplified — include all for single-project export
                }

            return ExportPayload(
                metadata: ExportMetadata(appVersion: appVersion),
                categories: category.map { [$0] } ?? [],
                projects: [projectExport],
                dependencies: deps
            )
        }
        return try Self.encode(payload)
    }

    private func buildFullPayload(db: Database, appVersion: String) throws -> ExportPayload {
        let categories = try PMDomain.Category.order(Column("sortOrder")).fetchAll(db)
        let projects = try Project.fetchAll(db)
        let projectExports = try projects.map { try buildProjectExport(db: db, project: $0) }
        let dependencies = try Dependency.fetchAll(db)

        return ExportPayload(
            metadata: ExportMetadata(appVersion: appVersion),
            categories: categories,
            projects: projectExports,
            dependencies: dependencies
        )
    }

    private func buildProjectExport(db: Database, project: Project) throws -> ProjectExport {
        let phases = try Phase.filter(Column("projectId") == project.id)
            .order(Column("sortOrder")).fetchAll(db)
        let phaseExports = try phases.map { phase -> PhaseExport in
            let milestones = try Milestone.filter(Column("phaseId") == phase.id)
                .order(Column("sortOrder")).fetchAll(db)
            let milestoneExports = try milestones.map { milestone -> MilestoneExport in
                let tasks = try PMTask.filter(Column("milestoneId") == milestone.id)
                    .order(Column("sortOrder")).fetchAll(db)
                let taskExports = try tasks.map { task -> TaskExport in
                    let subtasks = try Subtask.filter(Column("taskId") == task.id)
                        .order(Column("sortOrder")).fetchAll(db)
                    return TaskExport(task: task, subtasks: subtasks)
                }
                return MilestoneExport(milestone: milestone, tasks: taskExports)
            }
            return PhaseExport(phase: phase, milestones: milestoneExports)
        }

        let documents = try Document.filter(Column("projectId") == project.id).fetchAll(db)
        let checkIns = try CheckInRecord.filter(Column("projectId") == project.id).fetchAll(db)

        let conversations = try Conversation.filter(Column("projectId") == project.id).fetchAll(db)
        let conversationExports = try conversations.map { convo -> ConversationExport in
            let messages = try ChatMessageRecord
                .filter(Column("conversationId") == convo.id)
                .order(Column("timestamp")).fetchAll(db)
                .map { $0.toDomain() }
            return ConversationExport(conversation: convo, messages: messages)
        }

        return ProjectExport(
            project: project,
            phases: phaseExports,
            documents: documents,
            checkIns: checkIns,
            conversations: conversationExports
        )
    }

    private static func encode(_ payload: ExportPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }
}

public enum ExportError: Error, Sendable {
    case projectNotFound(UUID)
}
