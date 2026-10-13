import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain
@testable import PMServices

// MARK: - Test Helper

private let retroProjectId = UUID()
private let retroCategoryId = UUID()

@MainActor
func makeRetroManager(llmClient: MockLLMClient = MockLLMClient()) -> (
    RetrospectiveFlowManager, MockLLMClient, MockProjectRepository,
    MockPhaseRepository, MockMilestoneRepository, MockTaskRepository, MockCheckInRepository
) {
    let projectRepo = MockProjectRepository()
    let phaseRepo = MockPhaseRepository()
    let milestoneRepo = MockMilestoneRepository()
    let taskRepo = MockTaskRepository()
    let checkInRepo = MockCheckInRepository()

    let manager = RetrospectiveFlowManager(
        projectRepo: projectRepo,
        phaseRepo: phaseRepo,
        milestoneRepo: milestoneRepo,
        taskRepo: taskRepo,
        checkInRepo: checkInRepo,
        llmClient: llmClient
    )

    return (manager, llmClient, projectRepo, phaseRepo, milestoneRepo, taskRepo, checkInRepo)
}

// MARK: - Tests

@Suite("RetrospectiveFlowManager")
struct RetrospectiveFlowManagerTests {

    @Test("Initial state is idle")
    @MainActor
    func initialState() {
        let (manager, _, _, _, _, _, _) = makeRetroManager()
        #expect(manager.step == .idle)
        #expect(manager.targetPhase == nil)
        #expect(manager.reflectionText == "")
        #expect(manager.messages.isEmpty)
        #expect(manager.aiSummary == nil)
        #expect(manager.returnBriefing == nil)
        #expect(manager.isLoading == false)
        #expect(manager.error == nil)
    }

    @Test("Check phase completion — all milestones completed")
    @MainActor
    func phaseCompletionAllDone() async {
        let (manager, _, _, _, milestoneRepo, _, _) = makeRetroManager()
        let phase = Phase(projectId: retroProjectId, name: "Phase 1")

        milestoneRepo.milestones = [
            Milestone(phaseId: phase.id, name: "M1", status: .completed),
            Milestone(phaseId: phase.id, name: "M2", status: .completed)
        ]

        let result = await manager.checkPhaseCompletion(phase)
        #expect(result == true)
    }

    @Test("Check phase completion — not all milestones done")
    @MainActor
    func phaseCompletionNotDone() async {
        let (manager, _, _, _, milestoneRepo, _, _) = makeRetroManager()
        let phase = Phase(projectId: retroProjectId, name: "Phase 1")

        milestoneRepo.milestones = [
            Milestone(phaseId: phase.id, name: "M1", status: .completed),
            Milestone(phaseId: phase.id, name: "M2", status: .inProgress)
        ]

        let result = await manager.checkPhaseCompletion(phase)
        #expect(result == false)
    }

    @Test("Check phase completion — already has retrospective")
    @MainActor
    func phaseAlreadyRetrospected() async {
        let (manager, _, _, _, milestoneRepo, _, _) = makeRetroManager()
        var phase = Phase(projectId: retroProjectId, name: "Phase 1")
        phase.retrospectiveCompletedAt = Date()

        milestoneRepo.milestones = [
            Milestone(phaseId: phase.id, name: "M1", status: .completed)
        ]

        let result = await manager.checkPhaseCompletion(phase)
        #expect(result == false)
    }

    @Test("Check phase completion — no milestones")
    @MainActor
    func phaseNoMilestones() async {
        let (manager, _, _, _, _, _, _) = makeRetroManager()
        let phase = Phase(projectId: retroProjectId, name: "Empty Phase")

        let result = await manager.checkPhaseCompletion(phase)
        #expect(result == false)
    }

    @Test("Prompt retrospective sets state")
    @MainActor
    func promptRetrospective() {
        let (manager, _, _, _, _, _, _) = makeRetroManager()
        let phase = Phase(projectId: retroProjectId, name: "Phase 1")

        manager.promptRetrospective(for: phase)

        #expect(manager.step == .promptUser)
        #expect(manager.targetPhase?.id == phase.id)
        #expect(manager.reflectionText == "")
    }

