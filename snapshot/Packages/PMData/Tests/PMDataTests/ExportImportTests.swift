import Testing
import Foundation
@testable import PMData
@testable import PMDomain
import GRDB

// MARK: - Export Tests

@Suite("DataExporter")
struct DataExporterTests {

    func seedDB() async throws -> DatabaseManager {
        let db = try DatabaseManager()
        try db.seedCategoriesIfNeeded()
        let categories = try await db.dbQueue.read { db in try PMDomain.Category.fetchAll(db) }
        let cat = categories[0]

        let project = Project(name: "Test Project", categoryId: cat.id, lifecycleState: .focused, focusSlotIndex: 0)
        let phase = Phase(projectId: project.id, name: "Phase 1", sortOrder: 0)
        let milestone = Milestone(phaseId: phase.id, name: "M1")
        let task = PMTask(milestoneId: milestone.id, name: "T1", effortType: .deepFocus)
        let subtask = Subtask(taskId: task.id, name: "S1")
        let doc = Document(projectId: project.id, type: .visionStatement, title: "Vision", content: "Build something")
        let checkIn = CheckInRecord(projectId: project.id, depth: .quickLog, transcript: "All good")

        // New entities
        let docVersion = DocumentVersion(documentId: doc.id, version: 1, title: "Vision v1", content: "Build something v1")
        let session = Session(projectId: project.id, mode: .exploration)
        let sessionMsg = SessionMessage(sessionId: session.id, role: .user, content: "Hello AI")
        let sessionSummary = SessionSummary(
            sessionId: session.id,
            mode: .exploration,
            completionStatus: .completed,
            contentEstablished: SessionSummary.ContentEstablished(decisions: ["Decision 1"], factsLearned: [], progressMade: []),
            contentObserved: SessionSummary.ContentObserved(),
            whatComesNext: SessionSummary.WhatComesNext(nextActions: ["Next step"]),
            duration: 120,
            messageCount: 1
        )
        let processProfile = ProcessProfile(projectId: project.id, planningDepth: .fullRoadmap)
        let deliverable = Deliverable(projectId: project.id, type: .visionStatement, status: .inProgress, title: "Vision Doc", content: "Content here")

        try await db.dbQueue.write { db in
            try project.insert(db)
            try phase.insert(db)
            try milestone.insert(db)
            try task.insert(db)
            try subtask.insert(db)
            try doc.insert(db)
            try checkIn.insert(db)
            try docVersion.insert(db)
            try session.insert(db)
            try sessionMsg.insert(db)
            try sessionSummary.insert(db)
            try processProfile.insert(db)
            try deliverable.insert(db)
        }
        return db
    }

    @Test("Export all produces valid JSON with all entity types")
    func exportAll() async throws {
        let db = try await seedDB()
        let exporter = DataExporter(db: db.dbQueue)
        let data = try await exporter.exportAll(appVersion: "1.0.0")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportPayload.self, from: data)

        #expect(payload.metadata.appVersion == "1.0.0")
        #expect(payload.metadata.formatVersion == 2)
        #expect(payload.categories.count == 6)
        #expect(payload.projects.count == 1)

        let pe = payload.projects[0]
        #expect(pe.project.name == "Test Project")
        #expect(pe.phases.count == 1)
        #expect(pe.phases[0].milestones.count == 1)
        #expect(pe.phases[0].milestones[0].tasks.count == 1)
        #expect(pe.phases[0].milestones[0].tasks[0].subtasks.count == 1)
        #expect(pe.documents.count == 1)
        #expect(pe.checkIns.count == 1)
        #expect(pe.documentVersions.count == 1)
        #expect(pe.sessions.count == 1)
        #expect(pe.sessions[0].messages.count == 1)
        #expect(pe.sessions[0].summary != nil)
        #expect(pe.processProfile != nil)
        #expect(pe.deliverables.count == 1)
    }

    @Test("Export single project")
    func exportSingle() async throws {
        let db = try await seedDB()
        let projects = try await db.dbQueue.read { db in try Project.fetchAll(db) }
        let exporter = DataExporter(db: db.dbQueue)
        let data = try await exporter.exportProject(id: projects[0].id)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportPayload.self, from: data)

        #expect(payload.projects.count == 1)
        #expect(payload.categories.count == 1) // only the referenced category
    }

    @Test("Export nonexistent project throws")
    func exportNonexistent() async throws {
        let db = try DatabaseManager()
        let exporter = DataExporter(db: db.dbQueue)
        do {
            _ = try await exporter.exportProject(id: UUID())
            Issue.record("Expected error")
        } catch {
            // Expected
        }
    }

    @Test("Export with conversations and messages")
    func exportConversations() async throws {
        let db = try await seedDB()
        let projects = try await db.dbQueue.read { db in try Project.fetchAll(db) }

        // Add a conversation with messages
        let convo = Conversation(projectId: projects[0].id, conversationType: .brainDump)
        let msg1 = ChatMessage(role: .user, content: "Hello")
        let msg2 = ChatMessage(role: .assistant, content: "Hi!")
        try await db.dbQueue.write { db in
            try convo.save(db)
            try ChatMessageRecord(message: msg1, conversationId: convo.id).insert(db)
            try ChatMessageRecord(message: msg2, conversationId: convo.id).insert(db)
        }

        let exporter = DataExporter(db: db.dbQueue)
        let data = try await exporter.exportAll()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportPayload.self, from: data)

        #expect(payload.projects[0].conversations.count == 1)
        #expect(payload.projects[0].conversations[0].messages.count == 2)
    }
}

