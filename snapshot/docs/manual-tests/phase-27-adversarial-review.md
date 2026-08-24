# Phase 27: Adversarial Review Pipeline — Manual Test Brief

## Automated Tests
- **24 tests** in 2 suites, passing via `cd Packages/PMServices && swift test` and `cd Packages/PMFeatures && swift test`

### Suites
1. **ReviewExporterTests** (7 tests) — Export package building, JSON encode/decode round-trip, critique decoding, synthesis prompt building, empty documents edge case, critique identity, PipelineMetadata round-trip.
2. **AdversarialReviewManagerTests** (17 tests) — Initial state, export, export no-docs error, critique import from Data, direct critique import, empty critique rejection, synthesis with LLM, synthesis without export error, synthesis without critiques error, follow-up conversation, empty follow-up rejection, revision approval + save, approval with no revisions error, reset, concern counts, step equality, revised document equality.

## How to Access

### macOS & iOS
1. Open any project from the Focus Board or Project Browser
2. In the Project Detail view, select the **Review** tab (between Analytics and Overview)
3. The Adversarial Review pipeline view loads with the "Export for Review" button

## Manual Verification Checklist

### Export Step (27.1)
- [ ] "Export for Review" button visible in idle state
- [ ] Clicking export fetches project documents and builds ReviewExportPackage
- [ ] Export transitions to "Awaiting Critiques" step
- [ ] Export with no documents shows error message
- [ ] Export package shows project name and document count
- [ ] "Copy Export JSON" copies valid JSON to clipboard (macOS NSPasteboard, iOS UIPasteboard)
- [ ] Exported JSON is well-formed and contains all project documents

### Pipeline Integration (27.2)
- [ ] Exported JSON suitable for external review (n8n, Shortcuts, other AI models)
- [ ] "Import Critiques" button opens import sheet
- [ ] Import sheet has TextEditor for pasting JSON and "Import" button
- [ ] "Cancel" button closes import sheet without importing
- [ ] Import button disabled when text is empty

### Critique Import & Display (27.3)
- [ ] Importing valid critique JSON parses and stores critiques
- [ ] Invalid JSON shows error message
- [ ] Critique metrics displayed: count, total concerns (orange), total suggestions (blue), overlapping concerns (red)
- [ ] Overlapping concern count shows concerns mentioned by 2+ reviewers
- [ ] "Synthesise Critiques" button available after critiques imported
- [ ] Step indicator shows progress through pipeline

### Synthesis & Follow-up
- [ ] Synthesise sends documents + critiques to LLM
- [ ] Progress spinner shown during synthesis
- [ ] Synthesis response displayed in card with text selection
- [ ] Message history shows user/assistant conversation
- [ ] Follow-up text field available for iterating
- [ ] Follow-up sends additional messages to LLM with full history
- [ ] Empty follow-up messages ignored
- [ ] Send button disabled when empty or loading

### Revised Document Approval (27.4)
- [ ] Revised documents listed with title and changes summary
- [ ] "Approve Revisions" button saves revised content back to document store
- [ ] Document version incremented on approval
- [ ] Approval with no revised documents shows error
- [ ] Completion screen shows success icon and "Review Complete"
- [ ] "Start New Review" button resets pipeline to idle

### Step Indicator
- [ ] 5 steps displayed: Export, Critiques, Synthesise, Revise, Done
- [ ] Completed steps shown in accent color
- [ ] Future steps shown in faded secondary color
- [ ] Progress line connects steps

### Error Handling
- [ ] LLM errors surfaced as text, not crashes
- [ ] Export/import errors displayed clearly
- [ ] Pipeline recoverable after errors (can retry)

### Platform Parity
- [ ] macOS: Review tab accessible in Project Detail
- [ ] iOS: Review tab accessible in Project Detail
- [ ] Both platforms create AdversarialReviewManager with document repo and LLM client

## Files Created/Modified

### New Files (Phase 27)
- `Packages/PMServices/Sources/PMServices/AdversarialReview/ReviewExporter.swift` — Export package building, JSON encode/decode, file I/O, critique import, synthesis prompt building, supporting types
- `Packages/PMFeatures/Sources/PMFeatures/AdversarialReview/AdversarialReviewManager.swift` — Pipeline orchestrator with state machine, export, critique import, AI synthesis, follow-up, approval, save-back
- `Packages/PMFeatures/Sources/PMFeatures/AdversarialReview/AdversarialReviewView.swift` — Step-by-step pipeline UI with progress indicator, clipboard export, import sheet, synthesis display, revision approval

### Modified Files (This Audit)
- `Packages/PMFeatures/Sources/PMFeatures/ProjectDetail/ProjectDetailView.swift` — Added "Review" tab with AdversarialReviewView, added adversarialReviewManager property
- `ProjectManager/Sources/ContentView.swift` — Create AdversarialReviewManager per project in makeProjectDetailView()
- `ProjectManageriOS/Sources/iOSContentView.swift` — Same wiring as macOS
