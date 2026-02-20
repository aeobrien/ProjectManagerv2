import Foundation
import GRDB
import PMDomain
import PMUtilities

/// Manages the SQLite database connection and schema migrations.
public final class DatabaseManager: Sendable {
    public let dbQueue: DatabaseQueue

    /// Creates a file-based database at the given path.
    public init(path: String) throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        dbQueue = try DatabaseQueue(path: path, configuration: config)
        try migrate()
    }

    /// Creates an in-memory database (for testing).
    public init() throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        dbQueue = try DatabaseQueue(configuration: config)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1-schema") { db in
            // Categories
            try db.create(table: "category") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("isBuiltIn", .boolean).notNull().defaults(to: false)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
            }

            // Projects
            try db.create(table: "project") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("categoryId", .text).notNull()
                    .references("category", onDelete: .restrict)
                t.column("lifecycleState", .text).notNull().defaults(to: "idea")
                t.column("focusSlotIndex", .integer)
                t.column("pauseReason", .text)
                t.column("abandonmentReflection", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("lastWorkedOn", .datetime)
                t.column("definitionOfDone", .text)
                t.column("notes", .text)
                t.column("quickCaptureTranscript", .text)
            }

            // Phases
            try db.create(table: "phase") { t in
                t.primaryKey("id", .text).notNull()
                t.column("projectId", .text).notNull()
                    .references("project", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("status", .text).notNull().defaults(to: "notStarted")
                t.column("definitionOfDone", .text).notNull().defaults(to: "")
                t.column("retrospectiveNotes", .text)
                t.column("retrospectiveCompletedAt", .datetime)
            }

            // Milestones
            try db.create(table: "milestone") { t in
                t.primaryKey("id", .text).notNull()
                t.column("phaseId", .text).notNull()
                    .references("phase", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("status", .text).notNull().defaults(to: "notStarted")
                t.column("definitionOfDone", .text).notNull().defaults(to: "")
                t.column("deadline", .datetime)
                t.column("priority", .text).notNull().defaults(to: "normal")
                t.column("waitingReason", .text)
                t.column("waitingCheckBackDate", .datetime)
                t.column("notes", .text)
            }

            // Tasks
            try db.create(table: "pmTask") { t in
                t.primaryKey("id", .text).notNull()
                t.column("milestoneId", .text).notNull()
                    .references("milestone", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("status", .text).notNull().defaults(to: "notStarted")
                t.column("definitionOfDone", .text).notNull().defaults(to: "")
                t.column("isTimeboxed", .boolean).notNull().defaults(to: false)
                t.column("timeEstimateMinutes", .integer)
                t.column("adjustedEstimateMinutes", .integer)
                t.column("actualMinutes", .integer)
                t.column("timeboxMinutes", .integer)
                t.column("deadline", .datetime)
                t.column("priority", .text).notNull().defaults(to: "normal")
                t.column("effortType", .text)
                t.column("blockedType", .text)
                t.column("blockedReason", .text)
                t.column("waitingReason", .text)
                t.column("waitingCheckBackDate", .datetime)
                t.column("completedAt", .datetime)
                t.column("timesDeferred", .integer).notNull().defaults(to: 0)
                t.column("notes", .text)
                t.column("kanbanColumn", .text).notNull().defaults(to: "toDo")
            }

            // Subtasks
            try db.create(table: "subtask") { t in
                t.primaryKey("id", .text).notNull()
                t.column("taskId", .text).notNull()
                    .references("pmTask", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("isCompleted", .boolean).notNull().defaults(to: false)
                t.column("definitionOfDone", .text).notNull().defaults(to: "")
            }

            // Documents
            try db.create(table: "document") { t in
                t.primaryKey("id", .text).notNull()
                t.column("projectId", .text).notNull()
                    .references("project", onDelete: .cascade)
                t.column("type", .text).notNull()
                t.column("title", .text).notNull()
                t.column("content", .text).notNull().defaults(to: "")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("version", .integer).notNull().defaults(to: 1)
            }

            // Dependencies (advisory)
            try db.create(table: "dependency") { t in
                t.primaryKey("id", .text).notNull()
                t.column("sourceType", .text).notNull()
                t.column("sourceId", .text).notNull()
                t.column("targetType", .text).notNull()
                t.column("targetId", .text).notNull()
            }

            // Check-in records
            try db.create(table: "checkInRecord") { t in
                t.primaryKey("id", .text).notNull()
                t.column("projectId", .text).notNull()
                    .references("project", onDelete: .cascade)
                t.column("timestamp", .datetime).notNull()
                t.column("depth", .text).notNull()
                t.column("transcript", .text).notNull().defaults(to: "")
                t.column("aiSummary", .text).notNull().defaults(to: "")
                t.column("tasksCompleted", .text).notNull().defaults(to: "[]")
                t.column("issuesFlagged", .text).notNull().defaults(to: "[]")
            }

            // Conversations
            try db.create(table: "conversation") { t in
                t.primaryKey("id", .text).notNull()
                t.column("projectId", .text)
                    .references("project", onDelete: .cascade)
                t.column("conversationType", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Chat messages
            try db.create(table: "chatMessage") { t in
                t.primaryKey("id", .text).notNull()
                t.column("conversationId", .text).notNull()
                    .references("conversation", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("rawVoiceTranscript", .text)
            }

            // FTS index for search
            try db.create(virtualTable: "searchIndex", using: FTS5()) { t in
                t.synchronize(withTable: "document")
                t.column("title")
                t.column("content")
            }
        }

        try migrator.migrate(dbQueue)
    }

    /// Seeds the built-in categories if they don't exist yet.
    public func seedCategoriesIfNeeded() throws {
        try dbQueue.write { db in
            let count = try Category.fetchCount(db)
            guard count == 0 else { return }
            for category in Category.builtInCategories {
                try category.insert(db)
            }
        }
    }
}