// MARK: - Import Tests

@Suite("DataImporter")
struct DataImporterTests {

    @Test("Import into empty database")
    func importIntoEmpty() async throws {
        // Export from a seeded DB
        let sourceDB = try DatabaseManager()
        try sourceDB.seedCategoriesIfNeeded()
        let categories = try await sourceDB.dbQueue.read { db in try PMDomain.Category.fetchAll(db) }
        let project = Project(name: "Imported", categoryId: categories[0].id)
        let phase = Phase(projectId: project.id, name: "P1")
        let milestone = Milestone(phaseId: phase.id, name: "M1")
        let task = PMTask(milestoneId: milestone.id, name: "T1")
        try await sourceDB.dbQueue.write { db in
            try project.insert(db)
            try phase.insert(db)
            try milestone.insert(db)
            try task.insert(db)
        }

        let exporter = DataExporter(db: sourceDB.dbQueue)
        let data = try await exporter.exportAll()

        // Import into fresh DB
        let targetDB = try DatabaseManager()
        let importer = DataImporter(db: targetDB.dbQueue)
        let summary = try await importer.importData(from: data)

        #expect(summary.categoriesCreated == 6)
        #expect(summary.projectsCreated == 1)

        let importedProjects = try await targetDB.dbQueue.read { db in try Project.fetchAll(db) }
        #expect(importedProjects.count == 1)
        #expect(importedProjects[0].name == "Imported")
        #expect(importedProjects[0].id == project.id) // same UUID
    }

    @Test("Import merges by UUID — updates existing")
    func importMerges() async throws {
        let db = try DatabaseManager()
        try db.seedCategoriesIfNeeded()
        let categories = try await db.dbQueue.read { db in try PMDomain.Category.fetchAll(db) }

        // Create a project
        let project = Project(name: "Original", categoryId: categories[0].id)
        let phase = Phase(projectId: project.id, name: "P1")
        try await db.dbQueue.write { db in
            try project.insert(db)
            try phase.insert(db)
        }

        // Export, modify, re-import
        let exporter = DataExporter(db: db.dbQueue)
        let data = try await exporter.exportAll()

        // Decode, modify, re-encode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var payload = try decoder.decode(ExportPayload.self, from: data)
        payload.projects[0].project.name = "Updated via Import"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let modifiedData = try encoder.encode(payload)

        let importer = DataImporter(db: db.dbQueue)
        let summary = try await importer.importData(from: modifiedData)

        #expect(summary.projectsUpdated == 1)
        #expect(summary.projectsCreated == 0)

        let fetched = try await db.dbQueue.read { db in try Project.fetchOne(db, key: project.id) }
        #expect(fetched?.name == "Updated via Import")
    }

