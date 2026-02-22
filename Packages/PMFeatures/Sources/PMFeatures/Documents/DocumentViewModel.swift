import Foundation
import PMData
import PMDomain
import PMServices
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

    /// Version history for the currently selected document.
    public private(set) var versionHistory: [DocumentVersion] = []

    // MARK: - Dependencies

    private let projectId: UUID
    private let documentRepo: DocumentRepositoryProtocol
    private let versionRepo: DocumentVersionRepositoryProtocol?
    private let knowledgeBaseManager: KnowledgeBaseManager?

    /// Optional sync manager for tracking document changes.
    public var syncManager: SyncManager?

    // MARK: - Init

    public init(
        projectId: UUID,
        documentRepo: DocumentRepositoryProtocol,
        versionRepo: DocumentVersionRepositoryProtocol? = nil,
        knowledgeBaseManager: KnowledgeBaseManager? = nil
    ) {
        self.projectId = projectId
        self.documentRepo = documentRepo
        self.versionRepo = versionRepo
        self.knowledgeBaseManager = knowledgeBaseManager
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

    /// Select a document for editing. Auto-saves the previous document if it has changes.
    public func select(_ document: Document) {
        // Capture and save previous document synchronously before switching
        if hasUnsavedChanges, var oldDoc = selectedDocument {
            let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newTitle.isEmpty {
                oldDoc.title = newTitle
                oldDoc.content = editingContent
                oldDoc.updatedAt = Date()
                let docToSave = oldDoc
                // Update in list immediately
                if let idx = documents.firstIndex(where: { $0.id == docToSave.id }) {
                    documents[idx] = docToSave
                }
                Task {
                    do {
                        try await documentRepo.save(docToSave)
                        Log.ui.debug("Auto-saved document '\(newTitle)' (no version bump)")
                    } catch {
                        Log.ui.error("Auto-save failed: \(error)")
                    }
                }
            }
        }
        selectedDocument = document
        editingContent = document.content
        editingTitle = document.title
        hasUnsavedChanges = false

        // Load version history
        Task {
            await loadVersionHistory(for: document.id)
        }
    }

    /// Deselect the current document (auto-saves if needed).
    public func deselect() {
        if hasUnsavedChanges, var oldDoc = selectedDocument {
            let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newTitle.isEmpty {
                oldDoc.title = newTitle
                oldDoc.content = editingContent
                oldDoc.updatedAt = Date()
                let docToSave = oldDoc
                if let idx = documents.firstIndex(where: { $0.id == docToSave.id }) {
                    documents[idx] = docToSave
                }
                Task {
                    do {
                        try await documentRepo.save(docToSave)
                        Log.ui.debug("Auto-saved document '\(newTitle)' on deselect (no version bump)")
                    } catch {
                        Log.ui.error("Auto-save on deselect failed: \(error)")
                    }
                }
            }
        }
        selectedDocument = nil
        editingContent = ""
        editingTitle = ""
        hasUnsavedChanges = false
        versionHistory = []
    }

    /// Mark content as changed.
    public func markEdited() {
        guard let selected = selectedDocument else { return }
        hasUnsavedChanges = editingContent != selected.content || editingTitle != selected.title
    }

    // MARK: - Save

    /// Save the current editing state, bump the version number, and snapshot the previous version.
    public func save() async {
        guard var doc = selectedDocument else { return }

        let newContent = editingContent
        let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !newTitle.isEmpty else {
            error = "Document title cannot be empty."
            return
        }

        // Snapshot the current (pre-save) version before overwriting
        let snapshot = DocumentVersion(
            documentId: doc.id,
            version: doc.version,
            title: doc.title,
            content: doc.content,
            savedAt: doc.updatedAt
        )

        // Always increment version on explicit save
        doc.version += 1
        doc.title = newTitle
        doc.content = newContent
        doc.updatedAt = Date()

        do {
            // Save the version snapshot
            if let versionRepo {
                try await versionRepo.save(snapshot)
            }

            try await documentRepo.save(doc)
            selectedDocument = doc

            // Update in list
            if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
                documents[idx] = doc
            }

            hasUnsavedChanges = false

            // Reload version history
            await loadVersionHistory(for: doc.id)

            syncManager?.trackChange(entityType: .document, entityId: doc.id, changeType: .update)

            // Index document content in knowledge base
            if let kb = knowledgeBaseManager {
                let docToIndex = doc
                Task.detached {
                    do {
                        try await kb.indexDocument(docToIndex)
                    } catch {
                        Log.ai.error("Failed to index document in KB: \(error)")
                    }
                }
            }

            Log.ui.info("Saved document '\(newTitle)' v\(doc.version)")
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Version History

    /// Load version history for a document.
    public func loadVersionHistory(for documentId: UUID) async {
        guard let versionRepo else {
            versionHistory = []
            return
        }
        do {
            versionHistory = try await versionRepo.fetchAll(forDocument: documentId)
        } catch {
            Log.ui.error("Failed to load version history: \(error)")
            versionHistory = []
        }
    }

    /// Restore a document to a previous version.
    public func restoreVersion(_ version: DocumentVersion) {
        guard selectedDocument != nil else { return }
        editingTitle = version.title
        editingContent = version.content
        markEdited()
    }

    // MARK: - Create

    /// Create a new document.
    public func createDocument(type: DocumentType, title: String) async {
        let doc = Document(projectId: projectId, type: type, title: title)
        do {
            try await documentRepo.save(doc)
            syncManager?.trackChange(entityType: .document, entityId: doc.id, changeType: .create)
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
            syncManager?.trackChange(entityType: .document, entityId: document.id, changeType: .delete)
            documents.removeAll { $0.id == document.id }
            if selectedDocument?.id == document.id {
                selectedDocument = nil
                editingContent = ""
                editingTitle = ""
                hasUnsavedChanges = false
                versionHistory = []
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
