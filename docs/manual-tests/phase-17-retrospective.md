# Phase 17: Retrospective & Return Briefings — Manual Test Brief

## Automated Tests
- **20 tests** in 1 suite, passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **RetrospectiveFlowManagerTests** (20 tests) — Validates initial state defaults, phase completion detection (all milestones complete + no prior retrospective), prompt generation, beginning the AI reflection conversation, snooze per phase, submitting a reflection, handling empty reflection input, LLM error during conversation, follow-up question handling, completing the retrospective, dormancy detection (isDormant with 14-day threshold), return briefing generation, briefing generation error handling, state reset, FlowStep equality checks, and custom dormancy threshold configuration.

## Manual Verification Checklist
- [ ] RetrospectiveFlowManager initializes with no active retrospective session
- [ ] A phase with all milestones marked complete and no prior retrospective is detected as eligible
- [ ] A phase with incomplete milestones is not flagged for retrospective
- [ ] A phase that already has a retrospective is not flagged again
- [ ] The retrospective prompt is presented when a completed phase is detected
- [ ] Beginning the reflection starts an AI conversation for the phase retrospective
- [ ] Snoozing the retrospective for a specific phase defers it and does not re-prompt immediately
- [ ] Submitting a reflection with content saves the retrospective record
- [ ] Submitting an empty reflection is handled gracefully (rejected or warned)
- [ ] An LLM error during the reflection conversation displays appropriate feedback
- [ ] Follow-up questions from the AI continue the reflection dialogue
- [ ] Completing the retrospective marks the phase as having a retrospective record
- [ ] A project with no activity for 14 days is detected as dormant (isDormant returns true)
- [ ] A return briefing is generated for a dormant project summarizing what happened and what is next
- [ ] An error during briefing generation is handled gracefully
- [ ] Resetting the flow manager clears all in-progress state
- [ ] Custom dormancy threshold (other than 14 days) is respected when configured

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/Retrospective/RetrospectiveFlowManager.swift` — Phase completion detection, AI reflection conversation, snooze per phase, dormancy detection with configurable threshold, and return briefing generation
