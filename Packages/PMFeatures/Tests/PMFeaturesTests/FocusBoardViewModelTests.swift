import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain

// MARK: - Mock CheckIn Repository

final class MockCheckInRepository: CheckInRepositoryProtocol, @unchecked Sendable {
    var checkIns: [CheckInRecord] = []
    func fetchAll(forProject projectId: UUID) async throws -> [CheckInRecord] {
        checkIns.filter { $0.projectId == projectId }
    }
    func fetch(id: UUID) async throws -> CheckInRecord? { checkIns.first { $0.id == id } }
    func fetchLatest(forProject projectId: UUID) async throws -> CheckInRecord? {
        checkIns.filter { $0.projectId == projectId }.sorted { $0.timestamp > $1.timestamp }.first
    }
    func save(_ record: CheckInRecord) async throws {
        if let idx = checkIns.firstIndex(where: { $0.id == record.id }) { checkIns[idx] = record }
        else { checkIns.append(record) }
    }
    func delete(id: UUID) async throws { checkIns.removeAll { $0.id == id } }
}

// MARK: - Focus Board Test Helper

private let catId1 = UUID()
private let catId2 = UUID()
private let cat1 = PMDomain.Category(id: catId1, name: "Software", isBuiltIn: true, sortOrder: 0)
private let cat2 = PMDomain.Category(id: catId2, name: "Music", isBuiltIn: true, sortOrder: 1)

@MainActor
func makeFocusBoardVM() -> (
    FocusBoardViewModel, MockProjectRepository, MockCategoryRepository,
    MockTaskRepository, MockMilestoneRepository, MockPhaseRepository, MockCheckInRepository
) {
    let projectRepo = MockProjectRepository()
    let categoryRepo = MockCategoryRepository()
    categoryRepo.categories = [cat1, cat2]
    let taskRepo = MockTaskRepository()
    let milestoneRepo = MockMilestoneRepository()
    let phaseRepo = MockPhaseRepository()
    let checkInRepo = MockCheckInRepository()
    let vm = FocusBoardViewModel(
        projectRepo: projectRepo,
        categoryRepo: categoryRepo,
        taskRepo: taskRepo,
        milestoneRepo: milestoneRepo,
        phaseRepo: phaseRepo,
        checkInRepo: checkInRepo
    )
    return (vm, projectRepo, categoryRepo, taskRepo, milestoneRepo, phaseRepo, checkInRepo)
}

/// Helper to set up a focused project with tasks in the mock repos.
@MainActor
func seedFocusedProject(
    vm: FocusBoardViewModel,
    projectRepo: MockProjectRepository,
    phaseRepo: MockPhaseRepository,
    milestoneRepo: MockMilestoneRepository,
    taskRepo: MockTaskRepository,
    name: String = "Focused P",
    slotIndex: Int = 0,
    categoryId: UUID = catId1,
    tasks: [PMTask] = []
) -> (Project, Phase, Milestone) {
    let project = Project(name: name, categoryId: categoryId, lifecycleState: .focused, focusSlotIndex: slotIndex)
    projectRepo.projects.append(project)
    let phase = Phase(projectId: project.id, name: "P1")
    phaseRepo.phases.append(phase)
    let ms = Milestone(phaseId: phase.id, name: "M1")
    milestoneRepo.milestones.append(ms)
    for var task in tasks {
        task.milestoneId = ms.id
        taskRepo.tasks.append(task)
    }
    return (project, phase, ms)
}

// MARK: - Tests

@Suite("FocusBoardViewModel")
struct FocusBoardViewModelTests {

    @Test("Load populates focused projects and tasks")
    @MainActor
    func load() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        let tasks = [
            PMTask(id: UUID(), milestoneId: msId, name: "T1", kanbanColumn: .toDo),
            PMTask(id: UUID(), milestoneId: msId, name: "T2", kanbanColumn: .inProgress),
        ]
        let (project, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                                   milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: tasks)

        await vm.load()

