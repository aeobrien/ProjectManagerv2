# Phase 3: Data Export & Settings — Manual Test Brief

## Automated Tests
- **7 tests** across 3 suites, all passing via `cd Packages/PMData && swift test`

### Suites
1. **SettingsManager** (3 tests) — default values, UserDefaults persistence, @Observable property updates (maxFocusSlots, perCategoryLimit, doneRetention, checkInPrompts)
2. **DataExporter** (2 tests) — full database export to JSON, export structure validation (projects, categories, tasks, phases, milestones, subtasks)
3. **DataImporter** (2 tests) — JSON import into database, round-trip fidelity (export then import produces identical data)

## Manual Verification Checklist
- [ ] `cd Packages/PMData && swift test` — all tests pass (including the 36 from Phase 2 + 7 new)
- [ ] `xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'` — builds without errors
- [ ] App still launches and shows existing UI
- [ ] SettingsManager defaults are sensible (e.g. maxFocusSlots has a reasonable default)
- [ ] Export produces valid JSON containing all database entities
- [ ] Importing an exported JSON file restores all data correctly

## Files Created/Modified
### New Files
- `Packages/PMData/Sources/PMData/Settings/SettingsManager.swift` — UserDefaults-backed @Observable settings (maxFocusSlots, perCategoryLimit, doneRetention, checkInPrompts, etc.)
- `Packages/PMData/Sources/PMData/Export/DataExporter.swift` — Full database export to JSON
- `Packages/PMData/Sources/PMData/Export/DataImporter.swift` — JSON import back to database

## Pass Criteria
- [ ] All 7 new tests pass
- [ ] Full PMData test suite passes (Phase 2 + Phase 3 tests)
- [ ] App builds and launches without errors
- [ ] No warnings or errors in the build
