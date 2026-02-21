import Foundation
import PMDomain
import PMData
import PMUtilities
import os

/// ViewModel for the project browser — lists, filters, searches, and manages projects.
@Observable
@MainActor
public final class ProjectBrowserViewModel {
    // MARK: - Published State

    public private(set) var projects: [Project] = []
    public private(set) var categories: [PMDomain.Category] = []
    public private(set) var isLoading = false
    public private(set) var error: String?

    public var searchText: String = "" {
        didSet { Task { await applyFilters() } }
    }

    public var selectedLifecycleFilter: LifecycleFilter = .all {
        didSet { Task { await applyFilters() } }
    }

    public var selectedCategoryId: UUID? = nil {
        didSet { Task { await applyFilters() } }
    }

    public var sortOrder: SortOrder = .recentlyUpdated {
        didSet { applySort() }
    }

    // MARK: - Filtered/sorted output

    public private(set) var filteredProjects: [Project] = []

    // MARK: - Project CRUD State

    public var isShowingCreateSheet = false
    public var isShowingEditSheet = false
    public var isShowingDeleteConfirmation = false
    public var isShowingStateTransition = false

    public var editingProject: Project?
    public var transitionTarget: LifecycleState?
    public var pauseReason: String = ""
    public var abandonmentReflection: String = ""

    // MARK: - Dependencies

    private let projectRepo: ProjectRepositoryProtocol
    private let categoryRepo: CategoryRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol?
    private let documentRepo: DocumentRepositoryProtocol?

    // MARK: - Init

    public init(
        projectRepo: ProjectRepositoryProtocol,
        categoryRepo: CategoryRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol? = nil,
        documentRepo: DocumentRepositoryProtocol? = nil
    ) {
        self.projectRepo = projectRepo
        self.categoryRepo = categoryRepo
        self.taskRepo = taskRepo
        self.documentRepo = documentRepo
    }

    // MARK: - Loading

    public func load() async {
        isLoading = true
        error = nil
        do {
            projects = try await projectRepo.fetchAll()
            categories = try await categoryRepo.fetchAll()
            await applyFilters()
            Log.ui.info("Loaded \(self.projects.count) projects, \(self.categories.count) categories")
        } catch {
            self.error = error.localizedDescription
            Log.ui.error("Failed to load projects: \(error)")
        }
        isLoading = false
    }

    // MARK: - Filtering

    public func applyFilters() async {
        var result = projects

        // Lifecycle filter
        switch selectedLifecycleFilter {
        case .all:
            break
        case .state(let state):
            result = result.filter { $0.lifecycleState == state }
        }

        // Category filter
        if let categoryId = selectedCategoryId {
            result = result.filter { $0.categoryId == categoryId }
        }

        // Cross-entity search: project names + document content
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            var matchingProjectIds = Set(result.filter { $0.name.lowercased().contains(query) }.map(\.id))

            // Search documents (title + content)
            if let documentRepo {
                if let matchingDocs = try? await documentRepo.search(query: query) {
                    matchingProjectIds.formUnion(matchingDocs.map(\.projectId))
                }
            }

            result = result.filter { matchingProjectIds.contains($0.id) }
        }

        filteredProjects = result
        applySort()
    }

    private func applySort() {
        switch sortOrder {
        case .recentlyUpdated:
            filteredProjects.sort { $0.updatedAt > $1.updatedAt }
        case .name:
            filteredProjects.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .created:
            filteredProjects.sort { $0.createdAt > $1.createdAt }
        }
    }

    // MARK: - CRUD

    public func createProject(name: String, categoryId: UUID, definitionOfDone: String?) async {
        do {
            let project = Project(
                name: name,
                categoryId: categoryId,
                definitionOfDone: definitionOfDone
            )
            let errors = Validation.validate(project: project)
            guard errors.isEmpty else {
                self.error = "Validation failed: \(errors)"
                return
            }
            try await projectRepo.save(project)
            Log.ui.info("Created project '\(name)'")
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func updateProject(_ project: Project) async {
        do {
            var updated = project
            updated.updatedAt = Date()
            let errors = Validation.validate(project: updated)
            guard errors.isEmpty else {
                self.error = "Validation failed: \(errors)"
                return
            }
            try await projectRepo.save(updated)
            Log.ui.info("Updated project '\(project.name)'")
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func deleteProject(_ project: Project) async {
        do {
            try await projectRepo.delete(id: project.id)
            Log.ui.info("Deleted project '\(project.name)'")
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Lifecycle Transitions

    public func transitionProject(_ project: Project, to newState: LifecycleState) async {
        guard Validation.canTransition(from: project.lifecycleState, to: newState) else {
            error = "Cannot transition from \(project.lifecycleState.rawValue) to \(newState.rawValue)"
            return
        }

        var updated = project
        updated.lifecycleState = newState
        updated.updatedAt = Date()

        // Clear focus slot when leaving focused state
        if newState != .focused {
            updated.focusSlotIndex = nil
        }

        // Set pause reason or abandonment reflection
        if newState == .paused {
            updated.pauseReason = pauseReason.isEmpty ? nil : pauseReason
        }
        if newState == .abandoned {
            updated.abandonmentReflection = abandonmentReflection.isEmpty ? nil : abandonmentReflection
        }

        // Clear pause/abandonment fields when transitioning away
        if newState != .paused {
            updated.pauseReason = nil
        }
        if newState != .abandoned {
            updated.abandonmentReflection = nil
        }

        await updateProject(updated)
        pauseReason = ""
        abandonmentReflection = ""
    }

    /// Returns valid lifecycle transitions for a given project.
    public func validTransitions(for project: Project) -> Set<LifecycleState> {
        Validation.validTransitions(from: project.lifecycleState)
    }

    // MARK: - Helpers

    public func categoryName(for project: Project) -> String {
        categories.first { $0.id == project.categoryId }?.name ?? "Unknown"
    }
}

// MARK: - Supporting Types

public enum LifecycleFilter: Equatable, Hashable, Sendable {
    case all
    case state(LifecycleState)

    public var label: String {
        switch self {
        case .all: "All Projects"
        case .state(let s): s.rawValue.capitalized
        }
    }
}

public enum SortOrder: String, CaseIterable, Sendable {
    case recentlyUpdated = "Recently Updated"
    case name = "Name"
    case created = "Date Created"
}
