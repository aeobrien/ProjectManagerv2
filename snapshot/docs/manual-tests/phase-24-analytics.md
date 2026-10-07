# Phase 24: Estimate Calibration & Analytics — Manual Test Brief

## Automated Tests
- **23 tests** in 3 suites, passing via `cd Packages/PMServices && swift test` and `cd Packages/PMFeatures && swift test`
- All **167 tests** pass in PMServices, **235 tests** pass in PMFeatures (no regressions).

### Suites
1. **EstimateTrackerTests** (13 tests) — Accuracy ratios, average accuracy with min threshold, accuracy by effort type, suggested multiplier (clamped 0.5-3.0), trend detection, zero-estimate edge cases, empty data.
2. **ProjectAnalyticsTests** (5 tests) — Completion rate, average time by effort, frequently deferred detection, project summary stats, empty set handling.
3. **AnalyticsViewModelTests** (5 tests) — Initial state, data loading, insufficient data handling, neutral language descriptions, multiplier description.

## How to Access

### Navigation Path
1. Open app (macOS or iOS)
2. Select a project from Focus Board or Project Browser
3. In Project Detail, tap/click the **"Analytics"** tab (5th tab after Roadmap, Timeline, Documents, Overview)

### Data Setup
To see meaningful analytics, the selected project needs:
- At least 5 completed tasks (minimum threshold for accuracy display)
- Tasks with both `estimatedMinutes` and `actualMinutes` set
- Variety of effort types (quickWin, smallBatch, mediumEffort, deepWork) for breakdown

## Manual Verification Checklist

### Estimate Tracking (24.1)
- [ ] Average accuracy only appears after >= 5 completed tasks with estimates
- [ ] Before threshold: "Not Enough Data" empty state with neutral messaging
- [ ] Accuracy ratio computed as actual/estimated time across tasks
- [ ] Accuracy breakdown shows per effort type (quickWin, smallBatch, etc.)
- [ ] Suggested pessimism multiplier stays within 0.5x - 3.0x range
- [ ] Accuracy trend shows directional arrow (improving/declining) when enough data

### Analytics View (24.2)
- [ ] AnalyticsView accessible as "Analytics" tab in ProjectDetailView
- [ ] Summary section shows total tasks, completed count, completion percentage
- [ ] Estimate accuracy section shows ratio and neutral description
- [ ] Effort breakdown section shows per-type accuracy and average time
- [ ] Frequently deferred section lists tasks with >= 3 deferrals

### ADHD Guardrails
- [ ] **No streaks** — nowhere in the UI
- [ ] **No gamification** — no badges, points, rewards
- [ ] **No comparative metrics** — no cross-project or cross-user comparisons
- [ ] **No red/green scoring** — gauge uses neutral accent color, trend arrow uses secondary color
- [ ] Language is neutral throughout: "tend to finish faster", "generally close", "consider adding X%"

### AI Awareness (24.3)
- [ ] AI chat context includes estimate accuracy, suggested multiplier, and trend when available
- [ ] AI can reference calibration data when discussing estimates (e.g., "your estimates have been X% accurate")
- [ ] Estimate data appears in ESTIMATE CALIBRATION section of AI context
- [ ] When no estimate data available, section is omitted (not empty)

### Platform Parity
- [ ] macOS: Analytics tab accessible in ProjectDetailView
- [ ] iOS: Analytics tab accessible in ProjectDetailView
- [ ] Both platforms create AnalyticsViewModel per project

## Files Created/Modified

### New Files (Phase 24)
- `Packages/PMServices/Sources/PMServices/Analytics/EstimateTracker.swift` — EstimateTracker (accuracy ratios, trends, multiplier) and ProjectAnalytics (completion rates, effort breakdown, deferred detection)
- `Packages/PMFeatures/Sources/PMFeatures/Analytics/AnalyticsViewModel.swift` — @Observable ViewModel with neutral language descriptions
- `Packages/PMFeatures/Sources/PMFeatures/Analytics/AnalyticsView.swift` — SwiftUI analytics dashboard with summary, accuracy, effort, deferred sections

### Modified Files (This Audit)
- `Packages/PMFeatures/Sources/PMFeatures/ProjectDetail/ProjectDetailView.swift` — Added "Analytics" tab to DetailTab enum, wired AnalyticsView
- `Packages/PMFeatures/Sources/PMFeatures/Analytics/AnalyticsView.swift` — Fixed red/green/orange gauge to neutral accent color, trend arrow to secondary color
- `Packages/PMServices/Sources/PMServices/AI/ContextAssembler.swift` — Added estimateAccuracy, suggestedMultiplier, accuracyTrend to ProjectContext; added ESTIMATE CALIBRATION section to formatProjectContext()
- `Packages/PMFeatures/Sources/PMFeatures/Chat/ChatViewModel.swift` — Added EstimateTracker computation in buildProjectContext()
- `ProjectManager/Sources/ContentView.swift` — Create AnalyticsViewModel per project in makeProjectDetailView()
- `ProjectManageriOS/Sources/iOSContentView.swift` — Same wiring as macOS
