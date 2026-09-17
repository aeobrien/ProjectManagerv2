import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain
@testable import PMServices

@Suite("AdversarialReviewManager")
struct AdversarialReviewManagerTests {

    @MainActor
    private func makeManager(llmClient: MockLLMClient = MockLLMClient()) -> (
        AdversarialReviewManager, MockDocumentRepository, MockLLMClient
    ) {
        let docRepo = MockDocumentRepository()
        let manager = AdversarialReviewManager(
            documentRepo: docRepo,
            llmClient: llmClient
        )
        return (manager, docRepo, llmClient)
    }

    @Test("Initial state")
    @MainActor
    func initialState() {
        let (manager, _, _) = makeManager()
        #expect(manager.step == .idle)
        #expect(manager.isLoading == false)
        #expect(manager.error == nil)
        #expect(manager.exportPackage == nil)
        #expect(manager.critiques.isEmpty)
        #expect(manager.synthesisResponse == nil)
        #expect(manager.revisedDocuments.isEmpty)
        #expect(manager.messages.isEmpty)
    }

    @Test("Export documents for review")
    @MainActor
    func exportDocuments() async {
        let (manager, docRepo, _) = makeManager()
        let project = Project(name: "App", categoryId: UUID())
        let doc = Document(projectId: project.id, type: .visionStatement, title: "Vision", content: "Build it")
        docRepo.documents = [doc]

        await manager.exportForReview(project: project, brainDumpTranscript: "My ideas")

        #expect(manager.step == .awaitingCritiques)
        #expect(manager.exportPackage != nil)
        #expect(manager.exportPackage?.documents.count == 1)
        #expect(manager.exportPackage?.brainDumpTranscript == "My ideas")
        #expect(manager.error == nil)
    }

    @Test("Export fails with no documents")
    @MainActor
    func exportNoDocuments() async {
        let (manager, _, _) = makeManager()
        let project = Project(name: "Empty", categoryId: UUID())

        await manager.exportForReview(project: project)

        #expect(manager.error != nil)
        #expect(manager.step == .idle)
    }

