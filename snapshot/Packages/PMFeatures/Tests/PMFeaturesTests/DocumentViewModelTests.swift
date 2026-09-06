import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain

// MARK: - Document Test Helpers

private let docProjectId = UUID()

@MainActor
func makeDocumentVM() -> (DocumentViewModel, MockDocumentRepository) {
    let repo = MockDocumentRepository()
    let vm = DocumentViewModel(projectId: docProjectId, documentRepo: repo)
    return (vm, repo)
}

@MainActor
func makeDocumentVMWithVersions() -> (DocumentViewModel, MockDocumentRepository, MockDocumentVersionRepository) {
    let repo = MockDocumentRepository()
    let versionRepo = MockDocumentVersionRepository()
    let vm = DocumentViewModel(projectId: docProjectId, documentRepo: repo, versionRepo: versionRepo)
    return (vm, repo, versionRepo)
}

// MARK: - Tests

@Suite("DocumentViewModel")
struct DocumentViewModelTests {

    @Test("Initial state")
    @MainActor
    func initialState() {
        let (vm, _) = makeDocumentVM()
        #expect(vm.documents.isEmpty)
        #expect(vm.selectedDocument == nil)
        #expect(vm.isLoading == false)
        #expect(vm.hasUnsavedChanges == false)
        #expect(vm.versionHistory.isEmpty)
    }

    @Test("Load fetches documents")
    @MainActor
    func loadDocuments() async {
        let (vm, repo) = makeDocumentVM()
        repo.documents = [
            Document(projectId: docProjectId, type: .visionStatement, title: "Vision"),
            Document(projectId: docProjectId, type: .technicalBrief, title: "Brief")
        ]

        await vm.load()

        #expect(vm.documents.count == 2)
        #expect(vm.isLoading == false)
    }

