# Phase 19: CloudKit Sync — Manual Test Brief

## Automated Tests
- **77 tests** in PMData (16 sync-specific in 4 suites), passing via `cd Packages/PMData && swift test`
- **8 tests** in PMFeatures (SyncManager suite), passing via `cd Packages/PMFeatures && swift test`

### PMData Suites
1. **SyncRecordTests** (7 tests) — SyncChange creation, SyncEntityType coverage (all 10 types), SyncChangeType raw values, SyncState defaults, ConflictResolution raw values, SyncError equality, SyncChange equatable.
2. **InMemorySyncQueueTests** (5 tests) — Enqueue and retrieve pending, mark synced removes from pending, pending count tracking, purge old synced changes, purge keeps unsynced changes.
3. **ConflictResolverTests** (4 tests) — Last-write-wins (local newer), last-write-wins (remote newer), document close timestamps trigger manual merge, document far timestamps use last-write-wins.
4. **SyncEngineTests** (14 tests) — Track change enqueues, sync pushes pending, sync not authenticated, sync updates token, sync respects minimum interval, sync pulls remote, network error propagation, reset state, isSyncInProgress, push with dataProvider serialization, pull with dataProvider apply, pull with dataProvider delete, sync without dataProvider still completes, sync purges old synced changes.

### PMFeatures Suites
5. **SyncManagerTests** (8 tests) — Default state, syncNow success, syncNow auth error, syncNow network error, trackChange disabled, trackChange enabled, refreshState reads from engine, syncNow skips when disabled.

## Manual Verification Checklist
- [ ] Settings → iCloud Sync toggle enables/disables sync
- [ ] Settings → "Sync Now" button triggers a sync cycle
- [ ] Settings shows sync status (last sync date, pending count)
- [ ] Settings shows error message when sync fails
- [ ] Creating a project (Browser) tracks a `.project.create` change
- [ ] Updating a project tracks a `.project.update` change
- [ ] Deleting a project tracks a `.project.delete` change
- [ ] Phase/Milestone/Task/Subtask CRUD all track sync changes (ProjectDetailVM)
- [ ] Dependency add/remove tracks sync changes
- [ ] Document save/create/delete tracks sync changes (DocumentVM)
- [ ] Check-in creation tracks a `.checkIn.create` change
- [ ] Quick Capture project creation tracks a `.project.create` change
- [ ] Onboarding project/phase/milestone/task/document creation all track sync changes
- [ ] Retrospective phase save tracks a `.phase.update` change
- [ ] Focus Board project focus/unfocus tracks `.project.update` changes
- [ ] Focus Board task move/block/wait/unblock tracks `.task.update` changes
- [ ] AI ActionExecutor mutations (completeTask, createSubtask, etc.) trigger sync tracking via onChangeTracked callback
- [ ] SyncEngine pushes serialized entity payloads to CloudKit
- [ ] SyncEngine applies remote entity payloads locally on pull
- [ ] SyncEngine deletes local entities on remote delete
- [ ] ConflictResolver applies last-write-wins for non-document entities
- [ ] ConflictResolver triggers manual merge for documents with close timestamps
- [ ] Periodic sync fires every 5 minutes when enabled
- [ ] Sync state survives app restart (via UserDefaults syncEnabled)
- [ ] Entitlements include iCloud container and CloudKit service

## Files Created/Modified
### New Files
- `Packages/PMData/Sources/PMData/Sync/SyncRecord.swift` — SyncChange, SyncEntityType, SyncChangeType, SyncState, SyncConflict, ConflictResolution, SyncError
- `Packages/PMData/Sources/PMData/Sync/SyncEngine.swift` — Actor-based sync engine with push/pull, conflict resolution, dataProvider integration
- `Packages/PMData/Sources/PMData/Sync/InMemorySyncQueue.swift` — Actor-based in-memory change queue
- `Packages/PMData/Sources/PMData/Sync/CloudKitSyncBackend.swift` — CKContainer-based SyncBackendProtocol implementation
- `Packages/PMData/Sources/PMData/Sync/SyncDataProvider.swift` — SyncDataProviderProtocol and RepositorySyncDataProvider for entity serialization/deserialization
- `Packages/PMFeatures/Sources/PMFeatures/Sync/SyncManager.swift` — Observable sync manager with periodic sync, change tracking, UI state
- `ProjectManager/ProjectManager.entitlements` — App sandbox, CloudKit, iCloud container

### Modified Files
- `Packages/PMData/Sources/PMData/Settings/SettingsManager.swift` — Added `syncEnabled` setting
- `Packages/PMServices/Sources/PMServices/AI/ActionExecutor.swift` — Added `onChangeTracked` callback for sync tracking after every entity mutation
- `Packages/PMFeatures/Sources/PMFeatures/Settings/SettingsView.swift` — Added iCloud Sync section with toggle, status, sync button
- `Packages/PMFeatures/Sources/PMFeatures/ProjectDetail/ProjectDetailViewModel.swift` — Added syncManager and change tracking for all CRUD (phase/milestone/task/subtask/dependency)
- `Packages/PMFeatures/Sources/PMFeatures/ProjectBrowser/ProjectBrowserViewModel.swift` — Added syncManager and change tracking for project CRUD
- `Packages/PMFeatures/Sources/PMFeatures/Documents/DocumentViewModel.swift` — Added syncManager and change tracking for document CRUD
- `Packages/PMFeatures/Sources/PMFeatures/CheckIn/CheckInFlowManager.swift` — Added syncManager and change tracking for check-in creation
- `Packages/PMFeatures/Sources/PMFeatures/FocusBoard/FocusBoardViewModel.swift` — Added syncManager and change tracking for task/project mutations
- `Packages/PMFeatures/Sources/PMFeatures/QuickCapture/QuickCaptureViewModel.swift` — Added syncManager and change tracking for project creation
- `Packages/PMFeatures/Sources/PMFeatures/Onboarding/OnboardingFlowManager.swift` — Added syncManager and change tracking for project/phase/milestone/task/document creation
- `Packages/PMFeatures/Sources/PMFeatures/Retrospective/RetrospectiveFlowManager.swift` — Added syncManager and change tracking for phase update
- `ProjectManager/Sources/ContentView.swift` — Wired SyncEngine, SyncManager, RepositorySyncDataProvider; connected syncManager to all VMs/managers; wired ActionExecutor.onChangeTracked
- `ProjectManageriOS/Sources/iOSContentView.swift` — Same sync wiring as macOS
- `project.yml` — Added entitlements path for macOS target
