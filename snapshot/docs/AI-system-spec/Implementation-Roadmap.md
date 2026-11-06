## Implementation Roadmap

**Purpose of this section:** To break the complete AI system redesign into concrete, sequenced modules that can each be built and tested independently before moving to the next. Each module defines what's being built, what it depends on, what the deliverable is, and what "done" looks like. This is the document that turns the specification into work.

---

### Sequencing Principles

The module order is driven by dependencies — each module builds on what came before. The sequencing also front-loads the foundational infrastructure that everything else needs, so that later modules can focus on behaviour and interaction rather than plumbing.

The general arc is:

1. **Data model and infrastructure** — the entities and systems that everything else runs on
2. **The unified pipeline** — the single conversation manager that replaces all current fragmented managers
3. **Mode implementations** — each mode's specific behaviour, built on the unified pipeline
4. **Integration and refinement** — connecting everything, handling edge cases, polishing

Within each module, the approach should be: build it, test it in isolation, verify it works, then move on. Don't try to integrate everything at once at the end — each module should be functional and testable on its own.

---

### Testing Strategy

Before building any modules, set up the testing infrastructure:

- A dedicated `AISystemV2` directory within the services layer for all new code. All new entities, managers, and services live here, isolated from the existing AI code until Module 11.
- A test target with mock LLM responses for unit testing. Mock responses should include correctly formatted signals, malformed signals, and edge cases. Never hit real APIs in automated tests.
- A hidden dev screen in the app (accessible from Settings) for manual integration testing against real API calls. This screen allows: selecting a project, choosing a mode, running a conversation through the new ConversationManager, and inspecting the resulting session and summary data.
- Prompt snapshot tests that capture the full composed prompt for each mode and fail if the prompt changes unexpectedly.

Each module's "done" criteria include both automated tests and a manual integration test through the dev screen.

The existing AI managers (ChatViewModel, OnboardingFlowManager, CheckInFlowManager, ProjectReviewManager, RetrospectiveFlowManager) remain in place and continue to serve the existing UI throughout development. They are only removed in Module 11 after all modes are verified working end-to-end.

---

### Module 1: Session Infrastructure

**What this builds:** The foundational data model and lifecycle management for sessions — the entity that every AI interaction in the system depends on.

**Dependencies:** None. This is the foundation.

**Existing state:** The database has existing `conversation` and `chatMessage` tables from the current system. These will be superseded by the new session model.

**What to build:**

- **Session entity** as a GRDB record with SQL migration: ID, project reference, mode, sub-mode, timestamps (created, last active, completed), completion status (active / paused / completed / auto-summarised), raw message history (array of message objects with role, content, timestamp).
- **SessionSummary entity** as a GRDB record: linked to Session, with structured fields matching the summary template defined in the Session Architecture — metadata, content established, content observed, what comes next, mode-specific additions. Store as structured data, not freeform text, so fields can be queried and assembled selectively.
- **Database migration:** Create the new `session` and `session_summary` tables with the full schema defined in the spec. Write a migration that converts existing `conversation` records into `session` records, mapping `conversationType` to the appropriate mode/sub-mode. Existing `chatMessage` records are preserved as the session's raw message history. Old tables are dropped after migration.
- **Session lifecycle state machine:** transitions between active → paused → completed and active → paused → auto-summarised. Enforce single active session per project.
- **Auto-summarisation background process:** monitor for paused sessions exceeding the timeout threshold (default 24 hours). When triggered, call the summary generation prompt with the session's message history and store the result. Mark session as auto-summarised. The background process runs on app launch and periodically while the app is active (every 15 minutes). If the summary API call fails, retry with exponential backoff up to 3 attempts. If all retries fail, mark the session as `pending-auto-summary` and retry on next app launch. If the app is quit before summarisation completes, the session remains in paused state and the background process catches it on next launch. A session is never lost — the raw message history persists regardless of whether summarisation succeeds.
- **Summary generation service:** a dedicated function that takes a session's message history and mode, sends the summary generation prompt to the API, parses the structured response, and stores it as a SessionSummary entity. Used both for normal session completion and auto-summarisation.

