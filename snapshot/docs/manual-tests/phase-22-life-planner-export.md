# Phase 22: Life Planner Export — Manual Test Brief

## Automated Tests
- **18 tests** in 6 suites, passing via `cd Packages/PMServices && swift test`
- All **581 tests** pass across all 6 packages (no regressions).

### Suites
1. **ExportPayloadTests** (5 tests) — Validates ExportedTask and ExportedProjectSummary creation, JSON round-trip encoding, ExportPayloadBuilder assembly with correct task→milestone→phase→project mapping, multi-project mapping correctness.
2. **ExportServiceTests** (8 tests) — Validates export success/failure, status tracking, error type mapping (network/auth/config), debounce via shouldExport()/recordTrigger(), config update, and multiple export count accumulation.
3. **ExportConfigTests** (2 tests) — Validates default config values and config equality.
4. **ExportErrorTests** (1 test) — Validates error equality comparison.
5. **ExportDestinationTests** (1 test) — Validates raw values for api/jsonFile destinations.
6. **ExportResultTests** (1 test) — Validates all result case raw values.

## Manual Verification Checklist

### Payload Construction
- [ ] ExportPayloadBuilder correctly maps tasks to their owning project via milestone→phase→project chain
- [ ] Tasks in different projects appear with correct projectName and categoryName
- [ ] Project summaries include accurate taskCount and completedTaskCount
- [ ] ExportPayload encodes to JSON and decodes back without data loss

### Export Backends
- [ ] APIExportBackend sends HTTP POST to configured endpoint with Bearer auth header
- [ ] APIExportBackend handles 2xx success, 401/403 auth errors, and other HTTP errors
- [ ] FileExportBackend writes pretty-printed JSON to configured file path
- [ ] Backend selection follows lifePlannerSyncMethod setting (rest → API, file → File)

### Export Triggers
- [ ] On-launch export: When lifePlannerSyncEnabled is true, export runs during app initialization
- [ ] Data-change export: ActionExecutor mutations trigger debounced export via onLifePlannerExport callback
- [ ] Manual export: "Export Now" button in Life Planner Sync section triggers triggerLifePlannerExport()
- [ ] Manual export: "Export Now" button in Data Export section also triggers triggerLifePlannerExport()
- [ ] Debounce prevents rapid-fire exports (5-second default interval)

### Settings Integration
- [ ] Life Planner Sync section shows enable toggle, method picker
- [ ] REST API method shows endpoint and API key fields
- [ ] File Export method shows file path field
- [ ] MySQL method shows placeholder text
- [ ] Settings changes (endpoint, API key, file path) persist to UserDefaults
- [ ] Export service reconfigures backend based on selected method at app launch

### Export Status
- [ ] Last export result shows success (green check) or failure (red X) icon
- [ ] Last export date shows relative time
- [ ] Export count is tracked across the session

### Wiring
- [ ] ExportService created with correct backend in macOS ContentView
- [ ] ExportService created with correct backend in iOS iOSContentView
- [ ] RepositoryExportDataProvider wired with all required repos in both ContentViews
- [ ] ActionExecutor.onLifePlannerExport wired when lifePlannerSyncEnabled is true
- [ ] ExportService passed to SettingsView

### Platform Parity
- [ ] macOS and iOS export wiring is identical
- [ ] Both platforms trigger on-launch export when enabled

## Files Created/Modified

### New Files
- `Packages/PMServices/Sources/PMServices/LifePlannerExport/RepositoryExportDataProvider.swift` — Fetches focused project data from repos for export payload building

### Modified Files
- `Packages/PMServices/Sources/PMServices/LifePlannerExport/ExportPayload.swift` — Fixed ExportPayloadBuilder to correctly map tasks via milestone→phase→project chain, added `phases` parameter
- `Packages/PMServices/Sources/PMServices/LifePlannerExport/ExportService.swift` — Added LifePlannerDataProvider protocol, setDataProvider(), triggerLifePlannerExport(), triggerDebouncedExport(), updateBackend()
- `Packages/PMServices/Sources/PMServices/AI/ActionExecutor.swift` — Added onLifePlannerExport callback, called after mutations
- `Packages/PMData/Sources/PMData/Settings/SettingsManager.swift` — Added lifePlannerAPIEndpoint, lifePlannerAPIKey, lifePlannerFilePath properties
- `Packages/PMFeatures/Sources/PMFeatures/Settings/SettingsView.swift` — Added connection config fields per method, fixed Export Now to use triggerLifePlannerExport()
- `ProjectManager/Sources/ContentView.swift` — Export service backend selection, data provider wiring, on-launch export, ActionExecutor export hook
- `ProjectManageriOS/Sources/iOSContentView.swift` — Same wiring as macOS
- `Packages/PMServices/Tests/PMServicesTests/ExportServiceTests.swift` — Fixed builder test to pass phases, added multi-project mapping test
