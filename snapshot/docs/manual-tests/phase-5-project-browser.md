# Phase 5: Project Browser — Manual Test Brief

## Automated Tests
- **5 tests** in 1 suite, all passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **ProjectBrowserViewModel** (5 tests) — initial state defaults, load projects from repository, filter by lifecycle state, filter by category, search by name substring

## Manual Verification Checklist
- [ ] `cd Packages/PMFeatures && swift test` — all 5 tests pass
- [ ] `xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'` — builds without errors
- [ ] App launches and navigating to "All Projects" shows the project browser
- [ ] Project list displays all projects from the database
- [ ] Search bar filters projects by name in real time
- [ ] Lifecycle filter chips (active, paused, abandoned, completed) toggle correctly
- [ ] Category filter chips filter the project list by category
- [ ] Tapping "New Project" opens the create sheet
- [ ] ProjectCreateSheet accepts name, category, and Definition of Done
- [ ] Creating a project adds it to the list immediately
- [ ] Context menu on a project row opens the edit sheet
- [ ] ProjectEditSheet shows current values and allows editing
- [ ] Lifecycle state transitions work (e.g. active to paused) with appropriate prompts
- [ ] Pause and abandon transitions prompt for a reason
- [ ] Delete confirmation dialog appears before removing a project
- [ ] Validation prevents creating a project with an empty name

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/ProjectBrowser/ProjectBrowserViewModel.swift` — CRUD, filtering by lifecycle/category, search, lifecycle transitions, validation
- `Packages/PMFeatures/Sources/PMFeatures/ProjectBrowser/ProjectBrowserView.swift` — Full project list with search, filter chips, create/edit sheets, context menus
- `Packages/PMFeatures/Sources/PMFeatures/ProjectBrowser/ProjectCreateSheet.swift` — Form with name, category, Definition of Done
- `Packages/PMFeatures/Sources/PMFeatures/ProjectBrowser/ProjectEditSheet.swift` — Edit form with lifecycle state transitions, pause/abandon prompts, delete confirmation

## Pass Criteria
- [ ] All 5 tests pass
- [ ] Full PMFeatures test suite passes
- [ ] App builds and launches without errors
- [ ] Project CRUD operations work end-to-end in the UI
- [ ] Filtering and search behave correctly
- [ ] No warnings or errors in the build
