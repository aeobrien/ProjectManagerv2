import Foundation
import PMDomain
import PMUtilities
import os

/// ViewModel for managing project documents.
@Observable
@MainActor
public final class DocumentViewModel {
    // MARK: - State

    public private(set) var documents: [Document] = []
    public private(set) var isLoading = false
    public private(set) var error: String?

    /// The currently selected document for editing.
    public var selectedDocument: Document?

    /// Editing state for the selected document.
    public var editingContent: String = ""
    public var editingTitle: String = ""
    public private(set) var hasUnsavedChanges = false

    // MARK: - Dependencies

    private let projectId: UUID
    private let documentRepo: DocumentRepositoryProtocol

    // MARK: - Init

    public init(projectId: UUID, documentRepo: DocumentRepositoryProtocol) {
        self.projectId = projectId
        self.documentRepo = documentRepo
    }

    // MARK: - Loading

    public func load() async {
        isLoading = true
        do {
            documents = try await documentRepo.fetchAll(forProject: projectId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Selection

    /// Select a document for editing.
    public func select(_ document: Document) {
        selectedDocument = document
        editingContent = document.content
        editingTitle = document.title
        hasUnsavedChanges = false
    }

    /// Mark content as changed.
    public func markEdited() {
        guard let selected = selectedDocument else { return }
        hasUnsavedChanges = editingContent != selected.content || editingTitle != selected.title
    }

    // MARK: - Save

    /// Save the current editing state.
    public func save() async {
        guard var doc = selectedDocument else { return }

        let newContent = editingContent
        let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !newTitle.isEmpty else {
            error = "Document title cannot be empty."
            return
        }

        // Increment version if content changed
        if newContent != doc.content {
            doc.version += 1
        }

        doc.title = newTitle
        doc.content = newContent
        doc.updatedAt = Date()

        do {
            try await documentRepo.save(doc)
            selectedDocument = doc

            // Update in list
            if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
                documents[idx] = doc
            }

            hasUnsavedChanges = false
            Log.ui.info("Saved document '\(newTitle)' v\(doc.version)")
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Create

    /// Create a new document.
    public func createDocument(type: DocumentType, title: String) async {
        let doc = Document(projectId: projectId, type: type, title: title)
        do {
            try await documentRepo.save(doc)
            documents.append(doc)
            select(doc)
            Log.ui.info("Created document '\(title)'")
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Delete

    /// Delete a document.
    public func deleteDocument(_ document: Document) async {
        do {
            try await documentRepo.delete(id: document.id)
            documents.removeAll { $0.id == document.id }
            if selectedDocument?.id == document.id {
                selectedDocument = nil
                editingContent = ""
                editingTitle = ""
                hasUnsavedChanges = false
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Computed

    public func documents(ofType type: DocumentType) -> [Document] {
        documents.filter { $0.type == type }
    }
}
