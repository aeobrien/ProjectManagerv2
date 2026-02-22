# Project Manager — Full Manual Test Procedure

**Purpose:** Systematically exercise every feature in the app to identify gaps, bugs, and broken flows.
**App:** Project Manager (macOS + iOS), SwiftUI, GRDB, Swift 6
**Date:** February 2026
**Estimated time:** 2-3 hours for full procedure

---

## How to Use This Document

1. Work through each section sequentially — later sections build on data created in earlier ones
2. Mark each checkbox: PASS, FAIL, or BLOCKED (prerequisite failed)
3. Write observations next to any FAIL or unexpected behaviour
4. The "Observations" line after each section is for free-text notes
5. Some sections require an LLM API key — skip those cleanly if unavailable
6. Test macOS first, then repeat key flows on iOS

---

## Prerequisites

### Build Verification
```bash
# All automated tests pass (514 total)
cd Packages/PMDomain && swift test    # 85 tests
cd Packages/PMData && swift test      # 72 tests
cd Packages/PMServices && swift test  # 160 tests
cd Packages/PMFeatures && swift test  # 197 tests
```
- [ ] All 514 tests pass
- [ ] macOS app builds: `xcodebuild -scheme ProjectManager -destination 'platform=macOS' build`
- [ ] iOS app builds (if Xcode project configured for iOS target)

### Environment
- macOS 14+ (Sonoma) or later
- Xcode 16+
- Optional: `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` environment variable set (for AI tests in Parts 9-12)
- Optional: Microphone access (for voice input tests in Part 10)

---

## PART 1: App Launch & Navigation Shell
**Tests phases:** 0 (scaffolding), 4 (design system), 5.4 (navigation)

### 1.1 — First Launch
- Run the app (Cmd+R from Xcode)
- [ ] App window appears without crash
- [ ] No "Failed to Initialize" error screen
- [ ] Loading spinner appears briefly, then the main UI loads
- [ ] Console log shows "Database initialized at ..." (check Xcode console)

### 1.2 — Sidebar Navigation
- [ ] Sidebar is visible on the left side of the window
- [ ] **Main sections visible:** Focus Board, All Projects, Quick Capture, Roadmap, AI Chat
- [ ] **Settings section visible** below the main sections
- [ ] Clicking each section switches the detail area content
- [ ] Section switching is instant (no loading delays between sections)
- [ ] The selected section is visually highlighted in the sidebar

### 1.3 — Keyboard Shortcut
- Press **Cmd+Shift+N** from anywhere in the app
- [ ] A Quick Capture sheet appears as a modal/overlay
- [ ] Pressing Escape or clicking outside dismisses it

**Observations:**

---

## PART 2: Settings
**Tests phases:** 3 (settings persistence), 9.4 (SettingsView), 22.5 (export settings)

### 2.1 — Settings Panel Display
- Click "Settings" in the sidebar
- [ ] Settings panel appears with scrollable card sections
- [ ] Sections visible: **Focus Board, Check-in Prompts, Time Estimates, Notifications, Done Column, Voice Input, AI Assistant, Data Export, Life Planner Sync, Integration API**

### 2.2 — Focus Board Settings
- [ ] "Max focus slots" stepper works (range 1-10)
- [ ] "Max per category" stepper works (range 1-10)
- [ ] "Visible tasks per project" stepper works (range 1-10)
- [ ] "Staleness threshold (days)" stepper works (range 1-30)
- [ ] "Return briefing after (days)" stepper works (range 7-60)

### 2.3 — Check-in Settings
- [ ] "Gentle prompt (days)" stepper works
- [ ] "Moderate prompt (days)" stepper works
- [ ] "Prominent prompt (days)" stepper works
- [ ] "Deferred threshold" stepper works

### 2.4 — Estimates
- [ ] "Pessimism multiplier" slider moves and displays value (e.g. "1.5x")

### 2.5 — Notifications
- [ ] "Notifications enabled" toggle works
- [ ] When ON: "Max daily" stepper and quiet hours pickers appear
- [ ] When OFF: those controls disappear
- [ ] Quiet hours start/end pickers show hour values

### 2.6 — Done Column
- [ ] "Retention (days)" stepper works
- [ ] "Max visible items" stepper works

