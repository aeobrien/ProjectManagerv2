import Foundation
import PMData
import PMDomain
import PMServices
import PMUtilities
import os

/// Manages the retrospective flow: detect phase completion → prompt → AI conversation → store notes.
/// Also handles return briefings for dormant projects (14+ days since last activity).
@Observable
@MainActor
public final class RetrospectiveFlowManager {
    // MARK: - State

    public enum FlowStep: Sendable, Equatable {
        case idle
        case promptUser          // Phase completed, prompting for retro
        case reflecting          // User is writing reflections
        case aiConversation      // AI conversation in progress
        case completed
    }

    public private(set) var step: FlowStep = .idle
    public private(set) var isLoading = false
    public private(set) var error: String?

    /// The phase being reflected on.
    public private(set) var targetPhase: Phase?

    /// AI conversation messages.
    public private(set) var messages: [(role: String, content: String)] = []

    /// User's free-form reflection text.
    public var reflectionText: String = ""

    /// AI-generated summary of the retrospective.
    public private(set) var aiSummary: String?

    /// Return briefing for dormant projects.
    public private(set) var returnBriefing: String?

    /// Snooze tracking — phaseId → snooze expiry.
    public private(set) var snoozedUntil: [UUID: Date] = [:]

    /// Dormancy threshold in days.
    public var dormancyThresholdDays: Int = 14

    // MARK: - Dependencies

    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let checkInRepo: CheckInRepositoryProtocol
    private let llmClient: LLMClientProtocol
    private let contextAssembler: ContextAssembler

    /// Optional sync manager for tracking changes.
    public var syncManager: SyncManager?

    // MARK: - Init

    public init(
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        checkInRepo: CheckInRepositoryProtocol,
        llmClient: LLMClientProtocol,
        contextAssembler: ContextAssembler = ContextAssembler()
    ) {
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.milestoneRepo = milestoneRepo
        self.taskRepo = taskRepo
        self.checkInRepo = checkInRepo
        self.llmClient = llmClient
        self.contextAssembler = contextAssembler
    }

    // MARK: - Phase Completion Detection

    /// Check if a phase has all milestones completed and no retrospective yet.
    public func checkPhaseCompletion(_ phase: Phase) async -> Bool {
        guard phase.retrospectiveCompletedAt == nil else { return false }

        // Check if snoozed
        if let snoozeDate = snoozedUntil[phase.id], Date() < snoozeDate {
            return false
        }

        do {
            let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
            guard !milestones.isEmpty else { return false }
            return milestones.allSatisfy { $0.status == .completed }
        } catch {
            return false
        }
    }

    /// Begin the retrospective prompt for a completed phase.
    public func promptRetrospective(for phase: Phase) {
        targetPhase = phase
        step = .promptUser
        reflectionText = ""
        messages = []
        aiSummary = nil
        error = nil
    }

    /// Snooze the retrospective prompt.
    public func snooze(_ phase: Phase, days: Int = 1) {
        snoozedUntil[phase.id] = Calendar.current.date(byAdding: .day, value: days, to: Date())
        step = .idle
        targetPhase = nil
    }

    /// Start the reflection step.
    public func beginReflection() {
        step = .reflecting
    }

    // MARK: - AI Retrospective Conversation

    /// Send the user's reflection to the AI for a retrospective conversation.
    public func submitReflection() async {
        guard let phase = targetPhase else {
            error = "No phase selected for retrospective."
            return
        }

        let text = reflectionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            error = "Please share your thoughts about this phase."
            return
        }

        isLoading = true
        error = nil
        step = .aiConversation

