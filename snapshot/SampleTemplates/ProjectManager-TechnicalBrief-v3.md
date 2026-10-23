# Project Manager

**Technical Brief**
*Revised after adversarial review*

---

## 1. Overview

This document translates the Project Manager Vision Statement into a technical specification. It describes the architecture, data model, AI integration, user interface, and system behaviours required to build the application.

The Project Manager is a native macOS/iOS application (SwiftUI) for a single user to capture, plan, structure, and track personal projects. It features an integrated AI collaborator accessible via voice or text, a Focus Board enforcing work-in-progress limits and category diversity, a four-tier project hierarchy (Phase → Milestone → Task → Subtask), and sync with the Unified Work Guidance System (Life Planner) via an external database.

### Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Platform | SwiftUI (macOS + iOS) | Native performance, shared codebase, Apple ecosystem integration |
| Local database | SQLite (via SwiftData or GRDB) | Robust, embedded, no server dependency, well-supported on Apple platforms |
| Cross-device sync | CloudKit (private database) | Native Apple sync, single-user, no server to maintain, handles conflict resolution |
| AI integration | Built-in chat via LLM APIs | Keeps everything in one app, allows full project context to be passed with each request |
| Voice input | Local Whisper transcription | Privacy, offline capability, no per-request transcription cost |
| Life Planner sync | Periodic export to external MySQL database | Decoupled from core architecture, Life Planner runs on separate hardware |
| External tool integration | Local REST API | Allows coding tools (Claude Code, etc.) to push updates directly |
| AI context depth | Local RAG (vector store) | Enables deep project knowledge beyond context window limits, all on-device |

---

## 2. Architecture

### 2.1 High-Level Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                       SwiftUI Layer                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ ┌─────┐ │
│  │  Focus   │ │ Project  │ │   AI     │ │Roadmap │ │Quick│ │
│  │  Board   │ │ Browser  │ │   Chat   │ │  View  │ │Capt.│ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘ └──┬──┘ │
│       │             │            │            │         │    │
│  ┌────┴─────────────┴────────────┴────────────┴─────────┴──┐ │
│  │                  View Model Layer                        │ │
│  │     (ObservableObject classes, state management)         │ │
│  └────┬─────────────┬────────────┬──────────────┬──────────┘ │
│       │             │            │              │            │
│  ┌────┴─────┐ ┌─────┴─────┐ ┌───┴────────┐ ┌──┴─────────┐  │
│  │  Data    │ │    AI     │ │  Sync      │ │ Integration│  │
│  │  Layer   │ │  Service  │ │  Services  │ │ API        │  │
│  └────┬─────┘ └──┬────┬──┘ └───┬────┬───┘ └──┬─────────┘  │
│       │          │    │         │    │         │            │
│  ┌────┴───┐ ┌────┴──┐ ┌┴──────┐┌┴──┐ ┌┴──────┐│            │
│  │ SQLite │ │LLM API│ │Know-  ││CK │ │MySQL  ││            │
│  │ (local)│ │+Whispr│ │ledge  ││   │ │(exprt)││            │
│  └────────┘ └───────┘ │Base   │└───┘ └───────┘│            │
│                        │(RAG)  │               │            │
│                        └───────┘               │            │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Module Breakdown

The application is organised into the following modules, each independently developable and testable:

| Module | Responsibility |
|--------|---------------|
| **DataModel** | SQLite schema, entity definitions, CRUD operations, queries |
| **FocusManager** | Focus Board logic, diversity enforcement, staleness detection, slot management, task visibility curation |
| **AIService** | LLM API communication, prompt construction, context assembly, response parsing, behavioural contract enforcement |
| **KnowledgeBase** | Local vector store (RAG), embedding generation, incremental indexing, relevance retrieval for context assembly |
| **VoiceInput** | Local Whisper transcription, audio recording, speech-to-text pipeline |
| **SyncService** | CloudKit sync between macOS/iOS devices |
| **LifePlannerExport** | Periodic export of active tasks to external MySQL database |
| **IntegrationAPI** | Local REST API for external tool updates (Claude Code, etc.) |
| **QuickCapture** | Lightweight idea capture (voice/text → project stub), accessible globally |
| **OnboardingFlow** | Brain dump capture, AI-guided project planning conversation, document generation |
| **CheckInFlow** | Voice check-in conversation (quick log and full modes), progress parsing, documentation updates |
| **RetrospectiveFlow** | Phase-end retrospective conversation, lessons captured, next-phase reassessment |
| **ProjectBrowser** | Browsing, searching, filtering the full project pool |
| **FocusBoardUI** | Kanban board view, drag-and-drop, task cards, effort type filtering |
| **RoadmapUI** | Chronological phase/milestone/task display |
| **ProjectDetailUI** | Individual project view, documentation viewer/editor, milestone/task management, completed task history |
| **ChatUI** | Conversational AI interface, message history, voice input toggle, action confirmation |
| **NotificationManager** | iOS notification scheduling, snooze management, fatigue prevention |
| **DataExport** | Full project data export in portable JSON format |
| **SettingsManager** | User preferences, diversity limits, pessimism multiplier, category management, AI behaviour settings |

---

## 3. Data Model

### 3.1 Entity Relationship Diagram

```
Project (1) ──── (∞) Phase (1) ──── (∞) Milestone (1) ──── (∞) Task (1) ──── (∞) Subtask
   │                    │                   │                     │
   │                    │                   │                     │
   ├── categoryId: FK   ├── retrospective   ├── dependencies      ├── dependencies
   ├── lifecycleState   │   Notes           ├── waitingState      ├── blockedState
   ├── pauseReason      │                   ├── deadline          ├── waitingState
   ├── documents []     │                   └── priority          ├── timeEstimate
   └── focusSlot: Int?  │                                        ├── effortType
                        │                                        ├── timesDeferred
                        │                                        └── deadline
```

### 3.2 Core Entities

#### Project

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| name | String | Project title |
| categoryId | UUID | Foreign key → Category |
| lifecycleState | LifecycleState (enum) | Focused, Queued, Idea, Completed, Paused, Abandoned |
| focusSlotIndex | Int? | Position on Focus Board (0-4), nil if not focused |
| pauseReason | String? | Why the project was paused (seasonal, blocked, deprioritised, etc.) |
| abandonmentReflection | String? | Optional reflection notes when abandoning |
| createdAt | Date | When the project was created |
| updatedAt | Date | Last modification timestamp |
| lastWorkedOn | Date? | Last time a task was completed (for staleness detection) |
| definitionOfDone | String? | What completion looks like (optional for Idea-state projects) |
| notes | String? | Freeform notes |
| quickCaptureTranscript | String? | Original voice note from Quick Capture, if applicable |

#### Phase

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| projectId | UUID | Foreign key → Project |
| name | String | Phase title (e.g. "Phase 1: Core Infrastructure") |
| sortOrder | Int | Ordering within the project |
| status | PhaseStatus (enum) | NotStarted, InProgress, Completed |
| definitionOfDone | String | What completion of this phase looks like |
| retrospectiveNotes | String? | Filled in at phase completion via retrospective flow |
| retrospectiveCompletedAt | Date? | When the retrospective was conducted |

#### Milestone

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| phaseId | UUID | Foreign key → Phase |
| name | String | Milestone title |
| sortOrder | Int | Ordering within the phase |
| status | ItemStatus (enum) | NotStarted, InProgress, Blocked, Waiting, Completed |
| definitionOfDone | String | Clear binary end state |
| deadline | Date? | Target completion date |
| priority | Priority (enum) | High, Normal, Low (default: Normal) |
| waitingReason | String? | If status is Waiting, what we're waiting for |
| waitingCheckBackDate | Date? | When to resurface if still waiting |
| notes | String? | Freeform notes |