        #expect(vm.focusedProjects.count == 1)
        #expect(vm.tasksByProject[project.id]?.count == 2)
        #expect(vm.isLoading == false)
    }

    @Test("ToDo tasks are curated by default")
    @MainActor
    func toDoTasksCurated() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        var tasks: [PMTask] = []
        for i in 0..<10 {
            tasks.append(PMTask(id: UUID(), milestoneId: msId, name: "Task \(i)", sortOrder: i, kanbanColumn: .toDo))
        }
        let (project, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                                   milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: tasks)
        await vm.load()

        let curated = vm.toDoTasks(for: project.id)
        #expect(curated.count == FocusManager.defaultMaxVisibleTasks)
    }

    @Test("Show all toggle bypasses curation")
    @MainActor
    func showAllTasks() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        var tasks: [PMTask] = []
        for i in 0..<10 {
            tasks.append(PMTask(id: UUID(), milestoneId: msId, name: "Task \(i)", sortOrder: i, kanbanColumn: .toDo))
        }
        let (project, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                                   milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: tasks)
        await vm.load()

        vm.toggleShowAll(for: project.id)
        let all = vm.toDoTasks(for: project.id)
        #expect(all.count == 10)

        vm.toggleShowAll(for: project.id)
        let curated = vm.toDoTasks(for: project.id)
        #expect(curated.count == FocusManager.defaultMaxVisibleTasks)
    }

    @Test("Effort type filter narrows ToDo tasks")
    @MainActor
    func effortTypeFilter() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        let tasks = [
            PMTask(id: UUID(), milestoneId: msId, name: "Deep", sortOrder: 0, effortType: .deepFocus, kanbanColumn: .toDo),
            PMTask(id: UUID(), milestoneId: msId, name: "Quick", sortOrder: 1, effortType: .quickWin, kanbanColumn: .toDo),
            PMTask(id: UUID(), milestoneId: msId, name: "Admin", sortOrder: 2, effortType: .administrative, kanbanColumn: .toDo),
        ]
        let (project, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                                   milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: tasks)
        vm.showAllTasks.insert(project.id)
        await vm.load()

        vm.effortTypeFilter = .quickWin
        let filtered = vm.toDoTasks(for: project.id)
        #expect(filtered.count == 1)
        #expect(filtered[0].name == "Quick")
    }

    @Test("Done column respects retention days")
    @MainActor
    func doneRetention() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        let recentDone = PMTask(id: UUID(), milestoneId: msId, name: "Recent", status: .completed,
                                 completedAt: Date(), kanbanColumn: .done)
        let oldDone = PMTask(id: UUID(), milestoneId: msId, name: "Old", status: .completed,
                              completedAt: Date().addingTimeInterval(-86400 * 30), kanbanColumn: .done)
        let (project, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                                   milestoneRepo: milestoneRepo, taskRepo: taskRepo,
                                                   tasks: [recentDone, oldDone])
        await vm.load()

        vm.doneRetentionDays = 7
        let done = vm.doneTasks(for: project.id)
        #expect(done.count == 1)
        #expect(done[0].name == "Recent")
    }

    @Test("Done column respects max items")
    @MainActor
    func doneMaxItems() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        var tasks: [PMTask] = []
        for i in 0..<10 {
            tasks.append(PMTask(id: UUID(), milestoneId: msId, name: "Done \(i)", status: .completed,
                                 completedAt: Date(), kanbanColumn: .done))
        }
        let (project, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                                   milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: tasks)
        await vm.load()

        vm.doneMaxItems = 5
        let done = vm.doneTasks(for: project.id)
        #expect(done.count == 5)
    }

    @Test("Move task to Done marks completed")
    @MainActor
    func moveTaskToDone() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        let task = PMTask(id: UUID(), milestoneId: msId, name: "T1", kanbanColumn: .toDo)
        let (_, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                            milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: [task])
        await vm.load()

        await vm.moveTask(taskRepo.tasks[0], to: .done)

        let updated = taskRepo.tasks[0]
        #expect(updated.kanbanColumn == .done)
        #expect(updated.status == .completed)
        #expect(updated.completedAt != nil)
    }

    @Test("Move task from Done un-completes")
    @MainActor
    func moveTaskFromDone() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        let task = PMTask(id: UUID(), milestoneId: msId, name: "T1", status: .completed,
                           completedAt: Date(), kanbanColumn: .done)
        let (_, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                            milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: [task])
        await vm.load()

        await vm.moveTask(taskRepo.tasks[0], to: .toDo)

        let updated = taskRepo.tasks[0]
        #expect(updated.kanbanColumn == .toDo)
        #expect(updated.status == .notStarted)
        #expect(updated.completedAt == nil)
    }

    @Test("Focus project adds to board")
    @MainActor
    func focusProject() async {
        let (vm, projectRepo, _, _, _, _, _) = makeFocusBoardVM()
        let project = Project(name: "New", categoryId: catId1, lifecycleState: .queued)
        projectRepo.projects = [project]
        await vm.load()

        await vm.focusProject(project)

        let saved = projectRepo.projects.first { $0.id == project.id }
        #expect(saved?.lifecycleState == .focused)
        #expect(saved?.focusSlotIndex != nil)
    }

    @Test("Unfocus project removes from board")
    @MainActor
    func unfocusProject() async {
        let (vm, projectRepo, _, _, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let (project, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                                   milestoneRepo: milestoneRepo, taskRepo: MockTaskRepository())
        await vm.load()

        await vm.unfocusProject(project, to: .queued)

        let saved = projectRepo.projects.first { $0.id == project.id }
        #expect(saved?.lifecycleState == .queued)
        #expect(saved?.focusSlotIndex == nil)
    }

    @Test("Health badges computed for projects")
    @MainActor
    func healthBadges() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        let blockedTask = PMTask(id: UUID(), milestoneId: msId, name: "Blocked", status: .blocked,
                                  blockedType: .missingInfo, kanbanColumn: .toDo)
        let (project, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                                   milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: [blockedTask])
        await vm.load()

        let badges = vm.healthBadges(for: project.id)
        #expect(badges.contains { if case .blockedTasks = $0 { return true }; return false })
    }

    @Test("Diversity violations detected")
    @MainActor
    func diversityViolations() async {
        let (vm, projectRepo, _, _, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        // Add 3 focused projects in same category (limit is 2)
        for i in 0..<3 {
            let _ = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                       milestoneRepo: milestoneRepo, taskRepo: MockTaskRepository(),
                                       name: "P\(i)", slotIndex: i, categoryId: catId1)
        }
        await vm.load()

        #expect(vm.diversityViolations.count == 1)
        #expect(vm.diversityViolations[0].projectCount == 3)
    }

    @Test("In-progress tasks column")
    @MainActor
    func inProgressTasks() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        let tasks = [
            PMTask(id: UUID(), milestoneId: msId, name: "IP1", status: .inProgress, kanbanColumn: .inProgress),
            PMTask(id: UUID(), milestoneId: msId, name: "TD1", kanbanColumn: .toDo),
        ]
        let (project, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                                   milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: tasks)
        await vm.load()

        let ip = vm.inProgressTasks(for: project.id)
        #expect(ip.count == 1)
        #expect(ip[0].name == "IP1")
    }

    @Test("Total ToDo count includes uncurated tasks")
    @MainActor
    func totalToDoCount() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        var tasks: [PMTask] = []
        for i in 0..<8 {
            tasks.append(PMTask(id: UUID(), milestoneId: msId, name: "T\(i)", sortOrder: i, kanbanColumn: .toDo))
        }
        let (project, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                                   milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: tasks)
        await vm.load()

        #expect(vm.totalToDoCount(for: project.id) == 8)
        #expect(vm.toDoTasks(for: project.id).count == 3) // curated default
    }

    @Test("maxVisibleTasks changes curation count")
    @MainActor
    func maxVisibleTasks() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        var tasks: [PMTask] = []
        for i in 0..<10 {
            tasks.append(PMTask(id: UUID(), milestoneId: msId, name: "T\(i)", sortOrder: i, kanbanColumn: .toDo))
        }
        let (project, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                                   milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: tasks)
        await vm.load()

        vm.maxVisibleTasks = 5
        let curated = vm.toDoTasks(for: project.id)
        #expect(curated.count == 5)
    }

    @Test("Category name lookup")
    @MainActor
    func categoryName() async {
        let (vm, _, _, _, _, _, _) = makeFocusBoardVM()
        await vm.load()

        let project = Project(name: "P1", categoryId: catId1)
        #expect(vm.categoryName(for: project) == "Software")
    }

    @Test("Move task to InProgress changes status")
    @MainActor
    func moveToInProgress() async {
        let (vm, projectRepo, _, taskRepo, milestoneRepo, phaseRepo, _) = makeFocusBoardVM()
        let msId = UUID()
        let task = PMTask(id: UUID(), milestoneId: msId, name: "T1", kanbanColumn: .toDo)
        let (_, _, _) = seedFocusedProject(vm: vm, projectRepo: projectRepo, phaseRepo: phaseRepo,
                                            milestoneRepo: milestoneRepo, taskRepo: taskRepo, tasks: [task])
        await vm.load()

        await vm.moveTask(taskRepo.tasks[0], to: .inProgress)

        let updated = taskRepo.tasks[0]
        #expect(updated.kanbanColumn == .inProgress)
        #expect(updated.status == .inProgress)
    }
}
