# Phase 4: Design System — Manual Test Brief

## Automated Tests
- **2 tests** in 1 suite, all passing via `cd Packages/PMDesignSystem && swift test`

### Suites
1. **PMDesignSystem** (2 tests) — basic component rendering, token availability (colour and icon tokens resolve without errors)

## Manual Verification Checklist
- [ ] `cd Packages/PMDesignSystem && swift test` — all 2 tests pass
- [ ] `xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'` — builds without errors
- [ ] App still launches and shows existing UI
- [ ] ColourTokens provide 20+ colour definitions for app theming
- [ ] IconTokens map to valid SF Symbol names
- [ ] PMCard renders with correct padding, background, and corner radius
- [ ] PMEmptyState displays icon, title, and description
- [ ] PMSectionHeader renders with correct typography
- [ ] PMProgressLabel shows label and formatted percentage
- [ ] Health badges (stale, blocked, deferred) display distinct visual indicators
- [ ] PMProgressBar renders a horizontal fill bar with correct proportion
- [ ] PMCircularProgress renders a circular progress indicator
- [ ] TaskCardView displays task information in a reusable card layout

## Files Created/Modified
### New Files
- `Packages/PMDesignSystem/Sources/PMDesignSystem/Tokens/ColourTokens.swift` — 20+ colour definitions for app theming
- `Packages/PMDesignSystem/Sources/PMDesignSystem/Tokens/IconTokens.swift` — SF Symbol icon mappings
- `Packages/PMDesignSystem/Sources/PMDesignSystem/Components/CommonLayouts.swift` — PMCard, PMEmptyState, PMSectionHeader, PMProgressLabel
- `Packages/PMDesignSystem/Sources/PMDesignSystem/Components/HealthBadges.swift` — Visual indicators for stale, blocked, and deferred project badges
- `Packages/PMDesignSystem/Sources/PMDesignSystem/Components/ProgressComponents.swift` — PMProgressBar, PMCircularProgress
- `Packages/PMDesignSystem/Sources/PMDesignSystem/Components/TaskCardView.swift` — Reusable task card display component

## Pass Criteria
- [ ] All 2 tests pass
- [ ] App builds and launches without errors
- [ ] All token files compile and provide expected values
- [ ] All components render correctly in Xcode previews
- [ ] No warnings or errors in the build
