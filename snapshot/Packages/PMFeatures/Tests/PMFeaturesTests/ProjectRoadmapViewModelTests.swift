import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain

// MARK: - Roadmap Test Helper

private let rCatId = UUID()

@MainActor
func makeRoadmapVM(project: Project? = nil) -> (
    ProjectRoadmapViewModel, MockProjectRepository, MockPhaseRepository,
    MockMilestoneRepository, MockTaskRepository, MockDependencyRepository
) {
    let proj = project ?? Project(name: "Roadmap Project", categoryId: rCatId)
    let projectRepo = MockProjectRepository()
    projectRepo.projects = [proj]
    let phaseRepo = MockPhaseRepository()
    let milestoneRepo = MockMilestoneRepository()
    let taskRepo = MockTaskRepository()
    let depRepo = MockDependencyRepository()
    let vm = ProjectRoadmapViewModel(
        project: proj,
        projectRepo: projectRepo,
        phaseRepo: phaseRepo,
        milestoneRepo: milestoneRepo,
        taskRepo: taskRepo,
        dependencyRepo: depRepo
    )
    return (vm, projectRepo, phaseRepo, milestoneRepo, taskRepo, depRepo)
}

// MARK: - Tests

@Suite("ProjectRoadmapViewModel")
struct ProjectRoadmapViewModelTests {

