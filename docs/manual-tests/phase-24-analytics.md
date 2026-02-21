# Phase 24: Estimate Calibration & Analytics — Manual Test Brief

## Automated Tests
- **23 tests** in 3 suites, passing via `cd Packages/PMServices && swift test` and `cd Packages/PMFeatures && swift test`

### Suites
1. **EstimateTrackerTests** (13 tests) — Validates accuracy ratio computation, average accuracy with minimum data threshold, accuracy breakdown by effort type, suggested pessimism multiplier calculation (clamped 0.5-3.0), accuracy trend over time, handling of zero-estimate edge cases, single data point behavior, large dataset aggregation, mixed effort types, and boundary conditions for the pessimism clamp.
2. **ProjectAnalyticsTests** (5 tests) — Validates completion rate calculation, average time by effort type, frequently deferred task detection, project summary stats generation, and empty project edge case handling.
3. **AnalyticsViewModelTests** (5 tests) — Validates @Observable ViewModel initial state, data loading and display, ADHD-safe guardrails (no streaks, no gamification, no red/green scoring), neutral language descriptions for accuracy levels, and refresh behavior.

## Manual Verification Checklist
- [ ] EstimateTracker computes accuracy ratios correctly from actual vs. estimated durations
- [ ] Average accuracy requires a minimum data threshold before reporting a value
- [ ] Accuracy breakdown by effort type separates quick, medium, and large effort tasks
- [ ] Suggested pessimism multiplier stays within the 0.5-3.0 clamp range
- [ ] Accuracy trend shows directional improvement or decline over time
- [ ] ProjectAnalytics computes completion rate as a percentage of completed vs. total tasks
- [ ] ProjectAnalytics calculates average time by effort type from historical data
- [ ] Frequently deferred tasks are detected and surfaced in the project summary
- [ ] AnalyticsViewModel displays data using neutral, non-judgmental language
- [ ] AnalyticsViewModel does not include streaks, gamification elements, or red/green color scoring
- [ ] Analytics views render correctly and load data without blocking the main thread

## Files Created/Modified
### New Files
- `Packages/PMServices/Sources/PMServices/Analytics/EstimateTracker.swift` — Accuracy ratios, average accuracy with min data threshold, accuracy by effort type, suggested pessimism multiplier (clamped 0.5-3.0), and accuracy trend over time
- `Packages/PMFeatures/Sources/PMFeatures/Analytics/AnalyticsViewModel.swift` — @Observable ViewModel with ADHD-safe guardrails (no streaks, no gamification, no red/green scoring) and neutral language descriptions