        do {
            // Build context
            let project = try await projectRepo.fetch(id: phase.projectId)
            let phases = try await phaseRepo.fetchAll(forProject: phase.projectId)
            let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
            let checkIns = try await checkInRepo.fetchAll(forProject: phase.projectId)

            var allTasks: [PMTask] = []
            for ms in milestones {
                let tasks = try await taskRepo.fetchAll(forMilestone: ms.id)
                allTasks.append(contentsOf: tasks)
            }

            let userMessage = """
            Phase "\(phase.name)" is complete. Here are my reflections:

            \(text)
            """

            messages.append((role: "user", content: userMessage))

            let projectContext = ProjectContext(
                project: project ?? Project(name: "Unknown", categoryId: UUID()),
                phases: phases,
                milestones: milestones,
                tasks: allTasks,
                recentCheckIns: Array(checkIns.suffix(5))
            )

            let history = messages.map { LLMMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content) }
            let payload = try await contextAssembler.assemble(
                conversationType: .retrospective,
                projectContext: projectContext,
                conversationHistory: history
            )

            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: payload.messages, config: config)

            messages.append((role: "assistant", content: response.content))
            aiSummary = response.content

            Log.ai.info("Retrospective conversation for phase '\(phase.name)' completed")
        } catch {
            self.error = "Retrospective failed: \(error.localizedDescription)"
            step = .reflecting
            Log.ai.error("Retrospective failed: \(error)")
        }

        isLoading = false
    }

    /// Send a follow-up message in the retrospective conversation.
    public func sendFollowUp(_ message: String) async {
        guard targetPhase != nil else { return }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        messages.append((role: "user", content: text))

        do {
            let history = messages.map { LLMMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content) }
            let payload = try await contextAssembler.assemble(
                conversationType: .retrospective,
                projectContext: nil,
                conversationHistory: history
            )

            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: payload.messages, config: config)

            messages.append((role: "assistant", content: response.content))
            aiSummary = response.content
        } catch {
            self.error = "Follow-up failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Save Retrospective

    /// Save the retrospective notes to the phase and mark as completed.
    public func completeRetrospective() async {
        guard var phase = targetPhase else { return }

        // Combine user reflection + AI summary
        var notes = "## Reflection\n\n\(reflectionText)"
        if let summary = aiSummary {
            notes += "\n\n## AI Summary\n\n\(summary)"
        }

        phase.retrospectiveNotes = notes
        phase.retrospectiveCompletedAt = Date()

        do {
            try await phaseRepo.save(phase)
            syncManager?.trackChange(entityType: .phase, entityId: phase.id, changeType: .update)
            targetPhase = phase
            step = .completed
            Log.ui.info("Retrospective saved for phase '\(phase.name)'")
        } catch {
            self.error = "Failed to save retrospective: \(error.localizedDescription)"
        }
    }

    // MARK: - Return Briefing

    /// Check if a project is dormant (no activity for threshold days).
    public func isDormant(_ project: Project) -> Bool {
        guard let lastWorked = project.lastWorkedOn else { return true }
        let daysSince = Calendar.current.dateComponents([.day], from: lastWorked, to: Date()).day ?? 0
        return daysSince >= dormancyThresholdDays
    }

    /// Generate a return briefing for a dormant project.
    public func generateReturnBriefing(for project: Project) async {
        isLoading = true
        error = nil
        returnBriefing = nil

        do {
            let phases = try await phaseRepo.fetchAll(forProject: project.id)
            var allMilestones: [Milestone] = []
            var allTasks: [PMTask] = []
            for phase in phases {
                let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
                allMilestones.append(contentsOf: milestones)
                for ms in milestones {
                    let tasks = try await taskRepo.fetchAll(forMilestone: ms.id)
                    allTasks.append(contentsOf: tasks)
                }
            }

            let checkIns = try await checkInRepo.fetchAll(forProject: project.id)

            let projectContext = ProjectContext(
                project: project,
                phases: phases,
                milestones: allMilestones,
                tasks: allTasks,
                recentCheckIns: Array(checkIns.suffix(5))
            )

            let daysSince = project.lastWorkedOn.map {
                Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0
            } ?? 0

            let userMessage = "I'm returning to this project after \(daysSince) days away. Please give me a return briefing."
            let history = [LLMMessage(role: .user, content: userMessage)]

            let payload = try await contextAssembler.assemble(
                conversationType: .reEntry,
                projectContext: projectContext,
                conversationHistory: history
            )

            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: payload.messages, config: config)

            returnBriefing = response.content
            Log.ai.info("Return briefing generated for project '\(project.name)'")
        } catch {
            self.error = "Failed to generate briefing: \(error.localizedDescription)"
            Log.ai.error("Return briefing failed: \(error)")
        }

        isLoading = false
    }

    // MARK: - Reset

    /// Reset the flow to idle.
    public func reset() {
        step = .idle
        targetPhase = nil
        reflectionText = ""
        messages = []
        aiSummary = nil
        returnBriefing = nil
        error = nil
    }
}
