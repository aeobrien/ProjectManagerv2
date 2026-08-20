import Foundation
import PMDomain
import PMUtilities
import os

/// Tracks estimate accuracy and computes calibration data.
public struct EstimateTracker: Sendable {
    /// Minimum completed tasks before showing trends.
    public let minDataThreshold: Int

    public init(minDataThreshold: Int = 5) {
        self.minDataThreshold = minDataThreshold
    }

    /// Compute estimate accuracy for a set of completed tasks.
    /// Returns the ratio of actual to estimated time (1.0 = perfect, >1 = underestimate, <1 = overestimate).
    public func accuracyRatios(tasks: [PMTask]) -> [Float] {
        tasks.compactMap { task in
            guard let estimated = task.adjustedEstimateMinutes, estimated > 0,
                  let actual = task.actualMinutes, actual > 0 else { return nil }
            return Float(actual) / Float(estimated)
        }
    }

    /// Average accuracy ratio. Returns nil if insufficient data.
    public func averageAccuracy(tasks: [PMTask]) -> Float? {
        let ratios = accuracyRatios(tasks: tasks)
        guard ratios.count >= minDataThreshold else { return nil }
        return ratios.reduce(0, +) / Float(ratios.count)
    }

    /// Accuracy by effort type.
    public func accuracyByEffortType(tasks: [PMTask]) -> [EffortType: Float] {
        var result: [EffortType: Float] = [:]
        for type in EffortType.allCases {
            let typed = tasks.filter { $0.effortType == type }
            if let avg = averageAccuracy(tasks: typed) {
                result[type] = avg
            }
        }
        return result
    }

    /// Suggest a pessimism multiplier based on historical accuracy.
    /// If user consistently underestimates (ratio > 1), suggest increasing multiplier.
    public func suggestedMultiplier(tasks: [PMTask]) -> Float? {
        guard let avg = averageAccuracy(tasks: tasks) else { return nil }
        // If average accuracy is 1.5 (tasks take 50% longer), suggest 1.5x multiplier
        // Clamp between 0.5 and 3.0
        return max(0.5, min(3.0, avg))
    }

    /// Compute a trend over time (most recent tasks vs older tasks).
    /// Returns (older average, newer average) or nil if insufficient data.
    public func accuracyTrend(tasks: [PMTask]) -> (older: Float, newer: Float)? {
        let completedWithEstimates = tasks.filter {
            $0.adjustedEstimateMinutes != nil && $0.actualMinutes != nil && $0.completedAt != nil
        }
        .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }

        guard completedWithEstimates.count >= minDataThreshold * 2 else { return nil }

        let midpoint = completedWithEstimates.count / 2
        let older = Array(completedWithEstimates[..<midpoint])
        let newer = Array(completedWithEstimates[midpoint...])

        guard let olderAvg = averageAccuracy(tasks: older),
              let newerAvg = averageAccuracy(tasks: newer) else { return nil }

        return (older: olderAvg, newer: newerAvg)
    }
}

/// Computes project-level analytics with ADHD-safe guardrails.
/// NO streaks, NO gamification, NO comparative metrics, NO red/green scoring.
/// All analytics are neutral observations for self-reflection.
public struct ProjectAnalytics: Sendable {
    public init() {}

    /// Compute completion rate for a set of tasks.
    public func completionRate(tasks: [PMTask]) -> Float? {
        guard !tasks.isEmpty else { return nil }
        let completed = tasks.filter { $0.status == .completed }.count
        return Float(completed) / Float(tasks.count)
    }

    /// Average time per effort type (in minutes).
    public func averageTimeByEffortType(tasks: [PMTask]) -> [EffortType: Float] {
        var result: [EffortType: Float] = [:]
        for type in EffortType.allCases {
            let typed = tasks.filter { $0.effortType == type && $0.actualMinutes != nil }
            guard !typed.isEmpty else { continue }
            let total = typed.compactMap(\.actualMinutes).reduce(0, +)
            result[type] = Float(total) / Float(typed.count)
        }
        return result
    }

    /// Tasks most frequently deferred (timesDeferred > threshold).
    public func frequentlyDeferred(tasks: [PMTask], threshold: Int = 3) -> [PMTask] {
        tasks.filter { $0.timesDeferred >= threshold }
            .sorted { $0.timesDeferred > $1.timesDeferred }
    }

    /// Summary stats for a project.
    public func projectSummary(tasks: [PMTask]) -> ProjectSummaryStats {
        let total = tasks.count
        let completed = tasks.filter { $0.status == .completed }.count
        let blocked = tasks.filter { $0.status == .blocked }.count
        let waiting = tasks.filter { $0.status == .waiting }.count
        let totalActualMinutes = tasks.compactMap(\.actualMinutes).reduce(0, +)

        return ProjectSummaryStats(
            totalTasks: total,
            completedTasks: completed,
            blockedTasks: blocked,
            waitingTasks: waiting,
            totalActualMinutes: totalActualMinutes
        )
    }
}

/// Summary statistics for a project — neutral observations only.
public struct ProjectSummaryStats: Sendable, Equatable {
    public let totalTasks: Int
    public let completedTasks: Int
    public let blockedTasks: Int
    public let waitingTasks: Int
    public let totalActualMinutes: Int

    public init(
        totalTasks: Int,
        completedTasks: Int,
        blockedTasks: Int,
        waitingTasks: Int,
        totalActualMinutes: Int
    ) {
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.blockedTasks = blockedTasks
        self.waitingTasks = waitingTasks
        self.totalActualMinutes = totalActualMinutes
    }
}
