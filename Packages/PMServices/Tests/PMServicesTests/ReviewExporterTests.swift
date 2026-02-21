import Testing
import Foundation
@testable import PMServices
@testable import PMDomain

@Suite("ReviewExporter")
struct ReviewExporterTests {
    let exporter = ReviewExporter()

    @Test("Build export package from documents")
    func buildPackage() {
        let project = Project(name: "TestApp", categoryId: UUID())
        let doc1 = Document(projectId: project.id, type: .visionStatement, title: "Vision", content: "Build a great app")
        let doc2 = Document(projectId: project.id, type: .technicalBrief, title: "Technical Brief", content: "Use SwiftUI")

        let package = exporter.buildExportPackage(
            project: project,
            documents: [doc1, doc2],
            brainDumpTranscript: "I want to build an app"
        )

        #expect(package.projectId == project.id)
        #expect(package.projectName == "TestApp")
        #expect(package.documents.count == 2)
        #expect(package.brainDumpTranscript == "I want to build an app")
        #expect(package.documents[0].type == .visionStatement)
        #expect(package.documents[1].type == .technicalBrief)
    }

    @Test("Encode and decode export package")
    func roundTrip() throws {
        let project = Project(name: "App", categoryId: UUID())
        let doc = Document(projectId: project.id, type: .visionStatement, title: "Vision", content: "Content here")
        let package = exporter.buildExportPackage(project: project, documents: [doc])

        let data = try exporter.encodePackage(package)
        #expect(!data.isEmpty)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["projectName"] as? String == "App")
    }

    @Test("Decode critique import package")
    func decodeCritiques() throws {
        let projectId = UUID()
        let critiquePackage = CritiqueImportPackage(
            projectId: projectId,
            critiques: [
                ReviewCritique(
                    reviewerName: "Reviewer A",
                    documentType: .visionStatement,
                    concerns: ["Missing user personas"],
                    suggestions: ["Add target user section"],
                    overallAssessment: "Good start but needs more detail"
                )
            ],
            pipelineMetadata: PipelineMetadata(pipelineName: "n8n-review")
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(critiquePackage)

        let decoded = try exporter.decodeCritiques(data)
        #expect(decoded.projectId == projectId)
        #expect(decoded.critiques.count == 1)
        #expect(decoded.critiques[0].reviewerName == "Reviewer A")
        #expect(decoded.critiques[0].concerns == ["Missing user personas"])
        #expect(decoded.pipelineMetadata?.pipelineName == "n8n-review")
    }

    @Test("Build synthesis prompt includes all content")
    func synthesisPrompt() {
        let package = ReviewExportPackage(
            projectId: UUID(),
            projectName: "MyProject",
            documents: [
                ExportedReviewDocument(
                    documentId: UUID(), type: .visionStatement,
                    title: "Vision", content: "Build something great", version: 1
                )
            ],
            brainDumpTranscript: "Initial ideas here"
        )

        let critiques = [
            ReviewCritique(
                reviewerName: "Alice",
                concerns: ["Too vague"],
                suggestions: ["Be more specific"],
                overallAssessment: "Needs work"
            ),
            ReviewCritique(
                reviewerName: "Bob",
                concerns: ["Missing timeline"],
                suggestions: ["Add deadlines"],
                overallAssessment: "Promising"
            )
        ]

        let prompt = exporter.buildSynthesisPrompt(exportPackage: package, critiques: critiques)

        #expect(prompt.contains("MyProject"))
        #expect(prompt.contains("Build something great"))
        #expect(prompt.contains("Initial ideas here"))
        #expect(prompt.contains("Alice"))
        #expect(prompt.contains("Too vague"))
        #expect(prompt.contains("Bob"))
        #expect(prompt.contains("Missing timeline"))
        #expect(prompt.contains("overlapping concerns"))
    }

    @Test("Empty documents export package")
    func emptyDocs() {
        let project = Project(name: "Empty", categoryId: UUID())
        let package = exporter.buildExportPackage(project: project, documents: [])
        #expect(package.documents.isEmpty)
        #expect(package.projectName == "Empty")
    }

    @Test("ReviewCritique identity")
    func critiqueIdentity() {
        let id = UUID()
        let date = Date()
        let a = ReviewCritique(id: id, reviewerName: "A", concerns: [], suggestions: [], overallAssessment: "OK", receivedAt: date)
        let b = ReviewCritique(id: id, reviewerName: "A", concerns: [], suggestions: [], overallAssessment: "OK", receivedAt: date)
        #expect(a == b)
        #expect(a.id == id)
    }

    @Test("PipelineMetadata round-trip")
    func metadataRoundTrip() throws {
        let meta = PipelineMetadata(pipelineName: "test-pipeline", runId: "run-123")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(meta)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PipelineMetadata.self, from: data)
        #expect(decoded.pipelineName == "test-pipeline")
        #expect(decoded.runId == "run-123")
    }
}
