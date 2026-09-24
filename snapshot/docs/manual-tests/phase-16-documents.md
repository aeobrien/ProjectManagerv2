# Phase 16: Document Management — Manual Test Brief

## Automated Tests
- **16 tests** in 1 suite, passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **DocumentViewModelTests** (16 tests) — Validates initial state defaults, loading documents for a project, selecting a document, editing title and content with unsaved changes tracking, saving with automatic version increment, explicit save always bumps version, save fails with empty title, creating a new document, deleting a document, filtering by document type, version snapshot creation on save, multiple saves creating multiple snapshots, version history loading on document select, restoring a previous version, deselect clearing version history, and graceful nil version repo fallback.

## Manual Verification Checklist

### Document CRUD
- [ ] DocumentViewModel initializes with an empty document list and no selection
- [ ] Loading documents for a project populates the document list
- [ ] Creating a new document via the creation menu adds it to the list and selects it
- [ ] The document creation menu offers Vision Statement, Technical Brief, and Other
- [ ] Deleting a document removes it from the list and clears the selection
- [ ] Filtering by document type shows only documents of that type
- [ ] **(Phase 28.4)** A segmented picker in the document header offers: All, Vision, Brief, Other
- [ ] **(Phase 28.4)** Selecting "Vision" shows only Vision Statement documents
- [ ] **(Phase 28.4)** Selecting "Brief" shows only Technical Brief documents
- [ ] **(Phase 28.4)** Selecting "All" restores the full document list

### Editing
- [ ] Selecting a document from the list displays its title and content in the editor
- [ ] Editing the document title marks the document as having unsaved changes
- [ ] Editing the document content marks the document as having unsaved changes
- [ ] The unsaved changes indicator (blue dot) is visible when edits have not been saved
- [ ] Saving a document (Cmd+S) increments the version number and clears the unsaved indicator
- [ ] Save button is disabled when there are no unsaved changes

### Markdown Preview
- [ ] Toggling the preview button shows a side-by-side markdown preview on macOS
- [ ] Markdown formatting (headers, bold, lists) renders correctly in preview

### Version History
- [ ] Toggling the clock button shows the version history panel below the editor
- [ ] After saving edits, the previous version appears in the version history
- [ ] Multiple saves create multiple version snapshots with correct version numbers
- [ ] Each version entry shows version number, title, date, and a "Restore" button
- [ ] Clicking "Restore" on a previous version populates the editor with that version's content
- [ ] After restoring, the document shows as having unsaved changes (user must explicitly save)
- [ ] Version history panel shows "No previous versions" for newly created documents

### Layout
- [ ] On macOS, DocumentEditorView renders as a split-pane layout (HSplitView) with list and editor side by side
- [ ] On iOS, DocumentEditorView renders as a single-pane layout with navigation between list and editor
- [ ] On iOS, a back button ("Documents") appears when viewing the editor, returning to the document list

### Wiring
- [ ] Documents tab is visible in Project Detail view
- [ ] DocumentEditorView loads documents for the selected project

## Files

### Source Files
- `Packages/PMDomain/Sources/PMDomain/Entities/DocumentVersion.swift` — Version snapshot entity with documentId, version, title, content, savedAt
- `Packages/PMDomain/Sources/PMDomain/Protocols/DocumentVersionRepositoryProtocol.swift` — Repository protocol for version history CRUD
- `Packages/PMData/Sources/PMData/Repositories/SQLiteDocumentVersionRepository.swift` — GRDB implementation of version history persistence
- `Packages/PMData/Sources/PMData/Records/GRDBConformances.swift` — Added DocumentVersion GRDB conformance
- `Packages/PMData/Sources/PMData/DatabaseManager.swift` — Added v2-documentVersion migration
- `Packages/PMFeatures/Sources/PMFeatures/Documents/DocumentViewModel.swift` — Document lifecycle ViewModel with create, edit, save, delete, versioning, version history, restore, editing state tracking, and type filtering
- `Packages/PMFeatures/Sources/PMFeatures/Documents/DocumentEditorView.swift` — Split-pane editor on macOS (HSplitView), single-pane on iOS with back button, markdown preview toggle, version history panel with restore

### App Wiring
- `ProjectManager/Sources/ContentView.swift` — Creates SQLiteDocumentVersionRepository, passes to DocumentViewModel
- `ProjectManageriOS/Sources/iOSContentView.swift` — Same wiring for iOS

### Tests
- `Packages/PMFeatures/Tests/PMFeaturesTests/DocumentViewModelTests.swift` — 16 tests covering all CRUD, versioning, version history snapshots, restore, and graceful nil fallback
