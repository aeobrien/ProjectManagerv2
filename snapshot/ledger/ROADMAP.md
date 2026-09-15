# Roadmap

## Next Up
<!-- Highest priority incomplete tasks across all phases -->

| Task | Milestone | Phase | Status | Effort |
|------|-----------|-------|--------|--------|
| 5.1.1 Conversation history UI | 5.1 Pre-Testing Priority | 5: Polish & Gaps | Todo | Deep Focus |
| 5.1.2 Vision & technical brief templates | 5.1 Pre-Testing Priority | 5: Polish & Gaps | Todo | Deep Focus |
| 5.1.3 Adaptive onboarding first message | 5.1 Pre-Testing Priority | 5: Polish & Gaps | Todo | Deep Focus |
| 5.1.4 Document type filtering | 5.1 Pre-Testing Priority | 5: Polish & Gaps | Todo | Quick Win |
| 5.3.1 Define Dashboard sync protocol | 5.3 Dashboard Integration | 5: Polish & Gaps | Todo | Deep Focus |
| 6.1.1 Task description field | 6.1 Data Model Enhancements | 6: Future Features | Todo | Quick Win |

---

## Phase 1: Foundation
**Status:** Done
**Definition of Done:** Project scaffolding, domain models, and data layer complete with full test coverage.

### 1.1 — Project Scaffolding
**Status:** Done
**Priority:** High
**Definition of Done:** All 6 SPM packages created, logging system working, app builds and launches.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 1.1.1 | Xcode project + SPM package structure | Done | Administrative | XcodeGen with project.yml |
| 1.1.2 | Logging utility (os.Logger, 8 categories) | Done | Quick Win | PMUtilities |
| 1.1.3 | App entry point (placeholder SwiftUI) | Done | Quick Win | |

### 1.2 — Domain Models
**Status:** Done
**Priority:** High
**Definition of Done:** All entities, enums, protocols, computed properties, and FocusManager logic implemented and tested.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 1.2.1 | Core enumerations | Done | Deep Focus | LifecycleState, PhaseStatus, ItemStatus, Priority, EffortType, etc. |
| 1.2.2 | Entity types | Done | Deep Focus | Project, Phase, Milestone, Task, Subtask, Document, etc. |
| 1.2.3 | Computed properties | Done | Deep Focus | progressPercent, isStale, effectiveDeadline, etc. |
| 1.2.4 | Repository protocols | Done | Deep Focus | All CRUD protocols in PMDomain |
| 1.2.5 | Focus Board protocols and logic | Done | Deep Focus | Slot management, diversity, task visibility curation |
| 1.2.6 | Validation logic | Done | Deep Focus | State transitions, constraints |

### 1.3 — Data Persistence
**Status:** Done
**Priority:** High
**Definition of Done:** GRDB SQLite schema, all repository implementations, cascading deletes, filtered queries.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 1.3.1 | Database setup + schema | Done | Deep Focus | GRDB, migration infrastructure |
| 1.3.2 | Repository implementations | Done | Deep Focus | Full CRUD for all entities |
| 1.3.3 | Cascading operations | Done | Deep Focus | Delete cascades through hierarchy |
| 1.3.4 | Query operations | Done | Deep Focus | Filtered queries, search |
| 1.3.5 | Seed data | Done | Quick Win | Built-in categories |

### 1.4 — Data Export & Settings
**Status:** Done
**Priority:** Normal
**Definition of Done:** JSON export/import with merge, settings persistence.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 1.4.1 | JSON export (full + single project) | Done | Deep Focus | |
| 1.4.2 | JSON import with UUID merge | Done | Deep Focus | |
| 1.4.3 | Settings persistence | Done | Quick Win | UserDefaults-backed |

---

## Phase 2: Core UI
**Status:** Done
**Definition of Done:** Design system, project browser, hierarchy management, Focus Board, roadmap view, quick capture, and settings all functional.

### 2.1 — Design System
**Status:** Done
**Priority:** High
**Definition of Done:** All reusable UI components: colour tokens, task cards, health badges, progress bars, common layouts.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.1.1 | Colour tokens | Done | Creative | Slot colours, status colours, effort type colours |
| 2.1.2 | Task card component | Done | Deep Focus | Name, project, milestone, deadline, effort badge, status indicators |
| 2.1.3 | Health signal badges | Done | Deep Focus | Stale, blocked, overdue, deferred indicators |
| 2.1.4 | Progress components | Done | Quick Win | Progress bar, percentage label |
| 2.1.5 | Common layouts | Done | Quick Win | Section headers, empty states, dialogs |

