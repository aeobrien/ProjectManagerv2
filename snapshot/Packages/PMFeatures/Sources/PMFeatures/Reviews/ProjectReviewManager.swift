import Foundation
import PMDomain
import PMServices
import PMUtilities
import os

/// Manages AI project review conversations with cross-project pattern detection.
@Observable
@MainActor
public final class ProjectReviewManager {
    // MARK: - State

    public private(set) var isLoading = false
    public private(set) var error: String?
    public private(set) var reviewResponse: String?
    public private(set) var messages: [(role: String, content: String)] = []

    /// Detected patterns across projects.
    public private(set) var crossProjectPatterns: [CrossProjectPattern] = []

    /// Waiting items approaching or past their check-back dates.
    public private(set) var waitingItemAlerts: [WaitingItemAlert] = []

    // MARK: - Dependencies

    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let checkInRepo: CheckInRepositoryProtocol
    private let llmClient: LLMClientProtocol
    private let contextAssembler: ContextAssembler

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

    // MARK: - Review Context Assembly

    /// Build full Focus Board context for a review.
    public func assembleReviewContext() async throws -> ReviewContext {
        let focusedProjects = try await projectRepo.fetchFocused()
        let queuedProjects = try await projectRepo.fetchByLifecycleState(.queued)
        let pausedProjects = try await projectRepo.fetchByLifecycleState(.paused)

        var projectDetails: [ProjectReviewDetail] = []
        var allWaitingAlerts: [WaitingItemAlert] = []

        for project in focusedProjects {
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

            // Detect waiting items approaching check-back
            let waitingTasks = allTasks.filter { $0.status == .waiting }
            for task in waitingTasks {
                if let checkBack = task.waitingCheckBackDate {
                    let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: checkBack).day ?? 0
                    if daysUntil <= 1 {
                        allWaitingAlerts.append(WaitingItemAlert(
                            taskName: task.name,
                            projectName: project.name,
                            checkBackDate: checkBack,
                            isPastDue: daysUntil < 0
                        ))
                    }
                }
            }

            let detail = ProjectReviewDetail(
                project: project,
                phases: phases,
                milestones: allMilestones,
                tasks: allTasks,
                recentCheckIns: Array(checkIns.suffix(3)),
                blockedCount: allTasks.filter { $0.status == .blocked }.count,
                waitingCount: waitingTasks.count,
                frequentlyDeferred: allTasks.filter { $0.timesDeferred >= 3 }
            )
            projectDetails.append(detail)
        }

        waitingItemAlerts = allWaitingAlerts

