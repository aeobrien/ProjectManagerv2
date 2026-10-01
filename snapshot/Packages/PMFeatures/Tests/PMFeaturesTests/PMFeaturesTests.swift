import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain

// MARK: - Shared Error

enum MockError: Error { case mock }

// MARK: - Mock Repositories

final class MockProjectRepository: ProjectRepositoryProtocol, @unchecked Sendable {
    var projects: [Project] = []
    var savedProjects: [Project] = []
    var deletedIds: [UUID] = []

    func fetchAll() async throws -> [Project] { projects }
    func fetch(id: UUID) async throws -> Project? { projects.first { $0.id == id } }
    func fetchByLifecycleState(_ state: LifecycleState) async throws -> [Project] {
        projects.filter { $0.lifecycleState == state }
    }
    func fetchByCategory(_ categoryId: UUID) async throws -> [Project] {
        projects.filter { $0.categoryId == categoryId }
    }
    func fetchFocused() async throws -> [Project] {
        projects.filter { $0.lifecycleState == .focused }.sorted { ($0.focusSlotIndex ?? 0) < ($1.focusSlotIndex ?? 0) }
    }
    func save(_ project: Project) async throws {
        savedProjects.append(project)
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        } else {
            projects.append(project)
        }
    }
    func delete(id: UUID) async throws {
        deletedIds.append(id)
        projects.removeAll { $0.id == id }
    }
    func search(query: String) async throws -> [Project] {
        projects.filter { $0.name.lowercased().contains(query.lowercased()) }
    }
}

final class MockCategoryRepository: CategoryRepositoryProtocol, @unchecked Sendable {
    var categories: [PMDomain.Category] = []
    var shouldThrow = false

    func fetchAll() async throws -> [PMDomain.Category] {
        if shouldThrow { throw MockError.mock }
        return categories
    }
    func fetch(id: UUID) async throws -> PMDomain.Category? { categories.first { $0.id == id } }
    func save(_ category: PMDomain.Category) async throws {
        if let idx = categories.firstIndex(where: { $0.id == category.id }) {
            categories[idx] = category
        } else {
            categories.append(category)
        }
    }
    func delete(id: UUID) async throws {
        categories.removeAll { $0.id == id }
    }
    func seedBuiltInCategories() async throws {
        categories = PMDomain.Category.builtInCategories
    }
}

// MARK: - Test Helpers

let testCategoryId = UUID()
let testCategory = PMDomain.Category(id: testCategoryId, name: "Software", isBuiltIn: true, sortOrder: 0)
let testCategory2 = PMDomain.Category(name: "Music", isBuiltIn: true, sortOrder: 1)

@MainActor
func makeViewModel() -> (ProjectBrowserViewModel, MockProjectRepository, MockCategoryRepository) {
    let projectRepo = MockProjectRepository()
    let categoryRepo = MockCategoryRepository()
    categoryRepo.categories = [testCategory, testCategory2]
    let vm = ProjectBrowserViewModel(projectRepo: projectRepo, categoryRepo: categoryRepo)
    return (vm, projectRepo, categoryRepo)
}

// MARK: - ViewModel Tests

@Suite("ProjectBrowserViewModel")
struct ProjectBrowserViewModelTests {

