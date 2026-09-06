import Foundation

extension Milestone {
    /// Progress as a percentage based on completed tasks.
    public func progressPercent(tasks: [PMTask]) -> Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.status == .completed }.count
        return Double(completed) / Double(tasks.count) * 100
    }

    /// Whether the milestone has any tasks in a blocked or waiting state.
    public func hasUnresolvedBlocks(tasks: [PMTask]) -> Bool {
        tasks.contains { $0.status == .blocked || $0.status == .waiting }
    }

    /// Waiting tasks whose check-back date has arrived or passed.
    public func waitingItemsDueSoon(tasks: [PMTask], now: Date = Date()) -> [PMTask] {
        tasks.filter { task in
            task.status == .waiting &&
            task.waitingCheckBackDate.map { $0 <= now } ?? false
        }
    }

    /// Estimate accuracy ratio: actual vs estimated time across completed tasks.
    public func estimateAccuracy(tasks: [PMTask]) -> Double? {
        let completed = tasks.filter {
            $0.status == .completed && $0.timeEstimateMinutes != nil && $0.actualMinutes != nil
        }
        guard !completed.isEmpty else { return nil }
        let totalEstimated = completed.compactMap(\.timeEstimateMinutes).reduce(0, +)
        let totalActual = completed.compactMap(\.actualMinutes).reduce(0, +)
        guard totalEstimated > 0 else { return nil }
        return Double(totalActual) / Double(totalEstimated)
    }
}
