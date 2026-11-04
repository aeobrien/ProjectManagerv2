# Phase 8: Roadmap View — Manual Test Brief

## Automated Tests
- **8 tests** in 1 suite, all passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **ProjectRoadmapViewModel** (8 tests) — load project roadmap, progress calculation per phase, progress calculation per milestone, phase hierarchy flattening, milestone hierarchy flattening, dependency resolution between tasks, dependency warning detection, empty roadmap handling

## Manual Verification Checklist
- [ ] `cd Packages/PMFeatures && swift test` — all tests pass (Phase 5 + Phase 6 + Phase 7 + Phase 8)
- [ ] `xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'` — builds without errors
- [ ] App launches and selecting a project's Timeline tab shows the roadmap view
- [ ] Vertical timeline renders with a connected line between items
- [ ] Phases display with name, status icon, and progress percentage
- [ ] Milestones display with diamond shape indicator
- [ ] Tasks display nested under their parent milestones and phases
- [ ] Status icons correctly reflect the current state of each item (pending, in progress, done)
- [ ] Dependency warnings appear when a task depends on an incomplete predecessor
- [ ] Deadlines display alongside items that have due dates set
- [ ] Progress calculation accurately reflects completed vs total child items
- [ ] Hierarchy flattening produces the correct linear ordering for timeline display
- [ ] Empty projects show an appropriate empty state in the roadmap

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/Roadmap/ProjectRoadmapViewModel.swift` — Hierarchy flattening for timeline, dependency resolution, progress calculation
- `Packages/PMFeatures/Sources/PMFeatures/Roadmap/ProjectRoadmapView.swift` — Timeline visualization with vertical timeline, phase/milestone/task hierarchy, status icons, dependency warnings, deadline display, Diamond shape for milestones

## Pass Criteria
- [ ] All 8 tests pass
- [ ] Full PMFeatures test suite passes (Phase 5 through Phase 8)
- [ ] App builds and launches without errors
- [ ] Timeline visualization renders correctly with hierarchy
- [ ] Dependencies and deadlines display properly
- [ ] No warnings or errors in the build
