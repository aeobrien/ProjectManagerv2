# Phase 22: Life Planner Export — Manual Test Brief

## Automated Tests
- **17 tests** in 4 suites, passing via `cd Packages/PMServices && swift test`

### Suites
1. **ExportPayloadTests** (5 tests) — Validates Codable round-trip encoding/decoding for ExportedTask, ExportedProjectSummary, and ExportPayload structures, ExportPayloadBuilder assembly from domain objects, and empty payload edge cases.
2. **ExportServiceTests** (8 tests) — Validates actor-based export with debounce timing, APIExportBackend HTTP POST with Bearer auth, FileExportBackend JSON file output, ExportConfig validation, ExportStatus state transitions (idle/exporting/completed/failed), error handling for network failures, retry logic, and concurrent export request coalescing.
3. **ExportResultTests** (2 tests) — Validates ExportResult success and failure cases with associated metadata.
4. **ExportConfigTests** (2 tests) — Validates ExportConfig initialization with API endpoint and auth token, and file path configuration for FileExportBackend.

## Manual Verification Checklist
- [ ] ExportPayloadBuilder produces a valid ExportPayload from real project and task data
- [ ] ExportPayload encodes to JSON and decodes back without data loss
- [ ] APIExportBackend sends an HTTP POST to the configured endpoint with Bearer auth header
- [ ] APIExportBackend includes the full ExportPayload as the request body
- [ ] FileExportBackend writes a valid JSON file to the configured path
- [ ] ExportService debounces rapid export requests and only executes one export
- [ ] ExportStatus transitions correctly through idle, exporting, completed, and failed states
- [ ] Export errors (network failure, auth failure) are surfaced via ExportStatus
- [ ] Concurrent export requests are coalesced and do not produce duplicate exports
- [ ] ExportConfig correctly stores API endpoint, auth token, and file path settings

## Files Created/Modified
### New Files
- `Packages/PMServices/Sources/PMServices/LifePlannerExport/ExportPayload.swift` — Codable export structures (ExportedTask, ExportedProjectSummary, ExportPayload) and ExportPayloadBuilder
- `Packages/PMServices/Sources/PMServices/LifePlannerExport/ExportService.swift` — Actor-based export service with debounce, APIExportBackend (HTTP POST with Bearer auth), FileExportBackend (JSON file), ExportConfig, and ExportStatus tracking
