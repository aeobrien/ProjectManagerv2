import Foundation

extension Phase {
    /// Progress as a percentage based on completed milestones.
    public func progressPercent(milestones: [Milestone], tasksByMilestone: [UUID: [PMTask]]) -> Double {
        guard !milestones.isEmpty else { return 0 }
        let totalTasks = milestones.flatMap { tasksByMilestone[$0.id] ?? [] }
        guard !totalTasks.isEmpty else {
            // Fall back to milestone-level completion if no tasks exist
            let completed = milestones.filter { $0.status == .completed }.count
            return Double(completed) / Double(milestones.count) * 100
        }
        let completed = totalTasks.filter { $0.status == .completed }.count
        return Double(completed) / Double(totalTasks.count) * 100
    }
}