### 2.2 — Project Browser
**Status:** Done
**Priority:** High
**Definition of Done:** Browse, filter, search, CRUD projects with all lifecycle transitions. macOS sidebar navigation.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.2.1 | ProjectBrowserViewModel | Done | Deep Focus | Filter, search, sort |
| 2.2.2 | ProjectBrowserView | Done | Deep Focus | List/grid, filter controls, search |
| 2.2.3 | Project CRUD UI | Done | Deep Focus | Create, edit, lifecycle transitions |
| 2.2.4 | App navigation shell | Done | Deep Focus | macOS sidebar |

### 2.3 — Hierarchy Management
**Status:** Done
**Priority:** High
**Definition of Done:** Full CRUD for phases, milestones, tasks, subtasks. Dependencies, blocked/waiting states.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.3.1 | ProjectDetailViewModel | Done | Deep Focus | Full hierarchy management |
| 2.3.2 | ProjectDetailView | Done | Deep Focus | Tabbed: overview, roadmap, documents, history |
| 2.3.3 | Phase management | Done | Deep Focus | CRUD, reorder, status transitions |
| 2.3.4 | Milestone management | Done | Deep Focus | CRUD, DoD, deadline, priority, dependencies |
| 2.3.5 | Task management | Done | Deep Focus | CRUD, DoD/timebox, estimate, effort type, blocked/waiting |
| 2.3.6 | Subtask management | Done | Quick Win | CRUD, toggle completion |

### 2.4 — Focus Board
**Status:** Done
**Priority:** High
**Definition of Done:** Kanban board with drag-and-drop, diversity enforcement, effort filtering, health signals.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.4.1 | FocusBoardViewModel | Done | Deep Focus | FocusManager wiring, task visibility curation |
| 2.4.2 | FocusBoardView | Done | Deep Focus | 3-column Kanban, project headers, health badges |
| 2.4.3 | Drag-and-drop | Done | Deep Focus | Move between columns, mark complete |
| 2.4.4 | Effort type filter bar | Done | Quick Win | Session-based filtering |
| 2.4.5 | Show all tasks toggle | Done | Quick Win | Per-project expand |
| 2.4.6 | Done column management | Done | Quick Win | Configurable retention |
| 2.4.7 | Task detail popover | Done | Quick Win | Full details + quick actions |

### 2.5 — Roadmap View
**Status:** Done
**Priority:** Normal
**Definition of Done:** Per-project vertical timeline with phases, milestones, tasks, dependency visualisation.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.5.1 | ProjectRoadmapViewModel | Done | Deep Focus | Layout with dependency connections |
| 2.5.2 | ProjectRoadmapView | Done | Deep Focus | Timeline, status, deadlines, progress |
| 2.5.3 | Roadmap integration | Done | Quick Win | Project Detail tab |

### 2.6 — Quick Capture & Settings
**Status:** Done
**Priority:** Normal
**Definition of Done:** Quick capture creates Idea-state stubs (text + voice). Full settings UI.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.6.1 | QuickCaptureViewModel | Done | Deep Focus | Text + voice input |
| 2.6.2 | QuickCaptureView | Done | Deep Focus | Lightweight sheet, <30s goal |
| 2.6.3 | Global access (macOS shortcut) | Done | Quick Win | |
| 2.6.4 | SettingsView | Done | Deep Focus | All configurable settings |

---

## Phase 3: AI & Voice
**Status:** Done
**Definition of Done:** Voice input, AI service, chat UI, check-in flow, onboarding, documents, and retrospective all functional.

### 3.1 — Voice Input
**Status:** Done
**Priority:** High
**Definition of Done:** Record and transcribe locally with WhisperKit. Waveform display, editable transcript, reusable component.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.1.1 | Audio recording (AVAudioEngine) | Done | Deep Focus | Permission handling |
| 3.1.2 | WhisperKit integration | Done | Deep Focus | Configurable model size |
| 3.1.3 | VoiceInputManager | Done | Deep Focus | State machine, waveform, result delivery |
| 3.1.4 | Voice input UI component | Done | Deep Focus | Reusable across Chat and QuickCapture |

