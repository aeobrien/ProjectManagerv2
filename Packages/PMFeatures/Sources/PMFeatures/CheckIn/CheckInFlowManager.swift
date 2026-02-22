import Foundation
import PMDomain
import PMServices
import PMUtilities
import os

/// Check-in prompt urgency level.
public enum CheckInUrgency: Sendable, Equatable {
    case none
    case gentle      // 3+ days since last check-in
    case moderate    // 7+ days
    case prominent   // 14+ days
}

/// Snooze duration options.
public enum SnoozeDuration: Int, Sendable, CaseIterable {
    case oneDay = 1
    case threeDays = 3
    case oneWeek = 7
}

/// Manages check-in flow orchestration: prompting, AI interaction, and record creation.
@Observable
@MainActor
public final class CheckInFlowManager {
    // MARK: - State

    public private(set) var isCheckingIn = false
    public private(set) var error: String?
    public private(set) var lastCreatedRecord: CheckInRecord?

    /// Snooze dates per project — project ID → snooze until date.
    public private(set) var snoozedUntil: [UUID: Date] = [:]

    // MARK: - Dependencies

    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let checkInRepo: CheckInRepositoryProtocol
    private let llmClient: LLMClientProtocol
    private let actionParser: ActionParser
    private let actionExecutor: ActionExecutor
    private let contextAssembler: ContextAssembler

    /// Optional knowledge base manager for incremental indexing of check-in content.
    public var knowledgeBaseManager: KnowledgeBaseManager?

    /// Optional sync manager for tracking check-in changes.
    public var syncManager: SyncManager?

    /// Optional notification manager for scheduling check-in reminders.
    public var notificationManager: NotificationManager?

    // MARK: - Configuration

    public var gentleThresholdDays: Int = 3
    public var moderateThresholdDays: Int = 7
    public var prominentThresholdDays: Int = 14
    public var deferredThreshold: Int = 3

    // MARK: - Init

    public init(
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        checkInRepo: CheckInRepositoryProtocol,
        llmClient: LLMClientProtocol,
        actionExecutor: ActionExecutor,
        contextAssembler: ContextAssembler = ContextAssembler()
    ) {
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.milestoneRepo = milestoneRepo
        self.taskRepo = taskRepo
        self.checkInRepo = checkInRepo
        self.llmClient = llmClient
        self.actionParser = ActionParser()
        self.actionExecutor = actionExecutor
        self.contextAssembler = contextAssembler
    }

    // MARK: - Urgency Computation

    /// Compute check-in urgency for a project based on last check-in date.
    public func urgency(for project: Project, lastCheckIn: CheckInRecord?) -> CheckInUrgency {
        // Check snooze
        if let snoozeDate = snoozedUntil[project.id], Date() < snoozeDate {
            return .none
        }

        guard let lastCheckIn else { return .prominent }

        let daysSince = Calendar.current.dateComponents([.day], from: lastCheckIn.timestamp, to: Date()).day ?? 0

        if daysSince >= prominentThresholdDays { return .prominent }
        if daysSince >= moderateThresholdDays { return .moderate }
        if daysSince >= gentleThresholdDays { return .gentle }
        return .none
    }

    /// Compute days since last check-in.
    public func daysSinceCheckIn(_ lastCheckIn: CheckInRecord?) -> Int {
        guard let lastCheckIn else { return Int.max }
        return Calendar.current.dateComponents([.day], from: lastCheckIn.timestamp, to: Date()).day ?? 0
    }

    // MARK: - Snooze

    /// Snooze check-in prompts for a project.
    public func snooze(projectId: UUID, duration: SnoozeDuration) {
        let snoozeDate = Calendar.current.date(byAdding: .day, value: duration.rawValue, to: Date()) ?? Date()
        snoozedUntil[projectId] = snoozeDate
        Log.focus.info("Snoozed check-in for project \(projectId) until \(snoozeDate)")
    }

    // MARK: - Check-In Execution

