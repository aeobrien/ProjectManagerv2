import Testing
import Foundation
@testable import PMServices

// MARK: - Mock Notification Delivery

final class MockNotificationDelivery: NotificationDeliveryProtocol, @unchecked Sendable {
    var scheduledNotifications: [ScheduledNotification] = []
    var cancelledIds: [UUID] = []
    var cancelledAll = false
    var authorized = true
    var shouldThrow = false

    func schedule(_ notification: ScheduledNotification) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        scheduledNotifications.append(notification)
    }

    func cancel(id: UUID) async throws {
        cancelledIds.append(id)
    }

    func cancelAll() async throws {
        cancelledAll = true
    }

    func requestAuthorization() async throws -> Bool {
        authorized
    }
}

// MARK: - NotificationType Tests

@Suite("NotificationType")
struct NotificationTypeTests {

    @Test("All cases exist")
    func allCases() {
        let types = NotificationType.allCases
        #expect(types.count == 4)
        #expect(types.contains(.waitingCheckBack))
        #expect(types.contains(.deadlineApproaching))
        #expect(types.contains(.checkInReminder))
        #expect(types.contains(.phaseCompletion))
    }

    @Test("Raw values")
    func rawValues() {
        #expect(NotificationType.waitingCheckBack.rawValue == "waitingCheckBack")
        #expect(NotificationType.deadlineApproaching.rawValue == "deadlineApproaching")
    }
}

// MARK: - NotificationPreferences Tests

@Suite("NotificationPreferences")
struct NotificationPreferencesTests {

    @Test("Default preferences")
    func defaults() {
        let prefs = NotificationPreferences()
        #expect(prefs.enabledTypes.count == 4)
        #expect(prefs.maxDailyCount == 2)
        #expect(prefs.quietHoursStart == 21)
        #expect(prefs.quietHoursEnd == 9)
    }

    @Test("Quiet hours wrapping past midnight")
    func quietHoursWrap() {
        let prefs = NotificationPreferences(quietHoursStart: 21, quietHoursEnd: 9)

        // 10 PM — should be quiet
        var components = DateComponents()
        components.hour = 22
        components.minute = 0
        let late = Calendar.current.date(from: components)!
        #expect(prefs.isQuietHour(late) == true)

        // 3 AM — should be quiet
        components.hour = 3
        let early = Calendar.current.date(from: components)!
        #expect(prefs.isQuietHour(early) == true)

        // 12 PM — should not be quiet
        components.hour = 12
        let noon = Calendar.current.date(from: components)!
        #expect(prefs.isQuietHour(noon) == false)
    }

    @Test("Quiet hours same-day range")
    func quietHoursSameDay() {
        let prefs = NotificationPreferences(quietHoursStart: 22, quietHoursEnd: 23)

        var components = DateComponents()
        components.hour = 22
        components.minute = 30
        let inRange = Calendar.current.date(from: components)!
        #expect(prefs.isQuietHour(inRange) == true)

        components.hour = 10
        let outOfRange = Calendar.current.date(from: components)!
        #expect(prefs.isQuietHour(outOfRange) == false)
    }
}

// MARK: - NotificationManager Tests

@Suite("NotificationManager")
struct NotificationManagerTests {

    @Test("Schedule allowed notification")
    func scheduleAllowed() async throws {
        let delivery = MockNotificationDelivery()
        let prefs = NotificationPreferences(
            quietHoursStart: 23,
            quietHoursEnd: 5
        )
        let manager = NotificationManager(delivery: delivery, preferences: { prefs })

        // Use a non-quiet hour
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        let noon = Calendar.current.date(from: components)!

        let notification = ScheduledNotification(
            type: .checkInReminder,
            title: "Test",
            body: "Test body",
            scheduledFor: noon
        )

        let result = try await manager.scheduleIfAllowed(notification)
        #expect(result == true)
        #expect(delivery.scheduledNotifications.count == 1)
    }

    @Test("Disabled type is rejected")
    func disabledType() async throws {
        let delivery = MockNotificationDelivery()
        let prefs = NotificationPreferences(
            enabledTypes: [.deadlineApproaching] // Only deadlines enabled
        )
        let manager = NotificationManager(delivery: delivery, preferences: { prefs })

        let notification = ScheduledNotification(
            type: .checkInReminder,
            title: "Test",
            body: "Body",
            scheduledFor: Date()
        )

        let result = try await manager.scheduleIfAllowed(notification)
        #expect(result == false)
        #expect(delivery.scheduledNotifications.isEmpty)
    }

    @Test("Quiet hours block scheduling")
    func quietHoursBlock() async throws {
        let delivery = MockNotificationDelivery()
        let prefs = NotificationPreferences(quietHoursStart: 0, quietHoursEnd: 23) // Almost always quiet
        let manager = NotificationManager(delivery: delivery, preferences: { prefs })

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        let quietTime = Calendar.current.date(from: components)!

        let notification = ScheduledNotification(
            type: .checkInReminder,
            title: "Test",
            body: "Body",
            scheduledFor: quietTime
        )

        let result = try await manager.scheduleIfAllowed(notification)
        #expect(result == false)
    }

