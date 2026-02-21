# Phase 16: Document Management — Manual Test Brief

## Automated Tests
- **8 tests** in 1 suite, passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **DocumentViewModelTests** (8 tests) — Validates initial state defaults, loading documents for a project, selecting a document, editing title and content with unsaved changes tracking, saving with automatic version increment, creating a new document, deleting a document, and filtering the document list by document type.

## Manual Verification Checklist
- [ ] DocumentViewModel initializes with an empty document list and no selection
- [ ] Loading documents for a project populates the document list
- [ ] Selecting a document from the list displays its title and content in the editor
- [ ] Editing the document title marks the document as having unsaved changes
- [ ] Editing the document content marks the document as having unsaved changes
- [ ] The unsaved changes indicator is visible when edits have not been saved
- [ ] Saving a document increments the version number and clears the unsaved indicator
- [ ] Creating a new document via the creation menu adds it to the list and selects it
- [ ] The document creation menu offers the available document types
- [ ] Deleting a document removes it from the list and clears the selection
- [ ] Filtering by document type shows only documents of that type
- [ ] On macOS, DocumentEditorView renders as a split-pane layout (HSplitView) with list and editor side by side
- [ ] On iOS, DocumentEditorView renders as a single-pane layout with navigation between list and editor

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/Documents/DocumentViewModel.swift` — Document lifecycle ViewModel with create, edit, save, delete, versioning, editing state tracking, and type filtering
- `Packages/PMFeatures/Sources/PMFeatures/Documents/DocumentEditorView.swift` — Split-pane editor on macOS (HSplitView), single-pane on iOS, with document list, title/content editing, unsaved changes indicator, and document creation menu