**What "done" looks like:** You can create sessions, add messages to them, transition them through lifecycle states, and generate structured summaries. The auto-summarisation process runs in the background and correctly handles stale sessions, including failure cases. Existing conversation data is migrated to the new session model. All of this works independently of any UI — it's pure infrastructure. Write tests that verify: session state transitions, summary generation from a mock conversation, auto-summarisation triggering after timeout, auto-summarisation retry on failure, single-active-session-per-project enforcement, migration of existing conversation records.

---

### Module 2: Process Profile and Typed Deliverables

**What this builds:** The data model for per-project process recommendations and status-tracked deliverables.

**Dependencies:** None directly, though it will integrate with sessions later.

**Existing state:** The database has an existing `document` table with a `type` column, plus a `documentVersion` table for version history.

**What to build:**

- **ProcessProfile entity** as a GRDB record: linked to Project, containing recommended deliverables (array of deliverable type + status), planning depth (enum: fullRoadmap / milestonePlan / taskList / openEmergent), suggested mode path, modification history, timestamps.
- **Deliverable entity** as a GRDB record: linked to Project, with type (enum from catalogue: visionStatement / technicalBrief / setupSpecification / researchPlan / creativeBrief), status (pending / inProgress / completed / revised), content (the document text), version history (array of previous versions with timestamps and change notes).
- **DeliverableTemplate registry:** a static registry that maps each deliverable type to its information requirements and document structure (from the Deliverable Catalogue). This is what gets injected into Layer 2 prompts during Definition mode. Store as structured data that can be formatted into prompt text.
- **Migration of existing documents:** Create the new deliverable schema with a migration that maps existing documents to the new typed deliverable model. Map existing type values to catalogue types where possible (e.g., existing vision statements become `visionStatement` type with status `completed`). Documents that don't map to a catalogue type become untyped documents — the system supports informal documents alongside typed deliverables.

**What "done" looks like:** Projects can have a process profile and typed deliverables. The deliverable template registry returns the correct templates for each type. Existing documents are migrated without data loss. Write tests that verify: process profile creation and modification, deliverable status transitions, template retrieval, migration of existing documents to typed deliverables.

---

### Module 3: Prompt System

**What this builds:** The three-layer prompt composition system and the mode-aware prompt loading.

**Dependencies:** Module 2 (for deliverable templates that get injected into Layer 2).

**What to build:**

- **Layer 1 Foundation prompt:** stored as a compiled default in the PromptTemplateStore. Includes the full foundation prompt as defined in the Prompt Architecture, with the action block reference appended. Overridable by the user in Settings.
- **Layer 2 Mode prompts:** one per mode (Exploration, Definition, Planning, Execution Support) plus sub-mode variants for Execution Support (check-in, return briefing, project review, retrospective). Stored as compiled defaults, overridable. Support `{{variable}}` substitution for dynamic content (deliverable templates, mode-specific context).
- **Summary generation prompt:** the dedicated prompt used for generating session summaries. Stored as a compiled default.
- **PromptComposer service:** takes a mode, sub-mode, and set of context variables, and produces the complete system prompt by loading Layer 1, loading and substituting the appropriate Layer 2, and providing the composed result. This replaces the current approach where each manager builds its own prompt.
- **Migration from current templates:** the existing 14 templates in PromptTemplateStore should be mapped to the new system. Some will be replaced entirely by the new Layer 2 prompts. Some (like the action block reference) will be incorporated into Layer 1. Dead templates (like the unused markdown import prompt) should be removed.
- **User override migration:** Check for existing user prompt overrides in UserDefaults. If any exist, preserve the custom text and map it to the closest new template key where possible. If no clean mapping exists, reset to the new default and display a one-time notification in Settings: "The prompt system has been updated. Your custom prompts have been reset — you can re-customise them in Settings."

