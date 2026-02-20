import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain

// MARK: - Document Test Helper

private let docProjectId = UUID()

@MainActor
func makeDocumentVM() -> (DocumentViewModel, MockDocumentRepository) {
    let repo = MockDocumentRepository()
    let vm = DocumentViewModel(projectId: docProjectId, documentRepo: repo)
    return (vm, repo)
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

    @Test("Save without content change keeps version")
    @MainActor
    func saveKeepsVersion() async {
        let (vm, repo) = makeDocumentVM()
        let doc = Document(projectId: docProjectId, type: .visionStatement, title: "Vision", content: "Same")
        repo.documents = [doc]
        await vm.load()
        vm.select(doc)

        vm.editingTitle = "New Title"
        vm.markEdited()
        await vm.save()

        #expect(vm.selectedDocument?.version == 1) // Title-only change doesn't increment
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
}
