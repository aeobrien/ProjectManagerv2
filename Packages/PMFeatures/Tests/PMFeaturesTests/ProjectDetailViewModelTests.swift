import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain

// MARK: - Additional Mock Repositories

final class MockPhaseRepository: PhaseRepositoryProtocol, @unchecked Sendable {
    var phases: [Phase] = []
    func fetchAll(forProject projectId: UUID) async throws -> [Phase] {
        phases.filter { $0.projectId == projectId }.sorted { $0.sortOrder < $1.sortOrder }
    }
    func fetch(id: UUID) async throws -> Phase? { phases.first { $0.id == id } }
    func save(_ phase: Phase) async throws {
        if let idx = phases.firstIndex(where: { $0.id == phase.id }) { phases[idx] = phase }
        else { phases.append(phase) }
    }
    func delete(id: UUID) async throws { phases.removeAll { $0.id == id } }
    func reorder(phases: [Phase]) async throws {
        for p in phases { if let idx = self.phases.firstIndex(where: { $0.id == p.id }) { self.phases[idx] = p } }
    }
}

final class MockMilestoneRepository: MilestoneRepositoryProtocol, @unchecked Sendable {
    var milestones: [Milestone] = []
    func fetchAll(forPhase phaseId: UUID) async throws -> [Milestone] {
        milestones.filter { $0.phaseId == phaseId }.sorted { $0.sortOrder < $1.sortOrder }
    }
    func fetch(id: UUID) async throws -> Milestone? { milestones.first { $0.id == id } }
    func save(_ milestone: Milestone) async throws {
        if let idx = milestones.firstIndex(where: { $0.id == milestone.id }) { milestones[idx] = milestone }
        else { milestones.append(milestone) }
    }
    func delete(id: UUID) async throws { milestones.removeAll { $0.id == id } }
    func reorder(milestones: [Milestone]) async throws {
        for m in milestones { if let idx = self.milestones.firstIndex(where: { $0.id == m.id }) { self.milestones[idx] = m } }
    }
}

final class MockTaskRepository: TaskRepositoryProtocol, @unchecked Sendable {
    var tasks: [PMTask] = []
    func fetchAll(forMilestone milestoneId: UUID) async throws -> [PMTask] {
        tasks.filter { $0.milestoneId == milestoneId }.sorted { $0.sortOrder < $1.sortOrder }
    }
    func fetch(id: UUID) async throws -> PMTask? { tasks.first { $0.id == id } }
    func fetchByStatus(_ status: ItemStatus) async throws -> [PMTask] { tasks.filter { $0.status == status } }
    func fetchByEffortType(_ effortType: EffortType) async throws -> [PMTask] { tasks.filter { $0.effortType == effortType } }
    func fetchByKanbanColumn(_ column: KanbanColumn, milestoneId: UUID) async throws -> [PMTask] {
        tasks.filter { $0.kanbanColumn == column && $0.milestoneId == milestoneId }
    }
    func save(_ task: PMTask) async throws {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) { tasks[idx] = task }
        else { tasks.append(task) }
    }
    func delete(id: UUID) async throws { tasks.removeAll { $0.id == id } }
    func reorder(tasks: [PMTask]) async throws {
        for t in tasks { if let idx = self.tasks.firstIndex(where: { $0.id == t.id }) { self.tasks[idx] = t } }
    }
    func search(query: String) async throws -> [PMTask] { tasks.filter { $0.name.lowercased().contains(query.lowercased()) } }
}

final class MockSubtaskRepository: SubtaskRepositoryProtocol, @unchecked Sendable {
    var subtasks: [Subtask] = []
    func fetchAll(forTask taskId: UUID) async throws -> [Subtask] {
        subtasks.filter { $0.taskId == taskId }.sorted { $0.sortOrder < $1.sortOrder }
    }
    func fetch(id: UUID) async throws -> Subtask? { subtasks.first { $0.id == id } }
    func save(_ subtask: Subtask) async throws {
        if let idx = subtasks.firstIndex(where: { $0.id == subtask.id }) { subtasks[idx] = subtask }
        else { subtasks.append(subtask) }
    }
    func delete(id: UUID) async throws { subtasks.removeAll { $0.id == id } }
    func reorder(subtasks: [Subtask]) async throws {
        for s in subtasks { if let idx = self.subtasks.firstIndex(where: { $0.id == s.id }) { self.subtasks[idx] = s } }
    }
}

