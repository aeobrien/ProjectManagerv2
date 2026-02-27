import Foundation
import PMDomain

/// Cross-session pattern detection — computes observations from session history for inclusion in context.
public struct CrossSessionPatterns: Equatable, Sendable {
    /// Days since the most recent session (nil if no sessions).
    public let daysSinceLastSession: Int?
    /// Average days between sessions.
    public let averageSessionGap: Double?
    /// Number of completed sessions.
    public let completedSessionCount: Int
    /// Tasks that have been deferred across multiple sessions.
    public let frequentlyDeferredTaskNames: [String]
    /// Number of tasks deferred 3+ times.
    public let deferralCount: Int
    /// Engagement trend: increasing, stable, or decreasing session frequency.
    public let engagementTrend: EngagementTrend?
    /// Whether this qualifies as a "return" (14+ days since last session).
    public let isReturn: Bool

    public enum EngagementTrend: String, Equatable, Sendable {
        case increasing
        case stable
        case decreasing
    }

    public init(
        daysSinceLastSession: Int? = nil,
        averageSessionGap: Double? = nil,
        completedSessionCount: Int = 0,
        frequentlyDeferredTaskNames: [String] = [],
        deferralCount: Int = 0,
        engagementTrend: EngagementTrend? = nil,
        isReturn: Bool = false
    ) {
        self.daysSinceLastSession = daysSinceLastSession
        self.averageSessionGap = averageSessionGap
        self.completedSessionCount = completedSessionCount
        self.frequentlyDeferredTaskNames = frequentlyDeferredTaskNames
        self.deferralCount = deferralCount
        self.engagementTrend = engagementTrend
        self.isReturn = isReturn
    }

    /// Compute patterns from session summaries and task data.
    public static func compute(
        sessions: [Session],
        summaries: [SessionSummary],
        frequentlyDeferredTasks: [PMTask],
        now: Date = Date()
    ) -> CrossSessionPatterns {
        let completedSessions = sessions
            .filter { $0.status == .completed || $0.status == .autoSummarised }
            .sorted { $0.completedAt ?? $0.lastActiveAt < $1.completedAt ?? $1.lastActiveAt }

        let daysSinceLast: Int?
        if let lastSession = completedSessions.last {
            let lastDate = lastSession.completedAt ?? lastSession.lastActiveAt
            daysSinceLast = Calendar.current.dateComponents([.day], from: lastDate, to: now).day
        } else {
            daysSinceLast = nil
        }

        // Average gap between sessions
        let averageGap: Double?
        if completedSessions.count >= 2 {
            var totalDays: Double = 0
            for i in 1..<completedSessions.count {
                let prev = completedSessions[i - 1].completedAt ?? completedSessions[i - 1].lastActiveAt
                let curr = completedSessions[i].completedAt ?? completedSessions[i].lastActiveAt
                totalDays += curr.timeIntervalSince(prev) / 86400
            }
            averageGap = totalDays / Double(completedSessions.count - 1)
        } else {
            averageGap = nil
        }

        // Engagement trend: compare gap of recent sessions vs older sessions
        let trend: EngagementTrend?
        if completedSessions.count >= 4 {
            let mid = completedSessions.count / 2
            let olderSessions = Array(completedSessions.prefix(mid))
            let newerSessions = Array(completedSessions.suffix(from: mid))

            let olderGap = averageGapDays(olderSessions)
            let newerGap = averageGapDays(newerSessions)

            if let older = olderGap, let newer = newerGap {
                let ratio = newer / older
                if ratio < 0.7 {
                    trend = .increasing
                } else if ratio > 1.4 {
                    trend = .decreasing
                } else {
                    trend = .stable
                }
            } else {
                trend = nil
            }
        } else {
            trend = nil
        }

        let isReturn = daysSinceLast.map { $0 >= 14 } ?? false

        // Deferral patterns from summaries
        var deferredNames: [String] = []
        for summary in summaries {
            if case .executionSupport(let data) = summary.modeSpecific {
                deferredNames.append(contentsOf: data.tasksDeferred)
            }
        }
        // Also include frequently deferred tasks from project structure
        let taskDeferredNames = frequentlyDeferredTasks.map(\.name)

        // Combine and deduplicate
        let allDeferredNames = Array(Set(deferredNames + taskDeferredNames))

        return CrossSessionPatterns(
            daysSinceLastSession: daysSinceLast,
            averageSessionGap: averageGap,
            completedSessionCount: completedSessions.count,
            frequentlyDeferredTaskNames: allDeferredNames,
            deferralCount: frequentlyDeferredTasks.count,
            engagementTrend: trend,
            isReturn: isReturn
        )
    }

    // MARK: - Private

    private static func averageGapDays(_ sessions: [Session]) -> Double? {
        guard sessions.count >= 2 else { return nil }
        var total: Double = 0
        for i in 1..<sessions.count {
            let prev = sessions[i - 1].completedAt ?? sessions[i - 1].lastActiveAt
            let curr = sessions[i].completedAt ?? sessions[i].lastActiveAt
            total += curr.timeIntervalSince(prev) / 86400
        }
        return total / Double(sessions.count - 1)
    }
}
