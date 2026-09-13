import Foundation
import UserNotifications

/// Delivers notifications via UNUserNotificationCenter.
public struct UNNotificationDelivery: NotificationDeliveryProtocol {
    public init() {}

    public func schedule(_ notification: ScheduledNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let timeInterval = max(notification.scheduledFor.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)

        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    public func cancel(id: UUID) async throws {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [id.uuidString]
        )
    }

    public func cancelAll() async throws {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    public func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }
}