    @Test("Import critiques from data")
    @MainActor
    func importCritiquesData() async {
        let (manager, docRepo, _) = makeManager()
        let project = Project(name: "App", categoryId: UUID())
        docRepo.documents = [Document(projectId: project.id, type: .visionStatement, title: "V", content: "C")]
        await manager.exportForReview(project: project)

        let critiquePackage = CritiqueImportPackage(
            projectId: project.id,
            critiques: [
                ReviewCritique(
                    reviewerName: "Reviewer 1",
                    concerns: ["Issue A"],
                    suggestions: ["Fix A"],
                    overallAssessment: "Decent"
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(critiquePackage)

        manager.importCritiques(from: data)

        #expect(manager.step == .critiquesReceived)
        #expect(manager.critiques.count == 1)
        #expect(manager.critiques[0].reviewerName == "Reviewer 1")
    }

    @Test("Import critiques directly")
    @MainActor
    func importCritiquesDirect() {
        let (manager, _, _) = makeManager()

        let critiques = [
            ReviewCritique(reviewerName: "A", concerns: ["C1"], suggestions: [], overallAssessment: "OK"),
            ReviewCritique(reviewerName: "B", concerns: ["C2"], suggestions: ["S1"], overallAssessment: "Good"),
        ]
        manager.importCritiques(critiques)

        #expect(manager.step == .critiquesReceived)
        #expect(manager.critiques.count == 2)
        #expect(manager.totalConcernCount == 2)
        #expect(manager.totalSuggestionCount == 1)
    }

    @Test("Import empty critiques shows error")
    @MainActor
    func importEmptyCritiques() {
        let (manager, _, _) = makeManager()
        manager.importCritiques([])
        #expect(manager.error != nil)
        #expect(manager.step == .idle)
    }

    @Test("Synthesise critiques with AI")
    @MainActor
    func synthesise() async {
        let client = MockLLMClient()
        client.responseText = "Synthesis: Here are the revised documents."
        let (manager, docRepo, _) = makeManager(llmClient: client)

        let project = Project(name: "App", categoryId: UUID())
        docRepo.documents = [Document(projectId: project.id, type: .visionStatement, title: "V", content: "Content")]
        await manager.exportForReview(project: project)

        manager.importCritiques([
            ReviewCritique(reviewerName: "R1", concerns: ["Issue"], suggestions: ["Fix"], overallAssessment: "OK")
        ])

        await manager.synthesise()

        #expect(manager.step == .reviewingRevisions)
        #expect(manager.synthesisResponse != nil)
        #expect(manager.synthesisResponse?.contains("revised") == true)
        #expect(manager.messages.count == 2) // user + assistant
        #expect(manager.error == nil)
    }

    @Test("Synthesise without export fails")
    @MainActor
    func synthesiseNoExport() async {
        let (manager, _, _) = makeManager()
        await manager.synthesise()
        #expect(manager.error != nil)
    }

    @Test("Synthesise without critiques fails")
    @MainActor
    func synthesiseNoCritiques() async {
        let (manager, docRepo, _) = makeManager()
        let project = Project(name: "App", categoryId: UUID())
        docRepo.documents = [Document(projectId: project.id, type: .visionStatement, title: "V", content: "C")]
        await manager.exportForReview(project: project)

        await manager.synthesise()
        #expect(manager.error != nil)
    }

    @Test("Send follow-up during review")
    @MainActor
    func followUp() async {
        let client = MockLLMClient()
        client.responseText = "Synthesis result"
        let (manager, docRepo, _) = makeManager(llmClient: client)

        let project = Project(name: "App", categoryId: UUID())
        docRepo.documents = [Document(projectId: project.id, type: .visionStatement, title: "V", content: "C")]
        await manager.exportForReview(project: project)
        manager.importCritiques([
            ReviewCritique(reviewerName: "R", concerns: ["X"], suggestions: [], overallAssessment: "OK")
        ])
        await manager.synthesise()

        client.responseText = "Updated synthesis"
        await manager.sendFollowUp("Can you elaborate on concern X?")

        #expect(manager.messages.count == 4) // user, assistant, user, assistant
        #expect(manager.synthesisResponse == "Updated synthesis")
    }

    @Test("Empty follow-up ignored")
    @MainActor
    func emptyFollowUp() async {
        let (manager, _, _) = makeManager()
        await manager.sendFollowUp("   ")
        #expect(manager.messages.isEmpty)
    }

    @Test("Approve revisions saves to repo")
    @MainActor
    func approveRevisions() async {
        let (manager, docRepo, _) = makeManager()

        let projectId = UUID()
        let doc = Document(projectId: projectId, type: .visionStatement, title: "Vision", content: "Original")
        docRepo.documents = [doc]

        let revised = RevisedDocument(
            originalDocumentId: doc.id,
            type: .visionStatement,
            title: "Vision",
            revisedContent: "Improved content",
            changesSummary: "Added detail"
        )
        manager.addRevisedDocument(revised)

        await manager.approveRevisions()

        #expect(manager.step == .completed)
        let saved = docRepo.documents.first { $0.id == doc.id }
        #expect(saved?.content == "Improved content")
        #expect(saved?.version == 2)
    }

    @Test("Approve with no revisions shows error")
    @MainActor
    func approveEmpty() async {
        let (manager, _, _) = makeManager()
        await manager.approveRevisions()
        #expect(manager.error != nil)
    }

    @Test("Reset clears all state")
    @MainActor
    func resetState() async {
        let client = MockLLMClient()
        client.responseText = "Response"
        let (manager, docRepo, _) = makeManager(llmClient: client)

        let project = Project(name: "App", categoryId: UUID())
        docRepo.documents = [Document(projectId: project.id, type: .visionStatement, title: "V", content: "C")]
        await manager.exportForReview(project: project)
        manager.importCritiques([
            ReviewCritique(reviewerName: "R", concerns: [], suggestions: [], overallAssessment: "OK")
        ])

        manager.reset()

        #expect(manager.step == .idle)
        #expect(manager.exportPackage == nil)
        #expect(manager.critiques.isEmpty)
        #expect(manager.synthesisResponse == nil)
        #expect(manager.messages.isEmpty)
        #expect(manager.error == nil)
    }

    @Test("Computed concern counts")
    @MainActor
    func concernCounts() {
        let (manager, _, _) = makeManager()

        manager.importCritiques([
            ReviewCritique(reviewerName: "A", concerns: ["slow", "buggy"], suggestions: ["optimize"], overallAssessment: "OK"),
            ReviewCritique(reviewerName: "B", concerns: ["slow", "unclear"], suggestions: ["docs", "tests"], overallAssessment: "OK"),
        ])

        #expect(manager.totalConcernCount == 4)
        #expect(manager.totalSuggestionCount == 3)
        #expect(manager.overlappingConcernCount == 1) // "slow" appears twice
    }

    @Test("AdversarialReviewStep equality")
    func stepEquality() {
        #expect(AdversarialReviewStep.idle == AdversarialReviewStep.idle)
        #expect(AdversarialReviewStep.idle != AdversarialReviewStep.exporting)
    }

    @Test("RevisedDocument equality")
    func revisedDocEquality() {
        let id = UUID()
        let docId = UUID()
        let a = RevisedDocument(id: id, originalDocumentId: docId, type: .visionStatement, title: "T", revisedContent: "C", changesSummary: "S")
        let b = RevisedDocument(id: id, originalDocumentId: docId, type: .visionStatement, title: "T", revisedContent: "C", changesSummary: "S")
        #expect(a == b)
    }
}
