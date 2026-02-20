# Project Manager — Development Roadmap

---

## Module Dependency Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                        Feature Modules                           │
│  FocusBoardUI · ProjectBrowserUI · ProjectDetailUI · RoadmapUI  │
│  ChatUI · QuickCaptureUI · SettingsUI                           │
└──────────────────────────────┬──────────────────────────────────┘
                               │ depends on
┌──────────────────────────────┴──────────────────────────────────┐
│                       Service Modules                            │
│  AIService · KnowledgeBase · VoiceInput · CheckInFlow           │
│  OnboardingFlow · RetrospectiveFlow · NotificationManager       │
│  IntegrationAPI                                                  │
└──────────────────────────────┬──────────────────────────────────┘
                               │ depends on
┌──────────────────────────────┴──────────────────────────────────┐
│                        DesignSystem                              │
│  Reusable UI components, tokens, task cards, health badges,     │
│  colour system, common layouts                                   │
└──────────────────────────────┬──────────────────────────────────┘
                               │ depends on
┌──────────────────────────────┴──────────────────────────────────┐
│                         Data Layer                               │
│  SQLite persistence, repository implementations, CRUD,           │
│  SyncService (CloudKit), LifePlannerExport, DataExport           │
└──────────────────────────────┬──────────────────────────────────┘
                               │ depends on
┌──────────────────────────────┴──────────────────────────────────┐
│                          Domain                                  │
│  Entities, enums, protocols, pure business logic                 │
│  (FocusManager logic, computed properties, validation)           │
│  ZERO external dependencies                                      │
└──────────────────────────────┬──────────────────────────────────┘
                               │ depends on
