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

// MARK: - Mock Document Version Repository

final class MockDocumentVersionRepository: DocumentVersionRepositoryProtocol, @unchecked Sendable {
    var versions: [DocumentVersion] = []
    func fetchAll(forDocument documentId: UUID) async throws -> [DocumentVersion] {
        versions.filter { $0.documentId == documentId }.sorted { $0.version > $1.version }
    }
    func save(_ version: DocumentVersion) async throws {
        versions.append(version)
    }
    func deleteAll(forDocument documentId: UUID) async throws {
        versions.removeAll { $0.documentId == documentId }
    }
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

        let ideaProject = Project(name: "Idea", categoryId: obCatId, lifecycleState: .idea)
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

    // MARK: - Complexity Assessment

    @Test("Complexity medium with 5+ tasks")
    @MainActor
    func complexityMedium() async {
        let client = MockLLMClient()
        let msId = UUID()
        // 5 tasks → medium complexity
        var actions = "[ACTION: CREATE_MILESTONE] phaseId: \(msId)\nname: MS1 [/ACTION]"
        for i in 1...5 {
            actions += " [ACTION: CREATE_TASK] milestoneId: \(UUID())\nname: Task \(i)\npriority: normal [/ACTION]"
        }
        client.responseText = "Here's the plan. \(actions)"
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Medium project"

        await manager.startDiscovery()

        #expect(manager.proposedComplexity == .medium)
        #expect(manager.proposedItems.filter { $0.kind == .task }.count == 5)
    }

    @Test("Complexity complex with 10+ tasks")
    @MainActor
    func complexityComplex() async {
        let client = MockLLMClient()
        let msId = UUID()
        var actions = "[ACTION: CREATE_MILESTONE] phaseId: \(msId)\nname: MS1 [/ACTION]"
        for i in 1...10 {
            actions += " [ACTION: CREATE_TASK] milestoneId: \(UUID())\nname: Task \(i)\npriority: normal [/ACTION]"
        }
        client.responseText = "Complex plan. \(actions)"
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Complex project"

        await manager.startDiscovery()

        #expect(manager.proposedComplexity == .complex)
    }

    // MARK: - Document Generation

    @Test("Generate documents creates vision statement")
    @MainActor
    func generateDocumentsVision() async {
        let client = MockLLMClient()
        client.responseText = "No actions."
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Build a todo app"
        await manager.startDiscovery()

        // Now generate documents
        client.responseText = "This is the vision statement for the project."
        await manager.generateDocuments()

        #expect(manager.generatedVision != nil)
        #expect(manager.generatedVision == "This is the vision statement for the project.")
    }

    @Test("Generate documents creates tech brief for complex")
    @MainActor
    func generateDocumentsTechBrief() async {
        let client = MockLLMClient()
        let msId = UUID()
        // 10 tasks → complex
        var actions = "[ACTION: CREATE_MILESTONE] phaseId: \(msId)\nname: MS1 [/ACTION]"
        for i in 1...10 {
            actions += " [ACTION: CREATE_TASK] milestoneId: \(UUID())\nname: T\(i)\npriority: normal [/ACTION]"
        }
        client.responseText = "Plan. \(actions)"
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Big project"
        await manager.startDiscovery()
        #expect(manager.proposedComplexity == .complex)

        // Generate documents — first call returns vision, second returns brief
        client.responseText = "Vision content"
        await manager.generateDocuments()

        #expect(manager.generatedVision != nil)
        #expect(manager.generatedTechBrief != nil)
    }

    @Test("Create project saves documents for medium complexity")
    @MainActor
    func createProjectSavesDocuments() async {
        let client = MockLLMClient()
        let msId = UUID()
        // 5 tasks → medium complexity
        var actions = "[ACTION: CREATE_MILESTONE] phaseId: \(msId)\nname: MS1 [/ACTION]"
        for i in 1...5 {
            actions += " [ACTION: CREATE_TASK] milestoneId: \(UUID())\nname: T\(i)\npriority: normal [/ACTION]"
        }
        client.responseText = "Plan. \(actions)"
        let (manager, _, _, _, _, _, docRepo) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Medium project"
        await manager.startDiscovery()
        #expect(manager.proposedComplexity == .medium)

        // generateDocuments will be called automatically during createProject
        client.responseText = "Generated vision statement"
        await manager.createProject(name: "MediumApp", categoryId: obCatId, definitionOfDone: nil)

        #expect(manager.step == .completed)
        let visionDocs = docRepo.documents.filter { $0.type == .visionStatement }
        #expect(visionDocs.count == 1)
        #expect(visionDocs.first?.content == "Generated vision statement")
    }

    // MARK: - Task Attributes

