import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain

@Suite("CrossProjectRoadmapViewModel")
struct CrossProjectRoadmapViewModelTests {

    @MainActor
    private func makeVM() -> (
        CrossProjectRoadmapViewModel, MockProjectRepository, MockPhaseRepository, MockMilestoneRepository
    ) {
        let projectRepo = MockProjectRepository()
        let phaseRepo = MockPhaseRepository()
        let milestoneRepo = MockMilestoneRepository()

        let vm = CrossProjectRoadmapViewModel(
            projectRepo: projectRepo,
            phaseRepo: phaseRepo,
            milestoneRepo: milestoneRepo
        )

        return (vm, projectRepo, phaseRepo, milestoneRepo)
    }

    @Test("Initial state")
    @MainActor
    func initialState() {
        let (vm, _, _, _) = makeVM()
        #expect(vm.milestones.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(vm.projectCount == 0)
        #expect(vm.upcomingDeadlines.isEmpty)
        #expect(vm.unscheduled.isEmpty)
        #expect(vm.overdue.isEmpty)
    }

    @Test("Load milestones from focused projects")
    @MainActor
    func loadMilestones() async {
        let (vm, projectRepo, phaseRepo, milestoneRepo) = makeVM()

        var project = Project(name: "App", categoryId: UUID())
        project.focusSlotIndex = 0
        project.lifecycleState = .focused
        projectRepo.projects = [project]

        let phase = Phase(projectId: project.id, name: "Phase 1")
        phaseRepo.phases = [phase]

        let ms1 = Milestone(phaseId: phase.id, name: "MVP", deadline: Date().addingTimeInterval(86400 * 7))
        let ms2 = Milestone(phaseId: phase.id, name: "Beta", deadline: Date().addingTimeInterval(86400 * 14))
        milestoneRepo.milestones = [ms1, ms2]

        await vm.load()

        #expect(vm.milestones.count == 2)
        #expect(vm.projectCount == 1)
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
    }

    @Test("Milestones sorted by deadline, unscheduled last")
    @MainActor
    func sortOrder() async {
        let (vm, projectRepo, phaseRepo, milestoneRepo) = makeVM()

        var project = Project(name: "App", categoryId: UUID())
        project.focusSlotIndex = 0
        project.lifecycleState = .focused
        projectRepo.projects = [project]

        let phase = Phase(projectId: project.id, name: "P1")
        phaseRepo.phases = [phase]

        let soon = Date().addingTimeInterval(86400)
        let later = Date().addingTimeInterval(86400 * 30)

        let ms1 = Milestone(phaseId: phase.id, name: "Later", deadline: later)
        let ms2 = Milestone(phaseId: phase.id, name: "Soon", deadline: soon)
        let ms3 = Milestone(phaseId: phase.id, name: "No Date")
        milestoneRepo.milestones = [ms1, ms2, ms3]

        await vm.load()

        #expect(vm.milestones.count == 3)
        #expect(vm.milestones[0].milestoneName == "Soon")
        #expect(vm.milestones[1].milestoneName == "Later")
        #expect(vm.milestones[2].milestoneName == "No Date")
    }

    @Test("Upcoming deadlines filters and sorts")
    @MainActor
    func upcomingDeadlines() async {
        let (vm, projectRepo, phaseRepo, milestoneRepo) = makeVM()

        var project = Project(name: "App", categoryId: UUID())
        project.focusSlotIndex = 0
        project.lifecycleState = .focused
        projectRepo.projects = [project]

        let phase = Phase(projectId: project.id, name: "P1")
        phaseRepo.phases = [phase]

        milestoneRepo.milestones = [
            Milestone(phaseId: phase.id, name: "Has Date", deadline: Date().addingTimeInterval(86400)),
            Milestone(phaseId: phase.id, name: "No Date"),
        ]

        await vm.load()

        #expect(vm.upcomingDeadlines.count == 1)
        #expect(vm.upcomingDeadlines[0].milestoneName == "Has Date")
        #expect(vm.unscheduled.count == 1)
        #expect(vm.unscheduled[0].milestoneName == "No Date")
    }

    @Test("Overdue milestones detected")
    @MainActor
    func overdueDetection() async {
        let (vm, projectRepo, phaseRepo, milestoneRepo) = makeVM()

        var project = Project(name: "App", categoryId: UUID())
        project.focusSlotIndex = 0
        project.lifecycleState = .focused
        projectRepo.projects = [project]

        let phase = Phase(projectId: project.id, name: "P1")
        phaseRepo.phases = [phase]

        let pastDate = Date().addingTimeInterval(-86400 * 3)
        milestoneRepo.milestones = [
            Milestone(phaseId: phase.id, name: "Overdue", status: .inProgress, deadline: pastDate),
            Milestone(phaseId: phase.id, name: "Completed", status: .completed, deadline: pastDate),
            Milestone(phaseId: phase.id, name: "Future", deadline: Date().addingTimeInterval(86400 * 10)),
        ]

        await vm.load()

        #expect(vm.overdue.count == 1)
        #expect(vm.overdue[0].milestoneName == "Overdue")
    }