final class MockDependencyRepository: DependencyRepositoryProtocol, @unchecked Sendable {
    var dependencies: [Dependency] = []
    func fetchAll(forSource sourceId: UUID, sourceType: DependableType) async throws -> [Dependency] {
        dependencies.filter { $0.sourceId == sourceId && $0.sourceType == sourceType }
    }
    func fetchAll(forTarget targetId: UUID, targetType: DependableType) async throws -> [Dependency] {
        dependencies.filter { $0.targetId == targetId && $0.targetType == targetType }
    }
    func fetch(id: UUID) async throws -> Dependency? { dependencies.first { $0.id == id } }
    func save(_ dependency: Dependency) async throws {
        if let idx = dependencies.firstIndex(where: { $0.id == dependency.id }) { dependencies[idx] = dependency }
        else { dependencies.append(dependency) }
    }
    func delete(id: UUID) async throws { dependencies.removeAll { $0.id == id } }
}

// MARK: - Test Helper

private let catId = UUID()

@MainActor
func makeDetailVM(project: Project? = nil) -> (
    ProjectDetailViewModel, MockProjectRepository, MockPhaseRepository,
    MockMilestoneRepository, MockTaskRepository, MockSubtaskRepository, MockDependencyRepository
) {
    let proj = project ?? Project(name: "Test Project", categoryId: catId)
    let projectRepo = MockProjectRepository()
    projectRepo.projects = [proj]
    let phaseRepo = MockPhaseRepository()
    let milestoneRepo = MockMilestoneRepository()
    let taskRepo = MockTaskRepository()
    let subtaskRepo = MockSubtaskRepository()
    let depRepo = MockDependencyRepository()
    let vm = ProjectDetailViewModel(
        project: proj,
        projectRepo: projectRepo,
        phaseRepo: phaseRepo,
        milestoneRepo: milestoneRepo,
        taskRepo: taskRepo,
        subtaskRepo: subtaskRepo,
        dependencyRepo: depRepo
    )
    return (vm, projectRepo, phaseRepo, milestoneRepo, taskRepo, subtaskRepo, depRepo)
}

// MARK: - Tests

@Suite("ProjectDetailViewModel")
struct ProjectDetailViewModelTests {

    // MARK: - Loading

    @Test("Load populates hierarchy")
    @MainActor
    func loadHierarchy() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, subtaskRepo, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "Phase 1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        let task = PMTask(milestoneId: ms.id, name: "T1")
        taskRepo.tasks = [task]
        let sub = Subtask(taskId: task.id, name: "S1")
        subtaskRepo.subtasks = [sub]

        await vm.load()

