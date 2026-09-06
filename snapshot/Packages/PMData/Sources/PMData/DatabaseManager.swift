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

        migrator.registerMigration("v2-documentVersion") { db in
            try db.create(table: "documentVersion") { t in
                t.primaryKey("id", .text).notNull()
                t.column("documentId", .text).notNull()
                    .references("document", onDelete: .cascade)
                t.column("version", .integer).notNull()
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("savedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v3-repositoryURL") { db in
            try db.alter(table: "project") { t in
                t.add(column: "repositoryURL", .text)
            }
        }

        migrator.registerMigration("v4-sessions") { db in
            // Sessions
            try db.create(table: "session") { t in
                t.primaryKey("id", .text).notNull()
                t.column("projectId", .text).notNull()
                    .references("project", onDelete: .cascade)
                t.column("mode", .text).notNull()
                t.column("subMode", .text)
                t.column("status", .text).notNull().defaults(to: "active")
                t.column("createdAt", .datetime).notNull()
                t.column("lastActiveAt", .datetime).notNull()
                t.column("completedAt", .datetime)
                t.column("summaryId", .text)
            }
            try db.create(index: "session_project_status",
                          on: "session",
                          columns: ["projectId", "status"])

            // Session messages
            try db.create(table: "sessionMessage") { t in
                t.primaryKey("id", .text).notNull()
                t.column("sessionId", .text).notNull()
                    .references("session", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("rawVoiceTranscript", .text)
            }

            // Session summaries
            try db.create(table: "sessionSummary") { t in
                t.primaryKey("id", .text).notNull()
                t.column("sessionId", .text).notNull()
                    .references("session", onDelete: .cascade)
                    .unique()
                t.column("mode", .text).notNull()
                t.column("subMode", .text)
                t.column("completionStatus", .text).notNull()
                t.column("deliverableType", .text)
                t.column("contentEstablished", .text).notNull() // JSON
                t.column("contentObserved", .text).notNull() // JSON
                t.column("whatComesNext", .text).notNull() // JSON
                t.column("modeSpecific", .text) // JSON, nullable
                t.column("startedAt", .datetime).notNull()
                t.column("endedAt", .datetime).notNull()
                t.column("duration", .integer).notNull()
                t.column("messageCount", .integer).notNull()
                t.column("inputTokens", .integer)
                t.column("outputTokens", .integer)
            }
        }

        migrator.registerMigration("v5-processProfile-deliverable") { db in
            // Process profiles (one per project)
            try db.create(table: "processProfile") { t in
                t.primaryKey("id", .text).notNull()
                t.column("projectId", .text).notNull()
                    .references("project", onDelete: .cascade)
                    .unique()
                t.column("planningDepth", .text).notNull().defaults(to: "fullRoadmap")
                t.column("recommendedDeliverables", .text).notNull().defaults(to: "[]") // JSON
                t.column("suggestedModePath", .text).notNull().defaults(to: "[]") // JSON
                t.column("modificationHistory", .text).notNull().defaults(to: "[]") // JSON
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Typed deliverables
            try db.create(table: "deliverable") { t in
                t.primaryKey("id", .text).notNull()
                t.column("projectId", .text).notNull()
                    .references("project", onDelete: .cascade)
                t.column("type", .text).notNull()
                t.column("status", .text).notNull().defaults(to: "pending")
                t.column("title", .text).notNull().defaults(to: "")
                t.column("content", .text).notNull().defaults(to: "")
                t.column("versionHistory", .text).notNull().defaults(to: "[]") // JSON
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "deliverable_project_type",
                          on: "deliverable",
                          columns: ["projectId", "type"])
        }

        migrator.registerMigration("v6-codebase") { db in
            try db.create(table: "codebase") { t in
                t.primaryKey("id", .text).notNull()
                t.column("projectId", .text).notNull()
                    .references("project", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("sourceType", .text).notNull()
                t.column("localPath", .text)
                t.column("githubURL", .text)
                t.column("bookmarkData", .blob)
                t.column("clonedPath", .text)
                t.column("lastIndexedAt", .datetime)
                t.column("fileSizeLimitMB", .integer).notNull().defaults(to: 25)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v7-copy-deliverables-to-documents") { _ in
            // Placeholder — logic moved to v7b after discovering binary UUID + empty doc issues.
        }

        migrator.registerMigration("v7b-copy-deliverables-to-documents") { db in
            // Copy completed/revised deliverables into the document table.
            // If an empty document of the matching type exists, update it in place.
            // Otherwise create a new document.
            let deliverableRows = try Row.fetchAll(db, sql: """
                SELECT projectId, type, title, content, createdAt, updatedAt
                FROM deliverable
                WHERE status IN ('completed', 'revised')
                  AND content != ''
                """)

            for row in deliverableRows {
                let rawType: String = row["type"]
                let projectIdValue: DatabaseValue = row["projectId"]
                let title: String = row["title"]
                let content: String = row["content"]
                let createdAt: Date = row["createdAt"]
                let updatedAt: Date = row["updatedAt"]

                // Map DeliverableType → DocumentType
                let docType: String
                switch rawType {
                case "visionStatement": docType = "visionStatement"
                case "technicalBrief": docType = "technicalBrief"
                default: docType = "other"
                }

                // For visionStatement/technicalBrief: check by type (one per project).
                // For "other": check by title to avoid colliding with unrelated docs.
                let existingDoc: Row?
                if docType != "other" {
                    existingDoc = try Row.fetchOne(db, sql: """
                        SELECT id, content FROM document
                        WHERE projectId = ? AND type = ?
                        """, arguments: [projectIdValue, docType])
                } else {
                    existingDoc = try Row.fetchOne(db, sql: """
                        SELECT id, content FROM document
                        WHERE projectId = ? AND title = ?
                        """, arguments: [projectIdValue, title])
                }

                if let existing = existingDoc {
                    let existingContent: String = existing["content"]
                    if existingContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Update the empty document with the deliverable content
                        let existingId: DatabaseValue = existing["id"]
                        try db.execute(sql: """
                            UPDATE document SET content = ?, title = ?, updatedAt = ?, version = 1
                            WHERE id = ?
                            """, arguments: [content, title, updatedAt, existingId])
                    }
                    // If existing doc already has content, leave it alone
                } else {
                    // Create a new document
                    let docId = UUID()
                    // Use the deliverable's display name for a nicer title
                    let displayTitle: String
                    switch rawType {
                    case "visionStatement": displayTitle = "Vision Statement"
                    case "technicalBrief": displayTitle = "Technical Brief"
                    case "researchPlan": displayTitle = "Research Plan"
                    case "creativeBrief": displayTitle = "Creative Brief"
                    case "setupSpecification": displayTitle = "Setup Specification"
                    default: displayTitle = title
                    }

                    try db.execute(sql: """
                        INSERT INTO document (id, projectId, type, title, content, createdAt, updatedAt, version)
                        VALUES (?, ?, ?, ?, ?, ?, ?, 1)
                        """, arguments: [docId, projectIdValue, docType, displayTitle, content, createdAt, updatedAt])
                }
            }
        }

        migrator.registerMigration("v8-syncQueue") { db in
            try db.create(table: "syncChange") { t in
                t.primaryKey("id", .text).notNull()
                t.column("entityType", .text).notNull()
                t.column("entityId", .text).notNull()
                t.column("changeType", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("synced", .boolean).notNull().defaults(to: false)
            }
            try db.create(index: "syncChange_pending",
                          on: "syncChange",
                          columns: ["synced", "timestamp"])
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
