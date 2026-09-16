Good critique — you've caught some genuine issues. Let me respond to each point with specific instructions for amendments.

---

## A. Data Model Conflicts

**1. SwiftData → GRDB**

You're right, this is an error throughout. Do a global replacement: every reference to "SwiftData" becomes "GRDB". Every mention of entities should reference GRDB records with SQL migrations. The entity designs (fields, relationships) remain the same — this is a terminology and implementation approach correction, not a schema change.

**2. Existing conversation table**

We're implementing the new Session model as the replacement, not building around the old tables. Amend Module 1's brief: "The database has existing `conversation` and `chatMessage` tables. Create the new `session` and `session_summary` tables with the full schema defined in the spec. Write a migration that converts existing conversation records into session records, mapping `conversationType` to the appropriate mode/sub-mode. Existing chat messages are preserved as the session's raw message history. Old tables are dropped after migration."

**3. Existing document type field**

Same approach — implement the new version. Amend Module 2's brief: "The existing `document` table has a `type` column. Create the new deliverable schema as specified, with a migration that maps existing documents to the new typed deliverable model. Map existing type values to catalogue types where possible (e.g., existing vision statements become `visionStatement` type with status `completed`). Documents that don't map to a catalogue type become untyped documents — the system supports informal documents alongside typed deliverables."

**4. CheckInRecord migration underspecified**

Amend Module 11's brief: "CheckInRecord migration: create a Session record for each CheckInRecord with mode `executionSupport`, sub-mode `checkIn`, status `completed`. Generate a SessionSummary by mapping existing fields: `aiSummary` becomes the 'what was established' content, `tasksCompleted` maps to progress reported, `issuesFlagged` maps to patterns observed. Mark these summaries as `migrated-from-legacy` so the system knows they're less structured than natively generated summaries. The goal is to preserve historical context, not achieve perfect fidelity — these legacy summaries will gradually become less relevant as new sessions accumulate."

---

## B. Architectural Concerns

**5. Module 5 too large**

Agreed. Split Module 5 into two:

**Module 5a: Core Conversation Pipeline** — Build the ConversationManager with the six-step pipeline, tested against a simple general chat mode. This proves the pipeline works: session creation, context assembly, message handling, response display, session completion with summary generation. No mode transitions, no MODE_COMPLETE parsing, no action routing yet — just the basic conversation loop.

**Module 5b: Mode System and Response Processing** — Add mode configuration registry, MODE_COMPLETE signal parsing (see point 11 below for the full signal spec), mode transition handling, action routing based on mode configuration, and session resumption logic. This builds on 5a's working pipeline.

Update the dependency map so Module 6 depends on 5b.

**6. Premature deprecation**

Agreed. Revise Module 5's "done" criteria. Remove "the old manager classes are no longer used." Replace with: "The ConversationManager can run conversations in any mode through the unified pipeline. Old manager classes remain in place and continue to serve the existing UI. The new system is built and tested in isolation alongside the old system. Deprecation happens in Module 11 after all modes are verified."

**7. No incremental integration strategy**

Agreed. Add an integration checkpoint to each mode module (6-9). After each module is built and unit tested, it should be wired to the test harness with real API calls and verified end-to-end with real conversations. Add to each module brief: "Integration checkpoint: wire this mode to the test harness UI and run at least three real conversations that exercise the completion criteria, challenge network behaviour, and mode transition. Verify the AI's behaviour matches the mode specification. Fix any issues before proceeding to the next module."

---

## C. Spec Inconsistencies

**8. Token budget contradiction**

The 8000 figure describes the current system, not the target. In the Session Architecture and Prompt Architecture sections, add a note: "The existing ContextAssembler uses an 8000 token default. This is increased as part of Module 4. The new target is 16,000-24,000 tokens total per request, with the system prompt (all three layers) allocated 3,000-8,000 tokens depending on mode complexity, conversation history up to 8,000-12,000 tokens, and a minimum 2,000-3,000 token response reserve. These are starting points to be tuned based on testing." Annotate or remove the 8000 reference so it's clearly labelled as the old value being replaced.

**9. Action support in Definition/Planning contradictory**

Here's the resolution:

**Definition mode** does not use ACTION blocks at all. Document drafts are produced as content within the AI's response, delineated with `[DOCUMENT_DRAFT: deliverable_type]...[/DOCUMENT_DRAFT]` signals. The app extracts this content and presents it as an artifact. The conversational portion sits outside these blocks. When the user approves a final version, the app saves the content as a Deliverable entity.

**Planning mode** uses both mechanisms. Conversational discussion of structure happens in natural language. The AI presents structural proposals using `[STRUCTURE_PROPOSAL]...[/STRUCTURE_PROPOSAL]` signals, which the app renders as a reviewable hierarchy artifact. Once the user approves through conversation, the AI emits ACTION blocks (CREATE_PHASE, CREATE_MILESTONE, CREATE_TASK, etc.) to create the actual entities.

Add this clarification to both mode definitions and the Prompt Architecture section. Define the `DOCUMENT_DRAFT` and `STRUCTURE_PROPOSAL` signal formats alongside the existing ACTION block format.

**10. Artifact presentation system undefined**

Add this to Module 7's brief as a concrete deliverable: "Build the artifact presentation system. When the AI's response contains a `[DOCUMENT_DRAFT]...[/DOCUMENT_DRAFT]` block, the app extracts the content, renders it as a tappable inline artifact in the conversation, and allows the user to open it in an overlay for full review. Dismissing the overlay returns to the conversation. When a revised draft is produced, it replaces the previous artifact. Extend this in Module 8 to also handle `[STRUCTURE_PROPOSAL]...[/STRUCTURE_PROPOSAL]` blocks, rendered as an indented hierarchy rather than prose."

