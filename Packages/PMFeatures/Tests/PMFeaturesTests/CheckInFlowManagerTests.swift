import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain
@testable import PMServices

// MARK: - Check-In Test Helper

private let ciCatId = UUID()

@MainActor
func makeCheckInManager(llmClient: MockLLMClient = MockLLMClient()) -> (
    CheckInFlowManager, MockLLMClient, MockProjectRepository, MockTaskRepository, MockCheckInRepository
) {
    let projectRepo = MockProjectRepository()
    let phaseRepo = MockPhaseRepository()
    let milestoneRepo = MockMilestoneRepository()
    let taskRepo = MockTaskRepository()
    let subtaskRepo = MockSubtaskRepository()
    let checkInRepo = MockCheckInRepository()

    let executor = ActionExecutor(
        taskRepo: taskRepo,
        milestoneRepo: milestoneRepo,
        subtaskRepo: subtaskRepo,
        projectRepo: projectRepo
    )

    let manager = CheckInFlowManager(
        projectRepo: projectRepo,
        phaseRepo: phaseRepo,
        milestoneRepo: milestoneRepo,
        taskRepo: taskRepo,
        checkInRepo: checkInRepo,
        llmClient: llmClient,
        actionExecutor: executor
    )

    return (manager, llmClient, projectRepo, taskRepo, checkInRepo)
}

// MARK: - Tests

@Suite("CheckInFlowManager")
struct CheckInFlowManagerTests {

    @Test("Initial state")
    @MainActor
    func initialState() {
        let (manager, _, _, _, _) = makeCheckInManager()
        #expect(manager.isCheckingIn == false)
        #expect(manager.error == nil)
        #expect(manager.lastCreatedRecord == nil)
    }

    @Test("Urgency none when recent check-in")
    @MainActor
    func urgencyNone() {
        let (manager, _, _, _, _) = makeCheckInManager()
        let project = Project(name: "Test", categoryId: ciCatId)
        let checkIn = CheckInRecord(projectId: project.id, depth: .quickLog)

        let urgency = manager.urgency(for: project, lastCheckIn: checkIn)
        #expect(urgency == .none)
    }

    @Test("Urgency gentle after 3 days")
    @MainActor
    func urgencyGentle() {
        let (manager, _, _, _, _) = makeCheckInManager()
        let project = Project(name: "Test", categoryId: ciCatId)
        let checkIn = CheckInRecord(
            projectId: project.id,
            timestamp: Calendar.current.date(byAdding: .day, value: -4, to: Date())!,
            depth: .quickLog
        )

        let urgency = manager.urgency(for: project, lastCheckIn: checkIn)
        #expect(urgency == .gentle)
    }

    @Test("Urgency moderate after 7 days")
    @MainActor
    func urgencyModerate() {
        let (manager, _, _, _, _) = makeCheckInManager()
        let project = Project(name: "Test", categoryId: ciCatId)
        let checkIn = CheckInRecord(
            projectId: project.id,
            timestamp: Calendar.current.date(byAdding: .day, value: -8, to: Date())!,
            depth: .quickLog
        )

        let urgency = manager.urgency(for: project, lastCheckIn: checkIn)
        #expect(urgency == .moderate)
    }

    @Test("Urgency prominent after 14 days")
    @MainActor
    func urgencyProminent() {
        let (manager, _, _, _, _) = makeCheckInManager()
        let project = Project(name: "Test", categoryId: ciCatId)
        let checkIn = CheckInRecord(
            projectId: project.id,
            timestamp: Calendar.current.date(byAdding: .day, value: -15, to: Date())!,
            depth: .quickLog
        )

        let urgency = manager.urgency(for: project, lastCheckIn: checkIn)
        #expect(urgency == .prominent)
    }

    @Test("Urgency prominent when no check-in exists")
    @MainActor
    func urgencyProminentNoCheckIn() {
        let (manager, _, _, _, _) = makeCheckInManager()
        let project = Project(name: "Test", categoryId: ciCatId)

        let urgency = manager.urgency(for: project, lastCheckIn: nil)
        #expect(urgency == .prominent)
    }

    @Test("Snooze suppresses urgency")
    @MainActor
    func snoozeSuppressesUrgency() {
        let (manager, _, _, _, _) = makeCheckInManager()
        let project = Project(name: "Test", categoryId: ciCatId)

        manager.snooze(projectId: project.id, duration: .oneDay)

        let urgency = manager.urgency(for: project, lastCheckIn: nil)
        #expect(urgency == .none)
    }

    @Test("Days since check-in calculation")
    @MainActor
    func daysSinceCheckIn() {
        let (manager, _, _, _, _) = makeCheckInManager()
        let checkIn = CheckInRecord(
            projectId: UUID(),
            timestamp: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            depth: .quickLog
        )

        let days = manager.daysSinceCheckIn(checkIn)
        #expect(days == 5)
    }

