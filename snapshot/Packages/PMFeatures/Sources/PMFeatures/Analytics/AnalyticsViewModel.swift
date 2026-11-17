import Foundation
import PMDomain
import PMServices
import PMUtilities
import os

/// ViewModel for the reflective analytics view.
/// Guardrails: No streaks, no gamification, no comparative metrics, no red/green scoring.
@Observable
@MainActor
public final class AnalyticsViewModel {
    // MARK: - State

    public private(set) var isLoading = false
    public private(set) var error: String?

    public private(set) var estimateAccuracy: Float?
    public private(set) var accuracyByEffort: [EffortType: Float] = [:]
    public private(set) var suggestedMultiplier: Float?
    public private(set) var accuracyTrend: (older: Float, newer: Float)?

    public private(set) var completionRate: Float?
    public private(set) var averageTimeByEffort: [EffortType: Float] = [:]
    public private(set) var frequentlyDeferred: [PMTask] = []
    public private(set) var summary: ProjectSummaryStats?

    public private(set) var hasEnoughData = false

    // MARK: - Dependencies

    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let estimateTracker: EstimateTracker
    private let projectAnalytics: ProjectAnalytics

    // MARK: - Init

    public init(
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        estimateTracker: EstimateTracker = EstimateTracker(),
        projectAnalytics: ProjectAnalytics = ProjectAnalytics()
    ) {
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.milestoneRepo = milestoneRepo
        self.taskRepo = taskRepo
        self.estimateTracker = estimateTracker
        self.projectAnalytics = projectAnalytics
    }

    // MARK: - Loading

    /// Load analytics for a specific project.
    public func load(projectId: UUID) async {
        isLoading = true
        error = nil

        do {
            // Gather all tasks for the project
            let phases = try await phaseRepo.fetchAll(forProject: projectId)
            var allTasks: [PMTask] = []
            for phase in phases {
                let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
                for ms in milestones {
                    let tasks = try await taskRepo.fetchAll(forMilestone: ms.id)
                    allTasks.append(contentsOf: tasks)
                }
            }

            let completedTasks = allTasks.filter { $0.status == .completed }

            // Estimate tracking
            estimateAccuracy = estimateTracker.averageAccuracy(tasks: completedTasks)
            accuracyByEffort = estimateTracker.accuracyByEffortType(tasks: completedTasks)
            suggestedMultiplier = estimateTracker.suggestedMultiplier(tasks: completedTasks)
            accuracyTrend = estimateTracker.accuracyTrend(tasks: completedTasks)

            // Project analytics
            completionRate = projectAnalytics.completionRate(tasks: allTasks)
            averageTimeByEffort = projectAnalytics.averageTimeByEffortType(tasks: completedTasks)
            frequentlyDeferred = projectAnalytics.frequentlyDeferred(tasks: allTasks)
            summary = projectAnalytics.projectSummary(tasks: allTasks)

            hasEnoughData = estimateAccuracy != nil

            Log.ui.info("Analytics loaded for project: \(allTasks.count) tasks")
        } catch {
            self.error = "Failed to load analytics: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Format accuracy as a human-readable description.
    /// Uses neutral language only — no judgement.
    public func accuracyDescription(_ ratio: Float) -> String {
        if ratio < 0.8 {
            return "Tasks tend to finish faster than estimated"
        } else if ratio > 1.2 {
            return "Tasks tend to take longer than estimated"
        } else {
            return "Estimates are generally close to actual time"
        }
    }

    /// Format multiplier suggestion as neutral advice.
    public func multiplierDescription(_ multiplier: Float) -> String {
        if multiplier > 1.1 {
            let pct = Int((multiplier - 1) * 100)
            return "Consider adding \(pct)% to time estimates"
        } else if multiplier < 0.9 {
            let pct = Int((1 - multiplier) * 100)
            return "Estimates could be reduced by about \(pct)%"
        } else {
            return "Current estimates are well-calibrated"
        }
    }
}
