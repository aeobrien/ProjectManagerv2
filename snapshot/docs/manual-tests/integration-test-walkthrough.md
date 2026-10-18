# Integration Test Walkthrough

This document is a single end-to-end test flow through the running app.
Each step tests specific phases. When a step passes, those phases are verified.
When a step fails, we know exactly what's broken.

**How to use:** Work through sequentially. Mark each step PASS, FAIL, or BLOCKED.
A BLOCKED step means a prerequisite failed. Note any observations.

---

## Prerequisites

- macOS 14+ (Sonoma)
- Xcode 16.3+
- App builds without errors: `xcodebuild -scheme ProjectManager -destination 'platform=macOS' build`
- All automated tests pass:
  - `cd Packages/PMData && swift test` (72 tests)
  - `cd Packages/PMServices && swift test` (160 tests)
  - `cd Packages/PMFeatures && swift test` (197 tests)

---

## Part 1: App Launch and Navigation Shell

**Tests:** Phase 0 (scaffolding), Phase 4 (design system)

### Step 1.1 — App launches
- Run the app (Cmd+R)
- [ ] App window appears without crash
- [ ] No error screen ("Failed to Initialize") is shown
- [ ] A sidebar is visible on the left

### Step 1.2 — Sidebar navigation
- [ ] Sidebar shows "Main" section with: Focus Board, All Projects, AI Chat
- [ ] Sidebar shows "Settings" section below
- [ ] Clicking "Focus Board" shows the Focus Board in the detail area
- [ ] Clicking "All Projects" shows the Project Browser in the detail area
- [ ] Clicking "AI Chat" shows the Chat interface in the detail area
- [ ] Clicking "Settings" shows the Settings panel in the detail area
- [ ] Switching between sections is instant (no loading delay)

---

## Part 2: Settings

**Tests:** Phase 3 (settings), Phase 4 (design system components)

### Step 2.1 — Settings display
- Click "Settings" in the sidebar
- [ ] Settings panel appears with multiple card sections
- [ ] Sections visible: Focus Board, Check-in Prompts, Time Estimates, Notifications, Done Column, Voice Input, AI Assistant, Life Planner Sync, Integration API

### Step 2.2 — Settings controls respond
- [ ] Adjust "Max Focus Slots" stepper up and down — value changes
- [ ] Adjust "Staleness Threshold" stepper — value changes
- [ ] Move "Pessimism Multiplier" slider — value updates (e.g. "1.5x")
- [ ] Toggle "Notifications Enabled" ON — additional options appear (max daily, quiet hours)
- [ ] Toggle "Notifications Enabled" OFF — additional options disappear
- [ ] Change "Whisper Model" segmented picker — selection changes
- [ ] Toggle "Life Planner Sync" ON — sync method picker appears
- [ ] Toggle "Integration API" ON — port stepper appears

### Step 2.3 — Settings persist
- Note the current values of 2-3 settings
- Quit and relaunch the app
- Go to Settings
- [ ] Previously changed values are preserved

---

## Part 3: Project Browser — Create

**Tests:** Phase 1 (domain models), Phase 2 (persistence), Phase 5 (project browser)

### Step 3.1 — Empty state
- Click "All Projects" in the sidebar
- [ ] If no projects exist: empty state message is shown
- [ ] "New Project" button or "+" button is visible

### Step 3.2 — Create first project
- Click the "+" / "New Project" button
- [ ] A create sheet appears with fields: Name, Category picker, Definition of Done
- [ ] "Create" button is disabled when name is empty
- [ ] Category picker shows seeded categories (Personal, Work, Creative, Health, Learning, Financial)
- Type name: "Test App Alpha"
- Select category: "Personal"
- Type DoD: "MVP feature-complete with tests"
- Click "Create"
- [ ] Sheet dismisses
- [ ] "Test App Alpha" appears in the project list
- [ ] Project row shows the name and category

### Step 3.3 — Create second project
- Create another project:
  - Name: "Side Project Beta"
  - Category: "Creative"
  - DoD: "Published and shared"
- [ ] Second project appears in the list
- [ ] Both projects are visible

### Step 3.4 — Create third project
- Create a third project:
  - Name: "Work Task Gamma"
  - Category: "Work"
  - DoD: "Deployed to production"
- [ ] Three projects now visible in the list

---

## Part 4: Project Browser — Filter, Search, Edit

**Tests:** Phase 5 (project browser)

### Step 4.1 — Search
- Type "Alpha" in the search bar
- [ ] Only "Test App Alpha" is visible
- Clear the search
- [ ] All three projects are visible again

### Step 4.2 — Category filter
- Click the category filter (folder icon)
- Select "Personal"
- [ ] Only "Test App Alpha" is visible
- Select "All Categories"
- [ ] All projects visible again