#### Task

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| milestoneId | UUID | Foreign key → Milestone |
| name | String | Task description |
| sortOrder | Int | Ordering within the milestone |
| status | ItemStatus (enum) | NotStarted, InProgress, Blocked, Waiting, Completed |
| definitionOfDone | String | Clear binary completion statement (or timebox description for creative/exploratory tasks) |
| isTimeboxed | Bool | Whether this task uses a timebox instead of a traditional DoD |
| timeEstimateMinutes | Int? | User's estimate of duration |
| adjustedEstimateMinutes | Int? | Estimate × pessimism multiplier |
| actualMinutes | Int? | Recorded actual time (for calibration) |
| timeboxMinutes | Int? | Max time willing to spend (alternative to estimate) |
| deadline | Date? | Explicit deadline, or inherited from milestone |
| priority | Priority (enum) | High, Normal, Low (default: Normal) |
| effortType | EffortType (enum)? | DeepFocus, Creative, Administrative, Communication, Physical, QuickWin |
| blockedType | BlockedType? (enum) | PoorlyDefined, TooLarge, MissingInfo, MissingResource, DecisionRequired |
| blockedReason | String? | Details of the block |
| waitingReason | String? | If Waiting, what for |
| waitingCheckBackDate | Date? | When to resurface |
| completedAt | Date? | When the task was marked done |
| timesDeferred | Int | Counter: how many check-ins this task has appeared without progress (default 0). Used for avoidance pattern detection. |
| notes | String? | Freeform notes, updated by AI during check-ins |
| kanbanColumn | KanbanColumn (enum) | ToDo, InProgress, Done (for Focus Board display) |

#### Subtask

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| taskId | UUID | Foreign key → Task |
| name | String | Subtask description |
| sortOrder | Int | Ordering within the task |
| isCompleted | Bool | Binary completion state |
| definitionOfDone | String | Clear binary completion statement |

#### Document

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| projectId | UUID | Foreign key → Project |
| type | DocumentType (enum) | VisionStatement, TechnicalBrief, Other(String) |
| title | String | Document title |
| content | String | Full text content (Markdown) |
| createdAt | Date | Creation timestamp |
| updatedAt | Date | Last modification timestamp |
| version | Int | Incremented on each meaningful edit, for change tracking |

#### Dependency

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| sourceType | DependableType (enum) | Milestone, Task |
| sourceId | UUID | The item that has the dependency |
| targetType | DependableType (enum) | Milestone, Task |
| targetId | UUID | The item that must be completed first |

*Dependencies are **advisory, not enforced**. The system displays a warning when a task/milestone is started while its dependencies are incomplete, but does not prevent the user from proceeding. This supports creative workarounds and the "action over motion" principle.*

#### CheckInRecord

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| projectId | UUID | Foreign key → Project |
| timestamp | Date | When the check-in occurred |
| depth | CheckInDepth (enum) | QuickLog, FullConversation |
| transcript | String | Full voice transcript of the check-in |
| aiSummary | String | AI-generated summary of progress and changes |
| tasksCompleted | [UUID] | Task IDs marked complete during this check-in |
| issuesFlagged | [String] | New issues or blockers identified |

#### Category

Stored as a reference table to support user-extensible categories.

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| name | String | Category name |
| isBuiltIn | Bool | Whether this is a system-default category |
| sortOrder | Int | Display ordering |

Built-in categories (seeded on first launch): Software, Music, Hardware / Electronics, Creative, Life Admin, Research / Learning.

### 3.3 Enumerations

```swift
enum LifecycleState: String, Codable {
    case focused     // On the Focus Board
    case queued      // Planned, structured, ready for a slot
    case idea        // Captured (possibly via Quick Capture) but not yet planned
    case completed   // All work done (or current work cycle done for ongoing projects)
    case paused      // Temporarily shelved with a recorded reason
    case abandoned   // Honestly shelved with optional reflection
}

enum PhaseStatus: String, Codable {
    case notStarted
    case inProgress
    case completed
}

enum ItemStatus: String, Codable {
    case notStarted
    case inProgress
    case blocked
    case waiting
    case completed
}

enum Priority: String, Codable {
    case high
    case normal
    case low
}

enum EffortType: String, Codable {
    case deepFocus       // Sustained concentration, problem-solving, coding, writing
    case creative        // Open-ended, generative, exploratory
    case administrative  // Emails, forms, organising, scheduling
    case communication   // Phone calls, messages, reaching out
    case physical        // Hands-on work, building, cleaning
    case quickWin        // Small, low-effort, momentum tasks
}

enum BlockedType: String, Codable {
    case poorlyDefined
    case tooLarge
    case missingInfo
    case missingResource
    case decisionRequired
}

enum KanbanColumn: String, Codable {
    case toDo
    case inProgress
    case done
}

enum CheckInDepth: String, Codable {
    case quickLog
    case fullConversation
}

enum DocumentType: String, Codable {
    case visionStatement
    case technicalBrief
    case other
}
```

### 3.4 Derived / Computed Properties

These are not stored but calculated from the data:

| Property | Scope | Calculation |
|----------|-------|-------------|
| progressPercent | Milestone | completedTasks.count / totalTasks.count |
| progressPercent | Phase | completedMilestones.count / totalMilestones.count (or weighted by task count) |
| progressPercent | Project | weighted average across phases |
| isStale | Project | lastWorkedOn > 7 days ago (configurable) |
| effectiveDeadline | Task | task.deadline ?? milestone.deadline |
| isApproachingDeadline | Task/Milestone | effectiveDeadline within 3 days (configurable) |
| hasUnresolvedBlocks | Project | any descendant task with status == .blocked |
| daysSinceCheckIn | Project | now - lastCheckIn.timestamp |
| estimateAccuracy | Historical | average(actualMinutes / adjustedEstimateMinutes) across completed tasks |
| isFrequentlyDeferred | Task | timesDeferred >= 3 (configurable threshold) |
| waitingItemsDueSoon | Project | count of waiting tasks where checkBackDate <= today + 3 days |

---

## 4. Focus Board Logic

### 4.1 Slot Management

The Focus Board has a configurable maximum number of slots (default: 5). Each slot holds one focused project.

```
FocusManager:
  - maxSlots: Int (default 5, configurable in Settings)
  - maxPerCategory: Int (default 2, configurable in Settings)
  - maxVisibleTasksPerProject: Int (default 3, configurable in Settings)
```

#### Focusing a Project

When the user requests to focus a project:

1. **Check slot availability.** If all slots are occupied → reject with message: "Focus Board is full. Unfocus a project first, or swap."
2. **Check category diversity.** Count focused projects with the same category. If count >= maxPerCategory → warn: "You already have {count} {category} projects focused. Which would you like to swap out?" Offer an explicit **override** button: "Focus anyway." If overridden, display a persistent (but non-blocking) diversity warning on the Focus Board.
3. **Assign slot.** Place the project in the lowest available slot index. Set lifecycleState = .focused.
4. **Generate return briefing** (if applicable). If the project was last worked on more than 14 days ago (configurable), the AI generates a concise return briefing summarising where the project stood, what was completed, what was in progress or blocked, and what the suggested next steps are. This is displayed as a one-time card on the Focus Board or in the chat.
5. **Populate Kanban.** Tasks from the project's current phase are eligible for the Kanban view, subject to visibility limits (see below).

#### Unfocusing a Project

