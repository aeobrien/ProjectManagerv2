# Project Manager — AI System Overview

This document provides a comprehensive overview of how AI/LLM interactions work throughout the Project Manager app, written for discussion with an external collaborator (or Claude) about how to unify and improve the system.

---

## What Is This App?

Project Manager is a native macOS/iOS app (SwiftUI) for a single user to capture, plan, structure, and track personal projects. It's designed specifically for someone with ADHD and executive dysfunction — this shapes every interaction.

### Core Concepts

**Four-tier project hierarchy:**
- **Project** — a meaningful endeavour with intent and a desired outcome
- **Phase** — a major stage of work (e.g. "Foundation", "Core Features", "Polish")
- **Milestone** — a concrete checkpoint within a phase (e.g. "User authentication working")
- **Task** — a single unit of work within a milestone, with status (toDo / inProgress / done / waiting / blocked), priority (low / normal / high), and effort type (quickWin / deepFocus / admin / creative / physical)
- **Subtask** — a checkbox item within a task

**Project lifecycle:** idea → active → paused → completed / abandoned

**Focus Board:** The main view. Shows a curated set of "focused" projects (WIP-limited, category-diverse). Each focused project shows its current tasks in a kanban-style column. The Focus Board enforces limits: max focus slots, max per category, visible tasks per project.