### Step 4.3 — Edit a project
- Right-click "Test App Alpha" → "Edit..."
- [ ] Edit sheet appears with pre-filled name, category, DoD
- Change notes to: "This is my main test project"
- Click "Save"
- [ ] Sheet dismisses, project still in list

### Step 4.4 — Lifecycle transitions
- Right-click "Side Project Beta" → "Change State" → look for "Pause" or similar
- [ ] State transition options appear in context menu
- If a "Pause" option exists, click it
- [ ] If a reason prompt appears, enter "Taking a break" and confirm
- [ ] Project row should visually indicate paused state (or filter should work)
- Click the lifecycle filter chips (if visible) to filter by state
- [ ] Filtering by lifecycle state shows/hides projects correctly

---

## Part 5: Navigate to Project Detail

**Tests:** Phase 6 (hierarchy management)

### Step 5.1 — Click into a project
- Click on "Test App Alpha" in the project list
- [ ] PASS: Project detail view appears with project name, tabs (Roadmap, Timeline, Overview)
- [ ] FAIL: Nothing happens (navigation not wired up)

> **If this step FAILS:** Navigation from browser to detail is not connected.
> Mark all of Part 5 as BLOCKED and skip to Part 6.

### Step 5.2 — Add a phase
- In the Roadmap tab, find the "New phase name..." field
- Type "Research & Planning" and click "Add Phase"
- [ ] Phase appears in the roadmap list

### Step 5.3 — Add a second phase
- Type "Implementation" and add it
- [ ] Two phases visible, each with an expand chevron

### Step 5.4 — Add milestones
- Expand "Research & Planning" phase
- Add milestone: "Define Requirements"
- Add milestone: "Technical Spike"
- [ ] Both milestones appear under the phase

### Step 5.5 — Add tasks under a milestone
- Expand "Define Requirements" milestone
- Add task: "Write user stories"
- Add task: "Create wireframes"
- Add task: "Review with stakeholders"
- [ ] Three tasks appear under the milestone

### Step 5.6 — Add subtasks
- Expand "Write user stories" task
- Add subtask: "Draft initial stories"
- Add subtask: "Get feedback"
- [ ] Two subtasks appear under the task

### Step 5.7 — Toggle subtask completion
- Click the circle next to "Draft initial stories"
- [ ] Subtask shows as completed (checkmark, strikethrough text)
- Click it again
- [ ] Subtask returns to incomplete state

### Step 5.8 — Change task status via context menu
- Right-click "Create wireframes" → Status → "In Progress"
- [ ] Task icon/status updates to show in-progress
- Right-click "Create wireframes" → Status → "Completed"
- [ ] Task shows as completed

### Step 5.9 — Task blocking
- Right-click "Review with stakeholders" → Status → "Blocked"
- [ ] Task shows blocked indicator
- Right-click again → Status → "Not Started" (or unblock)
- [ ] Task returns to normal state

### Step 5.10 — Delete items
- Right-click one subtask → "Delete Subtask"
- [ ] Subtask disappears
- Add a throwaway task "DELETE ME" under any milestone
- Right-click → "Delete Task"
- [ ] Task disappears

### Step 5.11 — Overview tab
- Click the "Overview" tab
- [ ] Shows project definition of done
- [ ] Shows project notes (if entered)
- [ ] Shows phase count/list

### Step 5.12 — Timeline tab
- Click the "Timeline" tab
- [ ] Shows timeline visualization with phases, milestones, tasks
- [ ] Status icons are visible
- [ ] Progress indicators show completion percentages

---

## Part 6: Focus Board

**Tests:** Phase 7 (focus board), Phase 4 (health badges, task cards)

### Step 6.1 — Focus a project
- Go to "All Projects"
- Right-click "Test App Alpha" → look for "Focus" or lifecycle state change to focused
- [ ] Project's state changes to focused

> **Note:** If there's no "Focus" option in the context menu, try the Edit sheet
> and look for a lifecycle transition to "Focused".

### Step 6.2 — Focus Board shows the project
- Click "Focus Board" in the sidebar
- [ ] "Test App Alpha" appears as a Kanban section
- [ ] Three columns visible: To Do, In Progress, Done
- [ ] Tasks from the project appear in appropriate columns

### Step 6.3 — Move tasks between columns
- If a task card is in "To Do", click it
- [ ] A popover or detail appears with task info
- [ ] "Move to In Progress" button is available
- Click "Move to In Progress"
- [ ] Task card moves to the In Progress column

### Step 6.4 — Move task to Done
- Click the task in "In Progress"
- Click "Move to Done"
- [ ] Task card moves to Done column
- [ ] Task should be marked as completed

### Step 6.5 — Context menu on task card
- Right-click a task card
- [ ] Context menu shows column move options
- Select a different column
- [ ] Task moves accordingly

