# Phase 19: CloudKit Sync — Manual Test Brief

## Automated Tests
- **26 tests** in 4 suites, passing via `cd Packages/PMData && swift test`

### Suites
1. **SyncRecordTests** (6 tests) — Validates SyncChange entity tracking, SyncEntityType coverage for all 10 entity types, SyncChangeType enumeration (create/update/delete), SyncState transitions, SyncConflict construction, and ConflictResolution options.
2. **InMemorySyncQueueTests** (5 tests) — Validates actor-based in-memory sync queue operations including enqueue, dequeue, ordering, queue draining, and concurrent access safety.
3. **ConflictResolverTests** (4 tests) — Validates last-write-wins default resolution, manual merge triggering for documents with close timestamps, SyncError generation on unresolvable conflicts, and conflict resolution output types.
4. **SyncEngineTests** (9 tests) — Validates actor-based bidirectional sync lifecycle including push/pull cycle orchestration, minimum sync interval enforcement, change token tracking and persistence, error handling during push, error handling during pull, sync state transitions, partial failure recovery, idle-to-syncing state management, and full round-trip sync simulation.

## Manual Verification Checklist
- [ ] SyncEngine initiates a push/pull cycle when triggered and transitions through expected sync states
- [ ] SyncEngine respects the minimum sync interval and rejects sync requests that arrive too soon
- [ ] SyncEngine tracks and persists change tokens between sync cycles
- [ ] InMemorySyncQueue correctly enqueues local changes and dequeues them in order during push
- [ ] ConflictResolver applies last-write-wins for non-document entities
- [ ] ConflictResolver triggers manual merge for documents with timestamps within the close-timestamp threshold
- [ ] SyncChange records are created for all 10 entity types (create, update, and delete operations)
- [ ] SyncError is surfaced to the caller when push or pull fails
- [ ] Sync state reflects idle after a successful sync cycle completes
- [ ] Concurrent sync requests do not corrupt queue state (actor isolation)

## Files Created/Modified
### New Files
- `Packages/PMData/Sources/PMData/Sync/SyncRecord.swift` — SyncChange entity tracking, SyncEntityType (10 entity types), SyncChangeType (create/update/delete), SyncState, SyncConflict, ConflictResolution, and SyncError types
- `Packages/PMData/Sources/PMData/Sync/SyncEngine.swift` — Actor-based bidirectional sync engine with push/pull cycle, minimum sync interval enforcement, and change token tracking
- `Packages/PMData/Sources/PMData/Sync/InMemorySyncQueue.swift` — Actor-based in-memory sync queue for buffering local changes before push
