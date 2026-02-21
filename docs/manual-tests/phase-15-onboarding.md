# Phase 15: Project Onboarding — Manual Test Brief

## Automated Tests
- **14 tests** in 1 suite, passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **OnboardingFlowManagerTests** (14 tests) — Validates initial state defaults, starting brain dump step, voice transcript integration, AI discovery conversation, follow-up question handling, structure proposal generation, accepting a proposal (auto-creates phases/milestones/tasks), rejecting a proposal and restarting discovery, saving generated documents (vision statement + technical brief), and error handling for AI and persistence failures.

## Manual Verification Checklist
- [ ] OnboardingFlowManager initializes with no active onboarding session
- [ ] Starting onboarding presents the brain dump step for free-form project description
- [ ] Voice transcript can be used as brain dump input via VoiceInputView
- [ ] After brain dump submission, the AI begins a discovery conversation with clarifying questions
- [ ] Responding to discovery questions continues the AI-guided conversation
- [ ] Follow-up questions refine the project understanding before proposing structure
- [ ] The AI generates a structure proposal with phases, milestones, and tasks
- [ ] Accepting the proposal auto-creates the project with all proposed phases, milestones, and tasks
- [ ] Rejecting the proposal returns to the discovery conversation for further refinement
- [ ] A vision statement document is generated and saved upon project creation
- [ ] A technical brief document is generated and saved upon project creation
- [ ] Error during AI conversation displays appropriate feedback without losing prior input
- [ ] Error during project creation displays appropriate feedback and allows retry

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/Onboarding/OnboardingFlowManager.swift` — Multi-step onboarding flow manager with brain dump, AI-guided discovery, structure proposal, document generation, and auto-creation of project hierarchy
