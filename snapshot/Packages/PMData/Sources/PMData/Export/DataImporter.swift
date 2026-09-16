import Foundation
import GRDB
import PMDomain

/// Imports data from a JSON export, merging by UUID (update existing, create new).
public final class DataImporter: Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    /// Imports data from JSON, merging by UUID.
    /// Returns a summary of what was imported.
    public func importData(from jsonData: Data) async throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportPayload.self, from: jsonData)

        let summary = try await db.write { db -> ImportSummary in
            var s = ImportSummary()

            // Import categories
            for category in payload.categories {
                if try PMDomain.Category.fetchOne(db, key: category.id) != nil {
                    try category.update(db)
                    s.categoriesUpdated += 1
                } else {
                    try category.insert(db)
                    s.categoriesCreated += 1
                }
            }

            // Import projects with hierarchy
            for projectExport in payload.projects {
                try Self.importProject(projectExport, into: db, summary: &s)
            }

            // Import dependencies
            for dep in payload.dependencies {
                if try Dependency.fetchOne(db, key: dep.id) != nil {
                    try dep.update(db)
                    s.dependenciesUpdated += 1
                } else {
                    try dep.insert(db)
                    s.dependenciesCreated += 1
                }
            }

            return s
        }

        return summary
    }

    private static func importProject(_ export: ProjectExport, into db: Database, summary: inout ImportSummary) throws {
        let project = export.project
        if try Project.fetchOne(db, key: project.id) != nil {
            try project.update(db)
            summary.projectsUpdated += 1
        } else {
            try project.insert(db)
            summary.projectsCreated += 1
        }

        for phaseExport in export.phases {
            let phase = phaseExport.phase
            if try Phase.fetchOne(db, key: phase.id) != nil {
                try phase.update(db)
            } else {
                try phase.insert(db)
            }

            for milestoneExport in phaseExport.milestones {
                let milestone = milestoneExport.milestone
                if try Milestone.fetchOne(db, key: milestone.id) != nil {
                    try milestone.update(db)
                } else {
                    try milestone.insert(db)
                }

                for taskExport in milestoneExport.tasks {
                    let task = taskExport.task
                    if try PMTask.fetchOne(db, key: task.id) != nil {
                        try task.update(db)
                    } else {
                        try task.insert(db)
                    }

                    for subtask in taskExport.subtasks {
                        if try Subtask.fetchOne(db, key: subtask.id) != nil {
                            try subtask.update(db)
                        } else {
                            try subtask.insert(db)
                        }
                    }
                }
            }
        }

        for doc in export.documents {
            if try Document.fetchOne(db, key: doc.id) != nil {
                try doc.update(db)
            } else {
                try doc.insert(db)
            }
        }

        for checkIn in export.checkIns {
            if try CheckInRecord.fetchOne(db, key: checkIn.id) != nil {
                try checkIn.update(db)
            } else {
                try checkIn.insert(db)
            }
        }

        for convoExport in export.conversations {
            let convo = convoExport.conversation
            if try Conversation.fetchOne(db, key: convo.id) != nil {
                try convo.update(db)
            } else {
                try convo.insert(db)
            }
            // Replace all messages for this conversation
            try ChatMessageRecord.filter(Column("conversationId") == convo.id).deleteAll(db)
            for message in convoExport.messages {
                let record = ChatMessageRecord(message: message, conversationId: convo.id)
                try record.insert(db)
            }
        }

        // Document versions
        for docVersion in export.documentVersions {
            if try DocumentVersion.fetchOne(db, key: docVersion.id) != nil {
                try docVersion.update(db)
                summary.documentVersionsUpdated += 1
            } else {
                try docVersion.insert(db)
                summary.documentVersionsCreated += 1
            }
        }

        // Sessions with messages and summaries
        for sessionExport in export.sessions {
            let session = sessionExport.session
            if try Session.fetchOne(db, key: session.id) != nil {
                try session.update(db)
                summary.sessionsUpdated += 1
            } else {
                try session.insert(db)
                summary.sessionsCreated += 1
            }

            // Replace all messages for this session (mirrors ChatMessage pattern)
            try SessionMessage.filter(Column("sessionId") == session.id).deleteAll(db)
            for message in sessionExport.messages {
                try message.insert(db)
            }

            // Upsert summary if present
            if let summaryRecord = sessionExport.summary {
                if try SessionSummary.fetchOne(db, key: summaryRecord.id) != nil {
                    try summaryRecord.update(db)
                } else {
                    try summaryRecord.insert(db)
                }
            }
        }

        // Process profile (0 or 1 per project)
        if let profile = export.processProfile {
            if try ProcessProfile.fetchOne(db, key: profile.id) != nil {
                try profile.update(db)
                summary.processProfilesUpdated += 1
            } else {
                try profile.insert(db)
                summary.processProfilesCreated += 1
            }
        }

        // Deliverables
        for deliverable in export.deliverables {
            if try Deliverable.fetchOne(db, key: deliverable.id) != nil {
                try deliverable.update(db)
                summary.deliverablesUpdated += 1
            } else {
                try deliverable.insert(db)
                summary.deliverablesCreated += 1
            }
        }

        // Codebases (imported without bookmarkData — local ones need re-linking, GitHub ones re-clone)
        for codebase in export.codebases {
            if try Codebase.fetchOne(db, key: codebase.id) != nil {
                try codebase.update(db)
                summary.codebasesUpdated += 1
            } else {
                try codebase.insert(db)
                summary.codebasesCreated += 1
            }
        }
    }
}

/// Summary of import operations.
public struct ImportSummary: Equatable, Sendable {
    public var categoriesCreated: Int = 0
    public var categoriesUpdated: Int = 0
    public var projectsCreated: Int = 0
    public var projectsUpdated: Int = 0
    public var dependenciesCreated: Int = 0
    public var dependenciesUpdated: Int = 0
    public var documentVersionsCreated: Int = 0
    public var documentVersionsUpdated: Int = 0
    public var sessionsCreated: Int = 0
    public var sessionsUpdated: Int = 0
    public var processProfilesCreated: Int = 0
    public var processProfilesUpdated: Int = 0
    public var deliverablesCreated: Int = 0
    public var deliverablesUpdated: Int = 0
    public var codebasesCreated: Int = 0
    public var codebasesUpdated: Int = 0

    public var totalCreated: Int {
        categoriesCreated + projectsCreated + dependenciesCreated +
        documentVersionsCreated + sessionsCreated + processProfilesCreated + deliverablesCreated +
        codebasesCreated
    }
    public var totalUpdated: Int {
        categoriesUpdated + projectsUpdated + dependenciesUpdated +
        documentVersionsUpdated + sessionsUpdated + processProfilesUpdated + deliverablesUpdated +
        codebasesUpdated
    }
}