### 3.2 — Voice Quick Capture Integration
**Status:** Done
**Priority:** Normal
**Definition of Done:** Quick Capture supports voice alongside text, transcript stored.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.2.1 | Voice Quick Capture | Done | Deep Focus | Record, transcribe, store |

### 3.3 — AI Core Service
**Status:** Done
**Priority:** High
**Definition of Done:** LLM client, prompt templates, context assembly, action parsing, bundled confirmation.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.3.1 | LLM API client | Done | Deep Focus | Anthropic + OpenAI |
| 3.3.2 | Prompt templates | Done | Deep Focus | All conversation types, behavioural contract |
| 3.3.3 | Context assembly | Done | Deep Focus | Token counting, priority truncation |
| 3.3.4 | Response parsing | Done | Deep Focus | All action block types |
| 3.3.5 | Action execution | Done | Deep Focus | Bundled confirmation model |

### 3.4 — Chat UI
**Status:** Done
**Priority:** High
**Definition of Done:** Full chat interface with voice/text, project selector, action confirmation, conversation persistence.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.4.1 | ChatViewModel | Done | Deep Focus | Conversation state, send/receive |
| 3.4.2 | ChatView | Done | Deep Focus | Message bubbles, voice/text input |
| 3.4.3 | Action confirmation UI | Done | Deep Focus | Bundled + individual review |
| 3.4.4 | Return briefing display | Done | Deep Focus | Formatted card at conversation top |
| 3.4.5 | Conversation persistence | Done | Deep Focus | Save/load conversations |

### 3.5 — Check-In Flow
**Status:** Done
**Priority:** High
**Definition of Done:** Quick log + full conversation modes, check-in prompting, avoidance detection.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.5.1 | CheckInFlowManager | Done | Deep Focus | Orchestration, deferred tracking |
| 3.5.2 | Check-in prompting | Done | Deep Focus | 3/7/14 day thresholds, snooze |
| 3.5.3 | Quick Log mode | Done | Deep Focus | Streamlined update flow |
| 3.5.4 | Full Conversation mode | Done | Deep Focus | Pattern surfacing, scope reduction |
| 3.5.5 | Avoidance detection | Done | Deep Focus | timesDeferred tracking |

### 3.6 — Project Onboarding
**Status:** Done
**Priority:** High
**Definition of Done:** Brain dump to structured project with complexity-scaled planning, document generation.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.6.1 | OnboardingFlowManager | Done | Deep Focus | Brain dump > discovery > structure > approval |
| 3.6.2 | Complexity assessment | Done | Deep Focus | Simple/medium/complex scaling |
| 3.6.3 | Structure proposal UI | Done | Deep Focus | Reviewable/editable cards |
| 3.6.4 | Document generation | Done | Deep Focus | Vision statement, technical brief |
| 3.6.5 | Idea > Queued transition | Done | Quick Win | |

### 3.7 — Document Management
**Status:** Done
**Priority:** Normal
**Definition of Done:** View/edit project documents with markdown, version tracking.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.7.1 | DocumentViewModel | Done | Deep Focus | Load, display, edit, versions |
| 3.7.2 | DocumentEditorView | Done | Deep Focus | Markdown editing with preview |
| 3.7.3 | Document versioning | Done | Quick Win | Increment on meaningful edits |

### 3.8 — Retrospective & Return Briefings
**Status:** Done
**Priority:** Normal
**Definition of Done:** Phase-end retrospective prompts, AI conversation, return briefings on dormant project refocus.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.8.1 | RetrospectiveFlowManager | Done | Deep Focus | Phase completion detection, prompt |
| 3.8.2 | Retrospective UI trigger | Done | Deep Focus | Snoozable prompt |
| 3.8.3 | Retrospective conversation | Done | Deep Focus | AI-guided, notes stored on Phase |
| 3.8.4 | Return briefing generation | Done | Deep Focus | Context card for dormant projects |

---

## Phase 4: Platform & Intelligence
**Status:** Done
**Definition of Done:** Knowledge base, CloudKit sync, iOS app, notifications, Life Planner export, Integration API, analytics, AI reviews, cross-project roadmap, and adversarial review all functional.

### 4.1 — Knowledge Base (RAG)
**Status:** Done
**Priority:** Normal
**Definition of Done:** On-device embeddings, local vector store, incremental indexing, retrieval integrated with context assembly.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 4.1.1 | Embedding pipeline | Done | Deep Focus | Apple NLContextualEmbedding |
| 4.1.2 | Vector store | Done | Deep Focus | Per-project isolation in GRDB |
| 4.1.3 | Incremental indexing | Done | Deep Focus | Background processing |
| 4.1.4 | Retrieval integration | Done | Deep Focus | Hooked into AI context assembly |