### Step 6.6 — Effort type filter
- Look for effort type filter chips above the kanban board
- [ ] "All Types" chip is selected by default
- If you have tasks with different effort types, select a specific type
- [ ] Only tasks of that effort type are shown

### Step 6.7 — Focus a second project
- Focus "Work Task Gamma" (same method as Step 6.1)
- Return to Focus Board
- [ ] Both projects appear as separate Kanban sections
- [ ] Each has its own three-column layout

### Step 6.8 — Remove from focus
- Find the "X" button on one of the project sections
- Click it
- [ ] That project disappears from the Focus Board
- Go to "All Projects" and verify the project still exists (just unfocused)

---

## Part 7: AI Chat

**Tests:** Phase 12 (AI core), Phase 13 (chat UI)

> **Prerequisite:** An Anthropic or OpenAI API key must be set as an environment
> variable (ANTHROPIC_API_KEY or OPENAI_API_KEY). If no key is available,
> mark this section as BLOCKED and note it.

### Step 7.1 — Chat interface loads
- Click "AI Chat" in the sidebar
- [ ] Chat interface appears with message area and input bar
- [ ] Project selector picker is visible (should show "General" + project names)
- [ ] Conversation type picker is visible

### Step 7.2 — Send a message (no API key)
- Type "Hello, can you help me plan my project?" and press Send
- [ ] If no API key: an error message appears (expected)
- [ ] If API key present: message appears in chat, AI responds

### Step 7.3 — Project context (if API key available)
- Select "Test App Alpha" from the project picker
- Type "What's the status of this project?"
- [ ] AI responds with awareness of the project context
- [ ] Response appears as an assistant message bubble

### Step 7.4 — Action confirmation (if API key available)
- Ask the AI to make a change: "Can you create a new task called 'Setup CI/CD' in the first milestone?"
- [ ] If AI proposes an action: confirmation bar appears with checkboxes
- [ ] You can toggle individual changes on/off
- [ ] "Apply" button executes accepted changes
- [ ] "Cancel" button dismisses without applying

### Step 7.5 — Clear chat
- Click the clear/trash button
- [ ] All messages are cleared
- [ ] Chat returns to empty state

### Step 7.6 — Voice input toggle
- Click the microphone icon in the input bar
- [ ] Input switches to voice mode (VoiceInputView appears)
- Click the keyboard icon
- [ ] Input switches back to text mode

---

## Part 8: Quick Capture (macOS)

**Tests:** Phase 9 (quick capture), Phase 10-11 (voice input)

> **Note:** Quick Capture may only be accessible on iOS (tab bar).
> On macOS, check if there's a menu item, keyboard shortcut, or other trigger.

### Step 8.1 — Access Quick Capture
- [ ] PASS: Quick Capture is accessible (describe how)
- [ ] FAIL: No way to access Quick Capture on macOS

> If FAIL, skip to Part 9. Note that Quick Capture needs a macOS entry point.

### Step 8.2 — Capture an idea (if accessible)
- Type a project idea in the text field
- Select a category
- Click "Save Idea"
- [ ] Success message appears
- [ ] New project appears in the Project Browser

---

## Part 9: Documents

**Tests:** Phase 16 (document management)

### Step 9.1 — Access Document Editor
- From a project detail view, look for a "Documents" tab or section
- [ ] PASS: Document editor is accessible (describe how)
- [ ] FAIL: No navigation path to the document editor

> If FAIL, skip document tests. Note that document editor needs a navigation path.

### Step 9.2 — Create a document (if accessible)
- Click the "+" menu → "Vision Statement"
- [ ] New document appears in the list
- [ ] Document opens in the editor pane

### Step 9.3 — Edit and save
- Change the title to "Test App Alpha Vision"
- Type content: "This app will help manage projects effectively."
- [ ] Unsaved changes indicator appears (blue dot)
- Click "Save" (or Cmd+S)
- [ ] Version increments to v2 (or stays v1 if first save)
- [ ] Unsaved indicator disappears

### Step 9.4 — Create another document type
- Create a "Technical Brief" document
- [ ] Second document appears in the list
- [ ] Selecting either document loads its content in the editor

---

## Part 10: Data Persistence

**Tests:** Phase 2 (data persistence), Phase 3 (data export)

### Step 10.1 — Data survives restart
- Note how many projects exist and their names
- Note one project's phases/milestones/tasks
- Quit the app (Cmd+Q)
- Relaunch the app
- [ ] All projects are still present
- [ ] Project hierarchy (phases, milestones, tasks) is preserved
- [ ] Settings are preserved

### Step 10.2 — Delete and verify
- Delete one of the test projects (e.g. "Side Project Beta" if it was paused)
- [ ] Project disappears from the list
- [ ] Its phases, milestones, and tasks are also gone (cascade delete)
- Quit and relaunch
- [ ] Deleted project does not reappear

---