**Check-ins:** Periodic conversations with the AI about a specific project. Two depths: Quick Log (brief update, minimal questions) and Full Conversation (deeper reflection on progress, blockers, avoidance patterns). Check-ins record what was discussed and track task avoidance (tasks the user doesn't mention get their "times deferred" counter incremented).

**Documents:** Markdown documents attached to projects. The two most important are the **Vision Statement** (detailed spec of intent — what the project IS, why it exists, design principles, definition of done) and the **Technical Brief** (architecture, technology choices, data model, implementation order). These are auto-generated during onboarding but editable afterwards.

**Categories:** User-defined groupings like Software, Music, Hardware, Creative, Life Admin, Research/Learning. Used for Focus Board diversity enforcement.

**Quick Capture:** A lightweight entry point for jotting down project ideas as raw text. Creates an "idea" state project stub. No AI involved.

---

## The AI's Role (As Designed)

The AI acts as a **supportive project management assistant**. It has a behavioural contract that says:
- Be encouraging but honest. Celebrate progress, no matter how small.
- Never shame or guilt-trip about unfinished work, missed deadlines, or avoidance.
- Suggest concrete, actionable next steps rather than vague advice.
- Keep responses concise — long walls of text are overwhelming.
- Recognise patterns (frequent deferral, scope creep, stalled milestones) and gently surface them.
- Use timeboxing language ("try working on this for 25 minutes" rather than "finish this today").

The AI can propose **structured actions** — changes to the user's project data — using a markup format called ACTION blocks:

```
[ACTION: COMPLETE_TASK] taskId: <uuid> [/ACTION]
[ACTION: CREATE_TASK] milestoneId: <uuid-or-placeholder> name: Fix login bug priority: high effortType: quickWin [/ACTION]
```

There are 16 action types: complete/move/delete tasks and subtasks, create phases/milestones/tasks/subtasks/documents, update notes and documents, flag tasks as blocked or waiting, increment deferred counters, and suggest scope reductions.

Actions go through a confirmation flow based on a user-configurable **trust level**:
- **Confirm All** (default): every action shown for approval
- **Auto-apply Minor**: small actions (complete task, move task, create subtask) auto-applied; larger ones need confirmation
- **Auto-apply All**: everything auto-applied

---

## Shared AI Infrastructure

### LLMClient
Sends HTTP requests to Anthropic (Claude) or OpenAI (GPT-4o). Supports retries with exponential backoff. API key from UserDefaults or environment variables.

### ContextAssembler
Builds the full payload (system prompt + context + message history) for any conversation. For a given project, it formats:
- Project metadata (name, state, definition of done, notes, original capture transcript)
- Full hierarchy: Phase → Milestone → Task (with status, priority, effort type, deadlines, blocked/waiting state, deferred count) → Subtask
- Frequently deferred tasks (highlighted separately)
- Recent check-ins (last 3, with AI summaries)
- Estimate calibration data (accuracy ratio, suggested multiplier, trend)
- Optional RAG retrieval from a knowledge base

Token budget management: 8000 tokens default, truncates oldest messages first, reserves 1024 for response.

### ActionParser
Regex-based parser that extracts `[ACTION: TYPE]...[/ACTION]` blocks from AI responses. Returns separated natural language and structured action list. Handles placeholder IDs (non-UUID strings generate fresh UUIDs for CREATE actions).

### ActionExecutor
Takes parsed actions and either presents them for confirmation or auto-applies them. Generates human-readable descriptions for the confirmation UI. Executes accepted actions via repository protocols.

### PromptTemplateStore
All prompts are stored as compiled defaults but can be overridden by the user via UserDefaults (exposed in a Settings UI). Templates support `{{variable}}` substitution. 14 templates total, grouped into: Core, Onboarding, Check-ins, Reviews, Chat, Vision Discovery, Document Generation.

---

## Every Place AI Is Used

### 1. Main AI Chat

**Entry point:** ChatView — a general-purpose chat interface accessible from any project.

**Conversation types available in the picker:** General, Quick Log, Full Check-in, Review. (Onboarding was recently removed from this picker.)

**Flow:** Multi-turn. Messages accumulate and full history is sent with each request. Conversations are persisted and can be resumed later.

**What happens:**
1. User selects a project and conversation type
2. User types or dictates a message
3. ContextAssembler builds payload with appropriate system prompt + full project context + message history
4. LLMClient sends to API
5. ActionParser extracts natural language + actions
6. Trust level determines whether actions need confirmation
7. ActionExecutor applies accepted actions

**Return Briefing sub-flow:** When the user selects a project they haven't worked on in 14+ days, a single-shot return briefing is automatically generated and displayed as a dismissible card. Uses the `.reEntry` conversation type.

**System prompts used:** Depends on selected type — `.general`, `.checkInQuickLog`, `.checkInFull`, `.review`, `.reEntry`. All include the behavioural contract and action block documentation.

**What context the AI sees:** Full project hierarchy, recent check-ins, deferred task patterns, estimate calibration data, optional RAG context.

---

### 2. Onboarding (New Project Creation)

**Entry point:** OnboardingView — presented as a sheet when the user creates a new project from the Focus Board.

**This is the most complex AI flow.** It has multiple stages:

#### Stage 1: Brain Dump
The user writes a free-form description of their project idea. They can also provide a repository URL. If coming from a markdown import, the brain dump text is pre-filled with the imported content.

#### Stage 2: AI Discovery Conversation (multi-turn, 1–3 exchanges)
The manager sends the brain dump as the first user message. The system prompt tells the AI to:
- Reflect back understanding of the project
- Call out strengths
- Ask 2–3 targeted follow-up questions to fill specific gaps needed for a vision statement (purpose, scope exclusions, definition of done, target user, design principles, mental model, key workflows, ethical centre)
- When it has enough information, propose the project structure using ACTION blocks

The conversation continues for up to 3 exchanges (configurable). On the final exchange, the system prompt forces the AI to stop asking questions and produce the structure.

**Signal convention:** The AI includes CREATE_PHASE, CREATE_MILESTONE, and CREATE_TASK action blocks when it's ready to propose the structure. This triggers the transition to the next stage.

#### Stage 3: Structure Proposal
The parsed actions are displayed as a list of proposed phases, milestones, and tasks. The user can toggle items on/off, edit the project name, select a category, and fill in the definition of done. (Category and DoD are NOT auto-filled by the AI — they're manual fields.)

#### Stage 4: Create
The accepted items are created in the database. The project is saved with its hierarchy.

#### Stage 5: Document Generation (automatic for medium/complex projects)
Two separate single-shot LLM calls:
1. **Vision Statement:** The system prompt is just the behavioural contract. The user message contains the vision statement template (a detailed structural guide for a 200–400 line document) plus the brain dump text, the full conversation transcript, and a summary of the proposed structure.
2. **Technical Brief** (for complex projects only): Continuation of the same conversation, with the technical brief template.

The generated documents are saved to the project.

**What's different about onboarding:** It does NOT use ActionExecutor for the structure creation — it has its own direct repo calls. The actions are only parsed to extract the proposed structure (names of phases/milestones/tasks), not to create real entities. Real entities are created in the "Create" step from the user-approved list.

---

### 3. Check-In

**Entry point:** CheckInView — presented when the user initiates a check-in on a specific project.

**Flow:** Single-shot. User writes one message, gets one AI response.

**What happens:**
1. User selects Quick Log or Full Conversation depth
2. User describes what they worked on / how things are going
3. Manager builds full project context, sends to AI
4. AI responds with a summary and optional action proposals
5. **Avoidance detection:** The manager compares which tasks the AI mentioned in its actions against the visible (in-progress + not-started) tasks. Tasks not addressed get their `timesDeferred` counter incremented.
6. A `CheckInRecord` is created with the transcript, AI summary, completed tasks, and flagged issues
7. The check-in content is indexed in the knowledge base for future RAG retrieval

**System prompts:**
- Quick Log: "Ask minimal questions. Propose bundled changes. Keep response under 150 words."
- Full: "Take time to understand feelings about the project. Ask about progress, blockers, avoidance, whether milestones feel right, tasks that need breaking down. Surface patterns. Reference timeboxes."

---

### 4. Project Review

**Entry point:** ProjectReviewView — accessible from the Focus Board.

**Flow:** Multi-turn (initial review + follow-up questions).

**Important distinction:** This reviews the ENTIRE portfolio of focused projects, not just one. The manager gathers data across ALL focused projects and runs client-side pattern detection:
- **Stalls:** Projects with 7+ days since last check-in
- **Blocked accumulation:** Projects with 3+ blocked tasks
- **Deferral patterns:** 5+ deferred tasks across all projects
- **Waiting accumulation:** 3+ waiting items approaching check-back dates

The AI is given a structured summary of all focused projects' stats plus these detected patterns. It provides analytical commentary and recommendations.

**What's notable:** Despite the system prompt including action block documentation, the ProjectReviewManager **never parses or executes actions** from the AI response. The review is purely advisory/informational. This seems like a gap — the AI is told about actions but its proposals are ignored.

---

### 5. Retrospective

**Entry point:** RetrospectiveView — triggered when a phase is completed.

**Flow:** Multi-turn (initial reflection + follow-up questions).

**What happens:**
1. Phase completion detected → user prompted for retrospective
2. User writes reflection text
3. AI responds with reflective conversation about what went well, challenges, patterns, unresolved feelings
4. Follow-up conversation possible
5. On completion, the combined reflection + AI summary is saved as `phase.retrospectiveNotes`

**System prompt:** "Help user reflect. For abandoned/paused projects, normalise the decision. Help frame as learning, not failure."

**What's notable:** Like Project Review, action block docs are included in the prompt but actions are **never parsed or executed**.

**Duplicate return briefing:** RetrospectiveFlowManager also has a `generateReturnBriefing(for:)` method that independently generates return briefings — duplicating functionality in ChatViewModel.

---

### 6. Adversarial Review

**Entry point:** AdversarialReviewView — accessible from the Project Detail view.

**This is the most architecturally different AI flow.** It bypasses ContextAssembler, PromptTemplates, and the behavioural contract entirely.

**Flow:**
1. **Export (no AI):** Package project documents as JSON for sending to external reviewers
2. **External review (manual):** User copies JSON, sends to external AI models (Claude, GPT-4, etc.), gets critiques back
3. **Import (no AI):** User pastes critique JSON, decoded into structured critique objects
4. **Synthesis (AI):** A custom prompt is built containing original documents + all critiques. The AI identifies overlapping concerns, recommends which to address, and produces revised documents.
5. **Follow-up (AI):** Multi-turn conversation continuing the synthesis
6. **Approval:** User approves revised documents, which are saved back

**What's different:** Direct `LLMClient.send()` calls with no system prompt, no behavioural contract, no ContextAssembler, no action blocks. The synthesis prompt is entirely self-contained. This is intentional — the adversarial review is meant to be a separate, more critical perspective, not filtered through the supportive assistant persona.

---

### 7. Vision Discovery (Partially Built, Not Wired Up)

There's infrastructure for a `.visionDiscovery` conversation type with exchange-aware prompts and a `READY_FOR_VISION` signal convention. It's designed for imported projects that already have a structure but need a vision statement generated through conversation. The prompts exist, the ContextAssembler handles it, but **no UI entry point exists** — it's dead code from a planned but not-yet-implemented flow.

---

### 8. Markdown Import → Onboarding

**Entry point:** SettingsView → Import section → MigrationView

**Recent change:** Import no longer uses AI directly. The importer just reads `.md` files and extracts the project name from the first `# heading`. The raw markdown is then handed to OnboardingFlowManager as the brain dump text, where it goes through the normal onboarding discovery conversation.

There is also a `PromptTemplates.markdownImport()` method that returns a prompt for extracting structured project data from markdown files, but **it is never called anywhere** — dead code from the previous approach.

---

## Summary: What Uses What

| Feature | Conv. Type | Multi-turn? | Uses ContextAssembler | Uses ActionParser | Executes Actions | Creates Data |
|---------|-----------|-------------|----------------------|-------------------|------------------|-------------|
| Main Chat | varies | Yes | Yes | Yes | Yes (trust levels) | Via ActionExecutor |
| Onboarding Discovery | `.onboarding` | Yes (1–3) | Yes (exchange-aware) | Yes (structure only) | No (direct repo) | Phases/milestones/tasks/docs |
| Onboarding Doc Gen | N/A (direct) | No (1–2 shots) | No | No | No | Documents |
| Check-In | `.checkInQuickLog`/`.checkInFull` | No (single) | Yes | Yes | Yes (via confirmation) | CheckInRecord + actions |
| Project Review | `.review` | Yes | Yes | **No** | **No** | None (advisory) |
| Retrospective | `.retrospective` | Yes | Yes | **No** | **No** | Phase notes |
| Return Briefing | `.reEntry` | No (single) | Yes | No | No | None (display only) |
| Adversarial Review | N/A | Yes | **No** | **No** | **No** | Document updates |
| Vision Discovery | `.visionDiscovery` | Yes (planned) | Yes (exchange-aware) | No | No | Not wired up |

---

## The Problems / Questions to Discuss

### 1. Fragmentation
Every AI feature has its own manager class with its own way of calling the LLM:
- `ChatViewModel` — full pipeline (ContextAssembler → ActionParser → ActionExecutor)
- `OnboardingFlowManager` — partial pipeline (ContextAssembler → ActionParser, but custom execution)
- `CheckInFlowManager` — full pipeline + custom avoidance detection
- `ProjectReviewManager` — ContextAssembler only, ignores actions
- `RetrospectiveFlowManager` — ContextAssembler only, ignores actions
- `AdversarialReviewManager` — completely custom, bypasses everything

There's no shared "AI conversation manager" that these all build on. Each reimplements the call-parse-respond cycle.

### 2. Inconsistent Action Handling
The system prompt includes action block documentation in reviews and retrospectives, but those features never parse or execute actions. The AI is essentially being told "you can propose changes" and then having its proposals silently ignored. Should these features support actions? Or should their prompts omit the action block docs?

### 3. Duplicate Return Briefing
Both `ChatViewModel` and `RetrospectiveFlowManager` independently generate return briefings with nearly identical logic.

### 4. Unclear Stage Boundaries
When a user goes from idea capture → onboarding → active project → check-ins → review → retrospective, what exactly is each stage trying to achieve?

- **Quick Capture:** Just getting the idea down before it's forgotten. No AI. Clear.
- **Onboarding:** Is it trying to help the user develop the idea? Validate it? Generate a vision statement? Build a task hierarchy? All of the above? Right now it tries to do everything in 3 exchanges, which may not be enough.
- **Check-ins:** Is it tracking progress? Proposing actions? Detecting avoidance? Providing emotional support? It tries to do all of these simultaneously.
- **Reviews:** Portfolio-level health check. Advisory only — but should it propose actions?
- **Retrospective:** Reflective closure. But it includes action docs in the prompt despite never using them.

### 5. Document Generation Disconnected
Vision statements and technical briefs are generated as a side effect of onboarding, in a completely different pipeline than the main chat or check-in flows. They can be edited in the document editor but can't be regenerated through conversation. The adversarial review can revise them, but through yet another separate pipeline.

### 6. Vision Discovery — Unused Infrastructure
There's a full conversation type, prompts, and ContextAssembler support for `.visionDiscovery` that isn't connected to anything. Was this meant to replace part of onboarding? Be a separate post-import flow? It's unclear how it fits.

### 7. What Should the AI Know and When?
The ContextAssembler provides the same format of project context regardless of conversation type. But different contexts might benefit from different information emphasis:
- Onboarding: no project exists yet, so no context to provide
- Check-ins: recent activity is most relevant
- Reviews: cross-project patterns matter most
- Retrospectives: the full arc of the phase matters
- Return briefings: what was last discussed, what's blocked

### 8. The "What Are We Trying to Achieve" Question
At the highest level, the AI serves these purposes:
1. **Capture & structure** — help the user turn a messy idea into an organised project
2. **Ongoing support** — help the user stay engaged, track progress, surface issues
3. **Critical analysis** — identify problems the user hasn't considered
4. **Reflection** — help the user process completed/abandoned work

Are these the right categories? Should they have clearer boundaries? Should there be a more unified conversation system that can serve all these purposes, with the conversation type just changing the system prompt and available actions?
