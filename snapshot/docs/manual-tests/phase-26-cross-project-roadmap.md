# Phase 26: Cross-Project Roadmap — Manual Test Brief

## Automated Tests
- **10 tests** in 1 suite, passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **CrossProjectRoadmapViewModelTests** (10 tests) — Initial state defaults, loading milestones from multiple focused projects, sort order (soonest deadline first, unscheduled last), upcoming deadlines computed property, overdue milestone detection, multiple projects with distinct color indices, filter by milestone status, empty projects edge case, CrossProjectMilestone equality, milestones grouped by project.

## How to Access

### macOS
1. Open the macOS app
2. In the sidebar, select **Cross-Project Roadmap** (map icon)
3. The roadmap loads milestones from all focused projects

### iOS
1. Open the iOS app
2. Tap the **More** tab (ellipsis icon)
3. Tap **Cross-Project Roadmap**
4. The roadmap loads milestones from all focused projects

## Manual Verification Checklist

### Milestone Loading & Sorting
- [ ] Milestones load from all focused projects on view appear
- [ ] Milestones with deadlines appear sorted soonest-first
- [ ] Milestones without deadlines appear in "No Deadline Set" section at the end
- [ ] Each project gets a distinct color dot (cycling through 5 SlotColours)
- [ ] Loading spinner shown while fetching data

### Stats Bar
- [ ] "Projects" badge shows count of unique projects
- [ ] "Milestones" badge shows total milestone count
- [ ] "Overdue" badge shows count of overdue milestones (red if any, green if none)
- [ ] "Upcoming" badge shows count of milestones with future deadlines

### Overdue Section
- [ ] Overdue milestones (past deadline, not completed) shown in red-labelled section
- [ ] Overdue section hidden when no milestones are overdue
- [ ] Deadline dates shown in red for overdue items

### Filter Bar
- [ ] "All" filter shows all milestones (default)
- [ ] "Not Started" filter shows only not-started milestones
- [ ] "In Progress" filter shows only in-progress milestones
- [ ] "Completed" filter shows only completed milestones
- [ ] Overdue and upcoming sections hidden when a filter is active

### By Project Section
- [ ] Milestones grouped under project names with color-coded dots
- [ ] Each project group shows milestone name, status badge, and deadline
- [ ] Completed milestones show filled diamond icon, others show outline

### Unscheduled Section
- [ ] Milestones without deadlines shown in "No Deadline Set" section
- [ ] Section hidden when all milestones have deadlines

### Empty State
- [ ] Empty state shown when no focused projects have milestones
- [ ] Empty state shows map icon and helpful message

### Error Handling
- [ ] Error message displayed if milestone loading fails
- [ ] No crashes on empty data

### Platform Parity
- [ ] macOS: Roadmap accessible from sidebar navigation
- [ ] iOS: Roadmap accessible from More tab → Cross-Project Roadmap
- [ ] Both platforms show identical data and layout

## Files Created/Modified

### New Files (Phase 26)
- `Packages/PMFeatures/Sources/PMFeatures/Roadmap/CrossProjectRoadmapViewModel.swift` — CrossProjectMilestone struct, CrossProjectRoadmapViewModel with loading, sorting, filtering, computed properties
- `Packages/PMFeatures/Sources/PMFeatures/Roadmap/CrossProjectRoadmapView.swift` — Full roadmap UI with stats, filters, overdue/upcoming/by-project/unscheduled sections

### Modified Files (This Audit)
- `Packages/PMFeatures/Sources/PMFeatures/Roadmap/CrossProjectRoadmapViewModel.swift` — Fixed color index cycling from `% 6` to `% 5` to match 5 available SlotColours
- `ProjectManageriOS/Sources/iOSContentView.swift` — Added CrossProjectRoadmapView accessible from More tab via NavigationLink
