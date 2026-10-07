import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain
@testable import PMServices

// MARK: - Tests

private let analyticsProjectId = UUID()

@Suite("AnalyticsViewModel")
struct AnalyticsViewModelTests {

    @Test("Initial state")
    @MainActor
    func initialState() {
        let vm = AnalyticsViewModel(
            projectRepo: MockProjectRepository(),
            phaseRepo: MockPhaseRepository(),
            milestoneRepo: MockMilestoneRepository(),
            taskRepo: MockTaskRepository()
        )
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(vm.estimateAccuracy == nil)
        #expect(vm.hasEnoughData == false)
    }

    @Test("Load with sufficient data")
    @MainActor
    func loadWithData() async {
        let phaseRepo = MockPhaseRepository()
        let milestoneRepo = MockMilestoneRepository()
        let taskRepo = MockTaskRepository()

        let phase = Phase(projectId: analyticsProjectId, name: "Phase 1")
        phaseRepo.phases = [phase]

        let ms = Milestone(phaseId: phase.id, name: "MS1")
        milestoneRepo.milestones = [ms]

        // Create 5+ tasks with estimates and actuals
        var tasks: [PMTask] = []
        for i in 0..<6 {
            var t = PMTask(milestoneId: ms.id, name: "Task \(i)")
            t.adjustedEstimateMinutes = 60
            t.actualMinutes = 90
            t.status = .completed
            t.completedAt = Date()
            tasks.append(t)
        }
        taskRepo.tasks = tasks

        let vm = AnalyticsViewModel(
            projectRepo: MockProjectRepository(),
            phaseRepo: phaseRepo,
            milestoneRepo: milestoneRepo,
            taskRepo: taskRepo
        )

        await vm.load(projectId: analyticsProjectId)

        #expect(vm.isLoading == false)
        #expect(vm.hasEnoughData == true)
        #expect(vm.estimateAccuracy != nil)
        #expect(vm.suggestedMultiplier != nil)
        #expect(vm.summary != nil)
        #expect(vm.summary?.totalTasks == 6)
    }

    @Test("Load with insufficient data")
    @MainActor
    func loadInsufficientData() async {
        let phaseRepo = MockPhaseRepository()
        let milestoneRepo = MockMilestoneRepository()
        let taskRepo = MockTaskRepository()

        let phase = Phase(projectId: analyticsProjectId, name: "Phase 1")
        phaseRepo.phases = [phase]
        let ms = Milestone(phaseId: phase.id, name: "MS1")
        milestoneRepo.milestones = [ms]
        taskRepo.tasks = [PMTask(milestoneId: ms.id, name: "Just one")]

        let vm = AnalyticsViewModel(
            projectRepo: MockProjectRepository(),
            phaseRepo: phaseRepo,
            milestoneRepo: milestoneRepo,
            taskRepo: taskRepo
        )

        await vm.load(projectId: analyticsProjectId)

        #expect(vm.hasEnoughData == false)
        #expect(vm.estimateAccuracy == nil)
    }

    @Test("Accuracy description neutral language")
    @MainActor
    func accuracyDescription() {
        let vm = AnalyticsViewModel(
            projectRepo: MockProjectRepository(),
            phaseRepo: MockPhaseRepository(),
            milestoneRepo: MockMilestoneRepository(),
            taskRepo: MockTaskRepository()
        )

        let under = vm.accuracyDescription(0.5)
        #expect(under.contains("faster"))

        let over = vm.accuracyDescription(1.8)
        #expect(over.contains("longer"))

        let good = vm.accuracyDescription(1.0)
        #expect(good.contains("close"))
    }

    @Test("Multiplier description neutral language")
    @MainActor
    func multiplierDescription() {
        let vm = AnalyticsViewModel(
            projectRepo: MockProjectRepository(),
            phaseRepo: MockPhaseRepository(),
            milestoneRepo: MockMilestoneRepository(),
            taskRepo: MockTaskRepository()
        )

        let increase = vm.multiplierDescription(1.5)
        #expect(increase.contains("adding"))

        let decrease = vm.multiplierDescription(0.7)
        #expect(decrease.contains("reduced"))

        let good = vm.multiplierDescription(1.0)
        #expect(good.contains("well-calibrated"))
    }
}