    @Test("Daily limit enforced")
    func dailyLimit() async throws {
        let delivery = MockNotificationDelivery()
        let prefs = NotificationPreferences(
            maxDailyCount: 1,
            quietHoursStart: 23,
            quietHoursEnd: 5
        )
        let manager = NotificationManager(delivery: delivery, preferences: { prefs })

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        let noon = Calendar.current.date(from: components)!

        let n1 = ScheduledNotification(type: .checkInReminder, title: "1", body: "1", scheduledFor: noon)
        let n2 = ScheduledNotification(type: .deadlineApproaching, title: "2", body: "2", scheduledFor: noon)

        let r1 = try await manager.scheduleIfAllowed(n1)
        let r2 = try await manager.scheduleIfAllowed(n2)

        #expect(r1 == true)
        #expect(r2 == false) // Limit reached
    }

    @Test("Snooze blocks scheduling")
    func snoozeBlocks() async throws {
        let delivery = MockNotificationDelivery()
        let prefs = NotificationPreferences(quietHoursStart: 23, quietHoursEnd: 5)
        let manager = NotificationManager(delivery: delivery, preferences: { prefs })

        manager.snooze(.checkInReminder, duration: .oneDay)
        #expect(manager.isSnoozed(.checkInReminder) == true)
        #expect(manager.isSnoozed(.deadlineApproaching) == false)

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        let noon = Calendar.current.date(from: components)!

        let notification = ScheduledNotification(
            type: .checkInReminder,
            title: "Test",
            body: "Body",
            scheduledFor: noon
        )

        let result = try await manager.scheduleIfAllowed(notification)
        #expect(result == false)
    }

    @Test("Snooze all types")
    func snoozeAll() {
        let delivery = MockNotificationDelivery()
        let prefs = NotificationPreferences()
        let manager = NotificationManager(delivery: delivery, preferences: { prefs })

        manager.snoozeAll(duration: .threeDays)

        for type in NotificationType.allCases {
            #expect(manager.isSnoozed(type) == true)
        }
    }

    @Test("Cancel notification")
    func cancel() async throws {
        let delivery = MockNotificationDelivery()
        let prefs = NotificationPreferences()
        let manager = NotificationManager(delivery: delivery, preferences: { prefs })
        let id = UUID()

        try await manager.cancel(id: id)
        #expect(delivery.cancelledIds.contains(id))
    }

    @Test("Cancel all notifications")
    func cancelAll() async throws {
        let delivery = MockNotificationDelivery()
        let prefs = NotificationPreferences()
        let manager = NotificationManager(delivery: delivery, preferences: { prefs })

        try await manager.cancelAll()
        #expect(delivery.cancelledAll == true)
    }

    @Test("Request authorization")
    func requestAuth() async throws {
        let delivery = MockNotificationDelivery()
        let prefs = NotificationPreferences()
        let manager = NotificationManager(delivery: delivery, preferences: { prefs })

        let result = try await manager.requestAuthorization()
        #expect(result == true)
    }
}

// MARK: - Notification Builders Tests

@Suite("NotificationBuilders")
struct NotificationBuilderTests {

    @Test("Waiting check-back notification")
    func waitingCheckBack() {
        let n = NotificationManager.waitingCheckBack(taskName: "Follow up", projectName: "App", taskId: UUID())
        #expect(n.type == .waitingCheckBack)
        #expect(n.title.contains("Follow up"))
        #expect(n.body.contains("App"))
    }

    @Test("Deadline approaching notification")
    func deadlineApproaching() {
        let deadline = Date().addingTimeInterval(86400)
        let n = NotificationManager.deadlineApproaching(name: "Ship MVP", projectName: "App", deadline: deadline, entityId: UUID())
        #expect(n.type == .deadlineApproaching)
        #expect(n.title.contains("Ship MVP"))
    }

    @Test("Check-in reminder notification")
    func checkInReminder() {
        let n = NotificationManager.checkInReminder(projectName: "App", projectId: UUID())
        #expect(n.type == .checkInReminder)
        #expect(n.title.contains("App"))
    }

    @Test("Phase completed notification")
    func phaseCompleted() {
        let n = NotificationManager.phaseCompleted(phaseName: "Phase 1", projectName: "App", phaseId: UUID())
        #expect(n.type == .phaseCompletion)
        #expect(n.title.contains("Phase 1"))
    }
}

// MARK: - NotificationSnoozeDuration Tests

@Suite("NotificationSnoozeDuration")
struct NotificationSnoozeDurationTests {

    @Test("All cases")
    func allCases() {
        let cases = NotificationSnoozeDuration.allCases
        #expect(cases.count == 3)
    }

    @Test("Raw values")
    func rawValues() {
        #expect(NotificationSnoozeDuration.oneDay.rawValue == "1 Day")
        #expect(NotificationSnoozeDuration.threeDays.rawValue == "3 Days")
        #expect(NotificationSnoozeDuration.oneWeek.rawValue == "1 Week")
    }
}
