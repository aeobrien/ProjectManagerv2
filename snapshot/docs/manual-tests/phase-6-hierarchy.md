# Phase 6: Hierarchy Management — Manual Test Brief

## Automated Tests
- **20 tests** in 1 suite, all passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **ProjectDetailViewModel** (20 tests) — load project with full hierarchy, create phase, delete phase, create milestone, delete milestone, create task, delete task, create subtask, delete subtask, reorder phases, reorder milestones, reorder tasks, block task, unblock task, wait on task, add dependency, remove dependency, progress calculation, hierarchy depth validation, empty project handling

## Manual Verification Checklist
- [ ] `cd Packages/PMFeatures && swift test` — all tests pass (Phase 5 + Phase 6)
- [ ] `xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'` — builds without errors
- [ ] App launches and selecting a project shows the detail view
- [ ] ProjectDetailView displays three tabs: Roadmap, Timeline, Overview
- [ ] RoadmapView shows expandable hierarchy (phases > milestones > tasks > subtasks)
- [ ] PhaseRow displays phase name, status, and progress
- [ ] MilestoneRow displays milestone name and status
- [ ] TaskRow displays task name, status, effort type, and priority
- [ ] SubtaskRow displays subtask name and completion state
- [ ] Inline creation works at each hierarchy level (phase, milestone, task, subtask)
- [ ] Inline editing updates names and properties at each level
- [ ] Deleting an item removes it and its children from the hierarchy
- [ ] Drag-to-reorder works for phases, milestones, and tasks
- [ ] Progress tracking updates as subtasks and tasks are completed
- [ ] Blocking a task marks it as blocked and shows the blocked indicator
- [ ] Unblocking a task restores it to its previous status
- [ ] Dependencies can be added and removed between tasks
- [ ] Wait operation sets the appropriate waiting state on a task

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/ProjectDetail/ProjectDetailViewModel.swift` — Full hierarchy loading (phases, milestones, tasks, subtasks), CRUD for all levels, dependency management, reordering
- `Packages/PMFeatures/Sources/PMFeatures/ProjectDetail/ProjectDetailView.swift` — Tabbed interface (Roadmap, Timeline, Overview) with expandable hierarchy
- `Packages/PMFeatures/Sources/PMFeatures/ProjectDetail/RoadmapView.swift` — Hierarchical display with PhaseRow, MilestoneRow, TaskRow, SubtaskRow sub-views, inline editing/creation/deletion, progress tracking

## Pass Criteria
- [ ] All 20 tests pass
- [ ] Full PMFeatures test suite passes (Phase 5 + Phase 6)
- [ ] App builds and launches without errors
- [ ] Full hierarchy CRUD works end-to-end in the UI
- [ ] Reordering persists correctly
- [ ] Dependencies display and function correctly
- [ ] No warnings or errors in the build