    @Test("Begin reflection transitions step")
    @MainActor
    func beginReflection() {
        let (manager, _, _, _, _, _, _) = makeRetroManager()
        let phase = Phase(projectId: retroProjectId, name: "Phase 1")
        manager.promptRetrospective(for: phase)

        manager.beginReflection()

        #expect(manager.step == .reflecting)
    }

    @Test("Snooze sets expiry and returns to idle")
    @MainActor
    func snooze() {
        let (manager, _, _, _, _, _, _) = makeRetroManager()
        let phase = Phase(projectId: retroProjectId, name: "Phase 1")
        manager.promptRetrospective(for: phase)

        manager.snooze(phase, days: 3)

        #expect(manager.step == .idle)
        #expect(manager.targetPhase == nil)
        #expect(manager.snoozedUntil[phase.id] != nil)
    }

    @Test("Snoozed phase returns false for completion check")
    @MainActor
    func snoozedPhaseSkipped() async {
        let (manager, _, _, _, milestoneRepo, _, _) = makeRetroManager()
        let phase = Phase(projectId: retroProjectId, name: "Phase 1")

        milestoneRepo.milestones = [
            Milestone(phaseId: phase.id, name: "M1", status: .completed)
        ]

        manager.snooze(phase, days: 1)

        let result = await manager.checkPhaseCompletion(phase)
        #expect(result == false)
    }

    @Test("Submit reflection triggers AI conversation")
    @MainActor
    func submitReflection() async {
        let client = MockLLMClient()
        client.responseText = "Great reflections! You showed real growth in this phase."
        let (manager, _, projectRepo, phaseRepo, milestoneRepo, _, _) = makeRetroManager(llmClient: client)

        let project = Project(name: "Test", categoryId: retroCategoryId)
        projectRepo.projects = [project]
        let phase = Phase(projectId: project.id, name: "Phase 1")
        phaseRepo.phases = [phase]
        milestoneRepo.milestones = [
            Milestone(phaseId: phase.id, name: "M1", status: .completed)
        ]

        manager.promptRetrospective(for: phase)
        manager.beginReflection()
        manager.reflectionText = "I learned a lot about async patterns."

        await manager.submitReflection()

        #expect(manager.step == .aiConversation)
        #expect(manager.messages.count == 2) // user + assistant
        #expect(manager.aiSummary != nil)
        #expect(manager.error == nil)
    }

    @Test("Submit empty reflection shows error")
    @MainActor
    func submitEmptyReflection() async {
        let (manager, _, _, _, _, _, _) = makeRetroManager()
        let phase = Phase(projectId: retroProjectId, name: "Phase 1")
        manager.promptRetrospective(for: phase)
        manager.beginReflection()
        manager.reflectionText = "   "

        await manager.submitReflection()

        #expect(manager.error != nil)
    }

    @Test("Submit reflection with LLM error")
    @MainActor
    func submitReflectionError() async {
        let client = MockLLMClient()
        client.shouldThrow = true
        let (manager, _, projectRepo, phaseRepo, _, _, _) = makeRetroManager(llmClient: client)

        let project = Project(name: "Test", categoryId: retroCategoryId)
        projectRepo.projects = [project]
        let phase = Phase(projectId: project.id, name: "Phase 1")
        phaseRepo.phases = [phase]

        manager.promptRetrospective(for: phase)
        manager.beginReflection()
        manager.reflectionText = "My thoughts"

        await manager.submitReflection()

        #expect(manager.error != nil)
        #expect(manager.step == .reflecting) // Falls back
    }

    @Test("Send follow-up message")
    @MainActor
    func sendFollowUp() async {
        let client = MockLLMClient()
        client.responseText = "AI response"
        let (manager, _, projectRepo, phaseRepo, _, _, _) = makeRetroManager(llmClient: client)

        let project = Project(name: "Test", categoryId: retroCategoryId)
        projectRepo.projects = [project]
        let phase = Phase(projectId: project.id, name: "Phase 1")
        phaseRepo.phases = [phase]

        manager.promptRetrospective(for: phase)
        manager.beginReflection()
        manager.reflectionText = "Initial thoughts"
        await manager.submitReflection()

        client.responseText = "Follow-up response"
        await manager.sendFollowUp("Tell me more about what went well")

        #expect(manager.messages.count == 4) // user, assistant, user, assistant
    }