### 2.7 — Voice Input
- [ ] Whisper model segmented picker shows options (Tiny/Base/Small/Medium/Large)
- [ ] Selecting different options changes the selection

### 2.8 — AI Assistant
- [ ] "Model identifier" text field is editable
- [ ] "Trust level" picker shows options (Confirm All/Confirm Destructive/Auto)

### 2.9 — Data Export
- [ ] Export section is visible
- [ ] "Export Now" button is present
- [ ] If no export service configured: shows "Export service not configured" message
- Note: Full export testing requires the export service to be wired up at the app level

### 2.10 — Life Planner Sync
- [ ] "Enable sync" toggle works
- [ ] When ON: sync method picker appears (MySQL/REST API/File Export)

### 2.11 — Integration API
- [ ] "Enable API" toggle works
- [ ] When ON: port stepper appears (range 1024-65535)

### 2.12 — Settings Persistence
- Note 3-4 setting values you changed
- Quit the app (Cmd+Q)
- Relaunch the app
- Navigate to Settings
- [ ] All changed values are preserved across restart

**Observations:**

---

## PART 3: Project Browser — CRUD
**Tests phases:** 1 (domain), 2 (persistence), 5 (project browser)

### 3.1 — Empty State
- Click "All Projects" in the sidebar
- [ ] If first launch: empty state message with icon is shown
- [ ] A way to create a new project is visible (+ button or menu)

### 3.2 — Create Project "Hospital Workflow System"
- Click the + / New Project button
- [ ] Create sheet appears with: Name, Category picker, Definition of Done fields
- [ ] "Create" button is disabled while name is empty
- [ ] Category picker shows seeded categories: **Software, Music, Hardware/Electronics, Creative, Life Admin, Research/Learning**
- Fill in:
  - Name: `Hospital Workflow System`
  - Category: `Software`
  - DoD: `Core workflow engine deployed and tested in staging`
- Click Create
- [ ] Sheet dismisses
- [ ] Project appears in the list with name and category shown

### 3.3 — Create Project "Patient Safety Tracker"
- Create another project:
  - Name: `Patient Safety Tracker`
  - Category: `Software`
  - DoD: `All safety check modules passing validation`
- [ ] Project appears in list alongside the first project

### 3.4 — Create Project "Staff Training Materials"
- Create a third project:
  - Name: `Staff Training Materials`
  - Category: `Creative`
  - DoD: `Complete training deck reviewed by department heads`
- [ ] Three projects now visible in the list

### 3.5 — Create Project "Equipment Audit"
- Create a fourth project:
  - Name: `Equipment Audit`
  - Category: `Life Admin`
  - DoD: `All equipment logged and tagged`
- [ ] Four projects visible

**Observations:**

---

## PART 4: Project Browser — Search, Filter, Edit, Lifecycle
**Tests phases:** 5 (project browser), 1.6 (validation)

### 4.1 — Search by Name
- Type `Hospital` in the search bar
- [ ] Only "Hospital Workflow System" is visible
- Type `Safety` in the search bar
- [ ] Only "Patient Safety Tracker" is visible
- Clear the search
- [ ] All four projects visible again

### 4.2 — Sort Order
- Look for a sort option (Recently Updated / Name / Date Created)
- [ ] Changing sort order reorders the project list
- [ ] "Name" sorts alphabetically
- [ ] "Recently Updated" puts most recently modified first

### 4.3 — Category Filter
- If there's a category filter control, select "Software"
- [ ] Only "Hospital Workflow System" and "Patient Safety Tracker" are visible
- Select "All" / clear the category filter
- [ ] All projects visible again

### 4.4 — Lifecycle State Filter
- If there's a lifecycle filter, check its options
- [ ] Filter options include: All Projects, Focused, Queued, Idea, Completed, Paused, Abandoned
- [ ] Selecting a specific state filters the list appropriately

### 4.5 — Edit a Project
- Right-click "Hospital Workflow System" → look for Edit option
- [ ] Edit sheet appears with pre-filled values
- Change the Definition of Done to: `Core workflow engine deployed, tested, and training complete`
- Save
- [ ] Changes are saved (verify by re-opening edit)