**What "done" looks like:** The PromptComposer can produce a complete Layer 1 + Layer 2 system prompt for any mode and sub-mode, with variables correctly substituted. The old template system is migrated, including user overrides where possible. Write tests that verify: correct prompt composition for each mode, variable substitution, Layer 2 swapping, that the composed prompts match the specifications defined in the mode definitions. Include prompt snapshot tests that capture the full composed prompt for each mode configuration.

---

### Module 4: Context Assembler Upgrade

**What this builds:** The mode-aware context assembly system that produces Layer 3 project context.

**Dependencies:** Module 1 (sessions and summaries to assemble from), Module 2 (process profiles and deliverables to include), Module 3 (the prompt system it feeds into).

**What to build:**

- **Mode-aware context selection:** extend the ContextAssembler with a configuration per mode that specifies which context components to include, as defined in the Session Architecture's context assembly section. Each mode has a list of components (documents, session summaries, project structure, patterns, etc.) with priority levels for token budget management.
- **Session summary integration:** replace the current "last 3 check-ins" approach with the session summary system. Retrieve all session summaries for a project, format the most recent 2-3 in full and condense older ones to key observations and patterns. Mode determines how many and which summaries are emphasised.
- **Updated token budget:** The existing ContextAssembler uses an 8000 token default. This is increased as part of this module. The new target is 16,000-24,000 tokens total per request, with the system prompt (all three layers) allocated 3,000-8,000 tokens depending on mode complexity, conversation history up to 8,000-12,000 tokens, and a minimum 2,000-3,000 token response reserve. These are starting points to be tuned based on testing. Implement the priority-based truncation system: when total context exceeds budget, degrade lower-priority components (summarise documents instead of including full text, condense older summaries further, simplify project structure). Layer 1 and Layer 2 are never truncated.
- **Cross-session pattern computation:** implement the app-level pattern detection defined in the Session Architecture — days since last session, deferral trends, blocked task accumulation, engagement frequency. Format these as structured data for inclusion in Execution Support context.
- **Standard Layer 3 format:** output the context in the consistent format defined in the Prompt Architecture (PROJECT header, PROCESS PROFILE, DOCUMENTS, SESSION HISTORY, CURRENT STRUCTURE, PATTERNS AND OBSERVATIONS, ACTIVE SESSION CONTEXT).

**What "done" looks like:** The ContextAssembler produces correctly structured Layer 3 context for each mode, drawing on sessions, summaries, deliverables, and project structure. Token budget management correctly prioritises and truncates at the new budget levels. Pattern computation produces meaningful observations from session data. Write tests that verify: correct component selection per mode, token budget enforcement with the new limits, summary formatting, pattern detection from mock session data.

---

### Module 5a: Core Conversation Pipeline

**What this builds:** The core ConversationManager with the six-step pipeline, tested against a simple general chat mode. This proves the pipeline works end-to-end before adding mode complexity.

**Dependencies:** Modules 1-4 (the full infrastructure stack).

**What to build:**

- **ConversationManager service:** implements the six-step pipeline defined in the Architecture Overview (session initiation → context assembly → message handling → response processing → session completion → auto-summarisation). Mode-agnostic — the mode is a configuration parameter, not a code branch. Initially tested with a simple general chat mode.
- **Basic response parsing:** unified parsing of AI responses that handles natural language extraction and ACTION block parsing (when mode supports it). Uses the existing ActionParser infrastructure.
- **Action routing:** parsed actions go through the existing trust level system (ActionExecutor). The conversation manager determines whether to invoke action parsing based on mode configuration, then delegates to the existing confirmation/execution flow.
- **Session resumption:** when the user returns to a project with a paused session, the manager offers to resume it. If resuming, the full message history is loaded. If starting fresh, the paused session is completed (summary generated) and a new session begins.
- **Error handling for the conversation pipeline:**
  - **API failure (network/timeout):** Preserve the user's message locally. Display an error state with retry option. Session remains active. No message is added to history until the API call succeeds.
  - **Rate limiting:** Detect rate limit responses, display a user-friendly wait message with estimated retry time, auto-retry after the limit window.
  - **Partial/malformed responses:** If the response is truncated or contains malformed signals, display the natural language portion as-is and log the parsing failure. Don't crash the session. The user can continue the conversation normally.
  - **Stuck sessions (AI never signals completion):** Handled by design — the user can always manually end a session or request a mode transition. Auto-summarisation timeout also catches this. No special handling needed.

