import Foundation
import PMDomain
import PMUtilities
import os

/// Types of notifications the app can schedule.
public enum NotificationType: String, Sendable, Codable, CaseIterable {
    case waitingCheckBack       // Waiting item past its check-back date
    case deadlineApproaching    // Deadline within 24h
    case checkInReminder        // Opt-in check-in nudge
    case phaseCompletion        // All milestones in a phase completed
}

/// A scheduled notification record.
public struct ScheduledNotification: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let type: NotificationType
    public let title: String
    public let body: String
    public let scheduledFor: Date
    public let entityId: UUID?
    public let projectName: String?

    public init(
        id: UUID = UUID(),
        type: NotificationType,
        title: String,
        body: String,
        scheduledFor: Date,
        entityId: UUID? = nil,
        projectName: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.scheduledFor = scheduledFor
        self.entityId = entityId
        self.projectName = projectName
    }
}

/// Notification preferences.
public struct NotificationPreferences: Equatable, Sendable, Codable {
    public var enabledTypes: Set<NotificationType>
    public var maxDailyCount: Int
    public var quietHoursStart: Int  // Hour (0-23)
    public var quietHoursEnd: Int    // Hour (0-23)

    public init(
        enabledTypes: Set<NotificationType> = Set(NotificationType.allCases),
        maxDailyCount: Int = 2,
        quietHoursStart: Int = 21,  // 9 PM
        quietHoursEnd: Int = 9      // 9 AM
    ) {
        self.enabledTypes = enabledTypes
        self.maxDailyCount = maxDailyCount
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
    }

    /// Check if a given time falls within quiet hours.
    public func isQuietHour(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        if quietHoursStart > quietHoursEnd {
            // Wraps past midnight (e.g., 21-9)
            return hour >= quietHoursStart || hour < quietHoursEnd
        } else {
            // Same day range (e.g., 22-23)
            return hour >= quietHoursStart && hour < quietHoursEnd
        }
    }
}

extension NotificationType: Hashable {}

/// Protocol for the notification delivery backend (testable without UNUserNotificationCenter).
public protocol NotificationDeliveryProtocol: Sendable {
    func schedule(_ notification: ScheduledNotification) async throws
    func cancel(id: UUID) async throws
    func cancelAll() async throws
    func requestAuthorization() async throws -> Bool
}

/// Manages notification scheduling with fatigue prevention and snooze support.
public final class NotificationManager: Sendable {
    private let delivery: NotificationDeliveryProtocol
    private let preferences: @Sendable () -> NotificationPreferences

    /// Snooze tracking — type → snooze expiry.
    private let _snoozedUntil: ManagedAtomic<[NotificationType: Date]>

    /// Today's scheduled count tracking.
    private let _scheduledToday: ManagedAtomic<ScheduledTodayState>

    public init(
        delivery: NotificationDeliveryProtocol,
        preferences: @escaping @Sendable () -> NotificationPreferences
    ) {
        self.delivery = delivery
        self.preferences = preferences
        self._snoozedUntil = ManagedAtomic([:])
        self._scheduledToday = ManagedAtomic(ScheduledTodayState())
    }

    // MARK: - Scheduling

    /// Schedule a notification if allowed by preferences and fatigue limits.
    public func scheduleIfAllowed(_ notification: ScheduledNotification) async throws -> Bool {
        let prefs = preferences()

        // Check if type is enabled
        guard prefs.enabledTypes.contains(notification.type) else { return false }

        // Check snooze
        let snoozed = _snoozedUntil.load()
        if let expiry = snoozed[notification.type], Date() < expiry {
            return false
        }

        // Check quiet hours
        if prefs.isQuietHour(notification.scheduledFor) {
            return false
        }

        // Check daily limit
        let todayState = _scheduledToday.load()
        let today = Calendar.current.startOfDay(for: Date())
        let count: Int
        if todayState.date == today {
            count = todayState.count
        } else {
            count = 0
        }

        guard count < prefs.maxDailyCount else { return false }

        // Schedule
        try await delivery.schedule(notification)

        // Update today count
        _scheduledToday.store(ScheduledTodayState(date: today, count: count + 1))

        Log.ui.info("Scheduled notification: \(notification.type.rawValue)")
        return true
    }