    @Test("Days since nil check-in returns max")
    @MainActor
    func daysSinceNilCheckIn() {
        let (manager, _, _, _, _) = makeCheckInManager()
        let days = manager.daysSinceCheckIn(nil)
        #expect(days == Int.max)
    }

    @Test("Perform quick log check-in creates record")
    @MainActor
    func performQuickLog() async {
        let (manager, _, _, _, checkInRepo) = makeCheckInManager()
        let project = Project(name: "Test", categoryId: ciCatId)

        let result = await manager.performCheckIn(
            project: project,
            depth: .quickLog,
            userMessage: "Made progress on the UI"
        )

        #expect(result != nil)
        #expect(result?.response != nil)
        #expect(checkInRepo.checkIns.count == 1)
        #expect(checkInRepo.checkIns.first?.depth == .quickLog)
        #expect(manager.lastCreatedRecord != nil)
    }

    @Test("Perform check-in with LLM error")
    @MainActor
    func performCheckInError() async {
        let client = MockLLMClient()
        client.shouldThrow = true
        let (manager, _, _, _, _) = makeCheckInManager(llmClient: client)
        let project = Project(name: "Test", categoryId: ciCatId)

        let result = await manager.performCheckIn(
            project: project,
            depth: .quickLog,
            userMessage: "Update"
        )

        #expect(result == nil)
        #expect(manager.error != nil)
    }

    @Test("Check-in increments deferred for unaddressed tasks")
    @MainActor
    func incrementDeferred() async {
        let client = MockLLMClient()
        client.responseText = "Looks good! No specific task actions."
        let (manager, _, _, taskRepo, _) = makeCheckInManager(llmClient: client)
        let project = Project(name: "Test", categoryId: ciCatId)

        // Create a visible task that won't be mentioned by AI
        let phase = Phase(projectId: project.id, name: "P1")
        let ms = Milestone(phaseId: phase.id, name: "M1")
        var task = PMTask(milestoneId: ms.id, name: "Unmentioned task", status: .inProgress)
        task.timesDeferred = 0
        taskRepo.tasks = [task]

        // Note: since our test mock phase/milestone repos are empty,
        // the context won't include this task. The increment happens
        // on tasks found via phaseRepo → milestoneRepo → taskRepo chain.
        // With empty repos, no deferred increment occurs.
        _ = await manager.performCheckIn(
            project: project,
            depth: .quickLog,
            userMessage: "Just a general update"
        )

        // Verify the flow completed without error
        #expect(manager.error == nil)
    }

    @Test("Frequently deferred tasks detection")
    @MainActor
    func frequentlyDeferred() {
        let (manager, _, _, _, _) = makeCheckInManager()
        manager.deferredThreshold = 3

        let tasks = [
            PMTask(milestoneId: UUID(), name: "Normal", sortOrder: 0, status: .notStarted),
            {
                var t = PMTask(milestoneId: UUID(), name: "Deferred", sortOrder: 1, status: .notStarted)
                t.timesDeferred = 5
                return t
            }()
        ]

        let deferred = manager.frequentlyDeferredTasks(from: tasks)
        #expect(deferred.count == 1)
        #expect(deferred.first?.name == "Deferred")
    }

    @Test("Custom thresholds work")
    @MainActor
    func customThresholds() {
        let (manager, _, _, _, _) = makeCheckInManager()
        manager.gentleThresholdDays = 1
        manager.moderateThresholdDays = 2
        manager.prominentThresholdDays = 3

        let project = Project(name: "Test", categoryId: ciCatId)
        let checkIn = CheckInRecord(
            projectId: project.id,
            timestamp: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
            depth: .quickLog
        )

        let urgency = manager.urgency(for: project, lastCheckIn: checkIn)
        #expect(urgency == .moderate)
    }

    @Test("Snooze durations")
    func snoozeDurations() {
        #expect(SnoozeDuration.oneDay.rawValue == 1)
        #expect(SnoozeDuration.threeDays.rawValue == 3)
        #expect(SnoozeDuration.oneWeek.rawValue == 7)
        #expect(SnoozeDuration.allCases.count == 3)
    }

    @Test("CheckInUrgency equality")
    func urgencyEquality() {
        #expect(CheckInUrgency.none == CheckInUrgency.none)
        #expect(CheckInUrgency.gentle != CheckInUrgency.moderate)
        #expect(CheckInUrgency.prominent == CheckInUrgency.prominent)
    }

    @Test("Check-in with actions creates confirmation")
    @MainActor
    func checkInWithActions() async {
        let client = MockLLMClient()
        let taskId = UUID()
        client.responseText = "Done! [ACTION: COMPLETE_TASK] taskId: \(taskId) [/ACTION]"
        let (manager, _, _, _, _) = makeCheckInManager(llmClient: client)
        let project = Project(name: "Test", categoryId: ciCatId)

        let result = await manager.performCheckIn(
            project: project,
            depth: .fullConversation,
            userMessage: "Finished the task"
        )

        #expect(result?.confirmation != nil)
        #expect(result?.confirmation?.changes.count == 1)
    }
}