**What "done" looks like:** The ConversationManager can run a basic multi-turn conversation, correctly assembling context, sending messages, parsing responses, handling actions via the existing trust level system, and generating session summaries on completion. Error cases are handled gracefully. Old manager classes remain in place and continue to serve the existing UI. Write tests that verify: the full pipeline for a general chat session, action parsing and routing, session creation and resumption, error handling for API failures and malformed responses.

---

### Module 5b: Mode System and Response Processing

**What this builds:** The mode configuration registry, signal parsing, and mode transition handling that makes the ConversationManager mode-aware.

**Dependencies:** Module 5a (the working core pipeline).

**What to build:**

- **Mode configuration registry:** a registry that maps each mode (and sub-mode) to its configuration — which Layer 2 prompt to use, which context components to include, whether actions are parsed, which signals are expected, and what happens on mode completion.
- **Response signal parser:** implement a response signal parser alongside the existing ActionParser. This parser handles structured signals distinct from ACTION blocks:
  - `[MODE_COMPLETE: <mode>]` — signals current mode's criteria are met
  - `[PROCESS_RECOMMENDATION: <deliverables>]` — emitted with Exploration completion
  - `[PLANNING_DEPTH: <depth>]` — emitted with Exploration completion
  - `[PROJECT_SUMMARY: <text>]` — emitted with Exploration completion
  - `[DELIVERABLES_PRODUCED: <types>]` — emitted with Definition completion
  - `[DELIVERABLES_DEFERRED: <types>]` — emitted with Definition completion
  - `[STRUCTURE_SUMMARY: <text>]` — emitted with Planning completion
  - `[FIRST_ACTION: <text>]` — emitted with Planning completion
  - `[SESSION_END]` — signals end of an Execution Support session
  - `[DOCUMENT_DRAFT: <type>]...[/DOCUMENT_DRAFT]` — contains a document draft
  - `[STRUCTURE_PROPOSAL]...[/STRUCTURE_PROPOSAL]` — contains a structural proposal
  These use the same bracket notation as ACTION blocks but are parsed separately. The response parser should extract all signal types in a single pass, returning: natural language content, any ACTION blocks (for modes that support them), and any signals.
- **Mode transition handling:** when a MODE_COMPLETE signal is detected, the manager completes the current session (triggering summary generation), updates project metadata as appropriate (process profile from Exploration, deliverable status from Definition, project structure from Planning), and signals the UI to prompt the user about the next mode.

**What "done" looks like:** The ConversationManager can be configured for any mode, correctly parsing mode-specific signals, handling mode transitions, and updating project metadata on completion. The old manager classes remain in place. Write tests that verify: mode configuration loading for each mode, signal parsing for all signal types (including malformed signals), mode transition handling with metadata updates.

---

### Module 6: Exploration Mode

**What this builds:** The first mode implementation on top of the unified pipeline — the Exploration conversation that replaces the current onboarding discovery flow.

**Dependencies:** Module 5b (the mode-aware conversation manager).

**What to build:**

