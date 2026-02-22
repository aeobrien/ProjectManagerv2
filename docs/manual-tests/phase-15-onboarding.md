# Phase 15: Project Onboarding — Manual Test Brief

## Automated Tests
- **24 tests** in 1 suite, passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **OnboardingFlowManagerTests** (24 tests) — Validates initial state, brain dump → discovery flow, structure proposal generation with task attributes (priority, effort type), toggling items, accepted item count, complexity assessment (simple/medium/complex), project creation with hierarchy, Idea→Queued transition, source project transcript inclusion, document generation (vision + tech brief), document auto-generation on medium/complex project creation, task parenting across milestones, default phase/milestone creation, task attribute propagation to PMTask, hierarchy distribution, reset, error handling, and equality checks.

## Manual Verification Checklist

### Entry Points
- [ ] In Project Browser, the "+" toolbar button shows a menu with "Quick Create" and "AI-Guided Onboarding"
- [ ] Clicking "AI-Guided Onboarding" opens the onboarding sheet
- [ ] Right-clicking an Idea-state project shows "Start Onboarding" in context menu
- [ ] "Start Onboarding" on an Idea project pre-fills the brain dump with Quick Capture transcript

### Brain Dump Step
- [ ] Text editor accepts free-form project description
- [ ] "Analyze with AI" button is disabled when text is empty
- [ ] Clicking "Analyze with AI" shows loading state and advances to discovery

### AI Discovery Step
- [ ] AI response is displayed with natural language explanation
- [ ] Suggested complexity (Simple/Medium/Complex) is shown

### Structure Proposal Step
- [ ] Proposed milestones and tasks are displayed as toggleable cards
- [ ] Each task shows priority, effort type, and parent milestone when available
- [ ] Tapping an item toggles its acceptance (green checkmark ↔ empty circle)
- [ ] Counter shows "X of Y items selected"
- [ ] For medium/complex projects, a "Generate Documents" button appears
- [ ] Clicking "Generate Documents" creates vision statement (and tech brief for complex)
- [ ] Document status indicators show when documents are ready
- [ ] Project name, category picker, and DoD fields are shown
- [ ] "Create Project" button requires name and category

### Project Creation
- [ ] Creating project shows progress indicator
- [ ] Project is created with lifecycle state "queued"
- [ ] All accepted phases, milestones, and tasks are created
- [ ] Tasks are distributed under their parent milestone (not all under first)
- [ ] Task attributes (priority, effort type) are preserved on created PMTask entities
- [ ] For medium/complex projects, vision statement document is saved
- [ ] For complex projects, technical brief document is also saved
- [ ] For Idea-state source projects, project transitions from Idea → Queued

### Completion
- [ ] Green checkmark and "Project Created" message shown
- [ ] "Done" button resets flow and dismisses sheet

### Error Handling
- [ ] AI error during discovery shows error message and returns to brain dump
- [ ] Error during project creation shows error message and returns to structure proposal

## Files
### Source Files
- `Packages/PMFeatures/Sources/PMFeatures/Onboarding/OnboardingFlowManager.swift` — Flow manager with brain dump, AI discovery, complexity assessment, structure proposal with task attributes, document generation, and hierarchy creation
- `Packages/PMFeatures/Sources/PMFeatures/Onboarding/OnboardingView.swift` — Full 5-step onboarding UI with step indicator, toggleable structure cards, document generation button, and project creation form
- `Packages/PMFeatures/Sources/PMFeatures/ProjectBrowser/ProjectBrowserView.swift` — Entry points: "AI-Guided Onboarding" toolbar menu and "Start Onboarding" context menu on Idea projects

### App Wiring
- `ProjectManager/Sources/ContentView.swift` — Creates OnboardingFlowManager, passes to ProjectBrowserView
- `ProjectManageriOS/Sources/iOSContentView.swift` — Same wiring for iOS

### Tests
- `Packages/PMFeatures/Tests/PMFeaturesTests/OnboardingFlowManagerTests.swift` — 24 tests covering all flow states, complexity levels, document generation, hierarchy creation, and task attribute propagation