    @Test("Load creates flattened items from hierarchy")
    @MainActor
    func loadHierarchy() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, _) = makeRoadmapVM()
        let phase = Phase(projectId: vm.project.id, name: "Design")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "Wireframes")
        milestoneRepo.milestones = [ms]
        let task = PMTask(milestoneId: ms.id, name: "Draw screens")
        taskRepo.tasks = [task]

        await vm.load()

        #expect(vm.items.count == 3)
        #expect(vm.items[0].kind == .phase)
        #expect(vm.items[1].kind == .milestone)
        #expect(vm.items[2].kind == .task)
        #expect(vm.isLoading == false)
    }

    @Test("Item depth matches hierarchy level")
    @MainActor
    func itemDepth() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, _) = makeRoadmapVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        let task = PMTask(milestoneId: ms.id, name: "T1")
        taskRepo.tasks = [task]

        await vm.load()

        #expect(vm.items[0].depth == 0)
        #expect(vm.items[1].depth == 1)
        #expect(vm.items[2].depth == 2)
    }

    @Test("Phase progress computed from milestones")
    @MainActor
    func phaseProgress() async {
        let (vm, _, phaseRepo, milestoneRepo, _, _) = makeRoadmapVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms1 = Milestone(phaseId: phase.id, name: "M1", sortOrder: 0, status: .completed)
        let ms2 = Milestone(phaseId: phase.id, name: "M2", sortOrder: 1, status: .notStarted)
        milestoneRepo.milestones = [ms1, ms2]

        await vm.load()

        let phaseItem = vm.items.first { $0.kind == .phase }
        #expect(phaseItem?.progress == 0.5)
    }

    @Test("Milestone progress computed from tasks")
    @MainActor
    func milestoneProgress() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, _) = makeRoadmapVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        let t1 = PMTask(milestoneId: ms.id, name: "T1", sortOrder: 0, status: .completed)
        let t2 = PMTask(milestoneId: ms.id, name: "T2", sortOrder: 1, status: .completed)
        let t3 = PMTask(milestoneId: ms.id, name: "T3", sortOrder: 2, status: .notStarted)
        taskRepo.tasks = [t1, t2, t3]

        await vm.load()

        let msItem = vm.items.first { $0.kind == .milestone }
        #expect(msItem != nil)
        // 2/3 completed
        let expected = 2.0 / 3.0
        #expect(abs((msItem?.progress ?? 0) - expected) < 0.01)
    }

    @Test("Unmet dependency detected")
    @MainActor
    func unmetDependency() async {
        let (vm, _, phaseRepo, milestoneRepo, _, depRepo) = makeRoadmapVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms1 = Milestone(phaseId: phase.id, name: "M1", sortOrder: 0, status: .notStarted)
        let ms2 = Milestone(phaseId: phase.id, name: "M2", sortOrder: 1, status: .notStarted)
        milestoneRepo.milestones = [ms1, ms2]
        let dep = Dependency(sourceType: .milestone, sourceId: ms1.id, targetType: .milestone, targetId: ms2.id)
        depRepo.dependencies = [dep]

        await vm.load()

        let ms2Item = vm.items.first { $0.id == ms2.id }
        #expect(ms2Item?.hasUnmetDependencies == true)

        let ms1Item = vm.items.first { $0.id == ms1.id }
        #expect(ms1Item?.hasUnmetDependencies == false)
    }

    @Test("Met dependency when source completed")
    @MainActor
    func metDependency() async {
        let (vm, _, phaseRepo, milestoneRepo, _, depRepo) = makeRoadmapVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms1 = Milestone(phaseId: phase.id, name: "M1", sortOrder: 0, status: .completed)
        let ms2 = Milestone(phaseId: phase.id, name: "M2", sortOrder: 1, status: .notStarted)
        milestoneRepo.milestones = [ms1, ms2]
        let dep = Dependency(sourceType: .milestone, sourceId: ms1.id, targetType: .milestone, targetId: ms2.id)
        depRepo.dependencies = [dep]

        await vm.load()

        let ms2Item = vm.items.first { $0.id == ms2.id }
        #expect(ms2Item?.hasUnmetDependencies == false)
    }

    @Test("Dependency source names resolved")
    @MainActor
    func dependencySourceNames() async {
        let (vm, _, phaseRepo, milestoneRepo, _, depRepo) = makeRoadmapVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms1 = Milestone(phaseId: phase.id, name: "Prerequisite", sortOrder: 0, status: .notStarted)
        let ms2 = Milestone(phaseId: phase.id, name: "Target", sortOrder: 1, status: .notStarted)
        milestoneRepo.milestones = [ms1, ms2]
        let dep = Dependency(sourceType: .milestone, sourceId: ms1.id, targetType: .milestone, targetId: ms2.id)
        depRepo.dependencies = [dep]

        await vm.load()

        let names = vm.dependencySourceNames(for: ms2.id)
        #expect(names == ["Prerequisite"])
    }

    @Test("Overall progress from milestones")
    @MainActor
    func overallProgress() async {
        let (vm, _, phaseRepo, milestoneRepo, _, _) = makeRoadmapVM()
        let p1 = Phase(projectId: vm.project.id, name: "P1", sortOrder: 0)
        let p2 = Phase(projectId: vm.project.id, name: "P2", sortOrder: 1)
        phaseRepo.phases = [p1, p2]
        let ms1 = Milestone(phaseId: p1.id, name: "M1", status: .completed)
        let ms2 = Milestone(phaseId: p2.id, name: "M2", status: .notStarted)
        milestoneRepo.milestones = [ms1, ms2]

        await vm.load()

        #expect(vm.overallProgress == 0.5)
    }

    @Test("Counts match hierarchy")
    @MainActor
    func counts() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, _) = makeRoadmapVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms1 = Milestone(phaseId: phase.id, name: "M1", sortOrder: 0)
        let ms2 = Milestone(phaseId: phase.id, name: "M2", sortOrder: 1)
        milestoneRepo.milestones = [ms1, ms2]
        taskRepo.tasks = [
            PMTask(milestoneId: ms1.id, name: "T1"),
            PMTask(milestoneId: ms1.id, name: "T2"),
            PMTask(milestoneId: ms2.id, name: "T3"),
        ]

        await vm.load()

        #expect(vm.phaseCount == 1)
        #expect(vm.milestoneCount == 2)
        #expect(vm.taskCount == 3)
    }

    @Test("Empty project produces no items")
    @MainActor
    func emptyProject() async {
        let (vm, _, _, _, _, _) = makeRoadmapVM()

        await vm.load()

        #expect(vm.items.isEmpty)
        #expect(vm.overallProgress == 0)
    }

    @Test("Task items carry effort type and priority")
    @MainActor
    func taskMetadata() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, _) = makeRoadmapVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        let task = PMTask(milestoneId: ms.id, name: "T1", priority: .high, effortType: .deepFocus)
        taskRepo.tasks = [task]

        await vm.load()

        let taskItem = vm.items.first { $0.kind == .task }
        #expect(taskItem?.priority == .high)
        #expect(taskItem?.effortType == .deepFocus)
    }

    @Test("Task dependency detection")
    @MainActor
    func taskDependency() async {
        let (vm, _, phaseRepo, milestoneRepo, taskRepo, depRepo) = makeRoadmapVM()
        let phase = Phase(projectId: vm.project.id, name: "P1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "M1")
        milestoneRepo.milestones = [ms]
        let t1 = PMTask(milestoneId: ms.id, name: "T1", sortOrder: 0, status: .notStarted)
        let t2 = PMTask(milestoneId: ms.id, name: "T2", sortOrder: 1, status: .notStarted)
        taskRepo.tasks = [t1, t2]
        let dep = Dependency(sourceType: .task, sourceId: t1.id, targetType: .task, targetId: t2.id)
        depRepo.dependencies = [dep]

        await vm.load()

        let t2Item = vm.items.first { $0.id == t2.id }
        #expect(t2Item?.hasUnmetDependencies == true)
    }
}