**11. MODE_COMPLETE signal parsing**

Add to Module 5b's brief: "Implement a response signal parser alongside the existing ActionParser. This parser handles structured signals distinct from ACTION blocks:

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

These use the same bracket notation as ACTION blocks but are parsed separately. The response parser should extract all signal types in a single pass, returning: natural language content, any ACTION blocks (for modes that support them), and any signals."

---

## D. Missing or Underspecified Areas

**12. No error handling strategy**

Add to Module 5a's brief: "Define error handling for the conversation pipeline:
- **API failure (network/timeout):** Preserve the user's message locally. Display an error state with retry option. Session remains active. No message is added to history until the API call succeeds.
- **Rate limiting:** Detect rate limit responses, display a user-friendly wait message with estimated retry time, auto-retry after the limit window.
- **Partial/malformed responses:** If the response is truncated or contains malformed signals, display the natural language portion as-is and log the parsing failure. Don't crash the session. The user can continue the conversation normally.
- **Stuck sessions (AI never signals completion):** Handled by design — the user can always manually end a session or request a mode transition. Auto-summarisation timeout also catches this. No special handling needed."

**13. Auto-summarisation failure mode**

Add to Module 1's brief: "Auto-summarisation failure handling: the background process runs on app launch and periodically while the app is active (every 15 minutes). If the summary API call fails, retry with exponential backoff up to 3 attempts. If all retries fail, mark the session as `pending-auto-summary` and retry on next app launch. If the app is quit before summarisation completes, the session remains in paused state and the background process catches it on next launch. A session is never lost — the raw message history persists regardless of whether summarisation succeeds."

**14. Cost/performance consideration**

This doesn't require a design change but add a note to the Session Architecture section: "Summary generation adds one additional API call per session. This is a lightweight call (small prompt, 300-600 token response) and the cost is marginal relative to the multi-turn conversation calls within the session itself. If cost becomes a concern, summaries could be generated using a smaller model (Sonnet or Haiku) since the task is structured extraction rather than creative reasoning. This is an optimisation that can be applied later without changing the architecture."

**15. Process Profile modification flow**

Add to Module 9's brief: "Process Profile modification: the user can update their project's process profile in two ways. First, conversationally — during any Execution Support session, the user can say 'I think we need a technical brief for this after all' and the AI proposes the update, which is saved to the process profile when accepted. Second, from the project detail view — add a 'Process' section that shows the current process profile (recommended deliverables and their status, planning depth) with the ability to add or remove deliverables and change planning depth directly. Both paths update the same ProcessProfile entity."

**16. Prompt versioning migration**

Add to Module 3's brief: "Check for existing user prompt overrides in UserDefaults. If any exist, preserve the custom text and map it to the closest new template key where possible. If no clean mapping exists, reset to the new default and display a one-time notification in Settings: 'The prompt system has been updated. Your custom prompts have been reset — you can re-customise them in Settings.'"

---

## E. Testing

**17. Testing guidance too vague**

Add a new section to the Implementation Roadmap — "Testing Strategy" — positioned before Module 1:

"**Testing Strategy:**

Before building any modules, set up the testing infrastructure:
- A dedicated `AISystemV2` directory within the services layer for all new code
- A test target with mock LLM responses for unit testing. Mock responses should include correctly formatted signals, malformed signals, and edge cases. Never hit real APIs in automated tests.
- A hidden dev screen in the app (accessible from Settings) for manual integration testing against real API calls. This screen allows: selecting a project, choosing a mode, running a conversation through the new ConversationManager, and inspecting the resulting session and summary data.
- Prompt snapshot tests that capture the full composed prompt for each mode and fail if the prompt changes unexpectedly.

Each module's 'done' criteria include both automated tests and a manual integration test through the dev screen."

**18. Dependency map over-constrained**

Partially agreed. Update the dependency map:

```
Modules 1, 2, 3 (parallel)
    ↓
Module 4
    ↓
Module 5a
    ↓
Module 5b
    ↓
Modules 6 → 7 → 8 → 9 (linear)
              ↓
              Module 10 (can start after Module 7, parallel with 8-9)
    ↓
Module 11 (after all others complete)
```

---

## F. Integration with Existing App

**19. No view migration plan**

Add to each mode module (6-9): "View integration: update the corresponding existing view (or create a new one if none exists) to use the ConversationManager instead of the old manager. The view should display the mode indicator, handle artifact presentation, and show mode transition prompts. During development, add a feature flag or dev setting that switches between old and new for that mode. Module 11 removes the old views and the feature flag."

**20. Focus Board integration missing**

Add to Module 11's brief: "Focus Board integration: the Focus Board should surface mode-relevant information for each project. For idea-state projects not on the Focus Board, the ideas list shows a 'Develop this idea' action that enters Exploration. For active projects, the project card indicates if there's an active or suggested mode action — 'Definition in progress', 'Ready for Planning', 'Check-in suggested'. The data is available from the process profile (deliverable status), session history (what's been completed), and mode transition signals (what's next). The specific UI treatment is a design decision to be resolved during Module 11 implementation."

---

Apply all of these amendments to the spec and roadmap documents. The critical structural changes are: GRDB throughout, Module 5 split into 5a and 5b, the artifact/signal system defined as concrete deliverables, integration checkpoints added to every mode module, and the testing strategy section added before Module 1.