### 4.6 — Lifecycle Transitions
- Right-click "Equipment Audit" → look for lifecycle state change options
- [ ] Valid transition options are shown (e.g., from its current state)
- Transition "Equipment Audit" to **Paused** state
- [ ] If a reason prompt appears, enter `Waiting for budget approval` and confirm
- [ ] Project shows paused indicator
- Transition "Equipment Audit" from Paused back to its previous state
- [ ] Project returns to active state

### 4.7 — Delete a Project
- Right-click "Equipment Audit" → Delete
- [ ] Confirmation dialog appears before deletion
- Confirm deletion
- [ ] Project disappears from list
- [ ] Three projects remain

### 4.8 — Validation
- Try creating a project with an empty name
- [ ] The "Create" button remains disabled or shows a validation error

**Observations:**

---

## PART 5: Project Detail — Hierarchy Management
**Tests phases:** 6 (hierarchy), 8 (roadmap view), 16 (documents)

### 5.1 — Navigate to Project Detail
- Click on "Hospital Workflow System" in the project list
- [ ] **CRITICAL:** Project detail view appears (navigation works)
- [ ] Project name is displayed prominently
- [ ] Tabs or sections visible (e.g., Overview, Roadmap, Documents)

> **If this fails:** Navigation is broken. Mark remainder of Part 5 as BLOCKED.

### 5.2 — Add Phases
- Find the phase creation UI (e.g., text field + "Add Phase" button in the Roadmap tab)
- Add phase: `Requirements & Discovery`
- Add phase: `Core Development`
- Add phase: `Testing & Deployment`
- [ ] All three phases appear in the hierarchy view

### 5.3 — Add Milestones
- Expand "Requirements & Discovery" phase
- Add milestone: `Stakeholder Interviews Complete`
- Add milestone: `Requirements Document Signed Off`
- Expand "Core Development" phase
- Add milestone: `Workflow Engine MVP`
- Add milestone: `Integration Tests Passing`
- [ ] Milestones appear nested under their phases

### 5.4 — Add Tasks
- Expand "Stakeholder Interviews Complete" milestone
- Add task: `Schedule interviews with department heads`
- Add task: `Prepare interview template`
- Add task: `Conduct interviews`
- Add task: `Compile findings report`
- [ ] Four tasks appear under the milestone
- Expand "Workflow Engine MVP" milestone
- Add task: `Design database schema`
- Add task: `Implement workflow state machine`
- Add task: `Build REST API endpoints`
- [ ] Three tasks appear under this milestone

### 5.5 — Add Subtasks
- Expand "Conduct interviews" task
- Add subtask: `Interview Dr. Smith (Cardiology)`
- Add subtask: `Interview Dr. Jones (Oncology)`
- Add subtask: `Interview Nurse Manager Williams`
- [ ] Three subtasks appear under the task

### 5.6 — Toggle Subtask Completion
- Click the completion toggle next to "Interview Dr. Smith (Cardiology)"
- [ ] Subtask shows as completed (checkmark, visual change)
- Click it again
- [ ] Subtask returns to incomplete

### 5.7 — Task Status Changes
- Right-click "Design database schema" → look for status options
- Change to "In Progress"
- [ ] Task visual updates to show in-progress state
- Right-click again → Change to "Completed"
- [ ] Task shows as completed
- Right-click "Build REST API endpoints" → Block it
- [ ] Task shows blocked indicator
- [ ] If prompted for block reason, enter `Waiting for API design review`
- Right-click → Unblock
- [ ] Returns to normal state

### 5.8 — Task Waiting State
- Right-click "Compile findings report" → Set Waiting (if available)
- [ ] Task shows waiting indicator
- [ ] If prompted for check-back date, enter a date

### 5.9 — Delete Items
- Add a throwaway task "DELETE ME TEST" under any milestone
- Right-click → Delete
- [ ] Task disappears
- Add a throwaway subtask "DELETE SUBTASK" under any task
- Right-click → Delete
- [ ] Subtask disappears

### 5.10 — Roadmap/Timeline View
- Look for a Roadmap or Timeline tab in the project detail
- [ ] Roadmap shows phases → milestones → tasks in a hierarchical view
- [ ] Status indicators (colours/icons) reflect current task states
- [ ] Progress percentages are shown for milestones/phases
- [ ] Completed items show as done visually

### 5.11 — Documents Tab
- Click the "Documents" tab
- [ ] Document management interface appears
- [ ] "+" menu shows: Vision Statement, Technical Brief, Other Document