    @Test("Complete retrospective saves notes to phase")
    @MainActor
    func completeRetrospective() async {
        let client = MockLLMClient()
        client.responseText = "Great retrospective summary."
        let (manager, _, projectRepo, phaseRepo, _, _, _) = makeRetroManager(llmClient: client)

        let project = Project(name: "Test", categoryId: retroCategoryId)
        projectRepo.projects = [project]
        let phase = Phase(projectId: project.id, name: "Phase 1")
        phaseRepo.phases = [phase]

        manager.promptRetrospective(for: phase)
        manager.beginReflection()
        manager.reflectionText = "Went really well"
        await manager.submitReflection()

        await manager.completeRetrospective()

        #expect(manager.step == .completed)
        let savedPhase = phaseRepo.phases.first { $0.id == phase.id }
        #expect(savedPhase?.retrospectiveNotes != nil)
        #expect(savedPhase?.retrospectiveCompletedAt != nil)
        #expect(savedPhase?.retrospectiveNotes?.contains("Went really well") == true)
    }

    @Test("isDormant detects inactive project")
    @MainActor
    func isDormant() {
        let (manager, _, _, _, _, _, _) = makeRetroManager()

        var project = Project(name: "Old", categoryId: retroCategoryId)
        project.lastWorkedOn = Calendar.current.date(byAdding: .day, value: -20, to: Date())
        #expect(manager.isDormant(project) == true)

        var recent = Project(name: "Recent", categoryId: retroCategoryId)
        recent.lastWorkedOn = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        #expect(manager.isDormant(recent) == false)

        let noDate = Project(name: "Never", categoryId: retroCategoryId)
        #expect(manager.isDormant(noDate) == true)
    }

    @Test("Generate return briefing")
    @MainActor
    func generateReturnBriefing() async {
        let client = MockLLMClient()
        client.responseText = "Welcome back! Here's where you left off..."
        let (manager, _, _, _, _, _, _) = makeRetroManager(llmClient: client)

        var project = Project(name: "Dormant Project", categoryId: retroCategoryId)
        project.lastWorkedOn = Calendar.current.date(byAdding: .day, value: -30, to: Date())

        await manager.generateReturnBriefing(for: project)

        #expect(manager.returnBriefing != nil)
        #expect(manager.returnBriefing?.contains("Welcome back") == true)
        #expect(manager.error == nil)
    }

    @Test("Return briefing with LLM error")
    @MainActor
    func returnBriefingError() async {
        let client = MockLLMClient()
        client.shouldThrow = true
        let (manager, _, _, _, _, _, _) = makeRetroManager(llmClient: client)

        let project = Project(name: "Test", categoryId: retroCategoryId)
        await manager.generateReturnBriefing(for: project)

        #expect(manager.error != nil)
        #expect(manager.returnBriefing == nil)
    }

    @Test("Reset clears all state")
    @MainActor
    func reset() {
        let (manager, _, _, _, _, _, _) = makeRetroManager()
        let phase = Phase(projectId: retroProjectId, name: "Phase 1")
        manager.promptRetrospective(for: phase)
        manager.reflectionText = "Some text"

        manager.reset()

        #expect(manager.step == .idle)
        #expect(manager.targetPhase == nil)
        #expect(manager.reflectionText == "")
        #expect(manager.messages.isEmpty)
        #expect(manager.aiSummary == nil)
        #expect(manager.returnBriefing == nil)
        #expect(manager.error == nil)
    }

    @Test("FlowStep equality")
    @MainActor
    func flowStepEquality() {
        #expect(RetrospectiveFlowManager.FlowStep.idle == RetrospectiveFlowManager.FlowStep.idle)
        #expect(RetrospectiveFlowManager.FlowStep.idle != RetrospectiveFlowManager.FlowStep.completed)
    }

    @Test("Custom dormancy threshold")
    @MainActor
    func customDormancyThreshold() {
        let (manager, _, _, _, _, _, _) = makeRetroManager()
        manager.dormancyThresholdDays = 7

        var project = Project(name: "Test", categoryId: retroCategoryId)
        project.lastWorkedOn = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        #expect(manager.isDormant(project) == true)

        project.lastWorkedOn = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        #expect(manager.isDormant(project) == false)
    }
}
