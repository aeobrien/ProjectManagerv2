import Foundation
import PMData
import PMDomain
import PMUtilities
import os

/// ViewModel for Quick Capture — creates Idea-state project stubs from text input.
@Observable
@MainActor
public final class QuickCaptureViewModel {
    // MARK: - State

    public var transcript: String = ""
    public var title: String = ""
    public var selectedCategoryId: UUID?
    public private(set) var categories: [PMDomain.Category] = []
    public private(set) var isSaving = false
    public private(set) var error: String?
    public private(set) var didSave = false

    // MARK: - Dependencies

    private let projectRepo: ProjectRepositoryProtocol
    private let categoryRepo: CategoryRepositoryProtocol

    /// Optional sync manager for tracking changes.
    public var syncManager: SyncManager?

    // MARK: - Init

    public init(projectRepo: ProjectRepositoryProtocol, categoryRepo: CategoryRepositoryProtocol) {
        self.projectRepo = projectRepo
        self.categoryRepo = categoryRepo
    }

    // MARK: - Loading

    public func loadCategories() async {
        do {
            categories = try await categoryRepo.fetchAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Save

    /// Creates an Idea-state project from the current input.
    public func save() async {
        let effectiveTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !effectiveTranscript.isEmpty else {
            error = "Please enter a description."
            return
        }

        // Use first line of transcript as title if none provided
        let projectName: String
        if effectiveTitle.isEmpty {
            projectName = String(effectiveTranscript.prefix(100))
                .components(separatedBy: .newlines).first ?? effectiveTranscript
        } else {
            projectName = effectiveTitle
        }

        // Use first category if none selected
        let categoryId = selectedCategoryId ?? categories.first?.id
        guard let categoryId else {
            error = "No categories available."
            return
        }

        isSaving = true
        do {
            let project = Project(
                name: projectName,
                categoryId: categoryId,
                lifecycleState: .idea,
                quickCaptureTranscript: effectiveTranscript
            )
            try await projectRepo.save(project)
            syncManager?.trackChange(entityType: .project, entityId: project.id, changeType: .create)
            didSave = true
            Log.ui.info("Quick captured project '\(projectName)'")
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    /// Resets the form for a new capture.
    public func reset() {
        transcript = ""
        title = ""
        selectedCategoryId = nil
        error = nil
        didSave = false
    }

    /// Whether the save button should be enabled.
    public var canSave: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }
}