1. Set lifecycleState = .queued (or .paused if the user provides a reason).
2. Clear focusSlotIndex.
3. Tasks retain their status (InProgress tasks are not reset — they'll reappear when refocused).
4. If the project has no incomplete tasks, prompt: complete or pause?

### 4.2 Task Visibility and Curation

The Focus Board's ToDo column shows a **limited, curated set** of tasks, not every task from every focused project. This prevents overwhelm.

**Selection algorithm** (per project, selecting up to `maxVisibleTasksPerProject` tasks):

1. Filter: status != .completed, status != .blocked, status != .waiting
2. Prefer: tasks with no unmet dependencies (warn but don't hide dependent tasks entirely — mark them visually as "dependency pending")
3. Sort: priority (high first) → deadline (soonest first) → sortOrder
4. Take top N (default 3)

**Total visible in ToDo**: maxVisibleTasksPerProject × number of focused projects (default: 15 max). This is the cognitive ceiling for the daily view.

**Filtering**: The user can additionally filter the ToDo column by effort type (e.g. show only QuickWin and Physical tasks on a low-energy day). This filter is session-based and resets on app relaunch.

**"Show all" toggle**: A toggle to temporarily show all eligible tasks from a specific project, for when the user needs the full picture. This expands that project's tasks only; other projects remain curated.

### 4.3 Health Signals

Calculated and displayed on the Focus Board:

| Signal | Condition | Display |
|--------|-----------|---------|
| **Stale** | No task completed in 7+ days | Clock icon on project header |
| **All tasks done** | Zero incomplete tasks in current phase | Prompt: "All tasks complete. Add more, complete, or swap?" |
| **Overdue** | Task past its deadline | Red indicator on task card |
| **Approaching deadline** | Task deadline within 3 days | Amber indicator on task card |
| **Blocked tasks** | Task(s) in blocked state | Badge on project header with count |
| **Waiting items due** | Waiting task(s) past check-back date | "Check in on waiting items" prompt |
| **Check-in overdue** | No check-in in 7+ days (configurable) | Prompt in project header (snoozable) |
| **Diversity override** | Category limit explicitly overridden | Persistent info banner at top |
| **Frequently deferred task** | Task with timesDeferred >= 3 | Subtle indicator on task card |

Standard UI colour conventions apply: red for overdue/urgent, amber for approaching deadlines, blue/grey for informational signals.

### 4.4 Kanban Board Behaviour

The Focus Board displays a single unified Kanban across all focused projects:

* **ToDo column**: Curated tasks (see 4.2), sorted by project slot colour grouping
* **In Progress column**: Tasks the user has moved here (manually, via drag-and-drop). No limit, but the AI may gently note during reviews if many tasks are simultaneously in progress.
* **Done column**: Recently completed tasks (configurable retention: default last 7 days or last 20 items, whichever is smaller), sorted by completion date descending. Older completed tasks move to the project's completed task history (accessible from Project Detail View). The Done column exists for visible progress and momentum — it should feel rewarding.

Each task card shows: task name, parent project name (colour-coded by slot), milestone name, deadline (if set), time estimate or timebox, effort type badge, and any status indicators.

Drag-and-drop moves tasks between columns. Moving to Done marks the task as completed (with completedAt timestamp). Moving from Done back to InProgress or ToDo un-completes it.

---

## 5. AI Integration

### 5.1 Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   ChatUI     │────▶│  AIService   │────▶│   LLM API    │
│  (SwiftUI)   │     │  (manages    │     │  (Anthropic / │
│              │◀────│   context,   │◀────│   OpenAI)    │
│  + VoiceInput│     │   prompts,   │     └──────────────┘
└──────────────┘     │   behaviour) │
                     └──────┬───────┘
                      ┌─────┴──────┐
                      │ ProjectData │
                      │  (context   │
                      │  assembly)  │
                      └────────────┘
```

### 5.2 AI Behavioural Contract

The AI's behaviour is governed by explicit rules that protect the vision's emotional safety principles. These rules are embedded in every system prompt.

**Tone rules:**

* Conversational, warm, and collaborative — like a thoughtful colleague
* Never uses performance language ("you should be further along," "you're behind")
* Never uses comparative phrasing ("most people would have..." "you usually...")
* Avoids "should" when discussing the user's work habits
* Avoids normative productivity framing
* Treats all progress as legitimate — a 5-minute check-in is not "less than" a 2-hour session
* When surfacing patterns (avoidance, stalls), frames them as observations with curiosity, not as problems to fix: "I've noticed X — what's going on there?" not "You keep failing to do X"

**Intervention rules:**

* During **quick log** check-ins: Accept updates, confirm changes, and move on. No analysis, no pattern surfacing, no probing. Match the user's brevity.
* During **full conversation** check-ins: May probe, suggest decomposition, surface patterns, and ask harder questions — but only with the user's engagement. If the user deflects, don't push.
* During **project reviews**: Full analytical mode. This is where pattern detection, avoidance surfacing, strategic questions, and Focus Board recommendations belong.
* During **onboarding**: Challenge network mode. Probe assumptions, reveal hidden complexity, question feasibility — but always collaboratively.
* **Never** surface avoidance patterns or stall observations unprompted in quick logs or brief interactions.

**Forbidden behaviours:**

* Never compare the user's performance across projects or time periods
* Never use streak language ("you were doing so well until...")
* Never imply moral judgement about productivity levels
* Never refuse to accept a quick log because "we should talk more about this"
* Never generate unsolicited motivational language

**Scope reduction capability:**

* When a task or milestone has been in progress significantly longer than estimated, or when a definition of done is proving unrealistic, the AI may suggest simplifying: "The original plan was X. Based on where you are, would it make sense to adjust the goal to Y?"
* This is offered as a question, never imposed.

### 5.3 Project Knowledge Base (Local RAG)

For long-running projects, the volume of accumulated data (check-in transcripts, document revisions, task notes, historical conversations) will exceed what can fit in any LLM's context window. Rather than relying solely on truncation and summarisation — which inevitably loses nuance — the system maintains a **local retrieval-augmented generation (RAG) layer** that lets the AI access the full project history selectively.

**How it works:**

1. **Indexing:** All project text data (check-in transcripts, document content, task notes, AI conversation history) is chunked and embedded into a local vector store. Embeddings are generated on-device using Apple's NaturalLanguage framework or a lightweight embedding model.
2. **Storage:** The vector store sits alongside the SQLite database as a local index. It is a retrieval layer, not a source of truth — the SQLite database remains authoritative.
3. **Retrieval:** Before each AI call, the system queries the vector store with the current conversation context to retrieve the most relevant chunks of historical data. For example, if the user mentions a wiring problem, the system might retrieve a check-in from six months ago where a similar issue was discussed and resolved.
4. **Injection:** Retrieved chunks are injected into the context payload alongside the structured project data (current phase, milestones, tasks). The AI sees both the structured current state and the relevant historical context.

**Benefits:**

* The AI can reference specific past conversations and decisions even from months ago, without requiring them to be in the context window at all times
* Long-running projects with extensive histories don't degrade the AI's knowledge — the knowledge base grows with the project
* The "AI knows your project deeply" promise scales to projects of any duration and complexity
* Context payloads stay lean (fast responses, lower API cost) while the AI's effective knowledge is much larger

**Implementation notes:**

* The vector store should be rebuilt/updated incrementally as new data is added (check-ins, document edits, etc.)
* Retrieval should be fast enough for voice-first interactions — pre-compute and cache where possible
* The knowledge base is per-project — each project has its own indexed corpus
* This is an enhancement to, not a replacement for, structured context assembly (section 5.4). The structured data (current phase, task statuses, milestones) is always included directly. The RAG layer supplements it with relevant historical depth.

### 5.4 Context Assembly

The AI's usefulness depends on having rich, relevant context. Before each API call, the AIService assembles a context payload from two sources: **structured project data** (always included) and **retrieved historical context** (from the knowledge base, when relevant).

**For project-specific conversations (check-ins, planning):**

```
System prompt:
  - Role definition (project collaborator)
  - Behavioural contract (see 5.2)
  - Check-in depth mode (quick log vs full conversation)

Structured project context (always included):
  - Project name, category, lifecycle state
  - Vision statement (full text, if exists, space permitting)
  - Current phase: name, definition of done, status
  - All milestones in current phase: name, status, deadline, progress %
  - All tasks in current phase: name, status, blocked/waiting info, time estimate,
    effort type, timesDeferred count
  - Recent check-in summaries (last 3-5)

Retrieved context (from knowledge base, based on conversation topic):
  - Relevant historical check-in excerpts
  - Relevant document sections (technical brief, etc.)
  - Relevant past conversation excerpts
  - Relevant task notes from completed work

User message:
  - Transcribed voice input or typed text
```

**For Focus Board review conversations:**

```
System prompt:
  - Role definition (analytical review mode)
  - Behavioural contract

Focus context:
  - All 5 focused projects: name, category, progress %, staleness, blocked count,
    frequently deferred tasks
  - Recent activity summary per project (tasks completed this week)
  - Any health signals (stale, approaching deadline, all tasks done)
  - Queued/paused projects summary (names, categories, pause reasons, last touched)
  - Waiting items approaching check-back dates

User message:
  - Transcribed voice input or typed text
```

**For new project brain dumps:**

```
System prompt:
  - Role definition emphasising discovery and challenge network behaviour
  - Behavioural contract (onboarding mode)
  - Onboarding process guidelines
  - Summary of existing projects (to identify overlaps or conflicts)

User message:
  - Transcribed brain dump
```

**For project re-entry (return briefing generation):**

```
System prompt:
  - Role definition (re-entry support)
  - Behavioural contract

Project context:
  - Full structured project data
  - Retrieved: all check-in summaries, key conversation excerpts, last known
    state when project was unfocused

Task:
  - Generate a concise return briefing: where things stood, what was done,
    what was in progress, what was blocked, and suggested next steps
```

### 5.5 Context Window Management

Even with the knowledge base handling historical depth, the assembled context payload must fit within the LLM's context window.

1. **Always include:** System prompt + behavioural contract, structured project data (name, category, status, current phase, milestones, tasks), user message
2. **Include if space permits (priority order):** Vision statement (full), retrieved knowledge base chunks, recent check-in summaries, technical brief
3. **Summarise if necessary:** For projects with 50+ tasks, include a summary rather than the full list. For long documents, include a condensed version.
4. **Pre-computed summaries:** When a check-in record is created, also generate and store a condensed summary for direct context inclusion. These complement the knowledge base — summaries go in the structured context, full transcripts go in the knowledge base for retrieval.
5. **Token budget:** Track approximate token usage and truncate/summarise to stay within the model's context window with room for the response. Optimise aggressively for mobile use where latency matters.

### 5.6 Response Parsing

AI responses in certain contexts need to be parsed for structured actions. The system prompt instructs the AI to include structured action blocks alongside natural language:

**During check-ins**, the AI may output actions such as:

```
[COMPLETE_TASK: {taskId}]
[UPDATE_NOTES: {taskId}, "Implementation note: switched to async/await pattern"]
[FLAG_BLOCKED: {taskId}, type: tooLarge, reason: "User says this is more complex than expected"]
[SET_WAITING: {taskId}, reason: "Waiting for parts delivery", checkBack: "2026-03-01"]
[CREATE_SUBTASK: {parentTaskId}, name: "...", definitionOfDone: "..."]
[UPDATE_DOCUMENT: {documentId}, section: "...", content: "..."]
[INCREMENT_DEFERRED: {taskId}]
[SUGGEST_SCOPE_REDUCTION: {milestoneId}, currentDoD: "...", suggestedDoD: "..."]
```

**During onboarding**, the AI may output:

```
[CREATE_MILESTONE: name: "...", definitionOfDone: "...", deadline: "...", priority: "..."]
[CREATE_TASK: milestoneId: "...", name: "...", definitionOfDone: "...", timeEstimate: N,
  effortType: "...", isTimeboxed: false]
[CREATE_DOCUMENT: type: visionStatement, content: "..."]
```

These action blocks are parsed by the AIService and executed against the data layer. The natural language response is displayed to the user.

**Confirmation model:**

* Actions are presented to the user for confirmation, but with **bundled approval** as the default. After a check-in, the AI presents a summary: "Here's what I'd update: [list]. Apply all?" with options to apply all, review individually, or cancel.
* For **quick log** check-ins with straightforward updates (2-3 task completions): the AI may present these inline with a single "Confirm" button rather than individual cards.
* A **trust level** setting (configurable): at the highest trust level, the AI applies non-destructive updates (notes, deferred counters) automatically and only asks for confirmation on state changes (completing tasks, creating items, changing blocked status). Default: confirm all.

### 5.7 Conversation Persistence

AI conversations are stored locally for reference:

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| projectId | UUID? | Associated project (nil for general/review conversations) |
| conversationType | ConversationType (enum) | BrainDump, CheckIn, Planning, Review, Retrospective, ReEntry, General |
| messages | [ChatMessage] | Ordered list of user/assistant messages |
| createdAt | Date | Start of conversation |
| updatedAt | Date | Last message timestamp |

Each ChatMessage contains: role (user/assistant), content (text), timestamp, and optionally the raw voice transcript (before any processing).

Conversation history is included in context assembly for ongoing conversations. Historical conversations are indexed in the project knowledge base (see 5.3) for selective retrieval, with pre-computed summaries available for direct context inclusion (see 5.5).

---

## 6. Voice Input

### 6.1 Whisper Integration

Voice input uses a locally-running Whisper model for transcription.

```
┌────────────┐     ┌──────────────┐     ┌──────────────┐
│ Microphone │────▶│ Audio Buffer  │────▶│   Whisper    │
│ (AVAudio)  │     │ (WAV/PCM)    │     │  (local)     │
└────────────┘     └──────────────┘     └──────┬───────┘
                                               │
                                        ┌──────┴───────┐
                                        │  Transcript  │
                                        │  (String)    │
                                        └──────┬───────┘
                                               │
                                        ┌──────┴───────┐
                                        │  ChatUI or   │
                                        │  AIService   │
                                        └──────────────┘
```

**Implementation approach:**

* Use a Swift Whisper wrapper (e.g. WhisperKit or whisper.cpp with Swift bindings)
* Model: `whisper-small` or `whisper-medium` depending on device capability — balance accuracy vs. speed
* Transcription runs on-device (no network dependency for voice input)
* The UI shows a real-time waveform during recording and a processing indicator during transcription
* Transcribed text is editable before sending — the user can correct transcription errors

**Voice interaction flow:**

1. User taps/holds the microphone button (or uses a keyboard shortcut on macOS)
2. Audio is recorded until the user releases/taps again
3. Whisper processes the audio locally
4. Transcript appears in the chat input field, editable
5. User sends (or edits and sends)

### 6.2 Text Input Fallback

Text input is always available alongside voice. The chat input field accepts typed text at all times. There is no mode switch — voice and text coexist. The microphone button sits adjacent to the text field.

---

## 7. Quick Capture

### 7.1 Flow

Quick Capture is a lightweight, globally-accessible mechanism for recording ideas without leaving the current context.

```
┌───────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Trigger           │────▶│  Capture Sheet   │────▶│  Project Created │
│  (button/shortcut/ │     │  (voice or text)  │     │  (Idea state)    │
│   widget)          │     │  + optional title  │     └──────────────────┘
└───────────────────┘     │  + optional categ. │
                          └──────────────────┘
```

**Access points:**

* **macOS**: Global keyboard shortcut (configurable), persistent button in sidebar, menu bar item
* **iOS**: Widget, shortcut action, persistent button in tab bar

**Capture fields:**

* **Voice note or text** (required) — the raw idea, stored as `quickCaptureTranscript`
* **Title** (optional) — if not provided, the AI can suggest one later during onboarding
* **Category** (optional) — quick selection from existing categories

**Result:** A new Project record in `lifecycleState = .idea` with the transcript stored. No phases, no milestones, no tasks. The project appears in the Project Browser under the "Ideas" filter, ready for full onboarding when the user is ready.

**Design goal:** Under 30 seconds from trigger to completion. The user should be able to Quick Capture while walking without breaking stride.

---

## 8. Project Onboarding Flow

### 8.1 User-Facing Flow

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│  Brain Dump  │────▶│  Discovery   │────▶│  Structure   │
│  (voice/text)│     │ Conversation │     │  Proposal    │
└─────────────┘     └──────────────┘     └──────┬───────┘
                                                │
                          ┌─────────────────────┤
                          ▼                     ▼
                   ┌──────────────┐     ┌──────────────┐
                   │   Simple     │     │   Complex    │
                   │  (direct to  │     │  (vision +   │
                   │  milestones) │     │  brief +     │
                   └──────┬───────┘     │  review)     │
                          │             └──────┬───────┘
                          │                    │
                          ▼                    ▼
                   ┌──────────────────────────────────┐
                   │  User reviews & approves          │
                   │  proposed milestones & tasks       │
                   └──────────────┬───────────────────┘
                                  │
                                  ▼
                   ┌──────────────────────────────────┐
                   │  Project created/updated          │
                   │  State: Queued (ready to focus)   │
                   └──────────────────────────────────┘
```

If the project originated as a Quick Capture idea, the brain dump conversation begins with the AI referencing the original voice note: "I have your original idea here: [summary]. Let's flesh this out."

### 8.2 Discovery Conversation Prompt Design

The AI's system prompt for onboarding conversations should instruct it to:

1. **Listen first.** Let the user talk. Don't interrupt the brain dump.
2. **Then probe.** Ask clarifying questions one at a time. Focus on: intent (why do you want to do this?), scope (how big is this?), unknowns (what don't you know yet?), outcome (what does done look like?), and practical first steps (what would you actually need to do first?).
3. **Reveal hidden complexity.** Based on the described project, flag things the user might not have considered. ("If you're building a hardware enclosure, you'll need to think about mounting, ventilation, and cable routing — have you considered those?")
4. **Assess complexity collaboratively.** As the conversation develops, form a view of whether this is a simple, medium, or complex project. Share this assessment with the user and agree on the appropriate planning depth.
5. **Propose structure.** Once the conversation has covered enough ground, propose: phases (if applicable — lightweight projects may need only one implicit phase), milestones, and tasks with definitions of done, time estimates, effort types, and priorities. Present these conversationally, not as a data dump. Invite feedback and revision.
6. **For creative/exploratory tasks:** Suggest timeboxes where binary definitions of done aren't natural. ("For 'explore texture options,' would it make sense to timebox that at 2 hours and see where you land?")
7. **For complex projects:** Offer to generate a vision statement and/or technical brief. Draft these in the conversation and allow the user to refine them before finalising.

### 8.3 Adversarial Review Pipeline (Complex Projects)

For projects that warrant the full pipeline, the review process can be automated via n8n or a similar workflow tool:

1. **Export:** Vision statement and technical brief are exported (via API or file) along with the original brain dump transcript.
2. **Submit to reviewers:** Two additional LLMs receive the documents with a critique prompt: "Review the vision statement against the original brain dump. Does it accurately capture the intent? What's missing? What's contradictory? What problems are overlooked? Then review the technical brief against the vision statement with the same questions."
3. **Collect critiques:** Responses are collected and stored.
4. **Synthesis:** The critiques are submitted (along with all original documents) back to the primary AI, which: identifies overlapping concerns, notes divergent opinions, recommends which critiques to address, and produces revised documents.
5. **User review:** Revised documents are presented to the user for final approval.
6. **Roadmap extraction:** From the approved documents, milestones and tasks are extracted and proposed for the user's approval.

This pipeline is **external to the app** (orchestrated by n8n or similar). The app's role is to export the necessary documents and import the results. The pipeline is only invoked for complex projects where the user and AI agree it's warranted.

---

## 9. Check-In System

### 9.1 Check-In Flow

```
┌─────────────────┐     ┌──────────────────┐
│  User initiates  │────▶│  Select depth:   │
│  check-in        │     │  Quick Log or    │
│  (or prompted)   │     │  Full Conversation│
└─────────────────┘     └────────┬─────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
          ┌──────────────────┐     ┌──────────────────┐
          │  Quick Log       │     │  Full Conversation│
          │  - Brief update  │     │  - Deep discussion│
          │  - AI confirms   │     │  - AI may probe   │
          │  - Bundled apply │     │  - Pattern surface│
          └────────┬─────────┘     └────────┬─────────┘
                   │                         │
                   ▼                         ▼
          ┌──────────────────────────────────────────┐
          │  AI proposes updates (bundled)             │
          │  User confirms: Apply All / Review / Cancel│
          └──────────────────┬───────────────────────┘
                             │
                             ▼
          ┌──────────────────────────────────────────┐
          │  Changes applied to database              │
          │  CheckInRecord created                    │
          │  timesDeferred incremented for untouched  │
          │  tasks that were visible/actionable        │
          └──────────────────────────────────────────┘
```

### 9.2 Check-In Prompting

The system prompts for check-ins based on time since last check-in, with escalating visibility. All prompts are **snoozable** (snooze options: 1 day, 3 days, 1 week).

| Condition | Prompt Level | Display |
|-----------|-------------|---------|
| 3+ days since last check-in | Gentle | Subtle badge on project in Focus Board |
| 7+ days since last check-in | Moderate | Visible prompt in project header (snoozable) |
| 14+ days since last check-in | Prominent | Banner on Focus Board (snoozable) + iOS notification (if opted in) |
| After completing a significant task | Suggestion | "Good progress! Quick check-in?" (dismissible) |

Prompts are never blocking. They don't prevent any other action. They escalate in visibility but can always be dismissed or snoozed. The system never nags — if the user snoozes, the prompt disappears for the snooze period.

### 9.3 AI Behaviour During Check-Ins

**Quick Log mode:**

1. Accept the user's update at face value
2. Parse for implicit task completions ("I finished the wiring" → mark wiring task complete)
3. Present bundled updates for confirmation
4. Done. No analysis, no probing.

**Full Conversation mode:**

1. **Be conversational.** This should feel like talking to a colleague, not filing a report.
2. **Ask what happened.** "What have you been working on?" / "How's the {milestone} going?"
3. **Listen for implicit updates.** If the user says "I finished wiring the power section," recognise this as a task completion even if they don't say "mark task X as done."
4. **Probe for problems** (gently). "You mentioned the routing was tricky — is that still an issue?" / "Anything blocking you right now?"
5. **Surface patterns** (when appropriate). "This is the third check-in where {task} hasn't progressed. Want to talk about what's making it difficult? Should we break it down differently?"
6. **Suggest scope reduction** (when appropriate). "This milestone has been in progress for much longer than planned. Would it make sense to simplify the goal?"
7. **Reference timeboxes.** "You timeboxed {task} at 30 minutes — how did that go?"
8. **Propose specific updates.** After the conversation, list the proposed changes as a bundled summary and ask for confirmation before applying.
9. **Update documentation.** Add progress notes to relevant tasks and milestones. Update the project's notes field with a summary.

### 9.4 Avoidance Detection

The system tracks task-level avoidance through the `timesDeferred` counter:

* When a check-in occurs and a task was visible/actionable on the Focus Board but not mentioned or progressed, its `timesDeferred` is incremented.
* When `timesDeferred` reaches a configurable threshold (default: 3), the task is flagged as "frequently deferred" with a subtle visual indicator.
* During **full conversation** check-ins and **project reviews**, the AI is instructed to notice frequently deferred tasks and explore what's behind the avoidance — but framed as curiosity, not judgement (per the behavioural contract).
* The AI may suggest: decomposition (too large), redefinition (poorly defined), effort type reassessment, or scope reduction.

---

## 10. Retrospective Flow

### 10.1 Trigger

When the last milestone in a phase is marked as completed, the system prompts a retrospective conversation.

### 10.2 Flow

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Phase completed  │────▶│  Retrospective   │────▶│  Next phase      │
│  (last milestone  │     │  conversation    │     │  review/revision │
│   marked done)    │     │  with AI         │     │  (if applicable) │
└──────────────────┘     └──────────────────┘     └──────────────────┘
```

### 10.3 AI Behaviour During Retrospectives

The AI's system prompt for retrospectives instructs it to explore:

1. **What went well?** Which milestones flowed smoothly? What worked about the approach?
2. **What didn't go well?** What took longer than expected? What was harder than anticipated? Where did blocks or avoidance appear?
3. **What was learned?** Any new skills, tools, or approaches discovered? Any assumptions proven wrong?
4. **Estimate calibration:** How did time estimates compare to actuals across the phase? Should the pessimism multiplier be adjusted?
5. **Next phase assessment:** Does the originally sketched next phase still make sense? Should it be revised based on what was learned?

The retrospective notes are stored on the Phase record. If the next phase exists, the AI may propose revisions to its milestones based on the retrospective conversation.

---

## 11. External Integration API

### 11.1 Purpose

A local REST API that allows external tools (Claude Code, Codex, automation scripts) to read project data and push updates directly to the Project Manager's database.

### 11.2 Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/projects | List all projects (filterable by state, category) |
| GET | /api/projects/{id} | Full project detail (phases, milestones, tasks) |
| GET | /api/projects/{id}/tasks | All tasks for a project (filterable by status) |
| PATCH | /api/tasks/{id} | Update task (status, notes, blockedType, etc.) |
| POST | /api/tasks/{id}/complete | Mark task as completed |
| POST | /api/tasks/{id}/notes | Append a note to a task |
| POST | /api/milestones/{milestoneId}/tasks | Create a new task within a milestone |
| POST | /api/projects/{id}/issues | Flag a new issue (creates a note or blocked task) |
| GET | /api/documents/{id} | Retrieve a project document |
| PATCH | /api/documents/{id} | Update document content |

### 11.3 Security

* Runs on `localhost` only (not exposed to the network)
* Optional API key for authentication (configurable in Settings)
* All writes are logged for audit/review

### 11.4 Use Case: Claude Code Workflow

1. Claude Code receives the project's roadmap and technical brief
2. It works through tasks sequentially, running tests
3. On task completion: `POST /api/tasks/{id}/complete` with notes about what was implemented
4. On discovering issues: `POST /api/projects/{id}/issues`
5. On updating documentation: `PATCH /api/documents/{id}`
6. The Project Manager reflects these changes immediately — the Focus Board updates, progress percentages change, and the AI has full awareness of what happened during the next check-in

---

## 12. Sync Services

### 12.1 CloudKit Sync (macOS ↔ iOS)

All core entities are synced via CloudKit's private database:

* **Sync unit:** Individual records (Project, Phase, Milestone, Task, Subtask, Document, CheckInRecord, Category)
* **Conflict resolution:** Last-write-wins for most fields. For document content (vision statements, technical briefs), CloudKit conflict resolution surfaces both versions for manual merge if timestamps are very close.
* **Offline support:** Full read/write capability offline. Changes queue and sync when connectivity is restored.
* **Sync trigger:** On app launch, on significant data change, and periodically in the background.

**Implementation note:** If using SwiftData, its native CloudKit integration (via NSPersistentCloudKitContainer) handles much of this automatically. If using GRDB, a custom CloudKit sync layer is required. The choice between SwiftData and GRDB should be made during implementation based on the complexity of queries needed and SwiftData's maturity at the time of development.

### 12.2 Life Planner Export (→ MySQL)

The Life Planner system runs on separate hardware and reads from a MySQL database. The Project Manager periodically exports relevant data:

**What is exported:**

* Active tasks from focused projects: task name, definition of done, time estimate (adjusted), deadline, milestone name, project name, project category, blocked/waiting status, dependencies, priority, effort type
* Summary project metadata: project name, category, focus status, overall progress

**Export trigger:**

* On every app launch
* After any data change to focused projects (debounced)
* Manual trigger available in Settings

**Export mechanism:**

* Direct MySQL connection from the app (via a lightweight MySQL client library), OR
* HTTP API endpoint on the Life Planner's host that accepts JSON payloads

The choice depends on network topology. **This should be configurable.**

**Data flow is one-directional:** Project Manager → Life Planner. The Life Planner does not write back to the Project Manager's database.

---

## 13. Notification System (iOS)

### 13.1 Notification Types

| Trigger | Content | Default | Configurable |
|---------|---------|---------|-------------|
| Waiting item past check-back date | "Still waiting on {item}?" | On | Yes — can disable |
| Task deadline within 24 hours | "{task} is due tomorrow" | On | Yes — can disable |
| No check-in for 14+ days | "It's been a while — quick check-in on {project}?" | Off (opt-in) | Yes |
| Phase completed | "Phase complete! Ready for a retrospective?" | On | Yes |

### 13.2 Fatigue Prevention

* **Maximum 2 notifications per day** (hard cap, configurable up or down)
* **Smart batching:** If multiple items trigger on the same day, combine into a single notification: "3 items need attention"
* **Snooze on all notifications:** Swiping a notification offers snooze options (1 day, 3 days, 1 week)
* **Quiet hours:** Respect system Do Not Disturb. No notifications outside configurable hours (default: 9am-8pm).
* **No routine check-in push notifications by default.** In-app prompts handle this. Push notifications are reserved for time-sensitive items (deadlines, waiting items). Users can opt in to check-in reminders if they find them helpful.

---

## 14. Data Export

### 14.1 Export Format

Full project data exportable as **JSON**, containing:

* All projects with all child entities (phases, milestones, tasks, subtasks)
* All documents (vision statements, technical briefs)
* All check-in records and conversation summaries
* All categories (including custom)
* Metadata (export date, app version)

### 14.2 Access

* Available in Settings > Data > Export All Data
* Also available per-project: Export a single project with all its data
* Export produces a `.json` file that can be saved to Files, shared, or backed up

### 14.3 Import

* Import from a previously exported JSON file
* Handles merging (by UUID) — existing records are updated, new records are created
* Used for backup recovery or migration between devices if CloudKit sync fails

---

## 15. User Interface

### 15.1 Navigation Structure

**macOS (sidebar navigation):**

```
┌──────────────┬─────────────────────────────────────┐
│              │                                     │
│  Focus Board │         [Main Content Area]         │
│              │                                     │
│  All Projects│   Displays the selected view:       │
│    Focused   │   - Focus Board (Kanban)             │
│    Queued    │   - Project Detail                   │
│    Ideas     │   - Roadmap                          │
│    Completed │   - AI Chat                          │
│    Paused    │   - Settings                         │
│    Abandoned │                                     │
│              │                                     │
│  AI Chat     │                                     │
│              │                                     │
│  [Quick      │                                     │
│   Capture]   │                                     │
│              │                                     │
│  Settings    │                                     │
│              │                                     │
└──────────────┴─────────────────────────────────────┘
```

**iOS (tab-based navigation):**

```
┌─────────────────────────────────────┐
│                                     │
│         [Main Content Area]         │
│                                     │
│   Displays the selected tab view    │
│                                     │
│                                     │
├──────┬──────┬──────┬──────┬────────┤
│Focus │Proj- │ AI   │ [+]  │  More  │
│Board │ects  │ Chat │Quick │(Settings│
│      │      │      │Capt. │ etc.)  │
└──────┴──────┴──────┴──────┴────────┘
```

### 15.2 Key Views

#### Focus Board View

* Kanban board with three columns: To Do (curated), In Progress, Done
* Task cards are colour-coded by project (each focus slot has a consistent colour)
* Task cards show: task name, project name, milestone name, deadline, time estimate/timebox, effort type badge, status indicators
* Effort type filter bar above the board (tap to filter by effort type)
* Drag-and-drop between columns
* Project headers above the board show: project name, category, progress bar, health signal badges
* Diversity override banner (if applicable) at top
* Tapping a task card opens a detail popover/sheet with full information and quick actions (mark complete, mark blocked, start check-in, etc.)
* "Show all tasks" toggle per project to expand beyond the curated set

#### Project Browser View

* List/grid of all projects, grouped or filterable by: lifecycle state (Focused, Queued, Ideas, Completed, Paused, Abandoned), category, last worked on, creation date
* Search bar: searches project names, milestone names, task names, and document content
* Each project card shows: name, category, lifecycle state, progress indicator, last worked on date
* Tapping a project opens the Project Detail View

#### Project Detail View

* **Header:** Project name, category, lifecycle state, focus status, overall progress
* **Tabs or sections:**
  * **Overview:** Definition of done, pause reason (if paused), abandonment reflection (if abandoned), notes, dates, health signals
  * **Roadmap:** Chronological view of phases → milestones → tasks (see Roadmap View)
  * **Documents:** Vision statement, technical brief — viewable and editable as Markdown
  * **History:** Check-in records, conversation summaries, completed task history (all tasks ever completed, not just recent)
  * **Quick Capture note:** Original voice transcript, if the project originated from Quick Capture
* **Quick actions:** Focus/unfocus, start check-in (quick log or full), add milestone, mark complete, pause (with reason), abandon (with optional reflection)

#### Roadmap View

* Available both as a project-specific view (within Project Detail) and as a cross-project view
* **Project Roadmap:** Vertical timeline showing phases, milestones within each phase, and tasks within each milestone. Each item shows: name, status, deadline, progress (for milestones), effort type, priority, and dependency indicators (visual connector lines, with warnings on unmet dependencies).
* **Cross-project Roadmap:** Shows milestones from all focused projects on a unified timeline, sorted by deadline. Useful for seeing what's coming up across all active work.

#### AI Chat View

* Conversational interface with message bubbles (user and assistant)
* Voice input button (microphone) alongside text input field
* **Project selector** at top: choose which project to discuss (or "General" for Focus Board reviews and new project brain dumps, or "New Project" for onboarding)
* **Check-in depth selector**: Quick Log / Full Conversation (when a project is selected)
* When a project is selected, the project's key info (name, current phase, progress) is shown in a compact header
* **Action confirmations:** When the AI proposes changes, these appear as a bundled summary card with "Apply All," "Review Individually," or "Cancel" options. Individual review shows each proposed change with accept/reject.
* **Return briefing display:** When re-entering a dormant project, the AI's return briefing is displayed as a formatted card at the top of the conversation.

#### Settings View

* **Focus Board:** Max slots (default 5), max per category (default 2), max visible tasks per project (default 3), staleness threshold (default 7 days)
* **Check-ins:** Prompt thresholds (3/7/14 days), snooze defaults
* **Time Estimates:** Pessimism multiplier (default 1.5x)
* **Categories:** View, add, edit, delete custom categories
* **AI:** API key configuration, model selection, trust level (confirm all / auto-apply minor updates), intervention depth preferences
* **Voice:** Whisper model selection (small/medium), audio input device
* **Notifications (iOS):** Enable/disable per notification type, quiet hours, max per day
* **Life Planner Sync:** Connection details (MySQL host/credentials or API endpoint), sync frequency, manual sync trigger, sync status/logs
* **Integration API:** Enable/disable, port, API key
* **Data:** Export all / Export single project / Import, backup info

---

## 16. Settings and Configuration Summary

### 16.1 User-Configurable Settings

| Setting | Default | Range | Location |
|---------|---------|-------|----------|
| maxFocusSlots | 5 | 1–10 | Settings > Focus Board |
| maxPerCategory | 2 | 1–maxFocusSlots | Settings > Focus Board |
| maxVisibleTasksPerProject | 3 | 1–10 | Settings > Focus Board |
| stalenessThresholdDays | 7 | 1–30 | Settings > Focus Board |
| checkInGentlePromptDays | 3 | 1–14 | Settings > Check-ins |
| checkInModeratePromptDays | 7 | 3–21 | Settings > Check-ins |
| checkInProminentPromptDays | 14 | 7–30 | Settings > Check-ins |
| pessimismMultiplier | 1.5 | 1.0–3.0 | Settings > Estimates |
| deferredThreshold | 3 | 1–10 | Settings > Check-ins |
| whisperModel | small | small/medium | Settings > Voice |
| aiModel | configurable | supported models | Settings > AI |
| aiTrustLevel | confirmAll | confirmAll / autoMinor | Settings > AI |
| notificationsEnabled | true | on/off | Settings > Notifications |
| maxDailyNotifications | 2 | 1–5 | Settings > Notifications |
| quietHoursStart | 20:00 | time | Settings > Notifications |
| quietHoursEnd | 09:00 | time | Settings > Notifications |
| lifePlannerSyncEnabled | false | on/off | Settings > Sync |
| lifePlannerSyncMethod | mysql | mysql/api | Settings > Sync |
| integrationAPIEnabled | false | on/off | Settings > Integration |
| integrationAPIPort | 8420 | 1024–65535 | Settings > Integration |
| returnBriefingThresholdDays | 14 | 7–60 | Settings > Focus Board |
| doneColumnRetentionDays | 7 | 1–30 | Settings > Focus Board |
| doneColumnMaxItems | 20 | 5–50 | Settings > Focus Board |

---

## 17. Development Roadmap

This roadmap follows the project's own philosophy: phased delivery, each phase independently valuable, with reassessment between phases.

### Phase 1: Foundation

**Goal:** A functional macOS app with the core data model, basic project management, the Focus Board, and Quick Capture.

Milestones:

1. **Data model and persistence** — SQLite database with all core entities, CRUD operations, unit tests
2. **Project Browser** — Create, view, edit, delete projects. Filter by lifecycle state and category. Search. Support all lifecycle states (Focused, Queued, Idea, Completed, Paused, Abandoned).
3. **Hierarchy management** — Create and manage phases, milestones, tasks, subtasks within a project. Advisory dependency tracking (warnings, not blocks). Priority and effort type assignment.
4. **Focus Board** — Kanban view with curated task visibility, slot management, diversity enforcement with override, drag-and-drop, health signals, effort type filtering
5. **Quick Capture** — Global shortcut, voice/text capture, Idea-state project stub creation
6. **Roadmap view** — Project-level chronological display of phases/milestones/tasks with dependency visualisation
7. **Settings** — Core configuration (focus limits, diversity limits, staleness threshold, categories, task visibility limits)
8. **Data export** — Full JSON export/import

**Phase 1 Definition of Done:** A user can Quick Capture ideas, create projects with full hierarchy, focus up to 5 with diversity rules enforced, view and manage a curated set of tasks on a Kanban board, filter by effort type, browse all projects by lifecycle state, and export all data. No AI, no sync, no iOS.

### Phase 2: AI Integration

**Goal:** Built-in AI chat with voice input, enabling brain dumps, check-ins (both depths), project planning, and retrospectives.

Milestones:

1. **Voice input** — Local Whisper integration, recording UI, transcription pipeline
2. **AI service layer** — LLM API integration, context assembly with token management, prompt construction with behavioural contract, response parsing with action blocks
3. **Project knowledge base** — Local vector store, embedding pipeline, incremental indexing of check-ins/documents/notes, relevance retrieval integrated with context assembly
4. **Chat UI** — Conversational interface, project selector, check-in depth selector, bundled action confirmation cards, trust level support
5. **Check-in flow** — Quick log and full conversation modes, AI-guided check-ins with proposed updates, avoidance detection (timesDeferred tracking), CheckInRecord storage
6. **Onboarding flow** — Brain dump capture (referencing Quick Capture transcripts), discovery conversation, milestone/task/effort type proposal and creation, document generation
7. **Retrospective flow** — Phase-end prompt, AI-guided retrospective conversation, notes stored on phase, next-phase reassessment
8. **Document management** — Vision statement and technical brief creation, viewing, editing within the app
9. **Return briefings** — Auto-generated when refocusing dormant projects

**Phase 2 Definition of Done:** A user can have voice or text conversations with an AI that follows the behavioural contract and draws on a project knowledge base for historical context, create new projects through guided brain dumps (including from Quick Capture stubs), do progress check-ins at two depth levels with bundled confirmation, conduct phase retrospectives, generate return briefings, and create/view/edit project documents. No iOS, no sync.

### Phase 3: Sync, iOS, and External Integration

**Goal:** CloudKit sync, a companion iOS app, Life Planner export, and the external integration API.

Milestones:

1. **CloudKit integration** — Sync all core entities between devices, conflict resolution, offline support
2. **iOS app** — Adapted UI for iPhone (tab-based navigation), full feature parity with macOS, Quick Capture widget
3. **iOS notifications** — Notification scheduling, fatigue prevention, snooze management, quiet hours
4. **Life Planner export** — MySQL/API sync mechanism, configurable connection, periodic export with effort type and priority data
5. **External integration API** — Local REST API for Claude Code and other tools, localhost only, optional auth
6. **Mobile voice check-ins** — Optimised voice input experience for iOS, background audio processing

**Phase 3 Definition of Done:** A user can manage projects from both macOS and iOS with data synced seamlessly, Quick Capture via widget while walking, do voice check-ins on the go, active task data (with effort types and priorities) flows to the Life Planner, and coding tools can push updates via the integration API.

### Phase 4: Refinement and Intelligence

**Goal:** Smarter AI behaviour, historical analytics (with guardrails), cross-project roadmap, and the adversarial review pipeline.

Milestones:

1. **Estimate calibration** — Track estimated vs actual time, surface accuracy trends, suggest pessimism multiplier adjustments
2. **AI project reviews** — Focus Board review conversations, cross-project pattern detection, stall/avoidance surfacing, scope reduction suggestions, waiting item accumulation awareness
3. **Adversarial review integration** — n8n pipeline for complex project onboarding, document export/import
4. **Cross-project roadmap** — Unified timeline view across all focused projects
5. **Reflective analytics** — Project completion rates, average time per effort type, estimate accuracy trends. **Guardrails:** No streaks, no gamification, no comparative metrics, no red/green scoring. All analytics are presented as neutral observations for self-reflection, never as performance judgements. The framing is "here's what happened" not "here's how you did."
6. **Check-in intelligence** — AI learns from check-in history to ask better questions, notice finer-grained patterns, and calibrate its intervention depth over time

**Phase 4 Definition of Done:** The system actively helps the user improve their planning and execution through data-driven insights (presented without judgement), smarter AI interactions, and automated review pipelines for complex projects.

---

## 18. Testing Strategy

Each module should be tested independently before integration.

### Unit Tests

| Module | Key Tests |
|--------|-----------|
| DataModel | CRUD for all entities, cascading deletes, computed properties, lifecycle state transitions |
| FocusManager | Slot assignment, diversity enforcement, override behaviour, staleness calculation, health signals, task visibility curation algorithm, effort type filtering |
| AIService | Context assembly (token counting, priority truncation, behavioural contract inclusion), action block parsing, prompt construction per conversation type, bundled confirmation generation |
| KnowledgeBase | Embedding generation, incremental index updates, relevance retrieval accuracy, per-project isolation, retrieval latency on large corpora |
| IntegrationAPI | Endpoint routing, authentication, write logging, concurrent access handling |
| SyncService | CloudKit record mapping, conflict resolution, offline queue |
| LifePlannerExport | MySQL/API payload construction (including effort type and priority), data mapping, error handling |
| NotificationManager | Trigger logic, fatigue cap enforcement, snooze state, quiet hours |
| QuickCapture | Project stub creation, transcript storage, lifecycle state correctness |
| DataExport | JSON serialisation/deserialisation, import merge logic, UUID handling |

### Integration Tests

| Flow | Test |
|------|------|
| Quick Capture → Onboarding | Capture idea → create stub → later onboard → verify transcript referenced → milestones created |
| Focus a project | Diversity check → slot assignment → return briefing (if dormant) → Kanban population → task visibility curation → correct display |
| Complete a task (drag) | Kanban drag-to-done → task status update → milestone progress recalculation → project progress update → staleness timer reset → done column retention |
| Quick Log check-in | AI context assembly → brief exchange → bundled action proposal → apply all → database updates → CheckInRecord created (depth: quickLog) |
| Full check-in | AI context assembly → deep conversation → pattern surfacing → bundled confirmation → selective approve → database updates → timesDeferred incremented for unaddressed tasks |
| Phase retrospective | Last milestone completed → retrospective prompted → AI conversation → notes stored → next phase assessed |
| External API update | Claude Code POSTs task completion → database updated → Focus Board reflects change → AI aware in next check-in |
| CloudKit sync | Create on device A → sync → verify on device B → edit on B → sync → verify on A |
| Life Planner export | Focus project → trigger export → verify payload includes effort type, priority, adjusted estimates |
| Data export/import | Export all → verify JSON completeness → import on clean install → verify all data restored |

### Manual Testing Checkpoints

After each milestone, the developer passes the build to the user for manual testing with a specific test script covering the milestone's features. Issues are logged and addressed before proceeding to the next milestone.

---

## 19. Open Questions and Implementation-Time Decisions

These are questions that don't need answers in this brief but should be resolved during development:

1. **SwiftData vs GRDB:** SwiftData offers native CloudKit integration but may have query limitations for complex reporting. GRDB offers more SQL control but requires a custom CloudKit sync layer. Evaluate based on Phase 1 query needs.

2. **Whisper model size:** `whisper-small` is faster but less accurate; `whisper-medium` is more accurate but slower and uses more memory. Test both on target hardware (including older iPhones) and make configurable.

3. **LLM model selection:** The AI service should be model-agnostic (supporting both Anthropic and OpenAI APIs at minimum). The default model can be decided based on performance and cost at development time.

4. **Action confirmation UX detail:** The brief specifies bundled confirmation with "Apply All / Review / Cancel." The exact visual design of this (inline cards, bottom sheet, modal) should be prototyped during Phase 2 and iterated based on feel. The key constraint: it must feel lightweight, not bureaucratic.

5. **Adversarial review pipeline orchestration:** n8n, Shortcuts, custom scripts, or something else? Decide during Phase 4 based on what's easiest to maintain.

6. **Document editing experience:** Markdown with a preview pane? A rich text editor? A simple text field? Decide during Phase 2 based on how often documents are actually edited vs just read.

7. **Return briefing generation timing:** Should the briefing be generated on-demand when refocusing (slower, more current), or pre-computed periodically for all queued/paused projects (faster at refocus time, may be slightly stale)? Test both approaches.

8. **Vector store implementation:** Options include SQLite with a vector extension (sqlite-vss), Apple's NaturalLanguage framework for embeddings with a custom index, or a lightweight dedicated solution like FAISS compiled for Apple platforms. Evaluate based on embedding quality, retrieval speed, and storage footprint on iOS devices.
