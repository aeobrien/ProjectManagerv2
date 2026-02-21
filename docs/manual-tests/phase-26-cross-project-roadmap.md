# Phase 26: Cross-Project Roadmap — Manual Test Brief

## Automated Tests
- **10 tests** in 1 suite, passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **CrossProjectRoadmapViewModelTests** (10 tests) — Validates initial state defaults, loading milestones from multiple focused projects, sort order (soonest deadline first with unscheduled last), upcoming deadlines computed property, overdue milestone detection, multiple projects with distinct color indices, filter by milestone status, empty projects edge case, CrossProjectMilestone equality, and milestones grouped by project.

## Manual Verification Checklist
- [ ] CrossProjectRoadmapViewModel loads milestones from all focused projects
- [ ] Milestones are sorted by deadline with soonest first and unscheduled milestones at the end
- [ ] upcomingDeadlines computed property returns only milestones with future deadlines
- [ ] Overdue milestones are correctly identified based on the current date
- [ ] Unscheduled milestones appear in a separate section or at the end of the list
- [ ] Each project is assigned a distinct color index for visual differentiation
- [ ] milestonesByProject groups milestones correctly under their parent project
- [ ] projectCount reflects the number of distinct projects with milestones
- [ ] Filtering by milestone status shows only milestones matching the selected status
- [ ] An empty project list results in an empty roadmap with no errors
- [ ] Roadmap view renders correctly with milestones from multiple projects

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/Roadmap/CrossProjectRoadmapViewModel.swift` — CrossProjectMilestone struct with milestone and parent project info, color index for project coding, CrossProjectRoadmapViewModel with milestone loading, sorting, computed properties (upcomingDeadlines, overdue, unscheduled, milestonesByProject, projectCount), and status filtering