- **Exploration mode configuration:** register the mode with the ConversationManager — Layer 2 prompt, context selection rules (new project: capture transcript + portfolio list; re-entry: full project context), no action parsing, MODE_COMPLETE signal handling that extracts process recommendation.
- **Process recommendation parsing:** when the AI signals Exploration complete, parse the PROCESS_RECOMMENDATION and PLANNING_DEPTH signals. Create or update the project's Process Profile entity.
- **Entry points:**
  - From idea-state project (user chooses to develop a captured idea)
  - From new project creation (direct entry without prior capture)
  - From markdown import (imported content as starting context)
  - Re-entry on existing project (from project detail view or AI suggestion during Execution Support)
- **UI integration:** the conversation view for Exploration. This can likely reuse the existing ChatView with mode-aware configuration rather than being a completely separate view. The key UI additions are: mode indicator showing the user they're in Exploration, and the transition prompt when the AI signals completion. During development, add a feature flag or dev setting that switches between old and new for this mode.

**Integration checkpoint:** Wire Exploration mode to the test harness UI and run at least three real conversations that exercise the completion criteria, challenge network behaviour, and mode transition. Verify the AI's behaviour matches the mode specification. Fix any issues before proceeding to the next module.

**What "done" looks like:** A user can enter Exploration mode on a new or existing project, have a multi-turn conversation that works toward the completion criteria defined in the mode specification, and exit with a process recommendation stored against the project. The conversation feels natural and unscripted. Test by running actual Exploration conversations and verifying: the AI works toward completion criteria without following a rigid script, the process recommendation is sensible for different project types, the transition signal is correctly parsed and stored.

---

### Module 7: Definition Mode

**What this builds:** The Definition mode implementation — the collaborative document production flow, including the artifact presentation system.

**Dependencies:** Module 6 (Exploration, which produces the process recommendation that Definition works from).

**What to build:**

- **Definition mode configuration:** register with ConversationManager — Layer 2 prompt with deliverable template injection, context selection (Exploration summary, process recommendation, existing documents), no ACTION block parsing during conversation.
- **Deliverable template injection:** when a Definition session starts, the ContextAssembler injects the appropriate deliverable template (information requirements + document structure) into the Layer 2 prompt based on which deliverable is being worked on.
- **Artifact presentation system:** Build the artifact presentation system for the entire app. When the AI's response contains a `[DOCUMENT_DRAFT: <type>]...[/DOCUMENT_DRAFT]` block, the app extracts the content, renders it as a tappable inline artifact in the conversation, and allows the user to open it in an overlay for full review. Dismissing the overlay returns to the conversation. When a revised draft is produced, it replaces the previous artifact. Definition mode does not use ACTION blocks — document drafts are produced as content delineated with `[DOCUMENT_DRAFT: deliverable_type]...[/DOCUMENT_DRAFT]` signals. The app extracts this content and presents it as an artifact. The conversational portion sits outside these blocks. When the user approves a final version, the app saves the content as a Deliverable entity.
- **Deliverable status tracking:** as the user works through Definition, deliverable statuses update — pending → inProgress when the session starts, inProgress → completed when the user approves. The process profile tracks which deliverables have been produced and which are pending.
- **Multi-session support:** Definition might span multiple sessions (one per deliverable). Each session focuses on a specific deliverable. The mode persists across sessions until all recommended deliverables are produced or explicitly deferred.
- **View integration:** Update the corresponding existing view (or create a new one) to use the ConversationManager, display the mode indicator, handle artifact presentation, and show mode transition prompts. During development, add a feature flag or dev setting that switches between old and new for this mode.

**Integration checkpoint:** Wire Definition mode to the test harness UI and run at least three real conversations that exercise the completion criteria, challenge network behaviour, and mode transition. Verify the AI's behaviour matches the mode specification. Fix any issues before proceeding to the next module.