        return ReviewContext(
            focusedProjects: projectDetails,
            queuedProjects: queuedProjects,
            pausedProjects: pausedProjects,
            waitingAlerts: allWaitingAlerts
        )
    }

    // MARK: - Cross-Project Pattern Detection

    /// Detect patterns across all focused projects.
    public func detectPatterns(context: ReviewContext) -> [CrossProjectPattern] {
        var patterns: [CrossProjectPattern] = []

        // Stall detection: projects with no check-ins in 7+ days
        for detail in context.focusedProjects {
            let lastCheckIn = detail.recentCheckIns.first?.timestamp
            if let last = lastCheckIn {
                let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
                if daysSince >= 7 {
                    patterns.append(CrossProjectPattern(
                        type: .stall,
                        projectName: detail.project.name,
                        description: "No check-in for \(daysSince) days"
                    ))
                }
            }
        }

        // High blocked count
        for detail in context.focusedProjects {
            if detail.blockedCount >= 3 {
                patterns.append(CrossProjectPattern(
                    type: .blockedAccumulation,
                    projectName: detail.project.name,
                    description: "\(detail.blockedCount) blocked tasks"
                ))
            }
        }

        // Frequently deferred across projects
        let totalDeferred = context.focusedProjects.flatMap(\.frequentlyDeferred)
        if totalDeferred.count >= 5 {
            patterns.append(CrossProjectPattern(
                type: .deferralPattern,
                projectName: nil,
                description: "\(totalDeferred.count) frequently deferred tasks across projects"
            ))
        }

        // Waiting accumulation
        if context.waitingAlerts.count >= 3 {
            patterns.append(CrossProjectPattern(
                type: .waitingAccumulation,
                projectName: nil,
                description: "\(context.waitingAlerts.count) waiting items approaching check-back dates simultaneously"
            ))
        }

        crossProjectPatterns = patterns
        return patterns
    }

    // MARK: - AI Review Conversation

    /// Start a review conversation with the AI.
    public func startReview() async {
        isLoading = true
        error = nil
        messages = []
        reviewResponse = nil

        do {
            let context = try await assembleReviewContext()
            let patterns = detectPatterns(context: context)

            // Build review prompt
            var prompt = "Please review my current Focus Board:\n\n"
            for detail in context.focusedProjects {
                let taskCount = detail.tasks.count
                let completedCount = detail.tasks.filter { $0.status == .completed }.count
                prompt += "**\(detail.project.name)**: \(completedCount)/\(taskCount) tasks done"
                if detail.blockedCount > 0 { prompt += ", \(detail.blockedCount) blocked" }
                if detail.waitingCount > 0 { prompt += ", \(detail.waitingCount) waiting" }
                prompt += "\n"
            }

            if !context.queuedProjects.isEmpty {
                prompt += "\nQueued projects:\n"
                for p in context.queuedProjects {
                    prompt += "- \(p.name)"
                    if let reason = p.pauseReason, !reason.isEmpty { prompt += " (reason: \(reason))" }
                    prompt += "\n"
                }
            }

            if !context.pausedProjects.isEmpty {
                prompt += "\nPaused projects:\n"
                for p in context.pausedProjects {
                    prompt += "- \(p.name)"
                    if let reason = p.pauseReason, !reason.isEmpty { prompt += " (reason: \(reason))" }
                    prompt += "\n"
                }
            }

            if !patterns.isEmpty {
                prompt += "\nDetected patterns:\n"
                for pattern in patterns {
                    prompt += "- \(pattern.description)\n"
                }
            }

            if !context.waitingAlerts.isEmpty {
                prompt += "\nWaiting items approaching check-back:\n"
                for alert in context.waitingAlerts {
                    prompt += "- \(alert.taskName) in \(alert.projectName)\(alert.isPastDue ? " (PAST DUE)" : "")\n"
                }
            }

            messages.append((role: "user", content: prompt))

            // Use first focused project for context, or nil
            let firstDetail = context.focusedProjects.first
            let projectContext: ProjectContext?
            if let detail = firstDetail {
                projectContext = ProjectContext(
                    project: detail.project,
                    phases: detail.phases,
                    milestones: detail.milestones,
                    tasks: detail.tasks,
                    recentCheckIns: detail.recentCheckIns,
                    frequentlyDeferredTasks: detail.frequentlyDeferred
                )
            } else {
                projectContext = nil
            }

            let history = messages.map { LLMMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content) }
            let payload = try await contextAssembler.assemble(
                conversationType: .review,
                projectContext: projectContext,
                conversationHistory: history
            )

            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: payload.messages, config: config)

            reviewResponse = response.content
            messages.append((role: "assistant", content: response.content))

            Log.ai.info("Project review completed for \(context.focusedProjects.count) projects")
        } catch {
            self.error = "Review failed: \(error.localizedDescription)"
            Log.ai.error("Project review failed: \(error)")
        }

        isLoading = false
    }

    /// Send a follow-up message in the review conversation.
    public func sendFollowUp(_ message: String) async {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        messages.append((role: "user", content: text))

        do {
            let history = messages.map { LLMMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content) }
            let payload = try await contextAssembler.assemble(
                conversationType: .review,
                projectContext: nil,
                conversationHistory: history
            )

            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: payload.messages, config: config)

            reviewResponse = response.content
            messages.append((role: "assistant", content: response.content))
        } catch {
            self.error = "Follow-up failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Reset

    public func reset() {
        messages = []
        reviewResponse = nil
        crossProjectPatterns = []
        waitingItemAlerts = []
        error = nil
    }
}

// MARK: - Supporting Types

/// Detail about a project for review purposes.
public struct ProjectReviewDetail: Sendable {
    public let project: Project
    public let phases: [Phase]
    public let milestones: [Milestone]
    public let tasks: [PMTask]
    public let recentCheckIns: [CheckInRecord]
    public let blockedCount: Int
    public let waitingCount: Int
    public let frequentlyDeferred: [PMTask]
}

/// Full review context across all focused projects.
public struct ReviewContext: Sendable {
    public let focusedProjects: [ProjectReviewDetail]
    public let queuedProjects: [Project]
    public let pausedProjects: [Project]
    public let waitingAlerts: [WaitingItemAlert]
}

/// A detected cross-project pattern.
public struct CrossProjectPattern: Sendable, Equatable {
    public let type: PatternType
    public let projectName: String?
    public let description: String

    public init(type: PatternType, projectName: String?, description: String) {
        self.type = type
        self.projectName = projectName
        self.description = description
    }
}

/// Types of cross-project patterns.
public enum PatternType: String, Sendable, Equatable {
    case stall                  // No recent activity
    case blockedAccumulation    // Many blocked tasks
    case deferralPattern        // Frequently deferred tasks
    case waitingAccumulation    // Many waiting items resolving at once
}

/// Alert for a waiting item approaching its check-back date.
public struct WaitingItemAlert: Sendable, Equatable {
    public let taskName: String
    public let projectName: String
    public let checkBackDate: Date
    public let isPastDue: Bool

    public init(taskName: String, projectName: String, checkBackDate: Date, isPastDue: Bool) {
        self.taskName = taskName
        self.projectName = projectName
        self.checkBackDate = checkBackDate
        self.isPastDue = isPastDue
    }
}