    @Test("Load populates projects and categories")
    @MainActor
    func loadPopulates() async {
        let (vm, projectRepo, _) = makeViewModel()
        let p = Project(name: "Test", categoryId: testCategoryId)
        projectRepo.projects = [p]

        await vm.load()

        #expect(vm.projects.count == 1)
        #expect(vm.categories.count == 2)
        #expect(vm.filteredProjects.count == 1)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @Test("Filter by lifecycle state")
    @MainActor
    func filterByState() async {
        let (vm, projectRepo, _) = makeViewModel()
        projectRepo.projects = [
            Project(name: "Focused", categoryId: testCategoryId, lifecycleState: .focused, focusSlotIndex: 0),
            Project(name: "Idea", categoryId: testCategoryId, lifecycleState: .idea),
            Project(name: "Queued", categoryId: testCategoryId, lifecycleState: .queued),
        ]
        await vm.load()

        vm.selectedLifecycleFilter = .state(.focused)
        // Allow the didSet Task to run
        try? await Task.sleep(for: .milliseconds(50))

        #expect(vm.filteredProjects.count == 1)
        #expect(vm.filteredProjects[0].name == "Focused")
    }

    @Test("Filter by category")
    @MainActor
    func filterByCategory() async {
        let (vm, projectRepo, _) = makeViewModel()
        projectRepo.projects = [
            Project(name: "P1", categoryId: testCategoryId),
            Project(name: "P2", categoryId: testCategory2.id),
        ]
        await vm.load()

        vm.selectedCategoryId = testCategoryId
        try? await Task.sleep(for: .milliseconds(50))

        #expect(vm.filteredProjects.count == 1)
        #expect(vm.filteredProjects[0].name == "P1")
    }

    @Test("Search filters by name")
    @MainActor
    func searchFilters() async {
        let (vm, projectRepo, _) = makeViewModel()
        projectRepo.projects = [
            Project(name: "Alpha", categoryId: testCategoryId),
            Project(name: "Beta", categoryId: testCategoryId),
            Project(name: "Alphabet", categoryId: testCategoryId),
        ]
        await vm.load()

        vm.searchText = "alph"
        try? await Task.sleep(for: .milliseconds(50))

        #expect(vm.filteredProjects.count == 2)
        #expect(vm.filteredProjects.allSatisfy { $0.name.lowercased().contains("alph") })
    }

    @Test("Sort by name")
    @MainActor
    func sortByName() async {
        let (vm, projectRepo, _) = makeViewModel()
        projectRepo.projects = [
            Project(name: "Zebra", categoryId: testCategoryId),
            Project(name: "Apple", categoryId: testCategoryId),
            Project(name: "Mango", categoryId: testCategoryId),
        ]
        await vm.load()

        vm.sortOrder = .name
        #expect(vm.filteredProjects[0].name == "Apple")
        #expect(vm.filteredProjects[1].name == "Mango")
        #expect(vm.filteredProjects[2].name == "Zebra")
    }

    @Test("Create project adds to repo and reloads")
    @MainActor
    func createProject() async {
        let (vm, projectRepo, _) = makeViewModel()
        await vm.load()

        await vm.createProject(name: "New Project", categoryId: testCategoryId, definitionOfDone: "Ship it")

        #expect(projectRepo.savedProjects.count == 1)
        #expect(projectRepo.savedProjects[0].name == "New Project")
        #expect(projectRepo.savedProjects[0].definitionOfDone == "Ship it")
        #expect(vm.projects.count == 1)
    }

    @Test("Create project with empty name sets error")
    @MainActor
    func createEmptyName() async {
        let (vm, _, _) = makeViewModel()
        await vm.load()

        await vm.createProject(name: "   ", categoryId: testCategoryId, definitionOfDone: nil)

        #expect(vm.error != nil)
        #expect(vm.projects.count == 0)
    }

    @Test("Update project saves and reloads")
    @MainActor
    func updateProject() async {
        let (vm, projectRepo, _) = makeViewModel()
        let p = Project(name: "Original", categoryId: testCategoryId)
        projectRepo.projects = [p]
        await vm.load()

        var updated = p
        updated.name = "Updated"
        await vm.updateProject(updated)

        #expect(vm.projects[0].name == "Updated")
    }

    @Test("Delete project removes from repo")
    @MainActor
    func deleteProject() async {
        let (vm, projectRepo, _) = makeViewModel()
        let p = Project(name: "ToDelete", categoryId: testCategoryId)
        projectRepo.projects = [p]
        await vm.load()

        await vm.deleteProject(p)

        #expect(projectRepo.deletedIds.contains(p.id))
        #expect(vm.projects.count == 0)
    }

    @Test("Transition project changes lifecycle state")
    @MainActor
    func transitionProject() async {
        let (vm, projectRepo, _) = makeViewModel()
        let p = Project(name: "P1", categoryId: testCategoryId, lifecycleState: .idea)
        projectRepo.projects = [p]
        await vm.load()

        await vm.transitionProject(p, to: .queued)

        #expect(vm.projects[0].lifecycleState == .queued)
    }

    @Test("Invalid transition sets error")
    @MainActor
    func invalidTransition() async {
        let (vm, projectRepo, _) = makeViewModel()
        let p = Project(name: "P1", categoryId: testCategoryId, lifecycleState: .idea)
        projectRepo.projects = [p]
        await vm.load()

        // idea -> completed is not valid
        await vm.transitionProject(p, to: .completed)

        #expect(vm.error != nil)
        #expect(vm.projects[0].lifecycleState == .idea)
    }

    @Test("Transition to paused sets pause reason")
    @MainActor
    func pauseTransition() async {
        let (vm, projectRepo, _) = makeViewModel()
        let p = Project(name: "P1", categoryId: testCategoryId, lifecycleState: .queued)
        projectRepo.projects = [p]
        await vm.load()

        vm.pauseReason = "Need more resources"
        await vm.transitionProject(p, to: .paused)

        #expect(vm.projects[0].lifecycleState == .paused)
        #expect(vm.projects[0].pauseReason == "Need more resources")
    }

    @Test("Transition to abandoned sets reflection")
    @MainActor
    func abandonTransition() async {
        let (vm, projectRepo, _) = makeViewModel()
        let p = Project(name: "P1", categoryId: testCategoryId, lifecycleState: .queued)
        projectRepo.projects = [p]
        await vm.load()

        vm.abandonmentReflection = "Not viable anymore"
        await vm.transitionProject(p, to: .abandoned)

        #expect(vm.projects[0].lifecycleState == .abandoned)
        #expect(vm.projects[0].abandonmentReflection == "Not viable anymore")
    }

    @Test("validTransitions returns correct set")
    @MainActor
    func validTransitions() {
        let (vm, _, _) = makeViewModel()
        let p = Project(name: "P1", categoryId: testCategoryId, lifecycleState: .idea)
        let transitions = vm.validTransitions(for: p)

        #expect(transitions.contains(.queued))
        #expect(transitions.contains(.abandoned))
        #expect(!transitions.contains(.completed))
        #expect(!transitions.contains(.focused))
    }

    @Test("categoryName returns correct name")
    @MainActor
    func categoryNameLookup() async {
        let (vm, _, _) = makeViewModel()
        await vm.load()

        let p = Project(name: "P1", categoryId: testCategoryId)
        #expect(vm.categoryName(for: p) == "Software")

        let unknown = Project(name: "P2", categoryId: UUID())
        #expect(vm.categoryName(for: unknown) == "Unknown")
    }
}

// MARK: - Navigation Tests

@Suite("AppNavigation")
struct AppNavigationTests {

    @Test("NavigationSection has correct icon names")
    func sectionIcons() {
        for section in NavigationSection.allCases {
            #expect(!section.iconName.isEmpty)
        }
    }

    @Test("NavigationSection main sections excludes settings")
    func mainSections() {
        let main = NavigationSection.allCases.filter(\.isMainSection)
        #expect(main.count == 5)
        #expect(!main.contains(.settings))
    }
}

// MARK: - Lifecycle Filter Tests

@Suite("LifecycleFilter")
struct LifecycleFilterTests {

    @Test("All filter has correct label")
    func allLabel() {
        #expect(LifecycleFilter.all.label == "All Projects")
    }

    @Test("State filter has capitalized label")
    func stateLabel() {
        #expect(LifecycleFilter.state(.focused).label == "Focused")
        #expect(LifecycleFilter.state(.idea).label == "Idea")
    }
}