**What "done" looks like:** A user can enter Definition mode, work through each recommended deliverable collaboratively with the AI, review drafts as artifacts, provide feedback, and approve final versions. Deliverable status is correctly tracked. Multiple sessions within Definition work smoothly. Test by running actual Definition sessions for different deliverable types and verifying: the AI uses the template to guide conversation, drafts are presented as reviewable artifacts, the user can refine through dialogue, final documents are saved as typed Deliverable entities.

---

### Module 8: Planning Mode

**What this builds:** The Planning mode implementation — collaborative roadmap construction.

**Dependencies:** Module 7 (Definition, which produces the documents Planning works from, and the artifact presentation system).

**What to build:**

- **Planning mode configuration:** register with ConversationManager — Layer 2 prompt, context selection (documents, Exploration/Definition summaries), action parsing enabled for structure creation (CREATE_PHASE, CREATE_MILESTONE, CREATE_TASK, CREATE_SUBTASK).
- **Structural proposal artifacts:** Extend the artifact presentation system (built in Module 7) to also handle `[STRUCTURE_PROPOSAL]...[/STRUCTURE_PROPOSAL]` blocks, rendered as an indented hierarchy rather than prose. The user reviews, discusses, and the AI revises. Planning mode uses both mechanisms: conversational discussion of structure happens in natural language, the AI presents structural proposals using `[STRUCTURE_PROPOSAL]...[/STRUCTURE_PROPOSAL]` signals rendered as a reviewable hierarchy artifact, and once the user approves through conversation, the AI emits ACTION blocks (CREATE_PHASE, CREATE_MILESTONE, CREATE_TASK, etc.) to create the actual entities.
- **Progressive detail enforcement:** the Layer 2 prompt guides this, but the mode configuration should also track which phases have been detailed. The first two phases should have full task detail before the mode can signal completion.
- **Action execution for structure creation:** unlike Exploration and Definition, Planning creates actual project data. When the user approves a structural proposal, the actions create Phase, Milestone, Task, and Subtask entities in the database. This uses the existing ActionExecutor infrastructure.
- **First action identification:** when Planning completes, the FIRST_ACTION signal identifies the specific starting task. This task should be flagged or surfaced on the Focus Board as the entry point.
- **View integration:** Update the corresponding existing view (or create a new one) to use the ConversationManager, display the mode indicator, handle structural proposal artifacts, and show mode transition prompts. During development, add a feature flag or dev setting that switches between old and new for this mode.

**Integration checkpoint:** Wire Planning mode to the test harness UI and run at least three real conversations that exercise the completion criteria, challenge network behaviour, and mode transition. Verify the AI's behaviour matches the mode specification. Fix any issues before proceeding to the next module.

**What "done" looks like:** A user can enter Planning mode, collaboratively build a project roadmap through conversation, review structural proposals as artifacts, and approve them into the actual project hierarchy. The progressive detail principle is followed. The user exits Planning knowing exactly what their first task is. Test by running actual Planning sessions and verifying: the phase → milestone → task hierarchy is created correctly, progressive detail is applied (full detail for first two phases, lighter for third, sketches for later), the first action is identified and surfaced.

---

### Module 9: Execution Support Mode

**What this builds:** The Execution Support mode with its four sub-modes — the ongoing partnership that spans the project's active life.

**Dependencies:** Modules 6-8 (the earlier modes that produce the data Execution Support draws on).

**What to build:**