### 5.12 — Create a Vision Statement
- Click "+" → Vision Statement
- [ ] New document appears in the document list
- [ ] Editor pane opens

### 5.13 — Edit Document Content
- Change title to: `Hospital Workflow System — Vision`
- Type content:
  ```
  # Vision

  A unified workflow management system for hospital departments.

  ## Goals
  - Reduce administrative overhead by 40%
  - Standardize cross-department handoffs
  - Real-time visibility into workflow bottlenecks
  ```
- [ ] Unsaved changes indicator (blue dot) appears
- Click Save (or Cmd+S)
- [ ] Saved successfully — indicator disappears
- [ ] Version number updates

### 5.14 — Markdown Preview Toggle
- Look for an eye icon / preview toggle button in the document editor toolbar
- Click it
- [ ] Markdown preview appears showing rendered headers, bullet points, etc.
- [ ] On macOS: split pane shows editor on left, preview on right
- Toggle preview off
- [ ] Returns to editor-only view

### 5.15 — Create a Technical Brief
- Create another document via "+" → Technical Brief
- [ ] Second document appears in list
- [ ] Selecting between documents switches the editor content

### 5.16 — Navigate Back
- Click the back button / breadcrumb to return to the project list
- [ ] Returns to Project Browser successfully
- Click into "Hospital Workflow System" again
- [ ] All hierarchy (phases, milestones, tasks, subtasks) is preserved
- [ ] Documents are still present

**Observations:**

---

## PART 6: Focus Board
**Tests phases:** 7 (focus board), 4 (health badges, task cards), 1.5 (FocusManager)

### 6.1 — Focus a Project
- From "All Projects", transition "Hospital Workflow System" to **Focused** state
  - Right-click → lifecycle transition → Focused (or use the edit sheet)
- [ ] Project state changes to Focused

### 6.2 — Focus Board Display
- Click "Focus Board" in the sidebar
- [ ] "Hospital Workflow System" appears as a project section
- [ ] Three Kanban columns visible: **To Do, In Progress, Done**
- [ ] Tasks from the project appear in the appropriate columns based on their status
- [ ] Task cards show: task name, project name, milestone name

### 6.3 — Focus a Second Project
- Go to "All Projects", transition "Patient Safety Tracker" to Focused
- Add some phases/milestones/tasks to it if empty:
  - Phase: `Safety Module Development`
  - Milestone: `Core Safety Checks`
  - Tasks: `Medication verification check`, `Patient ID validation`, `Allergy alert system`
- Return to Focus Board
- [ ] Both projects appear as separate Kanban sections
- [ ] Each project has its own To Do / In Progress / Done columns

### 6.4 — Move Tasks Between Columns
- Find a task card in "To Do"
- Try clicking it for a popover, or right-click for context menu
- [ ] Options to move to In Progress / Done are available
- Move a task to "In Progress"
- [ ] Task card moves to the In Progress column
- Move a task to "Done"
- [ ] Task card moves to Done column
- [ ] Task is marked as completed

### 6.5 — Drag and Drop
- Try dragging a task card from one column to another
- [ ] Drag feedback appears while dragging
- [ ] Dropping in a different column moves the task
- [ ] Task status updates to match the new column

### 6.6 — Task Cards — Visual Details
- Look at the task cards on the Focus Board
- [ ] Cards show the task name
- [ ] Cards show the project name (colour-coded if applicable)
- [ ] If a task has a deadline: deadline is shown
- [ ] If a task is blocked: blocked badge/indicator is visible
- [ ] If a task is frequently deferred (timesDeferred >= 3): indicator is visible

### 6.7 — Effort Type Filter
- Look for effort type filter controls (chips or picker) above the Kanban board
- [ ] Filter options available (All Types, Deep Focus, Quick Win, Admin, Creative, Physical)
- If tasks have effort types assigned, select a specific type
- [ ] Only tasks of that effort type are shown
- Select "All Types"
- [ ] All tasks visible again

### 6.8 — Health Signals
- Look at project headers/badges on the Focus Board
- [ ] If a project hasn't been checked in recently: staleness indicator visible
- [ ] If a project has blocked tasks: blocked count badge visible
- [ ] Progress bar for each project section

