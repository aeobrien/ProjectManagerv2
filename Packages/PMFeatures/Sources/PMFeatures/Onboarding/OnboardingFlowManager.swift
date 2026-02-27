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
        case aiConversation
        case structureProposal
        case creatingProject
        case completed
    }

    public private(set) var step: FlowStep = .brainDump
    public var brainDumpText: String = ""
    public var repoURL: String = ""
    public private(set) var aiResponse: String = ""
    public private(set) var proposedComplexity: ProjectComplexity = .simple
    public private(set) var proposedItems: [ProposedStructureItem] = []
    public private(set) var generatedVision: String?
    public private(set) var generatedTechBrief: String?
    public private(set) var isLoading = false
    public private(set) var error: String?
    public private(set) var createdProjectId: UUID?

    /// Multi-turn conversation state.
    public private(set) var conversationHistory: [LLMMessage] = []
    public private(set) var exchangeCount: Int = 0
    public var maxExchanges: Int = 3

    /// Whether this onboarding was initiated from a markdown import.
    public var isFromImport: Bool = false

    /// Suggested project name (from import or quick capture).
    public var suggestedProjectName: String = ""

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
            // Build user message with optional context
            var fullText = text
            if let transcript = sourceProject?.quickCaptureTranscript, !transcript.isEmpty {
                fullText = "Original capture: \(transcript)\n\nAdditional details: \(text)"
            }
            let trimmedURL = repoURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedURL.isEmpty {
                fullText += "\n\nRepository URL: \(trimmedURL)"
            }

            let userMessage = LLMMessage(role: .user, content: fullText)
            conversationHistory = [userMessage]
            exchangeCount = 1

            let payload = try await contextAssembler.assemble(
                conversationType: .onboarding,
                projectContext: nil,
                conversationHistory: conversationHistory,
                exchangeNumber: exchangeCount,
                maxExchanges: maxExchanges
            )

            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: payload.messages, config: config)

            Log.ai.debug("Onboarding startDiscovery: raw AI response (\(response.content.count) chars):\n\(response.content.prefix(2000))")

            let parsed = actionParser.parse(response.content)
            aiResponse = parsed.naturalLanguage
            conversationHistory.append(LLMMessage(role: .assistant, content: response.content))

            Log.ai.info("Onboarding startDiscovery: \(parsed.actions.count) parsed actions, naturalLanguage=\(parsed.naturalLanguage.count) chars")

            if !parsed.actions.isEmpty {
                // AI included ACTION blocks — move to structure proposal
                proposedItems = extractStructure(from: parsed.actions)
                proposedComplexity = assessComplexity(items: proposedItems)
                step = .structureProposal
                let count = proposedItems.count
                let complexity = proposedComplexity.rawValue
                Log.ai.info("Onboarding discovery complete: \(count) proposed items, \(complexity) complexity")
            } else {
                // No actions — AI wants more info, enter multi-turn conversation
                step = .aiConversation
                Log.ai.info("Onboarding entering multi-turn conversation (exchange \(self.exchangeCount) of \(self.maxExchanges))")
            }
        } catch {
            self.error = "Discovery failed: \(error.localizedDescription)"
            step = .brainDump
            Log.ai.error("Onboarding discovery failed: \(error)")
        }

        isLoading = false
    }

    /// Continue the multi-turn discovery conversation with the user's response.
    public func continueDiscovery(userResponse: String) async {
        let text = userResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        error = nil
        exchangeCount += 1

        do {
            conversationHistory.append(LLMMessage(role: .user, content: text))

            let payload = try await contextAssembler.assemble(
                conversationType: .onboarding,
                projectContext: nil,
                conversationHistory: conversationHistory,
                exchangeNumber: exchangeCount,
                maxExchanges: maxExchanges
            )

            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: payload.messages, config: config)

            Log.ai.debug("Onboarding continueDiscovery: raw AI response (\(response.content.count) chars):\n\(response.content.prefix(2000))")

            let parsed = actionParser.parse(response.content)
            aiResponse = parsed.naturalLanguage
            conversationHistory.append(LLMMessage(role: .assistant, content: response.content))

            Log.ai.info("Onboarding continueDiscovery: \(parsed.actions.count) parsed actions, exchangeCount=\(self.exchangeCount)/\(self.maxExchanges)")
            for (i, action) in parsed.actions.enumerated() {
                Log.ai.debug("Onboarding continueDiscovery: action[\(i)] = \(String(describing: action))")
            }

            if !parsed.actions.isEmpty || exchangeCount >= maxExchanges {
                let reason = !parsed.actions.isEmpty ? "actions present" : "max exchanges reached"
                Log.ai.info("Onboarding advancing to structureProposal: \(reason)")
                // Move to structure proposal
                if !parsed.actions.isEmpty {
                    proposedItems = extractStructure(from: parsed.actions)
                    Log.ai.info("Onboarding extractStructure: \(self.proposedItems.count) items from \(parsed.actions.count) actions")
                } else {
                    Log.ai.notice("Onboarding: max exchanges reached with 0 actions — proposedItems will be empty")
                }
                proposedComplexity = assessComplexity(items: proposedItems)
                step = .structureProposal
                Log.ai.info("Onboarding conversation complete after \(self.exchangeCount) exchanges, \(self.proposedItems.count) items, \(self.proposedComplexity.rawValue) complexity")
            }
            // Otherwise stay in .aiConversation
        } catch {
            self.error = "Discovery failed: \(error.localizedDescription)"
            Log.ai.error("Onboarding continue discovery failed: \(error)")
        }

        isLoading = false
    }

    /// Skip remaining discovery questions and move directly to structure proposal.
    public func skipToStructure() {
        proposedComplexity = assessComplexity(items: proposedItems)
        step = .structureProposal
        Log.ai.info("Onboarding skipped to structure proposal from exchange \(self.exchangeCount)")
    }

    /// Create the project from the accepted proposal.
    public func createProject(name: String, categoryId: UUID, definitionOfDone: String?) async {
        isLoading = true
        error = nil
        step = .creatingProject

        do {
            // Resolve repo URL
            let trimmedURL = repoURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let repoURLValue: String? = trimmedURL.isEmpty ? nil : trimmedURL

            // Create or update project
            var project: Project
            if var existing = sourceProject {
                existing.name = name
                existing.categoryId = categoryId
                existing.definitionOfDone = definitionOfDone
                existing.lifecycleState = .queued
                existing.repositoryURL = repoURLValue
                try await projectRepo.save(existing)
                syncManager?.trackChange(entityType: .project, entityId: existing.id, changeType: .update)
                project = existing
            } else {
                project = Project(
                    name: name,
                    categoryId: categoryId,
                    lifecycleState: .queued,
                    definitionOfDone: definitionOfDone,
                    repositoryURL: repoURLValue
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

            // Build conversation transcript if multi-turn discovery happened
            var conversationTranscript = ""
            if conversationHistory.count > 1 {
                conversationTranscript = "\n\nDiscovery conversation:\n" + conversationHistory.map { msg in
                    let role = msg.role == .user ? "User" : "Assistant"
                    return "\(role): \(msg.content)"
                }.joined(separator: "\n\n")
            }

            let visionPrompt = """
            \(PromptTemplates.visionStatementTemplate)

            ---

            Project description: \(brainDumpText)\(conversationTranscript)

            Proposed structure:
            \(structureSummary)
            """

            let messages = [
                LLMMessage(role: .system, content: PromptTemplates.behaviouralContract),
                LLMMessage(role: .user, content: visionPrompt)
            ]
            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: messages, config: config)
            generatedVision = response.content

            if proposedComplexity == .complex {
                let briefPrompt = """
                \(PromptTemplates.technicalBriefTemplate)

                ---

                Use the vision statement above as context. Base your technical decisions on the project's needs.
                """
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
        repoURL = ""
        isFromImport = false
        suggestedProjectName = ""
        aiResponse = ""
        proposedItems = []
        generatedVision = nil
        generatedTechBrief = nil
        error = nil
        createdProjectId = nil
        conversationHistory = []
        exchangeCount = 0
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
        // Track the last phase/milestone name for parenting
        var lastPhaseName: String?
        var lastMilestoneName: String?
        Log.ai.debug("extractStructure: processing \(actions.count) actions")
        for (index, action) in actions.enumerated() {
            switch action {
            case .createPhase(_, let name):
                lastPhaseName = name
                lastMilestoneName = nil
                items.append(ProposedStructureItem(kind: .phase, name: name))
                Log.ai.debug("extractStructure[\(index)]: phase '\(name)'")
            case .createMilestone(_, let name):
                lastMilestoneName = name
                items.append(ProposedStructureItem(kind: .milestone, name: name, parentName: lastPhaseName))
                Log.ai.debug("extractStructure[\(index)]: milestone '\(name)' under phase '\(lastPhaseName ?? "none")'")
            case .createTask(_, let name, let priority, let effortType):
                items.append(ProposedStructureItem(
                    kind: .task,
                    name: name,
                    parentName: lastMilestoneName,
                    priority: priority,
                    effortType: effortType
                ))
                Log.ai.debug("extractStructure[\(index)]: task '\(name)' under milestone '\(lastMilestoneName ?? "none")'")
            default:
                Log.ai.debug("extractStructure[\(index)]: skipping non-structure action: \(String(describing: action))")
            }
        }
        Log.ai.info("extractStructure: produced \(items.count) items (phases: \(items.filter { $0.kind == .phase }.count), milestones: \(items.filter { $0.kind == .milestone }.count), tasks: \(items.filter { $0.kind == .task }.count))")
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