- **Execution Support mode configuration with sub-modes:** register with ConversationManager — separate Layer 2 prompt variants for check-in, return briefing, project review, and retrospective. Full action support for check-ins and project reviews.
- **Context-aware session opening:** when a check-in or return briefing starts, the AI opens with reference to the most recent session summary — what was discussed, what was committed to, what's changed. This requires the ContextAssembler to highlight the most recent summary prominently.
- **Return briefing trigger:** detect when a project hasn't had a session in 14+ days (configurable) and prompt the user with a return briefing option when they open the project. The return briefing uses the Return Briefing sub-mode prompt.
- **Avoidance detection:** retain and improve the existing mechanism — compare tasks discussed in a session against visible tasks to detect which were avoided. Increment deferred counters. Include deferred task data in context assembly so the AI can surface patterns.
- **Project review multi-project context:** when the project review sub-mode is active, the ContextAssembler gathers summary data across all focused projects (not just one). The AI evaluates portfolio health and can propose cross-project actions.
- **Retrospective trigger:** detect phase completion or project state changes (completed/paused/abandoned) and prompt for a retrospective session. The retrospective sub-mode uses the reflective prompt and captures learnings.
- **Mode transition suggestions:** when the AI detects during a check-in that a bigger intervention is needed (re-exploration, new document, plan restructure), it suggests it conversationally. If the user agrees, the session ends and the appropriate mode is initiated.
- **Process Profile modification:** the user can update their project's process profile in two ways. First, conversationally — during any Execution Support session, the user can say "I think we need a technical brief for this after all" and the AI proposes the update, which is saved to the process profile when accepted. Second, from the project detail view — add a "Process" section that shows the current process profile (recommended deliverables and their status, planning depth) with the ability to add or remove deliverables and change planning depth directly. Both paths update the same ProcessProfile entity.
- **View integration:** Update the corresponding existing views (or create new ones) to use the ConversationManager for each sub-mode, display mode/sub-mode indicators, and show mode transition prompts. During development, add feature flags or dev settings that switch between old and new for each sub-mode.

**Integration checkpoint:** Wire each sub-mode to the test harness UI and run at least three real conversations per sub-mode that exercise the completion criteria, challenge network behaviour, and mode transitions. Verify the AI's behaviour matches the mode specification. Fix any issues before proceeding to the next module.

**What "done" looks like:** All four sub-modes work through the unified pipeline. Check-ins are multi-turn and context-aware. Return briefings trigger appropriately and re-engage the user gently. Project reviews span the portfolio. Retrospectives capture reflective content. The AI suggests mode transitions when appropriate. Process profile modification works through both conversation and direct UI. Test each sub-mode independently, then test the transitions between Execution Support and other modes.

---

### Module 10: Adversarial Review Integration

**What this builds:** Connects the existing adversarial review system to the new architecture.

**Dependencies:** Module 7 (Definition — the deliverables that get reviewed) and Module 2 (typed deliverables that the review operates on). Can be built in parallel with Modules 8-9.

**What to build:**

- **Export from typed deliverables:** update the export mechanism to pull from the new Deliverable entities rather than freeform documents. The process profile determines which deliverables are included.
- **Synthesis session integration:** the synthesis step should run through the unified conversation pipeline, but with the specialised synthesis prompt rather than Layer 1 + Layer 2. Configure this as a special mode that bypasses the foundation prompt.
- **Document revision flow:** when synthesis produces revised documents, update the Deliverable entities — increment version, store the previous version in history, update status to "revised."
- **Adversarial review as a suggested step:** the AI can suggest an adversarial review at the end of Planning mode for complex projects. Add this suggestion to the Planning mode's transition logic.

**What "done" looks like:** The adversarial review works with the new typed deliverable system. Export correctly packages current deliverables. Synthesis produces revised documents that are stored with version history. The feature is accessible both from the AI's suggestion and from the project detail view.

---

### Module 11: Cleanup and Migration

**What this builds:** Removes deprecated code, migrates existing data, ensures everything is coherent, and wires the new system into the main app UI.

**Dependencies:** All previous modules.

**What to build:**