## Part 11: Design System Visual Check

**Tests:** Phase 4 (design system)

### Step 11.1 — Visual consistency
- Browse through all accessible views
- [ ] Cards have consistent styling (PMCard component)
- [ ] Empty states show centered icon + message (PMEmptyState)
- [ ] Progress indicators use consistent styling
- [ ] Colour palette feels cohesive (no jarring mismatches)
- [ ] SF Symbols are used consistently for icons

### Step 11.2 — Health badges (if projects on Focus Board)
- With a focused project, check the Focus Board
- [ ] If a project has blocked tasks: blocked badge visible
- [ ] If a project hasn't been checked in recently: staleness badge visible
- [ ] Task cards show effort type, priority, and time estimate icons where applicable

---

## Gap Assessment

After completing the walkthrough, fill in this summary of what works and what doesn't.

### Navigation Gaps
These features have backends (ViewModels/managers) but no way to reach them in the UI:

| Feature | ViewModel/Manager | UI View | Navigation Path | Status |
|---------|-------------------|---------|-----------------|--------|
| Project Detail | ProjectDetailViewModel | ProjectDetailView | onSelectProject callback | ? |
| Document Editor | DocumentViewModel | DocumentEditorView | None found | ? |
| Check-in Flow | CheckInFlowManager | None | None | NO UI |
| Onboarding Flow | OnboardingFlowManager | None | None | NO UI |
| Retrospective Flow | RetrospectiveFlowManager | None | None | NO UI |
| Analytics | AnalyticsViewModel | None | None | NO UI |
| AI Project Review | ProjectReviewManager | None | None | NO UI |
| Cross-Project Roadmap | CrossProjectRoadmapViewModel | None | None | NO UI |
| Adversarial Review | AdversarialReviewManager | None | None | NO UI |
| Quick Capture (macOS) | QuickCaptureViewModel | QuickCaptureView | iOS tab only? | ? |

### Phase Verification Summary

| Phase | What It Built | Testable? | Result |
|-------|---------------|-----------|--------|
| 0 | App scaffolding, logging | Yes — app launches | |
| 1 | Domain models | Yes — via project creation | |
| 2 | SQLite persistence | Yes — data survives restart | |
| 3 | Settings, data export | Partial — settings yes, export no UI | |
| 4 | Design system | Yes — visual inspection | |
| 5 | Project Browser | Yes — CRUD, filter, search | |
| 6 | Hierarchy management | Depends — needs navigation to detail | |
| 7 | Focus Board | Yes — if project can be focused | |
| 8 | Roadmap View | Depends — needs navigation to detail | |
| 9 | Quick Capture | Partial — iOS only? | |
| 10 | Voice Input | Partial — microphone toggle in chat | |
| 11 | Voice Quick Capture | Depends on Quick Capture access | |
| 12 | AI Core | Yes — if API key available | |
| 13 | Chat UI | Yes — chat interface present | |
| 14 | Check-In Flow | No — no UI trigger | |
| 15 | Onboarding Flow | No — no UI trigger | |
| 16 | Documents | Depends — needs navigation path | |
| 17 | Retrospective | No — no UI trigger | |
| 18 | Knowledge Base (RAG) | No — backend only, no UI | |
| 19 | CloudKit Sync | No — backend only, no UI | |
| 20 | iOS App | Separate build required | |
| 21 | Notifications | No — backend only | |
| 22 | Life Planner Export | No — backend only | |
| 23 | Integration API | No — backend only | |
| 24 | Analytics | No — no View | |
| 25 | AI Project Reviews | No — no View | |
| 26 | Cross-Project Roadmap | No — no View | |
| 27 | Adversarial Review | No — no View | |

### Critical Gaps (things that should be fixable)

1. **Project detail navigation** — `onSelectProject` callback exists but is never passed in ContentView. Wiring this up would unlock Phase 6, 8, 16 testing.

2. **Quick Capture on macOS** — View exists, not accessible from the sidebar or a keyboard shortcut.

3. **Check-in, Onboarding, Retrospective flows** — Managers exist with full logic, but no UI views or trigger buttons exist anywhere.

4. **Analytics, AI Reviews, Cross-Project Roadmap, Adversarial Review** — ViewModels exist, but no SwiftUI Views were ever created for them.

5. **Document Editor** — View exists but no navigation path leads to it from any accessible part of the app.

### Backend-Only Features (by design)

These features are intentionally backend/service-layer and don't need UI to function:

- Phase 18: Knowledge Base — indexes content for AI context retrieval
- Phase 19: CloudKit Sync — syncs via SyncEngine actor
- Phase 21: Notifications — schedules via UNUserNotificationCenter
- Phase 22: Life Planner Export — exports via API/file backend
- Phase 23: Integration API — serves REST endpoints

These are testable via their automated unit tests but not through the app UI.
