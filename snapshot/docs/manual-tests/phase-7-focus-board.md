# Phase 7: Focus Board — Manual Test Brief

## Automated Tests
- **10 tests** in 1 suite, all passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **FocusBoardViewModel** (10 tests) — load focus projects, kanban column assignment (To Do, In Progress, Done), move task between columns, block task from board, unblock task from board, wait on task, diversity violation detection, effort type filtering, health signal computation, empty board handling

## Manual Verification Checklist
- [ ] `cd Packages/PMFeatures && swift test` — all tests pass (Phase 5 + Phase 6 + Phase 7)
- [ ] `cd Packages/PMDomain && swift test` — all PMDomain tests pass (FocusManager logic)
- [ ] `xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'` — builds without errors
- [ ] App launches and navigating to "Focus Board" shows the Kanban board
- [ ] Three-column layout displays: To Do, In Progress, Done
- [ ] Tasks appear in correct columns based on their kanban state
- [ ] Dragging a task between columns updates its status
- [ ] Context menus on task cards provide status transition options
- [ ] Effort filter controls which tasks are visible (e.g. small, medium, large)
- [ ] Health badges appear on tasks with stale, blocked, or deferred signals
- [ ] Task cards display project name, task name, priority, and effort type
- [ ] Diversity violations are flagged when too many tasks from one category are in focus
- [ ] FocusManager correctly computes health signals for each focus project
- [ ] Blocking a task from the board moves it out of active columns
- [ ] Unblocking a task restores it to the appropriate column
- [ ] Wait operation updates the task and reflects in the board

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/FocusBoard/FocusBoardViewModel.swift` — Focus slot management, Kanban view, task curation, health signals, diversity violations, effort filtering
- `Packages/PMFeatures/Sources/PMFeatures/FocusBoard/FocusBoardView.swift` — Three-column Kanban (To Do, In Progress, Done), drag support, effort filter, health badges, task cards with context menus
- `Packages/PMDomain/Sources/PMDomain/Logic/FocusManager.swift` — Health signal computation, diversity violation detection

## Pass Criteria
- [ ] All 10 tests pass
- [ ] Full PMFeatures test suite passes (Phase 5 + Phase 6 + Phase 7)
- [ ] PMDomain test suite passes with FocusManager tests
- [ ] App builds and launches without errors
- [ ] Kanban board displays and functions correctly
- [ ] Health signals and diversity violations are computed and displayed
- [ ] No warnings or errors in the build
