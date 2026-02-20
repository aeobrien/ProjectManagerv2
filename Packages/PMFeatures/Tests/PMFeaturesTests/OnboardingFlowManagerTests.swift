import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain
@testable import PMServices

// MARK: - Mock Document Repository

final class MockDocumentRepository: DocumentRepositoryProtocol, @unchecked Sendable {
    var documents: [Document] = []
    func fetchAll(forProject projectId: UUID) async throws -> [Document] { documents.filter { $0.projectId == projectId } }
    func fetch(id: UUID) async throws -> Document? { documents.first { $0.id == id } }
    func fetchByType(_ type: DocumentType, projectId: UUID) async throws -> [Document] {
        documents.filter { $0.type == type && $0.projectId == projectId }
    }
    func save(_ document: Document) async throws {
        if let idx = documents.firstIndex(where: { $0.id == document.id }) { documents[idx] = document }
        else { documents.append(document) }
    }
    func delete(id: UUID) async throws { documents.removeAll { $0.id == id } }
    func search(query: String) async throws -> [Document] { documents.filter { $0.title.contains(query) || $0.content.contains(query) } }
}

// MARK: - Onboarding Test Helper

private let obCatId = UUID()

@MainActor
func makeOnboardingManager(llmClient: MockLLMClient = MockLLMClient()) -> (
    OnboardingFlowManager, MockLLMClient, MockProjectRepository,
    MockPhaseRepository, MockMilestoneRepository, MockTaskRepository, MockDocumentRepository
) {
    let projectRepo = MockProjectRepository()
    let phaseRepo = MockPhaseRepository()
    let milestoneRepo = MockMilestoneRepository()
    let taskRepo = MockTaskRepository()
    let documentRepo = MockDocumentRepository()

    let manager = OnboardingFlowManager(
        llmClient: llmClient,
        projectRepo: projectRepo,
        phaseRepo: phaseRepo,
        milestoneRepo: milestoneRepo,
        taskRepo: taskRepo,
        documentRepo: documentRepo
    )

    return (manager, llmClient, projectRepo, phaseRepo, milestoneRepo, taskRepo, documentRepo)
}

// MARK: - Tests

@Suite("OnboardingFlowManager")
struct OnboardingFlowManagerTests {

    @Test("Initial state is brain dump")
    @MainActor
    func initialState() {
        let (manager, _, _, _, _, _, _) = makeOnboardingManager()
        #expect(manager.step == .brainDump)
        #expect(manager.brainDumpText == "")
        #expect(manager.isLoading == false)
        #expect(manager.error == nil)
        #expect(manager.proposedItems.isEmpty)
    }

    @Test("canStartDiscovery requires text")
    @MainActor
    func canStartDiscovery() {
        let (manager, _, _, _, _, _, _) = makeOnboardingManager()
        #expect(manager.canStartDiscovery == false)
        manager.brainDumpText = "Build an app"
        #expect(manager.canStartDiscovery == true)
    }

    @Test("Discovery moves to structure proposal")
    @MainActor
    func discoveryMovesToProposal() async {
        let client = MockLLMClient()
        let msId = UUID()
        client.responseText = "Great idea! [ACTION: CREATE_MILESTONE] phaseId: \(msId) name: MVP Release [/ACTION]"
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "I want to build a todo app"

        await manager.startDiscovery()

        #expect(manager.step == .structureProposal)
        #expect(manager.proposedItems.count == 1)
        #expect(manager.proposedItems.first?.name == "MVP Release")
    }

    @Test("Discovery with empty text shows error")
    @MainActor
    func discoveryEmptyText() async {
        let (manager, _, _, _, _, _, _) = makeOnboardingManager()
        manager.brainDumpText = "  "

        await manager.startDiscovery()

        #expect(manager.error != nil)
        #expect(manager.step == .brainDump)
    }

    @Test("Discovery with LLM error")
    @MainActor
    func discoveryError() async {
        let client = MockLLMClient()
        client.shouldThrow = true
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Test project"

        await manager.startDiscovery()

        #expect(manager.error != nil)
        #expect(manager.step == .brainDump)
    }