    @Test("Tasks extract priority and effort from actions")
    @MainActor
    func taskAttributesExtracted() async {
        let client = MockLLMClient()
        let msId = UUID()
        let taskMsId = UUID()
        client.responseText = "[ACTION: CREATE_MILESTONE] phaseId: \(msId)\nname: Build [/ACTION] [ACTION: CREATE_TASK] milestoneId: \(taskMsId)\nname: Setup\npriority: high\neffortType: deepFocus [/ACTION]"
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Test"

        await manager.startDiscovery()

        let taskItem = manager.proposedItems.first { $0.kind == .task }
        #expect(taskItem != nil)
        #expect(taskItem?.name == "Setup")
        #expect(taskItem?.priority == .high)
        #expect(taskItem?.effortType == .deepFocus)
    }

    @Test("Tasks parented under correct milestone")
    @MainActor
    func taskParenting() async {
        let client = MockLLMClient()
        let ms1Id = UUID()
        let ms2Id = UUID()
        let tId = UUID()
        client.responseText = "[ACTION: CREATE_MILESTONE] phaseId: \(ms1Id)\nname: Design [/ACTION] [ACTION: CREATE_MILESTONE] phaseId: \(ms2Id)\nname: Build [/ACTION] [ACTION: CREATE_TASK] milestoneId: \(tId)\nname: Wire UI\npriority: normal [/ACTION]"
        let (manager, _, _, _, _, _, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Test"

        await manager.startDiscovery()

        let taskItem = manager.proposedItems.first { $0.kind == .task }
        #expect(taskItem?.parentName == "Build") // Last milestone before this task
    }

    // MARK: - Hierarchy Creation

    @Test("Create hierarchy distributes tasks across milestones")
    @MainActor
    func hierarchyDistribution() async {
        let client = MockLLMClient()
        let id1 = UUID()
        let id2 = UUID()
        let tId1 = UUID()
        let tId2 = UUID()
        // Two milestones, two tasks — first task after first milestone, second task after second milestone
        client.responseText = "[ACTION: CREATE_MILESTONE] phaseId: \(id1)\nname: Alpha [/ACTION] [ACTION: CREATE_TASK] milestoneId: \(tId1)\nname: Task A\npriority: normal [/ACTION] [ACTION: CREATE_MILESTONE] phaseId: \(id2)\nname: Beta [/ACTION] [ACTION: CREATE_TASK] milestoneId: \(tId2)\nname: Task B\npriority: normal [/ACTION]"
        let (manager, _, _, _, milestoneRepo, taskRepo, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Multi-milestone project"
        await manager.startDiscovery()

        await manager.createProject(name: "Dist Test", categoryId: obCatId, definitionOfDone: nil)

        #expect(milestoneRepo.milestones.count == 2)
        #expect(taskRepo.tasks.count == 2)

        // Task A should be under Alpha, Task B under Beta
        let alphaMs = milestoneRepo.milestones.first { $0.name == "Alpha" }
        let betaMs = milestoneRepo.milestones.first { $0.name == "Beta" }
        let taskA = taskRepo.tasks.first { $0.name == "Task A" }
        let taskB = taskRepo.tasks.first { $0.name == "Task B" }
        #expect(taskA?.milestoneId == alphaMs?.id)
        #expect(taskB?.milestoneId == betaMs?.id)
    }

    @Test("Create hierarchy creates default phase and milestone when needed")
    @MainActor
    func hierarchyDefaults() async {
        let client = MockLLMClient()
        let tId = UUID()
        // Only tasks, no milestones or phases
        client.responseText = "[ACTION: CREATE_TASK] milestoneId: \(tId)\nname: Solo Task\npriority: normal [/ACTION]"
        let (manager, _, _, phaseRepo, milestoneRepo, taskRepo, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Simple project"
        await manager.startDiscovery()

        await manager.createProject(name: "Defaults", categoryId: obCatId, definitionOfDone: nil)

        #expect(phaseRepo.phases.count == 1)
        #expect(phaseRepo.phases.first?.name == "Phase 1")
        #expect(milestoneRepo.milestones.count == 1)
        #expect(milestoneRepo.milestones.first?.name == "Milestone 1")
        #expect(taskRepo.tasks.count == 1)
    }

    @Test("Task attributes propagate to created PMTask")
    @MainActor
    func taskAttributesPropagate() async {
        let client = MockLLMClient()
        let msId = UUID()
        let tId = UUID()
        client.responseText = "[ACTION: CREATE_MILESTONE] phaseId: \(msId)\nname: Build [/ACTION] [ACTION: CREATE_TASK] milestoneId: \(tId)\nname: Setup DB\npriority: high\neffortType: deepFocus [/ACTION]"
        let (manager, _, _, _, _, taskRepo, _) = makeOnboardingManager(llmClient: client)
        manager.brainDumpText = "Test"
        await manager.startDiscovery()

        await manager.createProject(name: "AttrTest", categoryId: obCatId, definitionOfDone: nil)

        let task = taskRepo.tasks.first { $0.name == "Setup DB" }
        #expect(task != nil)
        #expect(task?.priority == .high)
        #expect(task?.effortType == .deepFocus)
    }
}
