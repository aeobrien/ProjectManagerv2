# Phase 17: Retrospective & Return Briefings — Manual Test Brief

## Automated Tests
- **20 tests** in 1 suite, passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **RetrospectiveFlowManagerTests** (20 tests) — Validates initial state defaults, phase completion detection (all milestones complete + no prior retrospective), prompt generation, beginning the AI reflection conversation, snooze per phase, submitting a reflection, handling empty reflection input, LLM error during conversation, follow-up question handling, completing the retrospective, dormancy detection (isDormant with 14-day threshold), return briefing generation, briefing generation error handling, state reset, FlowStep equality checks, and custom dormancy threshold configuration.

## Manual Verification Checklist

### Phase Completion Detection & Retrospective Prompt
- [ ] When all milestones in a phase are marked completed, a green banner appears at the top of ProjectDetailView
- [ ] The banner shows the phase name and "Start Retrospective" button
- [ ] The banner shows a "Snooze" menu with 1 Day, 3 Days, 1 Week options
- [ ] Clicking "Snooze" dismisses the banner and doesn't re-prompt until the snooze expires
- [ ] A phase that already has a retrospective does not trigger the banner
- [ ] A phase with incomplete milestones does not trigger the banner

### Retrospective Flow (via banner or context menu)
- [ ] Clicking "Start Retrospective" opens a sheet with the RetrospectiveView
- [ ] In the prompt step, clicking "Begin Reflection" shows a text editor
- [ ] The text editor accepts free-form reflection text
- [ ] Submitting empty reflection shows an error message
- [ ] Submitting a reflection sends it to the AI and shows the AI conversation step
- [ ] The AI response is displayed with user/assistant message bubbles
- [ ] A follow-up text field allows additional questions to the AI
- [ ] Sending a follow-up appends to the conversation
- [ ] Clicking "Complete Retrospective" saves notes to the Phase record
- [ ] After completion, the phase shows a green "text.bubble.fill" icon in the roadmap
- [ ] LLM errors during reflection show appropriate error text and fall back to the reflection step

### Context Menu Entry
- [ ] Right-clicking a phase with all milestones completed shows "Start Retrospective" in context menu
- [ ] Phases with incomplete milestones do not show the retrospective context menu option
- [ ] Phases that already have a retrospective do not show "Start Retrospective"
- [ ] Phases with retrospective notes show "View Retrospective Notes" in context menu

### Return Briefing (in Chat)
- [ ] When selecting a project in Chat that has been dormant for 14+ days, a return briefing card appears
- [ ] The return briefing card shows "Welcome Back" with a purple accent
- [ ] Clicking the "X" dismiss button on the briefing card removes it
- [ ] The dormancy threshold is configurable in Settings ("Return briefing after (days)")
- [ ] On iOS, the threshold from Settings is respected (not hardcoded to 14)

### Return Briefing (in RetrospectiveView)
- [ ] In the idle view, a dormant project shows "This project has been dormant" with a moon icon
- [ ] Clicking "Generate Return Briefing" calls the LLM and displays the briefing
- [ ] LLM errors during briefing generation show appropriate error text

### Settings
- [ ] Settings > Focus Board shows "Return briefing after (days)" stepper (range 7-60)

## Files

### Source Files
- `Packages/PMFeatures/Sources/PMFeatures/Retrospective/RetrospectiveFlowManager.swift` — Phase completion detection, AI reflection conversation, snooze per phase, dormancy detection with configurable threshold, and return briefing generation
- `Packages/PMFeatures/Sources/PMFeatures/Retrospective/RetrospectiveView.swift` — Full 5-step retrospective UI with prompt, snooze, reflection editor, AI conversation with follow-ups, completion, and return briefing display
- `Packages/PMFeatures/Sources/PMFeatures/ProjectDetail/ProjectDetailViewModel.swift` — Added `phaseNeedingRetrospective`, `retrospectiveManager`, `checkForCompletedPhases()`, `dismissRetrospectivePrompt()`
- `Packages/PMFeatures/Sources/PMFeatures/ProjectDetail/ProjectDetailView.swift` — Added retrospective banner with Start/Snooze, sheet presentation of RetrospectiveView
- `Packages/PMFeatures/Sources/PMFeatures/ProjectDetail/RoadmapView.swift` — Added retrospective context menu on completed phases, retrospective completed indicator icon
- `Packages/PMFeatures/Sources/PMFeatures/Chat/ChatView.swift` — Return briefing card with working dismiss button
- `Packages/PMFeatures/Sources/PMFeatures/Chat/ChatViewModel.swift` — Return briefing auto-trigger on project selection, `dismissReturnBriefing()` method
- `Packages/PMServices/Sources/PMServices/AI/PromptTemplates.swift` — `retrospective()` and `reEntry()` system prompts

### App Wiring
- `ProjectManager/Sources/ContentView.swift` — Creates RetrospectiveFlowManager, passes to ProjectDetailViewModel
- `ProjectManageriOS/Sources/iOSContentView.swift` — Same wiring, plus returnBriefingThresholdDays from settings on ChatViewModel

### Tests
- `Packages/PMFeatures/Tests/PMFeaturesTests/RetrospectiveFlowManagerTests.swift` — 20 tests covering all flow states, phase completion detection, snooze, AI conversation, follow-ups, completion with note saving, dormancy detection, return briefing generation, error handling, reset, and custom thresholds
