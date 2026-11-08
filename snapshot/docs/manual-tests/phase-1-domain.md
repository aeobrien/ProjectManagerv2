# Phase 1: Domain Models — Manual Test Brief

## Automated Tests
- **85 tests** across 5 suites, all passing via `cd Packages/PMDomain && swift test`

### Suites
1. **Enums** (8 tests) — case counts, Codable round-trip, Priority sort values
2. **Entities** (12 tests) — default values, Codable round-trip, built-in categories, message containment
3. **Computed Properties** (24 tests) — effectiveDeadline, isApproachingDeadline, isOverdue, isFrequentlyDeferred, progressPercent, hasUnresolvedBlocks, waitingItemsDueSoon, estimateAccuracy, isStale, daysSinceCheckIn
4. **FocusManager** (19 tests) — slot management, category diversity, task visibility curation, health signals
5. **Validation** (22 tests) — focus slot range, lifecycle transitions, category diversity, entity validation (Project, PMTask)

## Manual Verification Checklist
- [ ] `cd Packages/PMDomain && swift test` — all 85 tests pass
- [ ] `xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'` — builds without errors
- [ ] App still launches and shows Phase 0 placeholder UI
- [ ] Review: PMDomain has ZERO external dependencies (only Foundation + PMUtilities)

## Files Created
### Enums (12 files)
`Packages/PMDomain/Sources/PMDomain/Enums/` — LifecycleState, PhaseStatus, ItemStatus, Priority, EffortType, BlockedType, KanbanColumn, CheckInDepth, DocumentType, DependableType, ConversationType, ChatRole

### Entities (13 files)
`Packages/PMDomain/Sources/PMDomain/Entities/` — Category, Project, Phase, Milestone, PMTask, Subtask, Document, Dependency, CheckInRecord, Conversation (+ ChatMessage), Project+Computed, Phase+Computed, Milestone+Computed

### Protocols (10 files)
`Packages/PMDomain/Sources/PMDomain/Protocols/` — ProjectRepository, PhaseRepository, MilestoneRepository, TaskRepository, SubtaskRepository, DocumentRepository, CheckInRepository, CategoryRepository, DependencyRepository, ConversationRepository

### Logic (2 files)
`Packages/PMDomain/Sources/PMDomain/Logic/` — FocusManager (slot management, diversity, task curation, health signals), Validation (lifecycle transitions, entity validation)

### Tests (1 file)
`Packages/PMDomain/Tests/PMDomainTests/PMDomainTests.swift` — 85 tests across 5 suites