- **Remove deprecated manager classes:** ChatViewModel, OnboardingFlowManager, CheckInFlowManager, ProjectReviewManager, RetrospectiveFlowManager — all replaced by the ConversationManager.
- **Remove dead code:** the unused Vision Discovery infrastructure, the unused markdown import prompt, the duplicate return briefing implementation.
- **Remove feature flags:** all the old/new toggle flags added during mode module development. The new system becomes the only system.
- **Migrate existing check-in records:** Create a Session record for each CheckInRecord with mode `executionSupport`, sub-mode `checkIn`, status `completed`. Generate a SessionSummary by mapping existing fields: `aiSummary` becomes the "what was established" content, `tasksCompleted` maps to progress reported, `issuesFlagged` maps to patterns observed. Mark these summaries as `migrated-from-legacy` so the system knows they're less structured than natively generated summaries. The goal is to preserve historical context, not achieve perfect fidelity — these legacy summaries will gradually become less relevant as new sessions accumulate.
- **Migrate existing conversation history:** any persisted conversations from the old system that weren't already migrated in Module 1 should be converted to sessions with auto-generated summaries, preserving the project's history.
- **View migration:** Update all remaining views to use the new ConversationManager. Remove old view code and the feature flags that toggled between old and new. Ensure all entry points (Focus Board, project detail, settings) correctly navigate to the new mode-aware views.
- **Focus Board integration:** The Focus Board should surface mode-relevant information for each project. For idea-state projects not on the Focus Board, the ideas list shows a "Develop this idea" action that enters Exploration. For active projects, the project card indicates if there's an active or suggested mode action — "Definition in progress", "Ready for Planning", "Check-in suggested". The data is available from the process profile (deliverable status), session history (what's been completed), and mode transition signals (what's next). The specific UI treatment is a design decision to be resolved during Module 11 implementation.
- **Settings UI updates:** update the prompt override settings to reflect the new Layer 1 / Layer 2 structure. Add trust level configuration if not already present.
- **Remove inconsistent action handling:** remove action block documentation from prompts that never parsed actions (the old review and retrospective prompts). This is handled by the new mode configuration, which explicitly defines action availability per mode.
- **Comprehensive testing:** end-to-end test of the full flow — Capture → Exploration → Definition → Planning → Execution Support — on a real project. Verify that mode transitions work, context accumulates correctly, the AI's behaviour matches the mode specifications, and no data is lost.

**What "done" looks like:** The codebase is clean — no deprecated managers, no dead code, no inconsistent prompt configurations, no feature flags. Existing data is migrated and accessible through the new system. The Focus Board surfaces mode state. The full mode flow works end-to-end.

---

### Module Dependency Map

```
Modules 1, 2, 3 (parallel — no dependencies between them)
    ↓
Module 4: Context Assembler Upgrade
    ↓
Module 5a: Core Conversation Pipeline
    ↓
Module 5b: Mode System and Response Processing
    ↓
Modules 6 → 7 → 8 → 9 (linear — each mode builds on the previous)
              ↓
              Module 10 (can start after Module 7, parallel with 8-9)
    ↓
Module 11: Cleanup and Migration (after all others complete)
```

Modules 1-3 can be built in parallel since they don't depend on each other. Module 4 depends on all three. Module 5a builds the core pipeline, Module 5b adds mode awareness. Modes 6-9 are linear because each produces data the next one draws on. Module 10 only depends on Module 7 (Definition) and Module 2 (typed deliverables), so it can be built in parallel with Modules 8 and 9. Module 11 waits for everything else.

---

### Working With Claude Code

For each module, the workflow should be:

1. **Provide the master spec** as persistent reference context — the complete compiled document.
2. **Provide the specific module brief** as the focused task — the relevant section from this roadmap.
3. **Reference the relevant spec sections** that the module implements — point Claude Code to the specific mode definition, session architecture section, or prompt architecture section that governs what's being built.
4. **Build and test the module** before moving on. Each module's "done" criteria define what to verify.
5. **Run the integration checkpoint** (for mode modules 6-9) — wire to the test harness, run real conversations, verify behaviour.
6. **Review the output** against the spec. Does the implementation match the design? If there are deviations, are they improvements or errors?

The master spec exists so that Claude Code understands the overall system it's building into. The module brief exists so it knows what to build right now. Both are needed — the spec for coherence, the module for focus.
