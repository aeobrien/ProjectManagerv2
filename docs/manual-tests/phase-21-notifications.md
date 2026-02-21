# Phase 21: iOS Notifications — Manual Test Brief

## Automated Tests
- **20 tests** in 5 suites, passing via `cd Packages/PMServices && swift test`

### Suites
1. **NotificationTypeTests** (2 tests) — Validates the 4 notification types (waitingCheckBack, deadlineApproaching, checkInReminder, phaseCompletion) and their associated metadata.
2. **NotificationPreferencesTests** (3 tests) — Validates configurable enabled types, daily limit settings, and quiet hours configuration (default 21:00-09:00).
3. **NotificationManagerTests** (10 tests) — Validates fatigue prevention with max 2 daily notifications, quiet hours enforcement (21:00-09:00), snooze functionality for 1/3/7 day durations, scheduling logic, duplicate prevention, notification delivery via NotificationDeliveryProtocol, daily counter reset, notification history tracking, permission request flow, and error handling.
4. **BuilderTests** (3 tests) — Validates static builder methods: waitingCheckBack(), deadlineApproaching(), checkInReminder(), and phaseCompleted() produce correctly configured notification payloads.
5. **SnoozeDurationTests** (2 tests) — Validates snooze duration calculations for 1-day, 3-day, and 7-day intervals and their date arithmetic.

## Manual Verification Checklist
- [ ] NotificationManager requests notification permission from the user on first use
- [ ] Notifications are scheduled and delivered via UNUserNotificationCenter on a real device
- [ ] Fatigue prevention limits delivery to a maximum of 2 notifications per day
- [ ] No notifications are delivered during quiet hours (21:00-09:00 by default)
- [ ] Snoozing a notification for 1 day reschedules it 24 hours later
- [ ] Snoozing a notification for 3 days reschedules it 72 hours later
- [ ] Snoozing a notification for 7 days reschedules it 168 hours later
- [ ] waitingCheckBack notification fires for items in the waiting state
- [ ] deadlineApproaching notification fires as a deadline nears
- [ ] checkInReminder notification fires at the configured check-in interval
- [ ] phaseCompletion notification fires when a project phase completes
- [ ] NotificationPreferences changes (enabled types, daily limit, quiet hours) take effect immediately
- [ ] NotificationDeliveryProtocol abstraction allows test doubles to replace UNUserNotificationCenter

## Files Created/Modified
### New Files
- `Packages/PMServices/Sources/PMServices/Notifications/NotificationManager.swift` — NotificationManager with fatigue prevention (max 2 daily), quiet hours (21:00-09:00), snooze (1/3/7 days), 4 notification types, NotificationPreferences, NotificationDeliveryProtocol, and static builder methods
