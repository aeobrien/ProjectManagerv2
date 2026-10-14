import Testing
import Foundation
@testable import PMServices
@testable import PMDomain

// MARK: - EstimateTracker Tests

@Suite("EstimateTracker")
struct EstimateTrackerTests {

    private func makeTask(estimated: Int?, actual: Int?, effort: EffortType? = nil, completed: Date? = Date()) -> PMTask {
        var task = PMTask(milestoneId: UUID(), name: "Task")
        task.adjustedEstimateMinutes = estimated
        task.actualMinutes = actual
        task.effortType = effort
        task.status = .completed
        task.completedAt = completed
        return task
    }

    @Test("Accuracy ratios computed correctly")
    func accuracyRatios() {
        let tracker = EstimateTracker(minDataThreshold: 1)
        let tasks = [
            makeTask(estimated: 60, actual: 90),   // 1.5
            makeTask(estimated: 30, actual: 30),   // 1.0
            makeTask(estimated: 120, actual: 60),  // 0.5
        ]
        let ratios = tracker.accuracyRatios(tasks: tasks)
        #expect(ratios.count == 3)
        #expect(abs(ratios[0] - 1.5) < 0.01)
        #expect(abs(ratios[1] - 1.0) < 0.01)
        #expect(abs(ratios[2] - 0.5) < 0.01)
    }

    @Test("Tasks without estimates are excluded")
    func excludeNoEstimate() {
        let tracker = EstimateTracker(minDataThreshold: 1)
        let tasks = [
            makeTask(estimated: nil, actual: 30),
            makeTask(estimated: 60, actual: nil),
            makeTask(estimated: 0, actual: 30),
        ]
        let ratios = tracker.accuracyRatios(tasks: tasks)
        #expect(ratios.isEmpty)
    }

    @Test("Average accuracy with threshold")
    func averageAccuracy() {
        let tracker = EstimateTracker(minDataThreshold: 3)

        // Not enough data
        let fewTasks = [makeTask(estimated: 60, actual: 60)]
        #expect(tracker.averageAccuracy(tasks: fewTasks) == nil)

        // Enough data
        let tasks = [
            makeTask(estimated: 60, actual: 90),
            makeTask(estimated: 60, actual: 60),
            makeTask(estimated: 60, actual: 30),
        ]
        let avg = tracker.averageAccuracy(tasks: tasks)
        #expect(avg != nil)
        #expect(abs(avg! - 1.0) < 0.01) // (1.5 + 1.0 + 0.5) / 3 = 1.0
    }

    @Test("Accuracy by effort type")
    func accuracyByEffortType() {
        let tracker = EstimateTracker(minDataThreshold: 1)
        let tasks = [
            makeTask(estimated: 60, actual: 120, effort: .deepFocus),
            makeTask(estimated: 30, actual: 30, effort: .quickWin),
        ]
        let result = tracker.accuracyByEffortType(tasks: tasks)
        #expect(result[.deepFocus] != nil)
        #expect(abs(result[.deepFocus]! - 2.0) < 0.01)
    }

    @Test("Suggested multiplier")
    func suggestedMultiplier() {
        let tracker = EstimateTracker(minDataThreshold: 2)
        let tasks = [
            makeTask(estimated: 60, actual: 90),
            makeTask(estimated: 60, actual: 90),
        ]
        let multiplier = tracker.suggestedMultiplier(tasks: tasks)
        #expect(multiplier != nil)
        #expect(abs(multiplier! - 1.5) < 0.01)
    }

    @Test("Multiplier clamped to range")
    func multiplierClamped() {
        let tracker = EstimateTracker(minDataThreshold: 1)
        // Very high ratio
        let overTasks = [makeTask(estimated: 10, actual: 100)]
        let over = tracker.suggestedMultiplier(tasks: overTasks)
        #expect(over != nil)
        #expect(over! <= 3.0)

        // Very low ratio
        let underTasks = [makeTask(estimated: 100, actual: 1)]
        let under = tracker.suggestedMultiplier(tasks: underTasks)
        #expect(under != nil)
        #expect(under! >= 0.5)
    }

