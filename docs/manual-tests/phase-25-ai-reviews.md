# Phase 25: AI Project Reviews — Manual Test Brief

## Automated Tests
- **11 tests** in 1 suite, passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **ProjectReviewManagerTests** (11 tests) — Validates initial state defaults, starting a review with project data, LLM error handling during review, follow-up message handling within a review conversation, empty follow-up rejection, stall detection (7+ days with no check-in), blocked task accumulation detection (3+ blocked tasks), waiting item accumulation detection (3+ waiting items simultaneously), deferral pattern detection (5+ deferred across projects), review state reset, and PatternType equality.

## Manual Verification Checklist
- [ ] ProjectReviewManager detects stall patterns when a project has no check-in for 7+ days
- [ ] ProjectReviewManager detects blocked accumulation when 3+ tasks are blocked in a project
- [ ] ProjectReviewManager detects waiting accumulation when 3+ items are in waiting state simultaneously
- [ ] ProjectReviewManager detects deferral patterns when 5+ tasks have been deferred across projects
- [ ] Starting a review assembles ReviewContext with correct project details and detected patterns
- [ ] AI review conversation sends context to the LLM and displays the response
- [ ] Follow-up messages maintain conversation context from prior exchanges
- [ ] Empty follow-up messages are rejected and do not trigger an LLM call
- [ ] LLM errors during review are surfaced to the user without crashing
- [ ] Waiting item alerts are generated for items that have been waiting without follow-up
- [ ] Review state resets cleanly when starting a new review or dismissing
- [ ] Cross-project patterns are detected across multiple projects, not just within a single project

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/Reviews/ProjectReviewManager.swift` — Cross-project pattern detection (stall, blocked accumulation, deferral pattern, waiting accumulation), AI review conversation, waiting item alerts, ReviewContext, ProjectReviewDetail, CrossProjectPattern, PatternType, and WaitingItemAlert types
