# Phase 2: Data Layer — Persistence — Manual Test Brief

## Automated Tests
- **36 tests** across 12 suites, all passing via `cd Packages/PMData && swift test`

### Suites
1. **Database Setup** (4 tests) — table creation, category seeding (idempotent), foreign keys enabled
2. **CategoryRepository** (2 tests) — CRUD, seed built-in categories
3. **ProjectRepository** (7 tests) — CRUD, fetch by lifecycle state, fetch focused (ordered by slot), fetch by category, search by name, update, empty results
4. **PhaseRepository** (2 tests) — CRUD, reorder
5. **MilestoneRepository** (1 test) — CRUD
6. **TaskRepository** (5 tests) — CRUD, fetch by status, fetch by effort type, fetch by kanban column, search by name
7. **SubtaskRepository** (1 test) — CRUD
8. **DocumentRepository** (3 tests) — CRUD, fetch by type, full-text search (FTS5)
9. **CheckInRepository** (1 test) — CRUD and fetchLatest
10. **DependencyRepository** (1 test) — CRUD and fetch by source/target
11. **ConversationRepository** (4 tests) — save with messages, fetch by type, append message, delete cascades messages
12. **Cascading Deletes** (5 tests) — project→all, phase→milestones+tasks+subtasks, milestone→tasks+subtasks, task→subtasks, category restrict

## Manual Verification Checklist
- [ ] `cd Packages/PMData && swift test` — all 36 tests pass
- [ ] `xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'` — builds without errors
- [ ] App still launches and shows Phase 0 placeholder UI

## Files Created/Modified
### New Files
- `Packages/PMData/Sources/PMData/DatabaseManager.swift` — Schema migration (v1), in-memory/file-based init, category seeding
- `Packages/PMData/Sources/PMData/Records/GRDBConformances.swift` — GRDB protocol conformances for all domain entities
- `Packages/PMData/Sources/PMData/Records/ChatMessageRecord.swift` — Wrapper for ChatMessage with conversationId foreign key
- `Packages/PMData/Sources/PMData/Records/TypeAliases.swift` — Disambiguates PMDomain.Category from ObjC Category
- `Packages/PMData/Sources/PMData/Repositories/SQLite*Repository.swift` — 10 repository implementations

### Deleted Files
- `Packages/PMData/Sources/PMData/PMData.swift` — Placeholder replaced by real implementation