    @Test("Accuracy trend")
    func accuracyTrend() {
        let tracker = EstimateTracker(minDataThreshold: 2)
        let baseDate = Date()
        var tasks: [PMTask] = []
        // Older tasks: take 2x as long
        for i in 0..<4 {
            tasks.append(makeTask(
                estimated: 60, actual: 120,
                completed: baseDate.addingTimeInterval(TimeInterval(-86400 * (10 - i)))
            ))
        }
        // Newer tasks: take 1x (accurate)
        for i in 4..<8 {
            tasks.append(makeTask(
                estimated: 60, actual: 60,
                completed: baseDate.addingTimeInterval(TimeInterval(-86400 * (10 - i)))
            ))
        }

        let trend = tracker.accuracyTrend(tasks: tasks)
        #expect(trend != nil)
        #expect(trend!.older > trend!.newer) // Older tasks were less accurate
    }

    @Test("Insufficient data for trend returns nil")
    func noTrend() {
        let tracker = EstimateTracker(minDataThreshold: 5)
        let tasks = [makeTask(estimated: 60, actual: 60)]
        let trend = tracker.accuracyTrend(tasks: tasks)
        #expect(trend == nil)
    }
}

// MARK: - ProjectAnalytics Tests

@Suite("ProjectAnalytics")
struct ProjectAnalyticsTests {

    @Test("Completion rate")
    func completionRate() {
        let analytics = ProjectAnalytics()
        var tasks: [PMTask] = []
        for _ in 0..<3 {
            var t = PMTask(milestoneId: UUID(), name: "Done")
            t.status = .completed
            tasks.append(t)
        }
        tasks.append(PMTask(milestoneId: UUID(), name: "Not done"))

        let rate = analytics.completionRate(tasks: tasks)
        #expect(rate != nil)
        #expect(abs(rate! - 0.75) < 0.01)
    }

    @Test("Completion rate empty")
    func completionRateEmpty() {
        let analytics = ProjectAnalytics()
        #expect(analytics.completionRate(tasks: []) == nil)
    }

    @Test("Average time by effort type")
    func avgTimeByEffort() {
        let analytics = ProjectAnalytics()
        var t1 = PMTask(milestoneId: UUID(), name: "T1")
        t1.effortType = .deepFocus
        t1.actualMinutes = 120
        var t2 = PMTask(milestoneId: UUID(), name: "T2")
        t2.effortType = .deepFocus
        t2.actualMinutes = 60

        let result = analytics.averageTimeByEffortType(tasks: [t1, t2])
        #expect(result[.deepFocus] != nil)
        #expect(abs(result[.deepFocus]! - 90.0) < 0.01)
    }

    @Test("Frequently deferred tasks")
    func frequentlyDeferred() {
        let analytics = ProjectAnalytics()
        var t1 = PMTask(milestoneId: UUID(), name: "Deferred")
        t1.timesDeferred = 5
        var t2 = PMTask(milestoneId: UUID(), name: "Normal")
        t2.timesDeferred = 1

        let result = analytics.frequentlyDeferred(tasks: [t1, t2])
        #expect(result.count == 1)
        #expect(result.first?.name == "Deferred")
    }

    @Test("Project summary stats")
    func projectSummary() {
        let analytics = ProjectAnalytics()
        var completed = PMTask(milestoneId: UUID(), name: "Done")
        completed.status = .completed
        completed.actualMinutes = 60
        var blocked = PMTask(milestoneId: UUID(), name: "Blocked")
        blocked.status = .blocked
        var waiting = PMTask(milestoneId: UUID(), name: "Waiting")
        waiting.status = .waiting

        let summary = analytics.projectSummary(tasks: [completed, blocked, waiting])
        #expect(summary.totalTasks == 3)
        #expect(summary.completedTasks == 1)
        #expect(summary.blockedTasks == 1)
        #expect(summary.waitingTasks == 1)
        #expect(summary.totalActualMinutes == 60)
    }
}