### 6.9 — Diversity Violations
- Focus a third project in the same category as an existing focused project
- [ ] If it exceeds the "max per category" setting: diversity warning/banner appears
- (If you can't easily test this, note it as "requires specific setup")

### 6.10 — Unfocus a Project
- Right-click a project section on the Focus Board, or go to All Projects
- Transition the project from Focused to another state (e.g., Queued)
- [ ] Project disappears from the Focus Board
- [ ] Project still exists in All Projects (not deleted, just unfocused)

**Observations:**

---

## PART 7: Quick Capture
**Tests phases:** 9 (quick capture), 11 (voice quick capture)

### 7.1 — Quick Capture via Sidebar
- Click "Quick Capture" in the sidebar
- [ ] Quick Capture interface appears in the detail area
- [ ] Text input field is visible
- [ ] Category picker is visible
- [ ] Title field is visible (optional)

### 7.2 — Capture a Text Idea
- Type in the text field: `Need to investigate automated medication dispensing systems for the pharmacy department`
- Optionally set a title: `Pharmacy Automation Research`
- Select category: `Research/Learning`
- Click Save / Create
- [ ] Success feedback appears
- Go to "All Projects"
- [ ] New project "Pharmacy Automation Research" (or similar) appears in the list
- [ ] Project is in **Idea** lifecycle state
- Click into it
- [ ] The quick capture transcript text is stored on the project

### 7.3 — Quick Capture via Keyboard Shortcut
- Press **Cmd+Shift+N**
- [ ] Quick Capture sheet/modal appears
- Type an idea: `Training video series for new nurses`
- Save it
- [ ] Sheet dismisses
- [ ] New project appears in All Projects

### 7.4 — Voice Capture (if microphone available)
- Open Quick Capture (sidebar or keyboard shortcut)
- Look for a microphone / voice input button
- [ ] Voice input toggle/button is present
- Click it
- [ ] If microphone permission not granted: permission prompt appears
- [ ] If permission granted: recording interface appears with waveform
- Speak a brief idea
- Stop recording
- [ ] Transcription appears (may take a moment)
- [ ] Transcript is editable before saving
- Save the captured idea
- [ ] Project created with the voice transcript

**Observations:**

---

## PART 8: Cross-Project Roadmap
**Tests phases:** 26 (cross-project roadmap)

### 8.1 — Access Cross-Project Roadmap
- Click "Roadmap" in the sidebar
- [ ] Cross-project roadmap view appears

### 8.2 — Milestone Display
- [ ] Milestones from all focused projects are visible
- [ ] Milestones are grouped or sorted (by project, by deadline, or both)
- [ ] Project names are shown and colour-coded

### 8.3 — Status Filtering
- If there are status filter options, try filtering
- [ ] Filters show/hide milestones by status (Not Started, In Progress, Completed)

### 8.4 — Deadline Display
- [ ] Milestones with deadlines show the date
- [ ] Overdue milestones are visually highlighted
- [ ] Upcoming deadlines are visually prominent

### 8.5 — Stats
- [ ] Summary statistics are shown (total milestones, completed count, etc.)

**Observations:**

---

## PART 9: AI Chat — Basic
**Tests phases:** 12 (AI core), 13 (chat UI)

> **Prerequisite:** An LLM API key must be set. If no key is available, mark this section and Parts 10-12 as BLOCKED.

### 9.1 — Chat Interface
- Click "AI Chat" in the sidebar
- [ ] Chat interface loads with: message area, text input field, send button
- [ ] Project selector picker is visible (shows "General" + all project names)
- [ ] Conversation type picker is visible

### 9.2 — Send a General Message (No Project)
- Leave project selector on "General"
- Type: `Hello, I'd like help thinking through my projects`
- Press Send
- [ ] User message appears in the chat
- [ ] Loading indicator appears while waiting for AI response
- [ ] If API key valid: AI response appears as assistant message
- [ ] If API key invalid/missing: error message appears (this is expected)

### 9.3 — Send a Project-Scoped Message
- Select "Hospital Workflow System" from the project picker
- Type: `What's the current status of this project? What should I focus on?`
- Send
- [ ] AI response demonstrates awareness of the project's phases, milestones, and tasks
- [ ] Response includes specific task names or milestone names from the project

### 9.4 — Conversation History
- Send several messages back and forth
- [ ] All messages appear in chronological order
- [ ] User messages and assistant messages are visually distinct (different alignment or colour)
- [ ] Scrolling works if messages exceed the visible area

### 9.5 — Clear Chat
- Look for a clear/trash button
- Click it
- [ ] All messages are removed
- [ ] Chat returns to empty state

### 9.6 — Voice Input in Chat
- Look for a microphone button in the chat input area
- [ ] Microphone button is visible
- Click it
- [ ] Voice input interface appears (waveform, recording controls)
- (If microphone not available, just verify the button exists and the view toggles)

**Observations:**

---

## PART 10: AI Chat — Action Confirmation
**Tests phases:** 12.4-12.5 (action parsing, execution), 13.3 (confirmation UI)

> **Prerequisite:** Working API key + a project with tasks

### 10.1 — Request an Action
- Select "Hospital Workflow System" from the project picker
- Type: `Please mark the "Schedule interviews with department heads" task as completed`
- Send
- [ ] AI response includes proposed actions
- [ ] A confirmation bar/card appears below the response
- [ ] Confirmation shows what will be changed (e.g., "Complete task: Schedule interviews...")

### 10.2 — Review Individual Changes
- [ ] Each proposed change has a checkbox or toggle
- [ ] You can deselect individual changes
- [ ] Deselected changes are visually muted

### 10.3 — Apply Changes
- Accept the proposed changes
- Click "Apply" / "Confirm"
- [ ] Changes are applied to the database
- [ ] Go to the project detail and verify the task status actually changed

### 10.4 — Cancel Changes
- Ask the AI to make another change
- When confirmation appears, click "Cancel"
- [ ] No changes are applied
- [ ] Confirmation card disappears

### 10.5 — Multi-Action Request
- Ask: `Create a new task "Draft communication plan" under the first milestone, and add notes to "Prepare interview template" saying "Include questions about current pain points"`
- [ ] AI proposes multiple actions
- [ ] Each action listed separately in the confirmation
- [ ] You can selectively accept/reject individual actions

**Observations:**

---

## PART 11: AI Chat — Conversation Persistence
**Tests phases:** 13.5 (conversation persistence)

### 11.1 — Conversation Saves Automatically
- Have an active chat conversation with several messages
- Note the conversation content
- Quit the app (Cmd+Q)
- Relaunch the app
- Go to AI Chat
- [ ] If conversation history feature is visible: previously saved conversations appear
- [ ] You can resume a previous conversation

### 11.2 — Multiple Conversations
- Start a new conversation (clear chat)
- Send a different message
- [ ] This creates a new conversation
- [ ] Previous conversations remain accessible (if a conversation list is shown)

**Observations:**

---

## PART 12: Check-In, Onboarding, Retrospective Flows
**Tests phases:** 14 (check-in), 15 (onboarding), 17 (retrospective)

> These flows may be triggered from specific views or buttons rather than the sidebar.
> Look for trigger buttons within project detail views, focus board, or chat.

### 12.1 — Check-In Flow
- Look for a check-in prompt or button on the Focus Board or within a project detail
- [ ] Check-in entry point exists (describe where you found it)
- If accessible:
  - [ ] Check-in urgency badges appear on projects that haven't been checked in
  - [ ] Starting a check-in presents depth options: Quick Log vs Full Conversation
  - [ ] Quick Log: brief update → AI confirms → proposed changes
  - [ ] Full Conversation: deeper AI-guided conversation
  - [ ] Snooze option available (1 day / 3 days / 1 week)

### 12.2 — Onboarding Flow
- Navigate to the Quick Capture idea you created earlier ("Pharmacy Automation Research")
- Look for an "Onboard" or "Plan this project" button
- [ ] Onboarding entry point exists (describe where you found it)
- If accessible:
  - [ ] Brain dump step: you can add initial thoughts
  - [ ] AI Discovery step: AI asks clarifying questions
  - [ ] Structure Proposal step: AI proposes phases/milestones/tasks
  - [ ] You can review and accept/reject individual items
  - [ ] Completing onboarding transitions project from Idea to Queued

### 12.3 — Retrospective Flow
- This triggers when all milestones in a phase are completed
- If you have a phase with all milestones completed:
  - [ ] Retrospective prompt appears
  - [ ] AI guides reflection conversation
  - [ ] Notes are stored on the Phase record
- [ ] Snooze option available

### 12.4 — Return Briefing
- If a project has been unfocused for 14+ days and is then refocused:
  - [ ] Return briefing card appears in the chat
  - [ ] Briefing summarizes: where things stood, what was in progress, suggested next steps

**Observations:**

---

## PART 13: Analytics
**Tests phases:** 24 (estimate calibration & analytics)

### 13.1 — Access Analytics
- Look for an analytics view or section (may be within project detail, settings, or AI chat)
- [ ] Analytics entry point exists (describe where you found it)
- If accessible:
  - [ ] Estimate accuracy gauge/display is shown
  - [ ] If enough completed tasks: accuracy trend is visible
  - [ ] Effort type breakdown is shown
  - [ ] Frequently deferred tasks list is shown
  - [ ] **ADHD guardrails verified:** No streaks, no gamification, no red/green scoring
  - [ ] Observations are neutral/compassionate in tone

**Observations:**

---

## PART 14: AI Project Reviews
**Tests phases:** 25 (AI project reviews)

### 14.1 — Access Project Review
- Look for a "Review" button or conversation type in the AI Chat
- [ ] Project review entry point exists (describe where)
- If accessible:
  - [ ] Review shows cross-project patterns
  - [ ] Waiting item alerts are surfaced
  - [ ] AI provides analytical observations about focus board state
  - [ ] Suggestions for scope reduction or priority changes

**Observations:**

---

## PART 15: Adversarial Review Pipeline
**Tests phases:** 27 (adversarial review)

### 15.1 — Access Adversarial Review
- Look for an adversarial review entry point (may be in project detail or a separate section)
- [ ] Entry point exists (describe where)
- If accessible:
  - [ ] Step indicator shows the pipeline stages
  - [ ] Export step: documents can be exported for external review
  - [ ] Import step: critiques can be imported (paste or file)
  - [ ] Synthesis step: AI synthesizes critiques
  - [ ] Revision step: revised documents presented for approval

**Observations:**

---

## PART 16: Data Persistence & Integrity
**Tests phases:** 2 (persistence), 3 (export/import)

### 16.1 — Full Data Survives Restart
- Note the current state:
  - Number of projects: ___
  - One project's full hierarchy (phases, milestones, tasks, subtasks): ___
  - Document content: ___
  - Settings values: ___
- Quit the app (Cmd+Q)
- Relaunch
- [ ] All projects are present with correct data
- [ ] Project hierarchies are fully intact
- [ ] Documents are preserved with content
- [ ] Settings are preserved
- [ ] Focus Board state is preserved (which projects are focused)

### 16.2 — Cascading Delete
- Create a throwaway project "DELETE CASCADE TEST"
- Add a phase, milestone, task, and subtask
- Delete the entire project
- [ ] Project disappears
- Quit and relaunch
- [ ] No orphaned phases, milestones, tasks, or subtasks remain

**Observations:**

---

## PART 17: Design System Visual Audit
**Tests phases:** 4 (design system)

### 17.1 — Visual Consistency
- Browse through all views you've visited
- [ ] Cards have consistent styling throughout (PMCard)
- [ ] Empty states show centred icon + message pattern (PMEmptyState)
- [ ] Progress indicators use consistent styling
- [ ] Colour palette feels cohesive — no jarring mismatches
- [ ] SF Symbols used consistently
- [ ] Text sizing hierarchy is logical (titles larger, captions smaller)

### 17.2 — Task Cards
- View task cards on the Focus Board
- [ ] Task cards show: name, project name, milestone name
- [ ] Blocked tasks have a red blocked indicator
- [ ] High-priority tasks have priority badge
- [ ] Effort type badges display correctly
- [ ] Overdue/approaching deadline indicators work (if deadlines are set)

### 17.3 — Colour Tokens
- [ ] Focus slot colours are distinct for different projects
- [ ] Status colours: blocked = red, waiting = amber, completed = green
- [ ] Effort types have distinct icon/colour indicators

**Observations:**

---

## PART 18: Integration API (Backend Test)
**Tests phases:** 23 (integration API)

> This tests the HTTP server via curl commands. Requires the Integration API to be enabled in Settings.

### 18.1 — Enable the API
- Go to Settings → Integration API
- Toggle "Enable API" ON
- Note the port number (default 8420)
- Restart the app (the server starts on init)

### 18.2 — List Projects
```bash
curl -s http://localhost:8420/api/v1/projects | python3 -m json.tool
```
- [ ] Returns JSON array of all projects
- [ ] Project data includes id, name, categoryId, lifecycleState

### 18.3 — Get Single Project
```bash
# Replace PROJECT_ID with an actual UUID from the list above
curl -s http://localhost:8420/api/v1/projects/PROJECT_ID | python3 -m json.tool
```
- [ ] Returns JSON for a single project

### 18.4 — Authentication (if API key set)
- If you set an API key in Settings:
```bash
curl -s http://localhost:8420/api/v1/projects
```
- [ ] Returns 401 Unauthorized without the key
```bash
curl -s -H "Authorization: Bearer YOUR_KEY" http://localhost:8420/api/v1/projects
```
- [ ] Returns data with correct key

**Observations:**

---

## PART 19: iOS App (Separate Build)
**Tests phases:** 20 (iOS app), 20.3 (widget)

> Build and run the iOS target on a simulator or device.

### 19.1 — iOS Launch
- Build and run the iOS app target
- [ ] App launches without crash
- [ ] Tab bar visible at bottom with: Focus Board, Projects, AI Chat, Quick Capture (+), More

### 19.2 — Tab Navigation
- [ ] Tapping each tab switches the view
- [ ] Focus Board shows Kanban-style display
- [ ] Projects shows the project browser list
- [ ] AI Chat shows the chat interface
- [ ] Quick Capture shows the capture interface
- [ ] More shows Settings

### 19.3 — iOS Project Navigation
- Go to Projects tab
- Tap on a project
- [ ] Project detail view appears with navigation
- [ ] Back button returns to the project list

### 19.4 — iOS Quick Capture
- Tap the Quick Capture tab (+)
- [ ] Capture interface appears
- Type an idea and save
- [ ] New project created

### 19.5 — Data Sharing
- [ ] Projects created on macOS appear on iOS (if using same database/simulator)
- [ ] Projects created on iOS appear on macOS

**Observations:**

---

## PART 20: Edge Cases & Stress Tests

### 20.1 — Long Text
- Create a project with a very long name (100+ characters)
- [ ] Text truncates gracefully — no layout breakage

### 20.2 — Special Characters
- Create a project named: `Test "Quotes" & <Angles> — Dashes`
- [ ] Name saves and displays correctly
- [ ] No crashes or encoding issues

### 20.3 — Rapid Actions
- Quickly create and delete 5 projects in succession
- [ ] No crashes, no orphaned data
- [ ] App remains responsive

### 20.4 — Empty States
- Delete all projects
- [ ] Focus Board shows empty state
- [ ] All Projects shows empty state
- [ ] Cross-Project Roadmap shows empty state
- [ ] No crashes on empty data

**Observations:**

---

## Summary Scorecard

Fill in after completing all parts.

| Part | Feature Area | Result | Critical Issues |
|------|-------------|--------|-----------------|
| 1 | App Launch & Navigation | | |
| 2 | Settings | | |
| 3 | Project Browser — CRUD | | |
| 4 | Project Browser — Filter/Edit | | |
| 5 | Project Detail — Hierarchy | | |
| 6 | Focus Board | | |
| 7 | Quick Capture | | |
| 8 | Cross-Project Roadmap | | |
| 9 | AI Chat — Basic | | |
| 10 | AI Chat — Actions | | |
| 11 | AI Chat — Persistence | | |
| 12 | Check-In/Onboarding/Retro | | |
| 13 | Analytics | | |
| 14 | AI Project Reviews | | |
| 15 | Adversarial Review | | |
| 16 | Data Persistence | | |
| 17 | Design System Visual | | |
| 18 | Integration API | | |
| 19 | iOS App | | |
| 20 | Edge Cases | | |

### Overall Assessment
- Total PASS: ___
- Total FAIL: ___
- Total BLOCKED: ___
- Critical bugs found: ___
- Navigation gaps found: ___
- Missing UI entry points: ___

### Priority Fixes Needed
1.
2.
3.

### Notes

