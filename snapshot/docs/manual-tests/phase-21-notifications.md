# Phase 21: iOS Notifications — Manual Test Brief

## Automated Tests
- **21 tests** in 5 suites, passing via `cd Packages/PMServices && swift test`
- All **579 tests** pass across all 6 packages (no regressions).

### Suites
1. **NotificationTypeTests** (2 tests) — Validates the 4 notification types (waitingCheckBack, deadlineApproaching, checkInReminder, phaseCompletion) and their raw values.
2. **NotificationPreferencesTests** (3 tests) — Validates default values, quiet hours wraparound past midnight, and same-day quiet hours range.
3. **NotificationManagerTests** (10 tests) — Validates scheduling, type disable rejection, quiet hours blocking, daily limit enforcement, snooze blocking, snooze-all, cancel, cancel-all, and authorization request.
4. **BuilderTests** (4 tests) — Validates static builder methods: waitingCheckBack(), deadlineApproaching(), checkInReminder(), phaseCompleted().
5. **SnoozeDurationTests** (2 tests) — Validates 1-day, 3-day, and 7-day snooze duration cases and raw values.

## Manual Verification Checklist

### Authorization & Delivery
- [ ] NotificationManager requests permission on first launch (both macOS and iOS)
- [ ] Notifications are delivered via UNUserNotificationCenter on a real device
- [ ] Notification content shows correct title/body for each type

### Fatigue Prevention
- [ ] Max 2 notifications per day (configurable in Settings)
- [ ] No notifications during quiet hours (default 9 PM to 9 AM)
- [ ] Daily counter resets at midnight

### Snooze
- [ ] Snoozing for 1 day blocks that type for 24 hours
- [ ] Snoozing for 3 days blocks that type for 72 hours
- [ ] Snoozing for 1 week blocks that type for 168 hours
- [ ] snoozeAll blocks all 4 types

### Event-Driven Scheduling
- [ ] Task moved to `.waiting` in Focus Board → schedules waitingCheckBack notification
- [ ] Task moved to `.waiting` in Project Detail → schedules waitingCheckBack notification
- [ ] Deadline within 24h detected on Focus Board load → schedules deadlineApproaching notification
- [ ] Check-in urgency detected on Focus Board load → schedules checkInReminder notification
- [ ] Phase completion detected in Project Detail → schedules phaseCompletion notification

### Settings Integration
- [ ] Global "Notifications enabled" toggle disables all scheduling when off
- [ ] Per-type toggles in Settings control which notification types are enabled:
  - [ ] Waiting items past check-back date
  - [ ] Deadlines approaching (24h)
  - [ ] Check-in reminders
  - [ ] Phase completion
- [ ] Max daily count stepper (1-5) controls fatigue limit
- [ ] Quiet hours start/end pickers (default 9 PM to 9 AM) control quiet period
- [ ] Settings changes take effect on next app launch

### Wiring
- [ ] NotificationManager created in macOS ContentView with correct preferences
- [ ] NotificationManager created in iOS iOSContentView with correct preferences
- [ ] NotificationManager injected into FocusBoardViewModel
- [ ] NotificationManager injected into ProjectDetailViewModel (per-project via cache)
- [ ] NotificationManager injected into CheckInFlowManager
- [ ] enabledTypes reflects both global toggle and per-type toggles

### macOS Regression
- [ ] macOS app continues to function correctly with notification wiring

## Files Created/Modified

### Pre-existing Files (original Phase 21)
- `Packages/PMServices/Sources/PMServices/Notifications/NotificationManager.swift` — NotificationManager with fatigue prevention, quiet hours, snooze, 4 types, builders
- `Packages/PMServices/Sources/PMServices/Notifications/UNNotificationDelivery.swift` — UNUserNotificationCenter implementation
- `Packages/PMServices/Tests/PMServicesTests/NotificationManagerTests.swift` — 21 tests

### Modified Files (audit fixes)
- `Packages/PMData/Sources/PMData/Settings/SettingsManager.swift` — Fixed quietHoursStart default (20→21), added per-type notification toggle properties (notifyWaitingCheckBack, notifyDeadlineApproaching, notifyCheckInReminder, notifyPhaseCompletion)
- `Packages/PMData/Tests/PMDataTests/SettingsTests.swift` — Updated quietHoursStart default expectation
- `Packages/PMFeatures/Sources/PMFeatures/Settings/SettingsView.swift` — Added per-type notification toggle UI
- `Packages/PMFeatures/Sources/PMFeatures/FocusBoard/FocusBoardViewModel.swift` — Added import PMServices, notificationManager property, scheduling calls in load() for deadlines/check-ins, scheduling in setWaiting()
- `Packages/PMFeatures/Sources/PMFeatures/ProjectDetail/ProjectDetailViewModel.swift` — Added notificationManager property, scheduling in checkForCompletedPhases() and waitTask()
- `Packages/PMFeatures/Sources/PMFeatures/CheckIn/CheckInFlowManager.swift` — Added notificationManager property
- `ProjectManager/Sources/ContentView.swift` — Built enabledTypes from per-type settings, wired notificationManager to checkInManager and focusBoardVM and detailVM
- `ProjectManageriOS/Sources/iOSContentView.swift` — Same enabledTypes and wiring fixes