    /// Perform a check-in for a project with the given depth.
    public func performCheckIn(
        project: Project,
        depth: CheckInDepth,
        userMessage: String
    ) async -> (response: String, confirmation: BundledConfirmation?)? {
        isCheckingIn = true
        error = nil

        do {
            // Build project context
            let context = try await buildProjectContext(for: project)

            // Snapshot visible tasks for deferred tracking
            let visibleTasks = context.tasks.filter {
                $0.status == .inProgress || $0.status == .notStarted
            }

            // Determine conversation type
            let conversationType: ConversationType = depth == .quickLog ? .checkInQuickLog : .checkInFull

            // Assemble context
            let history = [LLMMessage(role: .user, content: userMessage)]
            let payload = try await contextAssembler.assemble(
                conversationType: conversationType,
                projectContext: context,
                conversationHistory: history
            )

            // Send to LLM
            let config = LLMRequestConfig()
            let llmResponse = try await llmClient.send(messages: payload.messages, config: config)

            // Parse response
            let parsed = actionParser.parse(llmResponse.content)

            // Generate confirmation if actions present
            var confirmation: BundledConfirmation?
            if !parsed.actions.isEmpty {
                confirmation = actionExecutor.generateConfirmation(from: parsed.actions)
            }

            // Detect avoidance: tasks not addressed in the response
            let mentionedTaskIds = extractMentionedTaskIds(from: parsed.actions)
            let unaddressedTasks = visibleTasks.filter { !mentionedTaskIds.contains($0.id) }

            // Increment deferred count for unaddressed tasks
            for var task in unaddressedTasks {
                task.timesDeferred += 1
                try await taskRepo.save(task)
            }

            // Create check-in record
            let record = CheckInRecord(
                projectId: project.id,
                depth: depth,
                transcript: userMessage,
                aiSummary: parsed.naturalLanguage,
                tasksCompleted: parsed.actions.compactMap { action in
                    if case .completeTask(let id) = action { return id }
                    return nil
                },
                issuesFlagged: parsed.actions.compactMap { action in
                    if case .flagBlocked(_, _, let reason) = action { return reason }
                    return nil
                }
            )
            try await checkInRepo.save(record)
            lastCreatedRecord = record
            syncManager?.trackChange(entityType: .checkIn, entityId: record.id, changeType: .create)

            // Index check-in content in knowledge base
            if let kb = knowledgeBaseManager {
                Task.detached {
                    do {
                        try await kb.indexCheckIn(record)
                    } catch {
                        Log.ai.error("Failed to index check-in in KB: \(error)")
                    }
                }
            }

            Log.focus.info("Check-in completed for '\(project.name)' (\(depth.rawValue)), \(unaddressedTasks.count) tasks deferred")

            isCheckingIn = false
            return (response: parsed.naturalLanguage, confirmation: confirmation)

        } catch {
            self.error = "Check-in failed: \(error.localizedDescription)"
            Log.focus.error("Check-in failed: \(error)")
            isCheckingIn = false
            return nil
        }
    }

    /// Apply a check-in's bundled confirmation.
    public func applyConfirmation(_ confirmation: BundledConfirmation) async {
        do {
            try await actionExecutor.execute(confirmation)
        } catch {
            self.error = "Failed to apply changes: \(error.localizedDescription)"
        }
    }

    // MARK: - Frequently Deferred

    /// Get tasks that have been deferred too many times.
    public func frequentlyDeferredTasks(from tasks: [PMTask]) -> [PMTask] {
        tasks.filter { $0.timesDeferred >= deferredThreshold }
    }

    // MARK: - Helpers

    private func buildProjectContext(for project: Project) async throws -> ProjectContext {
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

        let recentCheckIns = try await checkInRepo.fetchAll(forProject: project.id)
        let frequentlyDeferred = allTasks.filter { $0.timesDeferred >= deferredThreshold }

        return ProjectContext(
            project: project,
            phases: phases,
            milestones: allMilestones,
            tasks: allTasks,
            recentCheckIns: Array(recentCheckIns.prefix(5)),
            frequentlyDeferredTasks: frequentlyDeferred
        )
    }

    private func extractMentionedTaskIds(from actions: [AIAction]) -> Set<UUID> {
        var ids = Set<UUID>()
        for action in actions {
            switch action {
            case .completeTask(let id): ids.insert(id)
            case .flagBlocked(let id, _, _): ids.insert(id)
            case .setWaiting(let id, _, _): ids.insert(id)
            case .incrementDeferred(let id): ids.insert(id)
            case .createSubtask(let id, _): ids.insert(id)
            default: break
            }
        }
        return ids
    }
}
