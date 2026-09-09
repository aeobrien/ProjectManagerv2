# Phase 9: Quick Capture & Settings — Manual Test Brief

## Automated Tests
- **5 tests** in 1 suite, all passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **QuickCaptureViewModel** (5 tests) — initial state defaults, load categories from repository, capture project with valid name, empty name validation error, toggle voice input mode

## Manual Verification Checklist
- [ ] `cd Packages/PMFeatures && swift test` — all tests pass (Phase 5 through Phase 9)
- [ ] `xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'` — builds without errors
- [ ] App launches and Quick Capture interface is accessible
- [ ] QuickCaptureView displays a text input field for project name
- [ ] Text/voice toggle switches between input modes
- [ ] Optional title field can be left blank or filled in
- [ ] Category picker lists all available categories
- [ ] Capturing a project with a valid name creates the project successfully
- [ ] Success messaging appears after a project is captured
- [ ] Attempting to capture with an empty name shows an error message
- [ ] Voice toggle switches the input mode indicator
- [ ] Navigating to "Settings" shows the SettingsView
- [ ] Focus Board settings section is present (max focus slots, per-category limit)
- [ ] Check-in prompts settings are configurable
- [ ] Time estimates settings are present
- [ ] Notifications settings section is present
- [ ] Voice settings section is present
- [ ] AI settings section is present
- [ ] Life planner settings section is present
- [ ] Integration API settings section is present
- [ ] Settings changes persist across app restarts (backed by SettingsManager)

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/QuickCapture/QuickCaptureViewModel.swift` — Quick project creation from text/voice, category selection
- `Packages/PMFeatures/Sources/PMFeatures/QuickCapture/QuickCaptureView.swift` — Lightweight capture interface with text/voice toggle, optional title, category picker, success/error messaging
- `Packages/PMFeatures/Sources/PMFeatures/Settings/SettingsView.swift` — Comprehensive settings panel (Focus Board, check-in prompts, time estimates, notifications, voice, AI, life planner, integration API)

## Pass Criteria
- [ ] All 5 tests pass
- [ ] Full PMFeatures test suite passes (Phase 5 through Phase 9)
- [ ] App builds and launches without errors
- [ ] Quick capture creates projects successfully
- [ ] Settings view displays all configuration sections
- [ ] Settings persist via UserDefaults/SettingsManager
- [ ] No warnings or errors in the build