    /// Cancel a specific notification.
    public func cancel(id: UUID) async throws {
        try await delivery.cancel(id: id)
    }

    /// Cancel all notifications.
    public func cancelAll() async throws {
        try await delivery.cancelAll()
    }

    // MARK: - Snooze

    /// Snooze a notification type for a duration.
    public func snooze(_ type: NotificationType, duration: NotificationSnoozeDuration) {
        var snoozed = _snoozedUntil.load()
        let expiry: Date
        switch duration {
        case .oneDay:
            expiry = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        case .threeDays:
            expiry = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        case .oneWeek:
            expiry = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        }
        snoozed[type] = expiry
        _snoozedUntil.store(snoozed)
    }

    /// Snooze all notification types.
    public func snoozeAll(duration: NotificationSnoozeDuration) {
        for type in NotificationType.allCases {
            snooze(type, duration: duration)
        }
    }

    /// Check if a type is currently snoozed.
    public func isSnoozed(_ type: NotificationType) -> Bool {
        let snoozed = _snoozedUntil.load()
        guard let expiry = snoozed[type] else { return false }
        return Date() < expiry
    }

    // MARK: - Authorization

    /// Request notification permissions.
    public func requestAuthorization() async throws -> Bool {
        try await delivery.requestAuthorization()
    }

    // MARK: - Notification Builders

    /// Create a waiting-item check-back notification.
    public static func waitingCheckBack(taskName: String, projectName: String, taskId: UUID) -> ScheduledNotification {
        ScheduledNotification(
            type: .waitingCheckBack,
            title: "Check back: \(taskName)",
            body: "This task in \(projectName) was waiting — time to follow up.",
            scheduledFor: Date(),
            entityId: taskId,
            projectName: projectName
        )
    }

    /// Create a deadline-approaching notification.
    public static func deadlineApproaching(name: String, projectName: String, deadline: Date, entityId: UUID) -> ScheduledNotification {
        ScheduledNotification(
            type: .deadlineApproaching,
            title: "Due soon: \(name)",
            body: "Deadline in \(projectName) is within 24 hours.",
            scheduledFor: Calendar.current.date(byAdding: .hour, value: -24, to: deadline) ?? Date(),
            entityId: entityId,
            projectName: projectName
        )
    }

    /// Create a check-in reminder notification.
    public static func checkInReminder(projectName: String, projectId: UUID) -> ScheduledNotification {
        ScheduledNotification(
            type: .checkInReminder,
            title: "Check in on \(projectName)?",
            body: "It's been a while since your last check-in.",
            scheduledFor: Date(),
            entityId: projectId,
            projectName: projectName
        )
    }

    /// Create a phase completion notification.
    public static func phaseCompleted(phaseName: String, projectName: String, phaseId: UUID) -> ScheduledNotification {
        ScheduledNotification(
            type: .phaseCompletion,
            title: "Phase complete: \(phaseName)",
            body: "All milestones in \(projectName) are done. Time for a retrospective?",
            scheduledFor: Date(),
            entityId: phaseId,
            projectName: projectName
        )
    }
}

// MARK: - Notification Snooze Duration

public enum NotificationSnoozeDuration: String, Sendable, CaseIterable {
    case oneDay = "1 Day"
    case threeDays = "3 Days"
    case oneWeek = "1 Week"
}

// MARK: - Simple thread-safe wrapper

/// Simple wrapper for thread-safe value access.
final class ManagedAtomic<Value: Sendable>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func load() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func store(_ newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}

/// Tracks how many notifications have been scheduled today.
struct ScheduledTodayState: Sendable {
    let date: Date
    let count: Int

    init(date: Date = Calendar.current.startOfDay(for: Date()), count: Int = 0) {
        self.date = date
        self.count = count
    }
}
