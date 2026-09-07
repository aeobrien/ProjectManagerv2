# Phase 25: AI Project Reviews — Manual Test Brief

## Automated Tests
- **35 tests** in 3 suites, passing via `cd Packages/PMFeatures && swift test` and `cd Packages/PMServices && swift test`
- All **235 tests** pass in PMFeatures, **167 tests** in PMServices (no regressions).

### Suites
1. **ProjectReviewManagerTests** (11 tests) — Initial state, review with projects, LLM error handling, follow-up messaging, empty follow-up rejection, stall detection (7+ days), blocked accumulation (3+), waiting accumulation (3+), deferral pattern (5+), state reset, PatternType equality.
2. **AdversarialReviewManagerTests** (17 tests) — Initial state, export documents, export fail (no docs), import critiques from data, import critiques directly, empty import rejection, synthesis with AI, synthesis without export fail, synthesis without critiques fail, follow-up during review, empty follow-up ignored, approve revisions saves, approve empty fails, state reset, concern counts, step equality, revised document equality.
3. **ReviewExporterTests** (7 tests) — Build export package, encode/decode roundtrip, decode critiques, build synthesis prompt, empty docs, critique identity, metadata roundtrip.

## How to Access

### Portfolio Review (Focus Board)
1. Open app (macOS or iOS)
2. Navigate to Focus Board
3. Click the **sparkles icon** ("Portfolio Review") in the toolbar
4. A sheet opens with ProjectReviewView
5. Click "Start Review" to trigger AI analysis of all focused projects

### Adversarial Review (Complex Project Onboarding)
- AdversarialReviewView is part of the complex project onboarding pipeline
- Triggered during project onboarding for projects that warrant the full pipeline

## Manual Verification Checklist

### Review Context Assembly (25.1)
- [ ] Review assembles context for all focused projects with phases, milestones, tasks
- [ ] Blocked count calculated per project
- [ ] Waiting count calculated per project
- [ ] Frequently deferred tasks (3+ deferrals) identified per project
- [ ] Waiting items approaching check-back dates (within 1 day) detected
- [ ] Past-due waiting items flagged with `isPastDue`
- [ ] Queued projects included with pause reasons
- [ ] Paused projects included with pause reasons
- [ ] Recent check-ins (last 3) included per project

### Review Conversation Flow (25.2)
- [ ] "Start Review" button triggers full context assembly + LLM call
- [ ] Review prompt lists each focused project with task counts, blocked/waiting counts
- [ ] Detected patterns included in prompt (stall, blocked, deferral, waiting)
- [ ] Queued/paused projects with reasons included in prompt
- [ ] Waiting item alerts with past-due flags included in prompt
- [ ] AI response displayed in conversation view
- [ ] Follow-up messages maintain full conversation history
- [ ] Empty follow-up messages are rejected
- [ ] LLM errors surfaced as error text, not crashes
- [ ] "Refresh Review" button available after initial review

### Cross-Project Pattern Detection
- [ ] **Stall**: Detected when project has no check-in for 7+ days
- [ ] **Blocked accumulation**: Detected when 3+ tasks blocked in a project
- [ ] **Deferral pattern**: Detected when 5+ frequently deferred tasks across all projects
- [ ] **Waiting accumulation**: Detected when 3+ waiting items approaching check-back simultaneously
- [ ] Patterns displayed as cards with type-appropriate icons and colors

### Waiting Item Accumulation (25.3)
- [ ] Waiting tasks within 1 day of check-back date generate alerts
- [ ] Past-due items shown with "Past due" label
- [ ] Items not yet due shown with check-back date
- [ ] Accumulation pattern fires when 3+ items approach simultaneously

### UI & Navigation
- [ ] Portfolio Review button visible in Focus Board toolbar (sparkles icon)
- [ ] Review opens as sheet with "Close" button
- [ ] Pattern cards show icon, project name, and description
- [ ] Waiting alerts show task name, project name, and due status
- [ ] Conversation messages alternate user (blue) and assistant (purple) icons
- [ ] Follow-up text field and send button available after initial review

### Platform Parity
- [ ] macOS: Review button in Focus Board toolbar, sheet opens correctly
- [ ] iOS: Review button in Focus Board toolbar, sheet opens correctly
- [ ] Both platforms instantiate ProjectReviewManager with all required repos

## Files Created/Modified

### New Files (Phase 25)
- `Packages/PMFeatures/Sources/PMFeatures/Reviews/ProjectReviewManager.swift` — ReviewManager with context assembly, pattern detection, AI conversation, supporting types
- `Packages/PMFeatures/Sources/PMFeatures/Reviews/ProjectReviewView.swift` — Review UI with patterns, waiting alerts, conversation, follow-up
- `Packages/PMFeatures/Sources/PMFeatures/AdversarialReview/AdversarialReviewManager.swift` — 5-step adversarial review pipeline
- `Packages/PMFeatures/Sources/PMFeatures/AdversarialReview/AdversarialReviewView.swift` — Pipeline UI with step indicator
- `Packages/PMServices/Sources/PMServices/AdversarialReview/ReviewExporter.swift` — Export/import logic for adversarial pipeline

### Modified Files (This Audit)
- `Packages/PMFeatures/Sources/PMFeatures/FocusBoard/FocusBoardView.swift` — Added reviewManager property, "Portfolio Review" toolbar button, sheet presentation
- `Packages/PMFeatures/Sources/PMFeatures/Reviews/ProjectReviewManager.swift` — Added queued/paused project reasons to review prompt
- `ProjectManager/Sources/ContentView.swift` — Instantiate ProjectReviewManager, pass to FocusBoardView
- `ProjectManageriOS/Sources/iOSContentView.swift` — Same wiring as macOS