### 4.2 — CloudKit Sync
**Status:** Done
**Priority:** Normal
**Definition of Done:** All entities sync via CloudKit private DB, conflict resolution, offline support.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 4.2.1 | CloudKit schema | Done | Deep Focus | All entities mapped |
| 4.2.2 | Sync engine | Done | Deep Focus | Push/pull, triggers |
| 4.2.3 | Conflict resolution | Done | Deep Focus | Last-write-wins, document merge |
| 4.2.4 | Offline support | Done | Deep Focus | Queued sync on reconnect |

### 4.3 — iOS App
**Status:** Done
**Priority:** Normal
**Definition of Done:** Full-featured iOS app with tab nav, adaptive layouts, Quick Capture widget.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 4.3.1 | iOS app target | Done | Deep Focus | Tab-based navigation |
| 4.3.2 | Adaptive layouts | Done | Deep Focus | iPhone screen sizes |
| 4.3.3 | Quick Capture widget | Done | Deep Focus | Home screen widget |
| 4.3.4 | Mobile voice optimisation | Done | Deep Focus | Walking use case |

### 4.4 — iOS Notifications
**Status:** Done
**Priority:** Normal
**Definition of Done:** Local notifications for waiting items, deadlines, check-in reminders. Fatigue prevention.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 4.4.1 | Notification scheduling | Done | Deep Focus | All notification types |
| 4.4.2 | Fatigue prevention | Done | Deep Focus | Max 2/day, batching, quiet hours |
| 4.4.3 | Notification settings | Done | Quick Win | Per-type, quiet hours |

### 4.5 — Life Planner Export
**Status:** Done
**Priority:** Normal
**Definition of Done:** Export active tasks to MySQL/API, debounced triggers, status display.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 4.5.1 | Export payload construction | Done | Deep Focus | |
| 4.5.2 | MySQL/API export | Done | Deep Focus | Configurable backend |
| 4.5.3 | Export triggers | Done | Deep Focus | Debounced on data change |
| 4.5.4 | Export settings and status | Done | Quick Win | |

### 4.6 — External Integration API
**Status:** Done
**Priority:** Normal
**Definition of Done:** Local REST API (FlyingFox) with all endpoints, auth, audit logging.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 4.6.1 | Local HTTP server | Done | Deep Focus | FlyingFox, port 8420 |
| 4.6.2 | All endpoints | Done | Deep Focus | Per technical brief section 11.2 |
| 4.6.3 | Authentication | Done | Quick Win | Optional API key |
| 4.6.4 | Audit logging | Done | Quick Win | All write ops logged |
| 4.6.5 | Settings integration | Done | Quick Win | Enable/disable, port, key |

### 4.7 — Estimate Calibration & Analytics
**Status:** Done
**Priority:** Normal
**Definition of Done:** Estimate tracking, reflective analytics view with ADHD-safe guardrails, AI awareness.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 4.7.1 | Estimate tracking | Done | Deep Focus | Estimated vs actual, accuracy trends |
| 4.7.2 | Reflective analytics view | Done | Deep Focus | No streaks, no gamification, neutral |
| 4.7.3 | AI awareness | Done | Deep Focus | Calibration data in AI context |

### 4.8 — AI Project Reviews
**Status:** Done
**Priority:** Normal
**Definition of Done:** Cross-project pattern detection, stall surfacing, waiting accumulation awareness.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 4.8.1 | Review context assembly | Done | Deep Focus | Full Focus Board context |
| 4.8.2 | Review conversation flow | Done | Deep Focus | Cross-project analysis |
| 4.8.3 | Waiting item accumulation awareness | Done | Deep Focus | Overwhelm flagging |

### 4.9 — Cross-Project Roadmap
**Status:** Done
**Priority:** Normal
**Definition of Done:** Unified timeline of milestones from all focused projects, colour-coded.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 4.9.1 | CrossProjectRoadmapViewModel | Done | Deep Focus | Aggregate milestones |
| 4.9.2 | CrossProjectRoadmapView | Done | Deep Focus | Timeline, colour coding |

