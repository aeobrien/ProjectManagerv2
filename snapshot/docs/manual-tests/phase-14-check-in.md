# Phase 14: Check-In Flow — Manual Test Brief

## Automated Tests
- **16 tests** in 1 suite, passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **CheckInFlowManagerTests** (16 tests) — Validates initial state defaults, starting check-ins at each depth (quickLog, standard, full), task selection for check-in scope, voice transcript integration, AI conversation during check-in, follow-up question handling, saving check-in records, snooze functionality (1h/3h/tomorrow), and error handling for failed operations.

## Manual Verification Checklist
- [ ] CheckInFlowManager initializes with no active check-in and default state
- [ ] Starting a quickLog check-in presents a minimal logging interface
- [ ] Starting a standard check-in presents task selection and progress entry
- [ ] Starting a full check-in presents the complete flow with AI conversation
- [ ] Task selection allows choosing which tasks to include in the check-in
- [ ] Voice transcript from VoiceInputView is accepted as check-in input
- [ ] AI conversation generates contextual follow-up questions during standard and full check-ins
- [ ] Responding to follow-up questions continues the AI conversation
- [ ] Saving a check-in persists the record with all entered data
- [ ] Snooze with 1-hour delay dismisses the check-in and reschedules appropriately
- [ ] Snooze with 3-hour delay dismisses the check-in and reschedules appropriately
- [ ] Snooze with tomorrow delay dismisses the check-in and reschedules appropriately
- [ ] Deferred tasks are tracked and surfaced in subsequent check-ins
- [ ] Error states (network failure, save failure) display appropriate feedback

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/CheckIn/CheckInFlowManager.swift` — Multi-depth check-in flow manager with AI conversation, deferred task tracking, snooze support, task selection, and check-in record persistence