    @Test("Select document sets editing state")
    @MainActor
    func selectDocument() async {
        let (vm, repo) = makeDocumentVM()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision", content: "Hello")
        repo.documents = [doc]
        await vm.load()

        vm.select(doc)

        #expect(vm.selectedDocument?.id == doc.id)
        #expect(vm.editingContent == "Hello")
        #expect(vm.editingTitle == "Vision")
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("Mark edited detects changes")
    @MainActor
    func markEdited() async {
        let (vm, repo) = makeDocumentVM()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision", content: "Original")
        repo.documents = [doc]
        await vm.load()
        vm.select(doc)

        vm.editingContent = "Modified"
        vm.markEdited()

        #expect(vm.hasUnsavedChanges == true)
    }

    @Test("Save increments version on content change")
    @MainActor
    func saveIncrementsVersion() async {
        let (vm, repo) = makeDocumentVM()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision", content: "V1")
        repo.documents = [doc]
        await vm.load()
        vm.select(doc)

        vm.editingContent = "V2"
        vm.markEdited()
        await vm.save()

        #expect(vm.selectedDocument?.version == 2)
        #expect(vm.selectedDocument?.content == "V2")
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("Explicit save always bumps version")
    @MainActor
    func saveBumpsVersion() async {
        let (vm, repo) = makeDocumentVM()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision", content: "Same")
        repo.documents = [doc]
        await vm.load()
        vm.select(doc)

        vm.editingTitle = "New Title"
        vm.markEdited()
        await vm.save()

        #expect(vm.selectedDocument?.version == 2) // Explicit save always bumps version
        #expect(vm.selectedDocument?.title == "New Title")
    }

    @Test("Save fails with empty title")
    @MainActor
    func saveEmptyTitle() async {
        let (vm, repo) = makeDocumentVM()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision", content: "Content")
        repo.documents = [doc]
        await vm.load()
        vm.select(doc)

        vm.editingTitle = "  "
        await vm.save()

        #expect(vm.error != nil)
    }

    @Test("Create document adds to list")
    @MainActor
    func createDocument() async {
        let (vm, _) = makeDocumentVM()

        await vm.createDocument(type: .technicalBrief, title: "Tech Brief")

        #expect(vm.documents.count == 1)
        #expect(vm.documents.first?.type == .technicalBrief)
        #expect(vm.selectedDocument != nil)
    }

    @Test("Delete document removes from list")
    @MainActor
    func deleteDocument() async {
        let (vm, repo) = makeDocumentVM()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision")
        repo.documents = [doc]
        await vm.load()
        vm.select(doc)

        await vm.deleteDocument(doc)

        #expect(vm.documents.isEmpty)
        #expect(vm.selectedDocument == nil)
    }

    @Test("Filter documents by type")
    @MainActor
    func filterByType() async {
        let (vm, repo) = makeDocumentVM()
        repo.documents = [
            Document(projectId: docProjectId, type: .visionStatement, title: "Vision"),
            Document(projectId: docProjectId, type: .technicalBrief, title: "Brief"),
            Document(projectId: docProjectId, type: .other, title: "Notes")
        ]
        await vm.load()

        #expect(vm.documents(ofType: .visionStatement).count == 1)
        #expect(vm.documents(ofType: .technicalBrief).count == 1)
        #expect(vm.documents(ofType: .other).count == 1)
    }

    // MARK: - Version History Tests

    @Test("Save creates version snapshot")
    @MainActor
    func saveCreatesVersionSnapshot() async {
        let (vm, repo, versionRepo) = makeDocumentVMWithVersions()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision", content: "V1 content")
        repo.documents = [doc]
        await vm.load()
        vm.select(doc)

        vm.editingContent = "V2 content"
        vm.markEdited()
        await vm.save()

        // Should have one version snapshot (the pre-save v1)
        #expect(versionRepo.versions.count == 1)
        #expect(versionRepo.versions[0].version == 1)
        #expect(versionRepo.versions[0].title == "Vision")
        #expect(versionRepo.versions[0].content == "V1 content")
        #expect(versionRepo.versions[0].documentId == doc.id)
    }

    @Test("Multiple saves create multiple snapshots")
    @MainActor
    func multipleSavesCreateSnapshots() async {
        let (vm, repo, versionRepo) = makeDocumentVMWithVersions()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision", content: "V1")
        repo.documents = [doc]
        await vm.load()
        vm.select(doc)

        // Save v1 → v2
        vm.editingContent = "V2"
        vm.markEdited()
        await vm.save()

        // Save v2 → v3
        vm.editingContent = "V3"
        vm.markEdited()
        await vm.save()

        #expect(versionRepo.versions.count == 2)
        #expect(versionRepo.versions[0].version == 1)
        #expect(versionRepo.versions[0].content == "V1")
        #expect(versionRepo.versions[1].version == 2)
        #expect(versionRepo.versions[1].content == "V2")
    }

    @Test("Version history loads on select")
    @MainActor
    func versionHistoryLoadsOnSelect() async {
        let (vm, repo, versionRepo) = makeDocumentVMWithVersions()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision", content: "Current")
        repo.documents = [doc]

        // Pre-populate version history
        versionRepo.versions = [
            DocumentVersion(documentId: doc.id, version: 1, title: "Vision", content: "First draft"),
            DocumentVersion(documentId: doc.id, version: 2, title: "Vision", content: "Second draft")
        ]

        await vm.load()
        vm.select(doc)

        // Give the async Task time to load version history
        try? await Task.sleep(for: .milliseconds(50))

        #expect(vm.versionHistory.count == 2)
        // Sorted descending by version
        #expect(vm.versionHistory[0].version == 2)
        #expect(vm.versionHistory[1].version == 1)
    }

    @Test("Restore version populates editing fields")
    @MainActor
    func restoreVersion() async {
        let (vm, repo, _) = makeDocumentVMWithVersions()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Current Title", content: "Current content", version: 3)
        repo.documents = [doc]
        await vm.load()
        vm.select(doc)

        let oldVersion = DocumentVersion(documentId: doc.id, version: 1, title: "Old Title", content: "Old content")
        vm.restoreVersion(oldVersion)

        #expect(vm.editingTitle == "Old Title")
        #expect(vm.editingContent == "Old content")
        #expect(vm.hasUnsavedChanges == true)
    }

    @Test("Deselect clears version history")
    @MainActor
    func deselectClearsVersionHistory() async {
        let (vm, repo, versionRepo) = makeDocumentVMWithVersions()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision", content: "Content")
        repo.documents = [doc]
        versionRepo.versions = [
            DocumentVersion(documentId: doc.id, version: 1, title: "Vision", content: "Old")
        ]
        await vm.load()
        vm.select(doc)
        try? await Task.sleep(for: .milliseconds(50))

        vm.deselect()

        #expect(vm.selectedDocument == nil)
        #expect(vm.versionHistory.isEmpty)
    }

    @Test("No version repo still works (graceful nil)")
    @MainActor
    func noVersionRepoWorks() async {
        let (vm, repo) = makeDocumentVM()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision", content: "V1")
        repo.documents = [doc]
        await vm.load()
        vm.select(doc)

        vm.editingContent = "V2"
        vm.markEdited()
        await vm.save()

        // Should still save fine, just no version history
        #expect(vm.selectedDocument?.version == 2)
        #expect(vm.versionHistory.isEmpty)
    }
}