### 4.10 — Adversarial Review Pipeline
**Status:** Done
**Priority:** Normal
**Definition of Done:** Document export for review, critique import, AI synthesis, revised document approval.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 4.10.1 | Document export for review | Done | Deep Focus | |
| 4.10.2 | Pipeline integration | Done | Deep Focus | n8n/Shortcuts hook |
| 4.10.3 | Critique import and display | Done | Deep Focus | |
| 4.10.4 | Revised document approval | Done | Deep Focus | |

---

## Phase 5: Polish & Gaps
**Status:** In Progress
**Definition of Done:** All pre-testing items addressed, manual testing complete, Dashboard integration designed.

### 5.1 — Pre-Testing Priority
**Status:** Todo
**Priority:** High
**Definition of Done:** All items that directly affect manual test sections are resolved.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 5.1.1 | Conversation history UI | Todo | Deep Focus | Browse/resume saved conversations in ChatView |
| 5.1.2 | Vision & technical brief templates | Todo | Deep Focus | Structured prompt templates for onboarding |
| 5.1.3 | Adaptive onboarding first message | Todo | Deep Focus | Reflect understanding before asking questions |
| 5.1.4 | Document type filtering | Todo | Quick Win | Filter by type in Documents tab |

### 5.2 — Post-Testing Enhancements
**Status:** Todo
**Priority:** Normal
**Definition of Done:** Enhancement features implemented and tested.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 5.2.1 | Codebase/repo linking | Todo | Deep Focus | localPath + repoURL on Project |
| 5.2.2 | KB indexing of external files | Todo | Deep Focus | File walker > chunker > embedder |
| 5.2.3 | Migration system from previous app | Todo | Deep Focus | AI-assisted restructuring |
| 5.2.4 | Retrospective "View Notes" action | Todo | Quick Win | Wire context menu to sheet |
| 5.2.5 | Cross-project linking | Todo | Deep Focus | Many-to-many ProjectLink entity |
| 5.2.6 | Auto-start AI message on session start | Todo | Quick Win | UX: AI sends opening message automatically |
| 5.2.7 | Combine approval/revision with message input | Todo | Deep Focus | UX: inline message field in overlay |

### 5.3 — Dashboard Integration
**Status:** Todo
**Priority:** High
**Definition of Done:** Bidirectional sync between Project Manager and Claude Code /dashboard system designed and implemented.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 5.3.1 | Define Dashboard sync protocol | Todo | Deep Focus | Data mapping, direction, source of truth |
| 5.3.2 | Implement sync mechanism | Todo | Deep Focus | Via Integration API or file-based |
| 5.3.3 | Test bidirectional flow | Todo | Deep Focus | |

---

## Phase 6: Future Features
**Status:** Todo
**Definition of Done:** Deferred features implemented as prioritised.

### 6.1 — Data Model Enhancements
**Status:** Todo
**Priority:** Normal
**Definition of Done:** Additional fields and entities added to the data model.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 6.1.1 | Task description field | Todo | Quick Win | description: String? for longer-form detail |
| 6.1.2 | Per-project shopping list | Todo | Deep Focus | Procurement tracker with links, prices, status |

---

## Dependencies

| Item | Depends On | Status |
|------|-----------|--------|
| 5.1.1 Conversation history UI | 3.4 Chat UI (Done) | Met |
| 5.1.2 Vision/brief templates | 3.6 Onboarding (Done) | Met |
| 5.3.2 Dashboard sync implementation | 5.3.1 Define sync protocol | Unmet |
| 5.3.2 Dashboard sync implementation | 4.6 Integration API (Done) | Met |

---

## Reference

### Status Values
| Status | Meaning |
|--------|---------|
| Todo | Not yet started |
| In Progress | Actively being worked on |
| Blocked: [reason] | Cannot proceed — reason is one of: poorly-defined, too-large, missing-info, missing-resource, decision-required |
| Waiting | User's part done, waiting on external input |
| Done | Complete |
| Dropped | Deliberately abandoned |

### Effort Types
| Type | Description |
|------|-------------|
| Deep Focus | Sustained concentration, problem-solving, design work |
| Creative | Open-ended, generative, exploratory |
| Administrative | Organising, documenting, updating, filing |
| Communication | Discussions, reviews, feedback |
| Physical | Hands-on work, building, soldering |
| Quick Win | Small, low-effort, momentum-building |

### Priority
High / Normal / Low — milestones only. Tasks inherit from their milestone unless overridden.