    @Test("Multiple projects with color indices")
    @MainActor
    func multipleProjects() async {
        let (vm, projectRepo, phaseRepo, milestoneRepo) = makeVM()

        var p1 = Project(name: "Alpha", categoryId: UUID())
        p1.focusSlotIndex = 0
        p1.lifecycleState = .focused
        var p2 = Project(name: "Beta", categoryId: UUID())
        p2.focusSlotIndex = 1
        p2.lifecycleState = .focused
        projectRepo.projects = [p1, p2]

        let phase1 = Phase(projectId: p1.id, name: "P1")
        let phase2 = Phase(projectId: p2.id, name: "P2")
        phaseRepo.phases = [phase1, phase2]

        milestoneRepo.milestones = [
            Milestone(phaseId: phase1.id, name: "A-MS1", deadline: Date().addingTimeInterval(86400)),
            Milestone(phaseId: phase2.id, name: "B-MS1", deadline: Date().addingTimeInterval(86400 * 2)),
        ]

        await vm.load()

        #expect(vm.milestones.count == 2)
        #expect(vm.projectCount == 2)
        #expect(vm.milestonesByProject.keys.count == 2)

        let alphaMs = vm.milestones.first { $0.projectName == "Alpha" }
        let betaMs = vm.milestones.first { $0.projectName == "Beta" }
        #expect(alphaMs?.colorIndex == 0)
        #expect(betaMs?.colorIndex == 1)
    }

    @Test("Filter milestones by status")
    @MainActor
    func filterByStatus() async {
        let (vm, projectRepo, phaseRepo, milestoneRepo) = makeVM()

        var project = Project(name: "App", categoryId: UUID())
        project.focusSlotIndex = 0
        project.lifecycleState = .focused
        projectRepo.projects = [project]

        let phase = Phase(projectId: project.id, name: "P1")
        phaseRepo.phases = [phase]

        milestoneRepo.milestones = [
            Milestone(phaseId: phase.id, name: "Done", status: .completed),
            Milestone(phaseId: phase.id, name: "WIP", status: .inProgress),
            Milestone(phaseId: phase.id, name: "New", status: .notStarted),
        ]

        await vm.load()

        #expect(vm.milestones(with: .completed).count == 1)
        #expect(vm.milestones(with: .inProgress).count == 1)
        #expect(vm.milestones(with: .notStarted).count == 1)
        #expect(vm.milestones(with: .blocked).count == 0)
    }

    @Test("Empty focused projects")
    @MainActor
    func emptyProjects() async {
        let (vm, _, _, _) = makeVM()

        await vm.load()

        #expect(vm.milestones.isEmpty)
        #expect(vm.projectCount == 0)
        #expect(vm.error == nil)
    }

    @Test("CrossProjectMilestone equality")
    func milestoneEquality() {
        let id = UUID()
        let projectId = UUID()
        let date = Date()

        let a = CrossProjectMilestone(
            id: id, milestoneName: "MVP", projectName: "App",
            projectId: projectId, deadline: date, status: .inProgress, colorIndex: 0
        )
        let b = CrossProjectMilestone(
            id: id, milestoneName: "MVP", projectName: "App",
            projectId: projectId, deadline: date, status: .inProgress, colorIndex: 0
        )
        #expect(a == b)
    }

    @Test("Milestones grouped by project")
    @MainActor
    func milestonesByProject() async {
        let (vm, projectRepo, phaseRepo, milestoneRepo) = makeVM()

        var p1 = Project(name: "Alpha", categoryId: UUID())
        p1.focusSlotIndex = 0
        p1.lifecycleState = .focused
        var p2 = Project(name: "Beta", categoryId: UUID())
        p2.focusSlotIndex = 1
        p2.lifecycleState = .focused
        projectRepo.projects = [p1, p2]

        let phase1 = Phase(projectId: p1.id, name: "P1")
        let phase2 = Phase(projectId: p2.id, name: "P2")
        phaseRepo.phases = [phase1, phase2]

        milestoneRepo.milestones = [
            Milestone(phaseId: phase1.id, name: "A1"),
            Milestone(phaseId: phase1.id, name: "A2"),
            Milestone(phaseId: phase2.id, name: "B1"),
        ]

        await vm.load()

        let grouped = vm.milestonesByProject
        #expect(grouped[p1.id]?.count == 2)
        #expect(grouped[p2.id]?.count == 1)
    }
}
