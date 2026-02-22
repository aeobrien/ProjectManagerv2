import Foundation
import PMData
import PMDomain
import PMServices
import PMUtilities
import os

/// Complexity assessment for a project.
public enum ProjectComplexity: String, Sendable, Equatable {
    case simple   // Direct to milestones
    case medium   // Vision statement + milestones
    case complex  // Vision + technical brief + full planning
}

/// A proposed structure item from AI onboarding.
public struct ProposedStructureItem: Identifiable, Sendable {
    public let id = UUID()
    public let kind: StructureItemKind
    public let name: String
    public let parentName: String?
    public var accepted: Bool

    // Task-specific attributes
    public let priority: Priority?
    public let effortType: EffortType?
    public let timeEstimateMinutes: Int?

    public init(
        kind: StructureItemKind,
        name: String,
        parentName: String? = nil,
        accepted: Bool = true,
        priority: Priority? = nil,
        effortType: EffortType? = nil,
        timeEstimateMinutes: Int? = nil
    ) {
        self.kind = kind
        self.name = name
        self.parentName = parentName
        self.accepted = accepted
        self.priority = priority
        self.effortType = effortType
        self.timeEstimateMinutes = timeEstimateMinutes
    }
}

/// Kind of proposed structure item.
public enum StructureItemKind: String, Sendable {
    case phase
    case milestone
    case task
}

/// Manages the project onboarding flow: brain dump → AI discovery → structure proposal → creation.
@Observable
@MainActor
public final class OnboardingFlowManager {
    // MARK: - State

    public enum FlowStep: Sendable, Equatable {
        case brainDump
        case aiDiscovery
        case structureProposal
        case creatingProject
        case completed
    }

    public private(set) var step: FlowStep = .brainDump
    public var brainDumpText: String = ""
    public private(set) var aiResponse: String = ""
    public private(set) var proposedComplexity: ProjectComplexity = .simple
    public private(set) var proposedItems: [ProposedStructureItem] = []
    public private(set) var generatedVision: String?
    public private(set) var generatedTechBrief: String?
    public private(set) var isLoading = false
    public private(set) var error: String?
    public private(set) var createdProjectId: UUID?

    /// The Idea-state project being onboarded (if any).
    public var sourceProject: Project?

    // MARK: - Dependencies

    private let llmClient: LLMClientProtocol
    private let actionParser: ActionParser
    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let documentRepo: DocumentRepositoryProtocol
    private let contextAssembler: ContextAssembler

    /// Optional sync manager for tracking changes.
    public var syncManager: SyncManager?

    // MARK: - Init

    public init(
        llmClient: LLMClientProtocol,
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        documentRepo: DocumentRepositoryProtocol,
        contextAssembler: ContextAssembler = ContextAssembler()
    ) {
        self.llmClient = llmClient
        self.actionParser = ActionParser()
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.milestoneRepo = milestoneRepo
        self.taskRepo = taskRepo
        self.documentRepo = documentRepo
        self.contextAssembler = contextAssembler
    }

    // MARK: - Flow

    /// Start the AI discovery conversation from the brain dump.
    public func startDiscovery() async {
        let text = brainDumpText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            error = "Please describe your project idea."
            return
        }

        isLoading = true
        error = nil
        step = .aiDiscovery

        do {
            // Include source project transcript if available
            var fullText = text
            if let transcript = sourceProject?.quickCaptureTranscript, !transcript.isEmpty {
                fullText = "Original capture: \(transcript)\n\nAdditional details: \(text)"
            }

            let history = [LLMMessage(role: .user, content: fullText)]
            let payload = try await contextAssembler.assemble(
                conversationType: .onboarding,
                projectContext: nil,
                conversationHistory: history
            )

            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: payload.messages, config: config)

            let parsed = actionParser.parse(response.content)
            aiResponse = parsed.naturalLanguage

            // Extract proposed structure from actions
            proposedItems = extractStructure(from: parsed.actions)
            proposedComplexity = assessComplexity(items: proposedItems)