    @Test("Toggle item acceptance")
    @MainActor
    func toggleItem() async {
        let client = MockLLMClient()
        let msId = UUID()
        client.responseText = "[ACTION: CREATE_MILESTONE] phaseId: \(msId) name: Test [/ACTION]"
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Project"
        await manager.startDiscovery()

        #expect(manager.proposedItems[0].accepted == true)
        manager.toggleItem(at: 0)
        #expect(manager.proposedItems[0].accepted == false)
    }

    @Test("Accepted item count")
    @MainActor
    func acceptedItemCount() async {
        let client = MockLLMClient()
        let id1 = UUID()
        let id2 = UUID()
        client.responseText = "[ACTION: CREATE_MILESTONE] phaseId: \(id1) name: M1 [/ACTION] [ACTION: CREATE_TASK] milestoneId: \(id2) name: T1 priority: normal [/ACTION]"
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Project"
        await manager.startDiscovery()

        #expect(manager.acceptedItemCount == 2)
        manager.toggleItem(at: 0)
        #expect(manager.acceptedItemCount == 1)
    }

    @Test("Create project from proposal")
    @MainActor
    func createProject() async {
        let client = MockLLMClient()
        let msId = UUID()
        client.responseText = "[ACTION: CREATE_MILESTONE] phaseId: \(msId) name: MVP [/ACTION]"
        let (manager, _, projectRepo, phaseRepo, milestoneRepo, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Build app"
        await manager.startDiscovery()

        await manager.createProject(name: "My App", categoryId: obCatId, definitionOfDone: "Ship it")

        #expect(manager.step == .completed)
        #expect(manager.createdProjectId != nil)
        #expect(projectRepo.projects.count == 1)
        #expect(projectRepo.projects.first?.lifecycleState == .queued)
        #expect(phaseRepo.phases.count == 1)
        #expect(milestoneRepo.milestones.count == 1)
    }

    @Test("Create project transitions Idea to Queued")
    @MainActor
    func ideaToQueued() async {
        let client = MockLLMClient()
        client.responseText = "Simple project, no actions."
        let (manager, _, projectRepo, _, _, _, _) = makeOnboardingManager(llmClient: client)

        var ideaProject = Project(name: "Idea", categoryId: obCatId, lifecycleState: .idea)
        projectRepo.projects = [ideaProject]
        manager.sourceProject = ideaProject
        manager.brainDumpText = "Expand on this idea"

        await manager.startDiscovery()
        await manager.createProject(name: "Real Project", categoryId: obCatId, definitionOfDone: nil)

        let updated = projectRepo.projects.first { $0.id == ideaProject.id }
        #expect(updated?.lifecycleState == .queued)
        #expect(updated?.name == "Real Project")
    }

    @Test("Reset clears all state")
    @MainActor
    func reset() async {
        let client = MockLLMClient()
        client.responseText = "Response"
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Test"
        await manager.startDiscovery()

        manager.reset()

        #expect(manager.step == .brainDump)
        #expect(manager.brainDumpText == "")
        #expect(manager.proposedItems.isEmpty)
        #expect(manager.error == nil)
    }

    @Test("Complexity assessment simple")
    @MainActor
    func complexitySimple() async {
        let client = MockLLMClient()
        client.responseText = "Simple project."
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Quick task"
        await manager.startDiscovery()

        #expect(manager.proposedComplexity == .simple)
    }

    @Test("Source project transcript included in discovery")
    @MainActor
    func sourceProjectTranscript() async {
        let client = MockLLMClient()
        client.responseText = "Got it!"
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)

        var source = Project(name: "Idea", categoryId: obCatId, lifecycleState: .idea)
        source.quickCaptureTranscript = "Voice captured idea"
        manager.sourceProject = source
        manager.brainDumpText = "More details"

        await manager.startDiscovery()

        #expect(manager.step == .structureProposal)
    }

    @Test("ProjectComplexity equality")
    func complexityEquality() {
        #expect(ProjectComplexity.simple == ProjectComplexity.simple)
        #expect(ProjectComplexity.simple != ProjectComplexity.complex)
    }

    @Test("FlowStep equality")
    @MainActor
    func flowStepEquality() {
        #expect(OnboardingFlowManager.FlowStep.brainDump == OnboardingFlowManager.FlowStep.brainDump)
        #expect(OnboardingFlowManager.FlowStep.brainDump != OnboardingFlowManager.FlowStep.completed)
    }
}
