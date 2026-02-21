# Phase 20: iOS App — Manual Test Brief

## Automated Tests
- **0 tests** — This phase is structural/navigation code with no dedicated test suite. Verification is manual.

### Suites
_No new test suites. This phase introduces platform-adaptive navigation and the iOS app entry point._

## Manual Verification Checklist
- [ ] iOS app launches successfully and displays the iOSContentView with tab navigation
- [ ] Tab bar shows all 5 tabs: Focus Board, Projects, AI Chat, Quick Capture, and More
- [ ] Each tab navigates to its corresponding view when tapped
- [ ] Tab selection state persists correctly when switching between tabs
- [ ] Tab items use .tabItem/.tag for iOS 17 compatibility (no iOS 18-only APIs)
- [ ] AdaptiveNavigationView renders IOSTabNavigationView on iOS
- [ ] AdaptiveNavigationView renders AppNavigationView on macOS
- [ ] DocumentEditorView uses HSplitView on macOS via #if os(macOS) conditional
- [ ] DocumentEditorView falls back to simple list layout on iOS
- [ ] macOS app continues to function correctly with AdaptiveNavigationView in place
- [ ] Navigation between tabs does not lose view state (e.g., scroll position in Projects)

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/Navigation/iOSTabNavigation.swift` — 5-tab TabView (Focus Board, Projects, AI Chat, Quick Capture, More) using .tabItem/.tag for iOS 17 compatibility
- `Packages/PMFeatures/Sources/PMFeatures/Navigation/AdaptiveNavigationView.swift` — Platform-adaptive navigation: AppNavigationView on macOS, IOSTabNavigationView on iOS
- `ProjectManageriOS/Sources/ProjectManageriOSApp.swift` — iOS app entry point
- `ProjectManageriOS/Sources/iOSContentView.swift` — iOS content view with tab navigation

### Modified Files
- `Packages/PMFeatures/Sources/PMFeatures/Documents/DocumentEditorView.swift` — Added #if os(macOS) for HSplitView with simple list fallback on iOS