            step = .structureProposal
            let count = proposedItems.count
            let complexity = proposedComplexity.rawValue
            Log.ai.info("Onboarding discovery complete: \(count) items, \(complexity) complexity")
        } catch {
            self.error = "Discovery failed: \(error.localizedDescription)"
            step = .brainDump
            Log.ai.error("Onboarding discovery failed: \(error)")
        }

        isLoading = false
    }

    /// Create the project from the accepted proposal.
    public func createProject(name: String, categoryId: UUID, definitionOfDone: String?) async {
        isLoading = true
        error = nil
        step = .creatingProject

        do {
            // Create or update project
            var project: Project
            if var existing = sourceProject {
                existing.name = name
                existing.categoryId = categoryId
                existing.definitionOfDone = definitionOfDone
                existing.lifecycleState = .queued
                try await projectRepo.save(existing)
                syncManager?.trackChange(entityType: .project, entityId: existing.id, changeType: .update)
                project = existing
            } else {
                project = Project(
                    name: name,
                    categoryId: categoryId,
                    lifecycleState: .queued,
                    definitionOfDone: definitionOfDone
                )
                try await projectRepo.save(project)
                syncManager?.trackChange(entityType: .project, entityId: project.id, changeType: .create)
            }

            // Create accepted phases, milestones, and tasks
            let acceptedItems = proposedItems.filter(\.accepted)
            try await createHierarchy(acceptedItems, projectId: project.id)

            // Generate documents if not already generated
            if (proposedComplexity == .medium || proposedComplexity == .complex) && generatedVision == nil {
                await generateDocuments()
            }

            // Save documents based on complexity
            if proposedComplexity == .medium || proposedComplexity == .complex {
                if let vision = generatedVision {
                    let doc = Document(
                        projectId: project.id,
                        type: .visionStatement,
                        title: "Vision Statement",
                        content: vision
                    )
                    try await documentRepo.save(doc)
                    syncManager?.trackChange(entityType: .document, entityId: doc.id, changeType: .create)
                }
            }
            if proposedComplexity == .complex {
                if let brief = generatedTechBrief {
                    let doc = Document(
                        projectId: project.id,
                        type: .technicalBrief,
                        title: "Technical Brief",
                        content: brief
                    )
                    try await documentRepo.save(doc)
                    syncManager?.trackChange(entityType: .document, entityId: doc.id, changeType: .create)
                }
            }

            createdProjectId = project.id
            step = .completed
            Log.ai.info("Onboarding complete: created project '\(name)' with \(acceptedItems.count) items")
        } catch {
            self.error = "Failed to create project: \(error.localizedDescription)"
            step = .structureProposal
            Log.ai.error("Onboarding project creation failed: \(error)")
        }

        isLoading = false
    }

    /// Generate vision and/or technical brief documents via AI.
    public func generateDocuments() async {
        isLoading = true

        do {
            let structureSummary = proposedItems.filter(\.accepted).map { "\($0.kind.rawValue): \($0.name)" }.joined(separator: "\n")
            let prompt = """
            Based on this project description and structure, generate a vision statement:

            Description: \(brainDumpText)

            Structure:
            \(structureSummary)
            """

            let messages = [
                LLMMessage(role: .system, content: PromptTemplates.behaviouralContract),
                LLMMessage(role: .user, content: prompt)
            ]
            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: messages, config: config)
            generatedVision = response.content

            if proposedComplexity == .complex {
                let briefPrompt = "Now generate a technical brief for implementation. Include architecture decisions, tech stack recommendations, and key constraints."
                let briefMessages = messages + [
                    LLMMessage(role: .assistant, content: response.content),
                    LLMMessage(role: .user, content: briefPrompt)
                ]
                let briefResponse = try await llmClient.send(messages: briefMessages, config: config)
                generatedTechBrief = briefResponse.content
            }
        } catch {
            self.error = "Document generation failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Toggle acceptance of a structure item.
    public func toggleItem(at index: Int) {
        guard index < proposedItems.count else { return }
        proposedItems[index].accepted.toggle()
    }

    /// Reset the flow to start over.
    public func reset() {
        step = .brainDump
        brainDumpText = ""
        aiResponse = ""
        proposedItems = []
        generatedVision = nil
        generatedTechBrief = nil
        error = nil
        createdProjectId = nil
    }

    // MARK: - Helpers

    private func assessComplexity(items: [ProposedStructureItem]) -> ProjectComplexity {
        let phaseCount = items.filter { $0.kind == .phase }.count
        let taskCount = items.filter { $0.kind == .task }.count
        if phaseCount >= 3 || taskCount >= 10 { return .complex }
        if phaseCount >= 2 || taskCount >= 5 { return .medium }
        return .simple
    }

    private func extractStructure(from actions: [AIAction]) -> [ProposedStructureItem] {
        var items: [ProposedStructureItem] = []
        // Track the last milestone name for parenting tasks
        var lastMilestoneName: String?
        for action in actions {
            switch action {
            case .createMilestone(_, let name):
                lastMilestoneName = name
                items.append(ProposedStructureItem(kind: .milestone, name: name))
            case .createTask(_, let name, let priority, let effortType):
                items.append(ProposedStructureItem(
                    kind: .task,
                    name: name,
                    parentName: lastMilestoneName,
                    priority: priority,
                    effortType: effortType
                ))
            default:
                break
            }
        }
        return items
    }

    private func createHierarchy(_ items: [ProposedStructureItem], projectId: UUID) async throws {
        // Group items by kind
        let phases = items.filter { $0.kind == .phase }
        let milestones = items.filter { $0.kind == .milestone }
        let tasks = items.filter { $0.kind == .task }

        // Create a default phase if none proposed but milestones/tasks exist
        let phase: Phase
        if let firstPhase = phases.first {
            phase = Phase(projectId: projectId, name: firstPhase.name)
        } else {
            phase = Phase(projectId: projectId, name: "Phase 1")
        }
        try await phaseRepo.save(phase)
        syncManager?.trackChange(entityType: .phase, entityId: phase.id, changeType: .create)

        // Create additional phases
        for (index, phaseItem) in phases.dropFirst().enumerated() {
            let p = Phase(projectId: projectId, name: phaseItem.name, sortOrder: index + 1)
            try await phaseRepo.save(p)
            syncManager?.trackChange(entityType: .phase, entityId: p.id, changeType: .create)
        }

        // Create milestones under first phase, tracking name→milestone for task parenting
        var milestonesByName: [String: Milestone] = [:]
        var firstMilestone: Milestone?
        for (index, msItem) in milestones.enumerated() {
            let ms = Milestone(phaseId: phase.id, name: msItem.name, sortOrder: index)
            try await milestoneRepo.save(ms)
            syncManager?.trackChange(entityType: .milestone, entityId: ms.id, changeType: .create)
            milestonesByName[msItem.name] = ms
            if firstMilestone == nil { firstMilestone = ms }
        }

        // If no milestones but tasks exist, create a default one
        if milestonesByName.isEmpty && !tasks.isEmpty {
            let ms = Milestone(phaseId: phase.id, name: "Milestone 1")
            try await milestoneRepo.save(ms)
            syncManager?.trackChange(entityType: .milestone, entityId: ms.id, changeType: .create)
            firstMilestone = ms
        }

        // Create tasks under their parent milestone (or first milestone as fallback)
        for (index, taskItem) in tasks.enumerated() {
            let targetMs = taskItem.parentName.flatMap { milestonesByName[$0] } ?? firstMilestone
            guard let ms = targetMs else { continue }

            let task = PMTask(
                milestoneId: ms.id,
                name: taskItem.name,
                sortOrder: index,
                timeEstimateMinutes: taskItem.timeEstimateMinutes,
                priority: taskItem.priority ?? .normal,
                effortType: taskItem.effortType
            )
            try await taskRepo.save(task)
            syncManager?.trackChange(entityType: .task, entityId: task.id, changeType: .create)
        }
    }

    // MARK: - Computed

    public var acceptedItemCount: Int {
        proposedItems.filter(\.accepted).count
    }

    public var canStartDiscovery: Bool {
        !brainDumpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
}
