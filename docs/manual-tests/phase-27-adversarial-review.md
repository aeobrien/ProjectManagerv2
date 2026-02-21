# Phase 27: Adversarial Review Pipeline — Manual Test Brief

## Automated Tests
- **24 tests** in 2 suites, passing via `cd Packages/PMServices && swift test` and `cd Packages/PMFeatures && swift test`

### Suites
1. **ReviewExporterTests** (7 tests) — Validates export package building from documents, JSON encode/decode round-trip for ReviewExportPackage, critique decoding from JSON into CritiqueImportPackage, synthesis prompt building from critiques and original documents, empty documents edge case, critique identity preservation, and PipelineMetadata round-trip encoding/decoding.
2. **AdversarialReviewManagerTests** (17 tests) — Validates initial idle state, export step execution, export with no documents error, critique import from raw Data, direct critique import via CritiqueImportPackage, empty critique import handling, synthesis step with LLM integration, synthesis without prior export error, synthesis without critiques error, follow-up conversation during review, empty follow-up rejection, revision approval and save-back to store, approval with empty revisions, pipeline reset to idle state, concern count tracking across critiques, AdversarialReviewStep equality, and revised document equality.

## Manual Verification Checklist
- [ ] ReviewExporter builds a complete ReviewExportPackage from the document store
- [ ] ReviewExportPackage encodes to JSON and decodes back without data loss
- [ ] Exported JSON file can be shared externally for adversarial critique
- [ ] CritiqueImportPackage decodes correctly from externally-provided JSON critiques
- [ ] AdversarialReviewManager transitions through all pipeline steps: idle, exporting, awaitingCritiques, critiquesReceived, synthesising, reviewingRevisions, completed
- [ ] Export step produces a valid package and transitions to awaitingCritiques
- [ ] Attempting export with no documents produces an appropriate error
- [ ] Importing critiques from raw Data correctly parses and stores them
- [ ] Importing critiques via direct CritiqueImportPackage works equivalently
- [ ] Synthesis step sends critiques and original documents to the LLM and produces revised documents
- [ ] Synthesis fails gracefully if no export has been performed
- [ ] Synthesis fails gracefully if no critiques have been imported
- [ ] Follow-up conversation allows iterating on synthesised revisions with the LLM
- [ ] Empty follow-up messages are rejected
- [ ] Approving revisions saves the revised documents back to the document store
- [ ] Pipeline reset returns all state to idle and clears intermediate data
- [ ] Concern counts accurately reflect the number of issues raised across all critiques

## Files Created/Modified
### New Files
- `Packages/PMServices/Sources/PMServices/AdversarialReview/ReviewExporter.swift` — Export package building from documents, JSON encode/decode, file I/O, critique import, synthesis prompt building, ReviewExportPackage, ExportedReviewDocument, ReviewCritique, CritiqueImportPackage, and PipelineMetadata types
- `Packages/PMFeatures/Sources/PMFeatures/AdversarialReview/AdversarialReviewManager.swift` — Full pipeline orchestration: export, await critiques, import, AI synthesis, follow-up conversation, revised document approval, save back to store, AdversarialReviewStep enum (idle, exporting, awaitingCritiques, critiquesReceived, synthesising, reviewingRevisions, completed)