        #expect(vm.phases.count == 1)
        #expect(vm.milestonesByPhase[phase.id]?.count == 1)
        #expect(vm.tasksByMilestone[ms.id]?.count == 1)
        #expect(vm.subtasksByTask[task.id]?.count == 1)
        #expect(vm.isLoading == false)
    }

    // MARK: - Phase CRUD

    @Test("Create phase")
    @MainActor
    func createPhase() async {
        let (vm, _, phaseRepo, _, _, _, _) = makeDetailVM()

        await vm.createPhase(name: "Design")

        #expect(phaseRepo.phases.count == 1)
        #expect(vm.phases.count == 1)
        #expect(vm.phases[0].name == "Design")
    }

    @Test("Update phase")
    @MainActor
    func updatePhase() async {
        let (vm, _, phaseRepo, _, _, _, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "Old")
        phaseRepo.phases = [phase]
        await vm.load()

        var updated = phase
        updated.name = "New"
        await vm.updatePhase(updated)

        #expect(vm.phases[0].name == "New")
    }

    @Test("Delete phase")
    @MainActor
    func deletePhase() async {
        let (vm, _, phaseRepo, _, _, _, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "ToDelete")
        phaseRepo.phases = [phase]
        await vm.load()

        await vm.deletePhase(phase)

        #expect(vm.phases.count == 0)
    }

    @Test("Reorder phases updates sort order")
    @MainActor
    func reorderPhases() async {
        let (vm, _, phaseRepo, _, _, _, _) = makeDetailVM()
        let p1 = Phase(projectId: vm.project.id, name: "A", sortOrder: 0)
        let p2 = Phase(projectId: vm.project.id, name: "B", sortOrder: 1)
        phaseRepo.phases = [p1, p2]
        await vm.load()

        await vm.reorderPhases([p2, p1]) // reverse

        let reordered = phaseRepo.phases.sorted { $0.sortOrder < $1.sortOrder }
        #expect(reordered[0].name == "B")
        #expect(reordered[1].name == "A")
    }

    // MARK: - Milestone CRUD

    @Test("Create milestone in phase")
    @MainActor
    func createMilestone() async {
        let (vm, _, phaseRepo, milestoneRepo, _, _, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        await vm.load()

        await vm.createMilestone(in: phase.id, name: "Wireframes", priority: .high)

        #expect(milestoneRepo.milestones.count == 1)
        #expect(vm.milestonesByPhase[phase.id]?.count == 1)
        #expect(vm.milestonesByPhase[phase.id]?[0].priority == .high)
    }

    @Test("Delete milestone")
    @MainActor
    func deleteMilestone() async {
        let (vm, _, phaseRepo, milestoneRepo, _, _, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        await vm.load()

        await vm.deleteMilestone(ms)

        #expect(milestoneRepo.milestones.count == 0)
    }

    // MARK: - Task CRUD

    @Test("Create task in milestone")
    @MainActor
    func createTask() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, _, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        await vm.load()

        await vm.createTask(in: ms.id, name: "Build login", effortType: .deepFocus, priority: .high)

        #expect(taskRepo.tasks.count == 1)
        #expect(taskRepo.tasks[0].effortType == .deepFocus)
        #expect(taskRepo.tasks[0].priority == .high)
    }

    @Test("Block task sets type and reason")
    @MainActor
    func blockTask() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, _, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        let task = PMTask(milestoneId: ms.id, name: "T1")
        taskRepo.tasks = [task]
        await vm.load()

        await vm.blockTask(task, type: .missingInfo, reason: "Need API docs")

        let updated = taskRepo.tasks[0]
        #expect(updated.status == .blocked)
        #expect(updated.blockedType == .missingInfo)
        #expect(updated.blockedReason == "Need API docs")
    }

    @Test("Wait task sets reason and check-back date")
    @MainActor
    func waitTask() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, _, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        let task = PMTask(milestoneId: ms.id, name: "T1")
        taskRepo.tasks = [task]
        await vm.load()

        let checkBack = Date().addingTimeInterval(86400 * 3)
        await vm.waitTask(task, reason: "Waiting for client", checkBackDate: checkBack)

        let updated = taskRepo.tasks[0]
        #expect(updated.status == .waiting)
        #expect(updated.waitingReason == "Waiting for client")
        #expect(updated.waitingCheckBackDate != nil)
    }

    @Test("Unblock task clears blocked state")
    @MainActor
    func unblockTask() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, _, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        let task = PMTask(milestoneId: ms.id, name: "T1", status: .blocked, blockedType: .missingInfo, blockedReason: "Need docs")
        taskRepo.tasks = [task]
        await vm.load()

        await vm.unblockTask(task)

        let updated = taskRepo.tasks[0]
        #expect(updated.status == .inProgress)
        #expect(updated.blockedType == nil)
        #expect(updated.blockedReason == nil)
    }

    @Test("Delete task")
    @MainActor
    func deleteTask() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, _, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        let task = PMTask(milestoneId: ms.id, name: "T1")
        taskRepo.tasks = [task]
        await vm.load()

        await vm.deleteTask(task)

        #expect(taskRepo.tasks.count == 0)
    }

    // MARK: - Subtask CRUD

    @Test("Create and toggle subtask")
    @MainActor
    func createAndToggleSubtask() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, subtaskRepo, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        let task = PMTask(milestoneId: ms.id, name: "T1")
        taskRepo.tasks = [task]
        await vm.load()

        await vm.createSubtask(in: task.id, name: "Step 1")

        #expect(subtaskRepo.subtasks.count == 1)
        #expect(subtaskRepo.subtasks[0].isCompleted == false)

        let sub = subtaskRepo.subtasks[0]
        await vm.toggleSubtask(sub)

        #expect(subtaskRepo.subtasks[0].isCompleted == true)
    }

    @Test("Delete subtask")
    @MainActor
    func deleteSubtask() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, subtaskRepo, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        let task = PMTask(milestoneId: ms.id, name: "T1")
        taskRepo.tasks = [task]
        let sub = Subtask(taskId: task.id, name: "S1")
        subtaskRepo.subtasks = [sub]
        await vm.load()

        await vm.deleteSubtask(sub)

        #expect(subtaskRepo.subtasks.count == 0)
    }

    // MARK: - Dependencies

    @Test("Add and check unmet dependencies")
    @MainActor
    func dependencies() async {
        let (vm, _, phaseRepo, milestoneRepo, _, _, depRepo) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms1 = Milestone(phaseId: phase.id, name: "M1", sortOrder: 0, status: .notStarted)
        let ms2 = Milestone(phaseId: phase.id, name: "M2", sortOrder: 1, status: .notStarted)
        milestoneRepo.milestones = [ms1, ms2]
        await vm.load()

        // ms2 depends on ms1
        await vm.addDependency(sourceType: .milestone, sourceId: ms1.id, targetType: .milestone, targetId: ms2.id)

        #expect(depRepo.dependencies.count == 1)
        #expect(vm.hasUnmetDependencies(targetId: ms2.id) == true)
        #expect(vm.hasUnmetDependencies(targetId: ms1.id) == false)
    }

    @Test("Dependency met when source is completed")
    @MainActor
    func dependencyMet() async {
        let (vm, _, phaseRepo, milestoneRepo, _, _, depRepo) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms1 = Milestone(phaseId: phase.id, name: "M1", sortOrder: 0, status: .completed)
        let ms2 = Milestone(phaseId: phase.id, name: "M2", sortOrder: 1, status: .notStarted)
        milestoneRepo.milestones = [ms1, ms2]
        let dep = Dependency(sourceType: .milestone, sourceId: ms1.id, targetType: .milestone, targetId: ms2.id)
        depRepo.dependencies = [dep]
        await vm.load()

        #expect(vm.hasUnmetDependencies(targetId: ms2.id) == false)
    }

    @Test("Remove dependency")
    @MainActor
    func removeDependency() async {
        let (vm, _, phaseRepo, milestoneRepo, _, _, depRepo) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms1 = Milestone(phaseId: phase.id, name: "M1")
        let ms2 = Milestone(phaseId: phase.id, name: "M2")
        milestoneRepo.milestones = [ms1, ms2]
        let dep = Dependency(sourceType: .milestone, sourceId: ms1.id, targetType: .milestone, targetId: ms2.id)
        depRepo.dependencies = [dep]
        await vm.load()

        await vm.removeDependency(dep)

        #expect(depRepo.dependencies.count == 0)
    }

    // MARK: - Task with timebox

    @Test("Create task with timebox")
    @MainActor
    func createTimeboxTask() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, _, _) = makeDetailVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        await vm.load()

        await vm.createTask(in: ms.id, name: "Quick task", isTimeboxed: true, timeboxMinutes: 25)

        #expect(taskRepo.tasks[0].timeboxMinutes == 25)
    }
}