    @Test("Export-import round-trip preserves all data including new entities")
    func roundTrip() async throws {
        let sourceDB = try DatabaseManager()
        try sourceDB.seedCategoriesIfNeeded()
        let categories = try await sourceDB.dbQueue.read { db in try PMDomain.Category.fetchAll(db) }

        let project = Project(name: "RoundTrip", categoryId: categories[0].id, lifecycleState: .focused, focusSlotIndex: 2)
        let phase = Phase(projectId: project.id, name: "Design", sortOrder: 0)
        let milestone = Milestone(phaseId: phase.id, name: "Wireframes", priority: .high)
        let task = PMTask(milestoneId: milestone.id, name: "Draw screens", priority: .high, effortType: .creative)
        let subtask = Subtask(taskId: task.id, name: "Login screen")
        let doc = Document(projectId: project.id, type: .technicalBrief, title: "Brief", content: "Details here")

        // New entities
        let docVersion = DocumentVersion(documentId: doc.id, version: 1, title: "Brief v1", content: "Details v1")
        let session = Session(projectId: project.id, mode: .definition)
        let sessionMsg = SessionMessage(sessionId: session.id, role: .assistant, content: "Here is the definition")
        let sessionSummary = SessionSummary(
            sessionId: session.id,
            mode: .definition,
            completionStatus: .completed,
            contentEstablished: SessionSummary.ContentEstablished(decisions: ["Use GRDB"], factsLearned: ["SQLite is fast"], progressMade: []),
            whatComesNext: SessionSummary.WhatComesNext(nextActions: ["Implement schema"]),
            duration: 300,
            messageCount: 5
        )
        let processProfile = ProcessProfile(
            projectId: project.id,
            planningDepth: .milestonePlan,
            suggestedModePath: ["exploration", "definition"]
        )
        let deliverable = Deliverable(
            projectId: project.id,
            type: .technicalBrief,
            status: .completed,
            title: "Tech Brief",
            content: "Full technical brief"
        )

        try await sourceDB.dbQueue.write { db in
            try project.insert(db)
            try phase.insert(db)
            try milestone.insert(db)
            try task.insert(db)
            try subtask.insert(db)
            try doc.insert(db)
            try docVersion.insert(db)
            try session.insert(db)
            try sessionMsg.insert(db)
            try sessionSummary.insert(db)
            try processProfile.insert(db)
            try deliverable.insert(db)
        }

        let exporter = DataExporter(db: sourceDB.dbQueue)
        let data = try await exporter.exportAll()

        let targetDB = try DatabaseManager()
        let importer = DataImporter(db: targetDB.dbQueue)
        let summary = try await importer.importData(from: data)

        // Verify original data preserved
        let importedProject = try await targetDB.dbQueue.read { db in try Project.fetchOne(db, key: project.id) }
        #expect(importedProject?.name == "RoundTrip")
        #expect(importedProject?.lifecycleState == .focused)
        #expect(importedProject?.focusSlotIndex == 2)

        let importedTask = try await targetDB.dbQueue.read { db in try PMTask.fetchOne(db, key: task.id) }
        #expect(importedTask?.effortType == .creative)
        #expect(importedTask?.priority == .high)

        let importedDoc = try await targetDB.dbQueue.read { db in try Document.fetchOne(db, key: doc.id) }
        #expect(importedDoc?.content == "Details here")

        // Verify new entity types preserved
        let importedDocVersion = try await targetDB.dbQueue.read { db in try DocumentVersion.fetchOne(db, key: docVersion.id) }
        #expect(importedDocVersion?.title == "Brief v1")
        #expect(importedDocVersion?.version == 1)

        let importedSession = try await targetDB.dbQueue.read { db in try Session.fetchOne(db, key: session.id) }
        #expect(importedSession?.mode == .definition)

        let importedMessages = try await targetDB.dbQueue.read { db in
            try SessionMessage.filter(Column("sessionId") == session.id).fetchAll(db)
        }
        #expect(importedMessages.count == 1)
        #expect(importedMessages[0].content == "Here is the definition")

        let importedSummary = try await targetDB.dbQueue.read { db in
            try SessionSummary.filter(Column("sessionId") == session.id).fetchOne(db)
        }
        #expect(importedSummary?.completionStatus == .completed)
        #expect(importedSummary?.contentEstablished.decisions == ["Use GRDB"])

        let importedProfile = try await targetDB.dbQueue.read { db in try ProcessProfile.fetchOne(db, key: processProfile.id) }
        #expect(importedProfile?.planningDepth == .milestonePlan)
        #expect(importedProfile?.suggestedModePath == ["exploration", "definition"])

        let importedDeliverable = try await targetDB.dbQueue.read { db in try Deliverable.fetchOne(db, key: deliverable.id) }
        #expect(importedDeliverable?.title == "Tech Brief")
        #expect(importedDeliverable?.status == .completed)

        // Verify summary counts
        #expect(summary.sessionsCreated == 1)
        #expect(summary.documentVersionsCreated == 1)
        #expect(summary.processProfilesCreated == 1)
        #expect(summary.deliverablesCreated == 1)
    }

    @Test("V1 payload (missing new fields) imports successfully with zero new-entity counts")
    func v1BackwardCompat() async throws {
        // Construct a v1-style payload JSON manually (no new fields)
        let sourceDB = try DatabaseManager()
        try sourceDB.seedCategoriesIfNeeded()
        let categories = try await sourceDB.dbQueue.read { db in try PMDomain.Category.fetchAll(db) }

        let project = Project(name: "V1 Project", categoryId: categories[0].id)
        try await sourceDB.dbQueue.write { db in
            try project.insert(db)
        }

        // Export, then strip the new fields to simulate v1
        let exporter = DataExporter(db: sourceDB.dbQueue)
        let data = try await exporter.exportAll()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var payload = try decoder.decode(ExportPayload.self, from: data)

        // Simulate v1 by setting format version to 1 and clearing new fields
        payload.metadata.formatVersion = 1

        // Re-encode without new fields by encoding to dict, removing keys, re-encoding
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var jsonObj = try JSONSerialization.jsonObject(with: encoder.encode(payload)) as! [String: Any]
        if var projects = jsonObj["projects"] as? [[String: Any]] {
            for i in projects.indices {
                projects[i].removeValue(forKey: "documentVersions")
                projects[i].removeValue(forKey: "sessions")
                projects[i].removeValue(forKey: "processProfile")
                projects[i].removeValue(forKey: "deliverables")
            }
            jsonObj["projects"] = projects
        }
        let v1Data = try JSONSerialization.data(withJSONObject: jsonObj)

        // Import v1 data
        let targetDB = try DatabaseManager()
        let importer = DataImporter(db: targetDB.dbQueue)
        let summary = try await importer.importData(from: v1Data)

        #expect(summary.projectsCreated == 1)
        #expect(summary.sessionsCreated == 0)
        #expect(summary.documentVersionsCreated == 0)
        #expect(summary.processProfilesCreated == 0)
        #expect(summary.deliverablesCreated == 0)
    }
}