┌──────────────────────────────┴──────────────────────────────────┐
│                         Utilities                                │
│  Logging, extensions, date helpers                               │
│  ZERO external dependencies                                      │
└─────────────────────────────────────────────────────────────────┘
```

### Package Structure

```
ProjectManager/
├── Packages/
│   ├── PMUtilities/          # Logging, extensions
│   ├── PMDomain/             # Entities, enums, protocols, business logic
│   ├── PMData/               # SQLite persistence, repositories
│   ├── PMDesignSystem/       # Reusable UI components, tokens
│   ├── PMServices/           # AI, voice, sync, export, integration API
│   └── PMFeatures/           # All feature modules (views + view models)
├── ProjectManager/           # App target (entry point, DI, navigation)
├── ProjectManagerTests/      # Integration tests
├── docs/
│   ├── manual-tests/
│   └── session-log.md
├── ROADMAP.md
├── WORKFLOW.md
└── CLAUDE.md
```

### Dependency Rules

1. **Utilities** depends on nothing (Foundation only)
2. **Domain** depends on Utilities only — pure types, no frameworks, no persistence
3. **Data** depends on Domain + Utilities — persistence implementations, repositories
4. **DesignSystem** depends on Domain + Utilities — SwiftUI components, needs entity types for display
5. **Services** depends on Data + Domain + Utilities — AI, voice, sync, needs DB access
6. **Features** depends on Services + DesignSystem + Data + Domain + Utilities — full vertical slices
7. **App target** depends on everything — wires it all together

Protocols live in **Domain**. Concrete implementations live in **Data** or **Services**. This enables testing with mocks at every level.

---

## Phase 0: Project Scaffolding

**Branch:** `phase-0/scaffolding`
**Package(s):** All (structure only), PMUtilities
**Depends on:** Nothing

### Sub-modules
- 0.1 **Project structure** — Xcode project, Swift Package Manager setup for all packages, directory structure, build configuration (macOS target only for now)
- 0.2 **Logging utility** — Unified logging system using `os.Logger` with subsystem/category scheme, severity levels, correlation IDs
- 0.3 **App entry point** — Minimal SwiftUI app that builds and runs, displays a placeholder screen

### Deliverables
- [ ] All packages created with correct dependency declarations
- [ ] PMUtilities has Logger with subsystem categories
- [ ] App builds and launches on macOS showing a placeholder view
- [ ] Smoke tests: project builds, app launches (2-3 tests)

### Key Decisions
- Xcode project vs XcodeGen vs SPM-only — decide based on current best practice for multi-package SwiftUI apps
- Minimum deployment target (macOS 14+ / iOS 17+ recommended for latest SwiftUI features)

---

## Phase 1: Domain Models

**Branch:** `phase-1/domain`
**Package(s):** PMDomain
**Depends on:** Phase 0

### Sub-modules
- 1.1 **Core enumerations** — LifecycleState, PhaseStatus, ItemStatus, Priority, EffortType, BlockedType, KanbanColumn, CheckInDepth, DocumentType, DependableType
- 1.2 **Entity types** — Project, Phase, Milestone, Task, Subtask, Document, Dependency, CheckInRecord, Category, Conversation, ChatMessage (as structs/classes with all fields from the technical brief)
- 1.3 **Computed properties** — progressPercent (per milestone/phase/project), isStale, effectiveDeadline, isApproachingDeadline, isOverdue, hasUnresolvedBlocks, daysSinceCheckIn, isFrequentlyDeferred, waitingItemsDueSoon
- 1.4 **Repository protocols** — ProjectRepository, PhaseRepository, MilestoneRepository, TaskRepository, SubtaskRepository, DocumentRepository, CheckInRepository, CategoryRepository, DependencyRepository, ConversationRepository
- 1.5 **Focus Board protocols and logic** — FocusManagerProtocol (slot management, diversity check, task visibility curation algorithm with user-configurable `maxVisibleTasksPerProject`, health signal computation). Pure business logic, no persistence.
- 1.6 **Validation logic** — Entity validation rules (e.g. focusSlotIndex range, lifecycle state transitions, category diversity constraints)

### Deliverables
- [ ] All entity types with full field definitions
- [ ] All enums with Codable conformance
- [ ] All computed properties implemented and tested
- [ ] All repository protocols defined
- [ ] FocusManager business logic with full test coverage
- [ ] Unit tests (40-60 expected)
- [ ] Test coverage: every enum case, every computed property, every validation rule, every FocusManager operation

### Key Decisions
- Whether entities are structs or classes (structs preferred for value semantics; classes if SwiftData requires them)
- Whether to use identifiable protocols from Foundation or custom

---

## Phase 2: Data Layer — Persistence

**Branch:** `phase-2/data-persistence`
**Package(s):** PMData
**Depends on:** Phase 1

### Sub-modules
- 2.1 **Database setup** — SQLite database creation, schema definition matching all Domain entities, migration infrastructure
- 2.2 **Repository implementations** — Concrete implementations of all repository protocols from Phase 1, full CRUD for every entity
- 2.3 **Cascading operations** — Deleting a project cascades to phases → milestones → tasks → subtasks. Deleting a phase cascades to milestones. Etc.
- 2.4 **Query operations** — Filtered queries: projects by lifecycle state, projects by category, tasks by status, tasks by effort type, search across project names/milestone names/task names/document content
- 2.5 **Seed data** — Built-in categories seeded on first launch (Software, Music, Hardware/Electronics, Creative, Life Admin, Research/Learning)

### Deliverables
- [ ] SQLite schema for all entities
- [ ] All repository protocol implementations
- [ ] Cascading delete behaviour
- [ ] Filtered query methods
- [ ] Category seed data
- [ ] Unit tests (50-70 expected): CRUD per entity, cascading deletes, filtered queries, edge cases (empty results, max limits)
- [ ] In-memory database option for testing

### Key Decisions
- **SwiftData vs GRDB** — This is the critical decision. Evaluate SwiftData's query capabilities against the needs here (filtered queries, search, computed aggregates). If SwiftData is insufficient, use GRDB. Document the decision and rationale.

---

## Phase 3: Data Layer — Export and Settings

**Branch:** `phase-3/data-export`
**Package(s):** PMData
**Depends on:** Phase 2

### Sub-modules
- 3.1 **JSON export** — Full data export: all projects with all child entities, documents, check-in records, categories, metadata (export date, app version). Single-project export.
- 3.2 **JSON import** — Import from exported file, merge by UUID (update existing, create new), handle version differences gracefully
- 3.3 **Settings persistence** — UserDefaults-backed settings store for all configurable values from the technical brief section 16.1. Observable for SwiftUI binding.

### Deliverables
- [ ] Export all data to JSON file
- [ ] Export single project to JSON file
- [ ] Import with UUID-based merge
- [ ] Settings store with all defaults
- [ ] Unit tests (20-30 expected): export/import round-trip, merge logic, settings defaults and overrides

### Key Decisions
- JSON encoding strategy: snake_case vs camelCase keys
- Whether settings use @AppStorage directly or a dedicated SettingsManager class

---

## Phase 4: Design System

**Branch:** `phase-4/design-system`
**Package(s):** PMDesignSystem
**Depends on:** Phase 1 (Domain types for display)

### Sub-modules
- 4.1 **Colour tokens** — Project slot colours (5 distinct colours for focus slots), status colours (blocked: red, waiting: amber, completed: green, stale: orange), effort type colours/icons
- 4.2 **Task card component** — Reusable task card showing: name, project name (colour-coded), milestone name, deadline, time estimate/timebox, effort type badge, status indicators (blocked, waiting, overdue, approaching deadline, frequently deferred)
- 4.3 **Health signal badges** — Stale badge, blocked count badge, overdue indicator, approaching deadline indicator, check-in overdue prompt, diversity override banner, frequently deferred indicator
- 4.4 **Progress components** — Progress bar (used for milestones, phases, projects), progress percentage label
- 4.5 **Common layouts** — Section headers, card containers, empty state views, confirmation dialogs

### Deliverables
- [ ] All colour tokens defined
- [ ] TaskCardView component with all variants
- [ ] All health signal badge components
- [ ] Progress bar and percentage components
- [ ] Common layout components
- [ ] SwiftUI previews for every component (in multiple states)
- [ ] Unit tests for any logic (colour selection, badge visibility conditions) (10-15 expected)

### Key Decisions
- Whether to use a formal design token system or simple SwiftUI extensions
- Icon set: SF Symbols or custom

---

## Phase 5: Feature — Project Browser

**Branch:** `phase-5/project-browser`
**Package(s):** PMFeatures, PMDesignSystem
**Depends on:** Phases 2, 3, 4

### Sub-modules
- 5.1 **ProjectBrowserViewModel** — Load projects, filter by lifecycle state (Focused/Queued/Ideas/Completed/Paused/Abandoned), filter by category, search (names, milestones, tasks, documents), sort options
- 5.2 **ProjectBrowserView** — List/grid of project cards, filter controls, search bar, navigation to project detail
- 5.3 **Project CRUD UI** — Create new project (name, category, definition of done), edit project metadata, lifecycle state transitions (with appropriate prompts: pause reason, abandonment reflection)
- 5.4 **App navigation shell** — macOS sidebar navigation structure with Focus Board, All Projects (with sub-filters), AI Chat, Settings sections

### Deliverables
- [ ] Project browser with all lifecycle state filters
- [ ] Category filtering
- [ ] Full-text search across projects/milestones/tasks/documents
- [ ] Create/edit/delete projects with all lifecycle transitions
- [ ] macOS sidebar navigation working
- [ ] Unit tests for ViewModel (15-20 expected)
- [ ] Manual test brief

### Key Decisions
- List vs grid default display
- Search implementation (SQLite FTS vs simple LIKE queries)

---

## Phase 6: Feature — Hierarchy Management

**Branch:** `phase-6/hierarchy`
**Package(s):** PMFeatures
**Depends on:** Phase 5

### Sub-modules
- 6.1 **ProjectDetailViewModel** — Load full project hierarchy, manage phases/milestones/tasks/subtasks, handle dependency creation
- 6.2 **ProjectDetailView** — Tabbed/sectioned view: overview, roadmap, documents, history. Header with project metadata.
- 6.3 **Phase management** — Create, edit, reorder, delete phases. Status transitions.
- 6.4 **Milestone management** — Create, edit, reorder, delete milestones within phases. Set definition of done, deadline, priority. Add dependencies (advisory — show warnings on unmet). Status transitions.
- 6.5 **Task management** — Create, edit, reorder, delete tasks within milestones. Set definition of done (or timebox), time estimate, effort type, priority. Add dependencies. Blocked/waiting state management with type, reason, and check-back date.
- 6.6 **Subtask management** — Create, edit, reorder, delete subtasks within tasks. Toggle completion.

### Deliverables
- [ ] Full CRUD for phases, milestones, tasks, subtasks within a project
- [ ] Dependency creation with advisory warnings
- [ ] Blocked and waiting state management
- [ ] Effort type and priority assignment
- [ ] Timebox as alternative to time estimates
- [ ] Unit tests for ViewModel (20-30 expected)
- [ ] Manual test brief

### Key Decisions
- Inline editing vs modal editing for hierarchy items
- How to present dependency warnings visually

---

## Phase 7: Feature — Focus Board

**Branch:** `phase-7/focus-board`
**Package(s):** PMFeatures, PMDesignSystem
**Depends on:** Phase 6

### Sub-modules
- 7.1 **FocusBoardViewModel** — Wire FocusManager logic to UI. Manage focus/unfocus operations, diversity enforcement with override, task visibility curation (user-configurable `maxVisibleTasksPerProject`, default 3, range 1-10), effort type filtering, health signal computation.
- 7.2 **FocusBoardView** — Three-column Kanban (ToDo, In Progress, Done). Task cards from DesignSystem. Project headers with progress bars and health badges. Diversity override banner.
- 7.3 **Drag-and-drop** — Move tasks between columns. Moving to Done marks complete (with timestamp). Moving from Done un-completes. macOS drag-and-drop support.
- 7.4 **Effort type filter bar** — Filter ToDo column by effort type. Session-based (resets on relaunch).
- 7.5 **"Show all tasks" toggle** — Per-project toggle to expand beyond curated set.
- 7.6 **Done column management** — Configurable retention (days/count). Older items accessible in project detail history.
- 7.7 **Task detail popover** — Tap a card to see full details + quick actions (complete, block, set waiting, start check-in placeholder).

### Deliverables
- [ ] Fully functional Kanban board with user-configurable task visibility (maxVisibleTasksPerProject)
- [ ] Focus/unfocus with diversity enforcement and override
- [ ] Drag-and-drop between columns
- [ ] Effort type filtering
- [ ] All health signals displayed
- [ ] Done column with configurable retention
- [ ] Unit tests for ViewModel (20-30 expected)
- [ ] Manual test brief

### Key Decisions
- SwiftUI drag-and-drop approach (transferable vs custom gesture)
- Whether Done column cleanup runs on a timer or on app launch

---

## Phase 8: Feature — Roadmap View

**Branch:** `phase-8/roadmap`
**Package(s):** PMFeatures, PMDesignSystem
**Depends on:** Phase 6

### Sub-modules
- 8.1 **ProjectRoadmapViewModel** — Load phases/milestones/tasks for a project, compute layout with dependency connections
- 8.2 **ProjectRoadmapView** — Vertical timeline: phases → milestones → tasks. Show name, status, deadline, progress, effort type, priority. Dependency arrows/lines with warnings on unmet.
- 8.3 **Roadmap integration** — Accessible from Project Detail View's Roadmap tab

### Deliverables
- [ ] Project-level roadmap with full hierarchy display
- [ ] Dependency visualisation with warning indicators
- [ ] Status, deadline, progress display per item
- [ ] Unit tests for ViewModel (10-15 expected)
- [ ] Manual test brief

### Key Decisions
- How to visually represent dependency arrows in SwiftUI (Canvas, overlay lines, or simplified indicators)

---

## Phase 9: Feature — Quick Capture & Settings

**Branch:** `phase-9/quick-capture-settings`
**Package(s):** PMFeatures
**Depends on:** Phase 5

### Sub-modules
- 9.1 **QuickCaptureViewModel** — Create Idea-state project stub from text input (voice comes in Phase 11). Store transcript, optional title, optional category.
- 9.2 **QuickCaptureView** — Lightweight sheet/popover. Text input field, optional title, optional category picker. Under 30 seconds goal.
- 9.3 **Global access (macOS)** — Keyboard shortcut to trigger Quick Capture from anywhere. Sidebar button.
- 9.4 **SettingsView** — All configurable settings from technical brief section 16.1, grouped by section. Backed by Settings store from Phase 3.

### Deliverables
- [ ] Quick Capture creates Idea-state project stubs (text-only for now, voice added in Phase 11)
- [ ] Global keyboard shortcut on macOS
- [ ] Full settings UI with all configuration options
- [ ] Unit tests (10-15 expected)
- [ ] Manual test brief

### Key Decisions
- macOS keyboard shortcut registration approach (NSEvent.addGlobalMonitorForEvents vs SwiftUI keyboard shortcuts)
- Quick Capture as sheet vs dedicated window

---

## Phase 10: Service — Voice Input

**Branch:** `phase-10/voice-input`
**Package(s):** PMServices
**Depends on:** Phase 0 (Utilities only)

### Sub-modules
- 10.1 **Audio recording** — AVAudioEngine/AVAudioRecorder setup. Record audio to WAV/PCM buffer. Permission handling.
- 10.2 **Whisper integration** — WhisperKit or whisper.cpp integration. Load model (small/medium configurable). Transcribe audio buffer to text.
- 10.3 **VoiceInputManager** — Observable class managing: recording state, waveform data (for UI), transcription state, result delivery. Clean start/stop/cancel API.
- 10.4 **Voice input UI component** — Microphone button, real-time waveform display during recording, processing indicator, editable transcript result. Reusable across ChatUI and QuickCapture.

### Deliverables
- [ ] Record audio and transcribe locally with Whisper
- [ ] Configurable model size (small/medium)
- [ ] Waveform visualisation during recording
- [ ] Editable transcript before sending
- [ ] Reusable VoiceInputView component
- [ ] Unit tests for VoiceInputManager state machine (10-15 expected)
- [ ] Manual test brief: record, transcribe, verify accuracy

### Key Decisions
- WhisperKit vs whisper.cpp — evaluate build complexity, model quality, Apple Silicon optimisation
- Whether to stream transcription or batch after recording stops

---

## Phase 11: Integrate Voice into Quick Capture

**Branch:** `phase-11/voice-quick-capture`
**Package(s):** PMFeatures
**Depends on:** Phases 9, 10

### Sub-modules
- 11.1 **Voice Quick Capture** — Add voice input option to Quick Capture flow. Record voice note, transcribe, store both audio transcript and text. User can edit transcript before saving.

### Deliverables
- [ ] Quick Capture supports voice input alongside text
- [ ] Transcript stored as quickCaptureTranscript on project
- [ ] Unit tests (5-8 expected)
- [ ] Manual test brief: voice capture while walking scenario

### Key Decisions
- Whether to store the raw audio file or only the transcript

---

## Phase 12: Service — AI Core

**Branch:** `phase-12/ai-service`
**Package(s):** PMServices
**Depends on:** Phases 2, 10

### Sub-modules
- 12.1 **LLM API client** — HTTP client for Anthropic and OpenAI APIs. Model-agnostic interface. API key management. Error handling, retry logic.
- 12.2 **Prompt templates** — System prompts for each conversation type (check-in quick log, check-in full, onboarding, review, retrospective, re-entry). Behavioural contract embedded in all prompts. Configurable role definitions.
- 12.3 **Context assembly** — Build context payloads per conversation type (section 5.4 of technical brief). Token counting/estimation. Priority-based truncation when context exceeds budget.
- 12.4 **Response parsing** — Parse structured action blocks from AI responses: COMPLETE_TASK, UPDATE_NOTES, FLAG_BLOCKED, SET_WAITING, CREATE_SUBTASK, UPDATE_DOCUMENT, INCREMENT_DEFERRED, SUGGEST_SCOPE_REDUCTION, CREATE_MILESTONE, CREATE_TASK, CREATE_DOCUMENT. Separate natural language from action blocks.
- 12.5 **Action execution** — Apply parsed actions to the database (via repositories). Bundled confirmation model: generate summary of proposed changes for user approval.

### Deliverables
- [ ] LLM API client supporting Anthropic and OpenAI
- [ ] All prompt templates with behavioural contract
- [ ] Context assembly for all conversation types
- [ ] Token budget management with priority truncation
- [ ] Action block parsing and execution
- [ ] Bundled confirmation model (data structures, not UI)
- [ ] Unit tests (30-40 expected): API client mocking, prompt construction, context assembly token counting, action parsing for every action type, bundled confirmation generation

### Key Decisions
- HTTP client: URLSession vs a lightweight library
- Token counting approach: exact (tokenizer) vs approximate (character-based estimation)
- Whether to use function calling / tool use or embedded text action blocks

---

## Phase 13: Feature — Chat UI

**Branch:** `phase-13/chat-ui`
**Package(s):** PMFeatures
**Depends on:** Phases 10, 12

### Sub-modules
- 13.1 **ChatViewModel** — Manage conversation state. Send messages (voice or text) to AIService. Receive responses. Present action confirmations. Handle conversation persistence.
- 13.2 **ChatView** — Message bubbles (user/assistant). Voice input button alongside text field. Project selector (specific project, General, New Project). Check-in depth selector (Quick Log / Full Conversation).
- 13.3 **Action confirmation UI** — Bundled summary card: "Apply All / Review Individually / Cancel". Individual review shows each proposed change with accept/reject. Trust level support (auto-apply minor if configured).
- 13.4 **Return briefing display** — When a dormant project is selected, show AI's return briefing as a formatted card at conversation top.
- 13.5 **Conversation persistence** — Save conversations to database. Load conversation history. Mark conversation types.

### Deliverables
- [ ] Full chat interface with voice and text input
- [ ] Project selector and depth selector
- [ ] Action confirmation (bundled and individual)
- [ ] Conversation persistence
- [ ] Return briefing display
- [ ] Unit tests for ViewModel (15-20 expected)
- [ ] Manual test brief: full conversation flow with AI

### Key Decisions
- Message rendering: attributed text vs SwiftUI views
- Streaming responses vs wait-for-complete

---

## Phase 14: Feature — Check-In Flow

**Branch:** `phase-14/check-in`
**Package(s):** PMFeatures, PMServices
**Depends on:** Phase 13

### Sub-modules
- 14.1 **CheckInFlowManager** — Orchestrate check-in: load project context, determine depth (quick log vs full), send to AI, parse response, present confirmations, apply updates, create CheckInRecord, increment timesDeferred for unaddressed visible tasks.
- 14.2 **Check-in prompting** — Compute check-in overdue status per project (3/7/14 day thresholds). Display gentle/moderate/prominent prompts on Focus Board. Snoozable with configurable durations (1 day, 3 days, 1 week).
- 14.3 **Quick Log mode** — Streamlined: user gives brief update, AI confirms and proposes bundled changes, apply all.
- 14.4 **Full Conversation mode** — AI probes, surfaces patterns, references timeboxes, suggests scope reduction. Deeper exchange before proposing changes.
- 14.5 **Avoidance detection** — Increment timesDeferred on visible/actionable tasks not mentioned. Flag frequently deferred tasks (configurable threshold). AI notices these in full conversations.

### Deliverables
- [ ] Both check-in modes working end-to-end
- [ ] Check-in prompting with escalation and snooze
- [ ] timesDeferred tracking and frequently deferred flagging
- [ ] CheckInRecord creation with proper depth tagging
- [ ] Unit tests (20-25 expected)
- [ ] Manual test brief: quick log and full conversation scenarios

### Key Decisions
- How to determine which tasks were "visible/actionable" for deferred counting (snapshot at check-in start?)

---

## Phase 15: Feature — Project Onboarding

**Branch:** `phase-15/onboarding`
**Package(s):** PMFeatures, PMServices
**Depends on:** Phase 13

### Sub-modules
- 15.1 **OnboardingFlowManager** — Orchestrate brain dump → discovery conversation → structure proposal → user approval → project creation/update. Reference Quick Capture transcript if originating from an Idea-state project.
- 15.2 **Complexity assessment** — AI assesses simple/medium/complex. Simple → direct to milestones. Medium → vision statement + milestones. Complex → vision + technical brief + full planning.
- 15.3 **Structure proposal UI** — Present AI-proposed phases, milestones, tasks (with DoD, time estimates, effort types, priorities) as reviewable/editable cards. User can accept, modify, or reject individual items.
- 15.4 **Document generation** — AI generates vision statement and/or technical brief during onboarding. Stored as Document entities.
- 15.5 **Idea → Queued transition** — When onboarding completes, move project from Idea to Queued state. Full hierarchy now exists.

### Deliverables
- [ ] Complete onboarding flow from brain dump to structured project
- [ ] Quick Capture → Onboarding path (reference original transcript)
- [ ] Complexity-scaled planning depth
- [ ] Reviewable structure proposals
- [ ] Document generation and storage
- [ ] Unit tests (15-20 expected)
- [ ] Manual test brief: onboard a simple and complex project

### Key Decisions
- Whether structure proposals are editable inline or via a separate editing step

---

## Phase 16: Feature — Document Management

**Branch:** `phase-16/documents`
**Package(s):** PMFeatures
**Depends on:** Phase 6

### Sub-modules
- 16.1 **DocumentViewModel** — Load, display, edit documents. Track versions.
- 16.2 **DocumentEditorView** — Markdown editing with preview (or chosen approach). View and edit vision statements and technical briefs within Project Detail.
- 16.3 **Document versioning** — Increment version on meaningful edits. Change tracking (at minimum: timestamp of each version).

### Deliverables
- [ ] View and edit project documents (vision statements, technical briefs)
- [ ] Markdown rendering
- [ ] Version tracking
- [ ] Unit tests (8-12 expected)
- [ ] Manual test brief

### Key Decisions
- Markdown editor approach: split pane (edit + preview), inline rendering, or plain text with syntax highlighting

---

## Phase 17: Feature — Retrospective Flow

**Branch:** `phase-17/retrospective`
**Package(s):** PMFeatures, PMServices
**Depends on:** Phase 13

### Sub-modules
- 17.1 **RetrospectiveFlowManager** — Detect when last milestone in a phase is completed. Prompt retrospective. Orchestrate AI conversation covering: what went well, what didn't, what was learned, estimate calibration, next phase assessment.
- 17.2 **Retrospective UI trigger** — Display prompt when phase completes. Snoozable but persistent until conducted or dismissed.
- 17.3 **Retrospective conversation** — AI system prompt for retrospective mode. Store notes on Phase record. Optionally propose revisions to next phase.
- 17.4 **Return briefing generation** — When a project is refocused after being dormant (14+ days configurable), AI generates a return briefing: where things stood, what was done, what was in progress/blocked, suggested next steps. Displayed as a card in chat.

### Deliverables
- [ ] Phase completion triggers retrospective prompt
- [ ] AI-guided retrospective conversation
- [ ] Notes stored on Phase record
- [ ] Return briefings on project refocus
- [ ] Unit tests (12-18 expected)
- [ ] Manual test brief

### Key Decisions
- Whether return briefings are generated on-demand or pre-computed

---

## Phase 18: Service — Knowledge Base (RAG)

**Branch:** `phase-18/knowledge-base`
**Package(s):** PMServices
**Depends on:** Phase 2

### Sub-modules
- 18.1 **Embedding pipeline** — Generate embeddings for text chunks using Apple NaturalLanguage framework or a lightweight on-device model. Chunk strategy for different content types (check-in transcripts, documents, task notes, conversations).
- 18.2 **Vector store** — Local vector storage alongside SQLite. Per-project indexing. Similarity search with configurable top-K results.
- 18.3 **Incremental indexing** — Index new content as it's created (check-ins, document edits, task notes). Background processing. No re-index of unchanged content.
- 18.4 **Retrieval integration** — Hook into AIService context assembly. Query knowledge base with current conversation context. Inject relevant historical chunks into AI context payload.

### Deliverables
- [ ] On-device embedding generation
- [ ] Local vector store with per-project isolation
- [ ] Incremental indexing on data changes
- [ ] Relevance retrieval integrated with context assembly
- [ ] Unit tests (15-20 expected): embedding generation, indexing, retrieval accuracy, per-project isolation
- [ ] Performance tests: retrieval latency benchmarks

### Key Decisions
- **Vector store implementation**: sqlite-vss, Apple NaturalLanguage + custom index, or FAISS. Evaluate embedding quality, retrieval speed, and storage footprint on iOS.
- Chunk size and overlap strategy
- When to trigger indexing (immediate vs batched)

---

## Phase 19: Sync — CloudKit

**Branch:** `phase-19/cloudkit`
**Package(s):** PMData (SyncService)
**Depends on:** Phase 2

### Sub-modules
- 19.1 **CloudKit schema** — Map all core entities to CloudKit record types. Handle relationships.
- 19.2 **Sync engine** — Push local changes to CloudKit. Pull remote changes. Trigger: on launch, on significant change, periodically.
- 19.3 **Conflict resolution** — Last-write-wins for most fields. Document content: surface both versions for manual merge if timestamps are very close.
- 19.4 **Offline support** — Full read/write offline. Queue changes for sync on reconnection.

### Deliverables
- [ ] All entities sync via CloudKit private database
- [ ] Conflict resolution strategy implemented
- [ ] Offline read/write with queued sync
- [ ] Unit tests (15-20 expected): record mapping, conflict scenarios, offline queue
- [ ] Integration test: create on device A → sync → verify on device B

### Key Decisions
- If SwiftData was chosen in Phase 2, leverage NSPersistentCloudKitContainer. If GRDB, build custom sync layer.
- How to handle the knowledge base vector store across devices (likely: rebuild per-device rather than sync)

---

## Phase 20: iOS App

**Branch:** `phase-20/ios-app`
**Package(s):** App target (iOS), PMFeatures
**Depends on:** Phases 7, 9, 13, 19

### Sub-modules
- 20.1 **iOS app target** — New target sharing all packages. Tab-based navigation: Focus Board, Projects, AI Chat, Quick Capture (+), More (Settings).
- 20.2 **Adaptive layouts** — Ensure all views work on iPhone screen sizes. Adjust Focus Board for narrower display (possibly vertical columns or horizontal scroll).
- 20.3 **Quick Capture widget** — iOS home screen widget for one-tap Quick Capture.
- 20.4 **Mobile voice optimisation** — Optimised voice input for walking use case. Background audio processing considerations.

### Deliverables
- [ ] Full-featured iOS app with tab navigation
- [ ] All features from macOS available on iOS
- [ ] Quick Capture widget
- [ ] Voice input optimised for mobile
- [ ] Manual test brief: core flows on iPhone

### Key Decisions
- iPad support (immediate or deferred)
- Widget complexity (simple launch vs inline capture)

---

## Phase 21: iOS Notifications

**Branch:** `phase-21/notifications`
**Package(s):** PMServices (NotificationManager)
**Depends on:** Phase 20

### Sub-modules
- 21.1 **Notification scheduling** — Schedule local notifications for: waiting items past check-back date, deadlines within 24h, check-in reminders (opt-in), phase completion.
- 21.2 **Fatigue prevention** — Max 2/day (configurable). Smart batching of multiple items. Respect quiet hours (default 9am-8pm). Snooze on all (1 day, 3 days, 1 week).
- 21.3 **Notification settings** — Per-type enable/disable. Quiet hours configuration. Max daily count.

### Deliverables
- [ ] All notification types working
- [ ] Fatigue prevention enforced
- [ ] Snooze functionality
- [ ] Settings integration
- [ ] Unit tests (10-15 expected)
- [ ] Manual test brief

### Key Decisions
- UNUserNotificationCenter scheduling strategy (recalculate on data change or periodic refresh)

---

## Phase 22: Service — Life Planner Export

**Branch:** `phase-22/life-planner-export`
**Package(s):** PMServices (LifePlannerExport)
**Depends on:** Phase 2

### Sub-modules
- 22.1 **Export payload** — Construct export data: active tasks from focused projects (name, DoD, adjusted estimate, deadline, milestone, project, category, status, dependencies, priority, effort type). Project summary metadata.
- 22.2 **MySQL export** — Direct MySQL connection via lightweight client library. Write to configured tables.
- 22.3 **API export** — HTTP POST JSON payload to configured endpoint. Alternative to MySQL.
- 22.4 **Export triggers** — On app launch, on focused project data change (debounced), manual trigger in Settings.
- 22.5 **Export settings and status** — Connection configuration. Sync frequency. Manual trigger. Status/logs display.

### Deliverables
- [ ] Export to MySQL or API endpoint (configurable)
- [ ] Debounced automatic export on data changes
- [ ] Manual export trigger
- [ ] Export status/logs
- [ ] Unit tests (15-20 expected): payload construction, data mapping, debounce logic
- [ ] Manual test brief

### Key Decisions
- MySQL client library for Swift (mysql-swift, or similar)
- Whether to support both MySQL and API simultaneously or as exclusive options

---

## Phase 23: Service — External Integration API

**Branch:** `phase-23/integration-api`
**Package(s):** PMServices (IntegrationAPI)
**Depends on:** Phase 2

### Sub-modules
- 23.1 **Local HTTP server** — Lightweight HTTP server running on localhost (configurable port, default 8420). Start/stop with app lifecycle.
- 23.2 **Endpoints** — All endpoints from technical brief section 11.2: GET projects, GET project detail, GET tasks, PATCH task, POST complete, POST notes, POST new task, POST issues, GET/PATCH documents.
- 23.3 **Authentication** — Optional API key (configurable in Settings).
- 23.4 **Audit logging** — All write operations logged for review.
- 23.5 **Settings integration** — Enable/disable, port configuration, API key management.

### Deliverables
- [ ] Local REST API with all endpoints
- [ ] Optional API key auth
- [ ] Write audit logging
- [ ] Settings UI integration
- [ ] Unit tests (15-20 expected): endpoint routing, auth, payload validation, concurrent access
- [ ] Manual test brief: curl commands to test each endpoint

### Key Decisions
- HTTP server library: Vapor (heavyweight), Swifter, or custom with NWListener
- Whether to support WebSocket in addition to REST for real-time updates

---

## Phase 24: Intelligence — Estimate Calibration & Analytics

**Branch:** `phase-24/analytics`
**Package(s):** PMFeatures, PMServices
**Depends on:** Phase 14 (check-in flow provides actual time data)

### Sub-modules
- 24.1 **Estimate tracking** — Track estimated vs actual time across completed tasks. Compute accuracy trends. Suggest pessimism multiplier adjustments.
- 24.2 **Reflective analytics view** — Project completion rates, average time per effort type, estimate accuracy trends. **Guardrails enforced**: no streaks, no gamification, no comparative metrics, no red/green scoring. Neutral observations only.
- 24.3 **AI awareness** — Feed estimate calibration data into AI context for project reviews and planning conversations.

### Deliverables
- [ ] Estimate accuracy tracking and trends
- [ ] Analytics view with guardrails
- [ ] AI integration for estimate-informed advice
- [ ] Unit tests (10-15 expected)
- [ ] Manual test brief

### Key Decisions
- Minimum data threshold before showing trends (avoid misleading stats from small samples)

---

## Phase 25: Intelligence — AI Project Reviews

**Branch:** `phase-25/ai-reviews`
**Package(s):** PMFeatures, PMServices
**Depends on:** Phase 14

### Sub-modules
- 25.1 **Review context assembly** — Full Focus Board context: all focused projects, progress, staleness, blocked counts, frequently deferred tasks, waiting items approaching check-back dates, queued/paused projects with reasons.
- 25.2 **Review conversation flow** — User-initiated review conversation. AI in full analytical mode: cross-project pattern detection, stall surfacing, scope reduction suggestions, Focus Board recommendations, paused project re-entry suggestions (including seasonal awareness).
- 25.3 **Waiting item accumulation awareness** — AI notices when many waiting items are resolving simultaneously and flags potential overwhelm.

### Deliverables
- [ ] Project review conversations with full analytical capability
- [ ] Cross-project pattern detection
- [ ] Waiting accumulation awareness
- [ ] Unit tests (10-15 expected)
- [ ] Manual test brief

### Key Decisions
- Whether to offer scheduled review reminders (weekly?) or purely on-demand

---

## Phase 26: Feature — Cross-Project Roadmap

**Branch:** `phase-26/cross-project-roadmap`
**Package(s):** PMFeatures
**Depends on:** Phase 8

### Sub-modules
- 26.1 **CrossProjectRoadmapViewModel** — Load milestones from all focused projects, sort by deadline, compute unified timeline.
- 26.2 **CrossProjectRoadmapView** — Unified timeline showing milestones from all focused projects, colour-coded by project. Upcoming deadlines prominently displayed.

### Deliverables
- [ ] Cross-project roadmap view
- [ ] Milestone timeline sorted by deadline
- [ ] Project colour coding
- [ ] Unit tests (8-10 expected)
- [ ] Manual test brief

### Key Decisions
- Whether this is a separate top-level view or a mode within the existing Roadmap view

---

## Phase 27: Intelligence — Adversarial Review Pipeline

**Branch:** `phase-27/adversarial-review`
**Package(s):** PMFeatures, PMServices
**Depends on:** Phase 15 (onboarding), Phase 16 (documents)

### Sub-modules
- 27.1 **Document export for review** — Export vision statement, technical brief, and brain dump transcript in a format suitable for external pipeline.
- 27.2 **Pipeline integration** — Hook for n8n/Shortcuts/scripts: export documents → trigger external review → import critiques → synthesise → present revised documents.
- 27.3 **Critique import and display** — Import external reviewer critiques. Display alongside original documents. AI synthesises overlapping concerns and divergent opinions.
- 27.4 **Revised document approval** — Present revised documents for user approval. On approval, update stored documents and optionally re-extract roadmap.

### Deliverables
- [ ] Document export for external review
- [ ] Critique import mechanism
- [ ] Synthesis conversation with AI
- [ ] Revised document approval flow
- [ ] Unit tests (10-12 expected)
- [ ] Manual test brief

### Key Decisions
- **Pipeline orchestration tool**: n8n, Shortcuts, custom script. Decide based on maintainability.
- Export/import format (JSON files, clipboard, API calls)

---

## Phase Summary

| Phase | Name | Packages | Key Dependency |
|-------|------|----------|----------------|
| 0 | Scaffolding | All (structure), Utilities | — |
| 1 | Domain Models | Domain | Phase 0 |
| 2 | Data Persistence | Data | Phase 1 |
| 3 | Data Export & Settings | Data | Phase 2 |
| 4 | Design System | DesignSystem | Phase 1 |
| 5 | Project Browser | Features | Phases 2, 3, 4 |
| 6 | Hierarchy Management | Features | Phase 5 |
| 7 | Focus Board | Features | Phase 6 |
| 8 | Roadmap View | Features | Phase 6 |
| 9 | Quick Capture & Settings | Features | Phase 5 |
| 10 | Voice Input | Services | Phase 0 |
| 11 | Voice Quick Capture | Features | Phases 9, 10 |
| 12 | AI Core | Services | Phases 2, 10 |
| 13 | Chat UI | Features | Phases 10, 12 |
| 14 | Check-In Flow | Features, Services | Phase 13 |
| 15 | Project Onboarding | Features, Services | Phase 13 |
| 16 | Document Management | Features | Phase 6 |
| 17 | Retrospective & Return Briefings | Features, Services | Phase 13 |
| 18 | Knowledge Base (RAG) | Services | Phase 2 |
| 19 | CloudKit Sync | Data | Phase 2 |
| 20 | iOS App | App, Features | Phases 7, 9, 13, 19 |
| 21 | iOS Notifications | Services | Phase 20 |
| 22 | Life Planner Export | Services | Phase 2 |
| 23 | Integration API | Services | Phase 2 |
| 24 | Estimate Calibration & Analytics | Features, Services | Phase 14 |
| 25 | AI Project Reviews | Features, Services | Phase 14 |
| 26 | Cross-Project Roadmap | Features | Phase 8 |
| 27 | Adversarial Review Pipeline | Features, Services | Phases 15, 16 |

---

## Parallelisation Opportunities

Several phases can be developed in parallel once their dependencies are met:

- **After Phase 2**: Phases 18, 19, 22, 23 can all start (they only need Data layer)
- **After Phase 5**: Phases 6 and 9 can run in parallel
- **After Phase 6**: Phases 7, 8, and 16 can run in parallel
- **After Phase 10**: Phase 11 can start (once Phase 9 is also done)
- **After Phase 13**: Phases 14, 15, and 17 can run in parallel

In practice, a single developer will work sequentially through the main path (0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 9 → 10 → 11 → 12 → 13 → 14 → 15), deferring parallel-eligible phases to when they're most useful.
