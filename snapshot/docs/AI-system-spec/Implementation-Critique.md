# Critique of the AI System Spec + Implementation Roadmap

This document reviews the AI-System-Complete-Spec and Implementation-Roadmap against the existing codebase, identifying issues, inconsistencies, conflicts, and potential implementation problems.

---

## A. Data Model Conflicts

### 1. "SwiftData" vs GRDB — the spec is wrong throughout

The spec repeatedly says "SwiftData" for new entities (Session, SessionSummary, ProcessProfile, Deliverable). But CLAUDE.md explicitly states SwiftData was rejected in favour of **GRDB**, and the entire existing persistence layer (`DatabaseManager.swift`) uses GRDB with raw SQL migrations. Every mention of "SwiftData" in the roadmap modules needs to be changed to GRDB records + migrations. This isn't cosmetic — the approach to schema definition, querying, relationships, and migrations is fundamentally different.

### 2. Conversation table already exists

Module 1 designs a "Session" entity from scratch, but the database already has a `conversation` table (with `id`, `projectId`, `conversationType`, timestamps) and a `chatMessage` table. The roadmap doesn't acknowledge these existing tables. You need to decide: migrate the existing `conversation` table into the new `Session` entity, or add `session` as a new table alongside it? If the latter, what happens to existing conversation data? The roadmap's Module 11 mentions migration but Module 1 should be designed with this in mind from the start.

### 3. Document table already has a `type` field

Module 2 treats typed deliverables as entirely new, but the existing `document` table already has a `type` column. The roadmap should acknowledge this and define how existing document types map to the new deliverable catalogue types.

### 4. CheckInRecord → Session migration is underspecified

Module 11 says "convert existing CheckInRecord data into Session + SessionSummary entities." But CheckInRecords are single-shot (one user message + one AI response) while Sessions are multi-turn with structured summaries. The mapping isn't straightforward — what becomes the "summary" for a CheckInRecord that only has `aiSummary` (a freeform string) and `tasksCompleted`/`issuesFlagged` (JSON arrays)?

---

## B. Architectural Concerns

### 5. Module 5 is too large and risky

The Unified Conversation Manager (Module 5) replaces *five* existing managers simultaneously. It depends on Modules 1-4, and Modules 6-11 all depend on it. This is the highest-risk module in the entire plan, and it's described as a single deliverable. If it goes wrong, everything downstream is blocked.

**Suggestion:** Split Module 5 into two parts:
- **5a:** The core ConversationManager with the 6-step pipeline, tested with a single mode (e.g. General chat, which is the simplest)
- **5b:** Mode configuration system, response parser upgrades (MODE_COMPLETE signals), and mode transition handling

### 6. "Deprecation of existing managers" is premature in Module 5

The roadmap says Module 5 should replace ChatViewModel, OnboardingFlowManager, etc. But those managers are the *only* working AI flows. If you delete them before Modules 6-9 are built, you have no working AI features for potentially weeks. The old managers should coexist with the new ConversationManager until Module 11, with the new system being built and tested in the isolated harness. The roadmap says this implicitly but Module 5's "done" criteria contradict it by saying "the old manager classes are no longer used."

### 7. No incremental integration strategy

The roadmap is build-build-build for 11 modules, then integrate at the end in Module 11. This is risky. Each mode module (6-9) should include a step where it's tested against the *real* UI (not just unit tests) before moving to the next. A testing harness is the right approach — but the roadmap should explicitly call out integration checkpoints.

---

## C. Spec Inconsistencies

### 8. Token budget contradicts itself

The spec says "Token budget management: 8000 tokens default" in the existing ContextAssembler section, but later says "Total Token Budget: 16,000-24,000 tokens per request." The roadmap doesn't specify which is correct or when to change it. Module 4 (Context Assembler Upgrade) should explicitly define the new token budget.

### 9. Action support in modes is contradictory

- **Module 6 (Exploration):** "no action parsing" — correct per spec.
- **Module 7 (Definition):** "no action parsing during conversation" — but then how does the AI produce document drafts? The spec says documents are presented as "artifacts" but the mechanism isn't defined. Is it a special block format? A signal? Plain markdown in the response?
- **Module 8 (Planning):** "action parsing enabled for structure creation" — but also says structural proposals are presented as "artifacts" for review. So are they ACTION blocks or artifacts? The spec seems to want both, which needs clarification.

### 10. "Artifact presentation system" is undefined

Modules 7 and 8 both reference an "artifact presentation system" for documents and structural proposals. This is a significant UI feature that doesn't appear in any module's "what to build" list as a concrete deliverable. Who builds it? When? It needs its own work item, probably inside Module 7 since that's where it's first needed.

### 11. MODE_COMPLETE signal parsing — where does it live?

The spec defines `[MODE_COMPLETE: exploration]` signals, but the existing ActionParser only handles `[ACTION: TYPE]...[/ACTION]` blocks. Module 5 mentions a "unified response parser" but doesn't detail how MODE_COMPLETE, PROCESS_RECOMMENDATION, PROJECT_SUMMARY, SESSION_END, and FIRST_ACTION signals are parsed. Are these new ACTION types? A different regex? This needs to be specified.

---

## D. Missing or Underspecified Areas

### 12. No error handling strategy

What happens when an LLM call fails mid-session? The current LLMClient has retry logic, but the spec doesn't address:
- Partial responses (network timeout mid-stream)
- API rate limiting during multi-turn sessions
- Malformed MODE_COMPLETE signals
- The AI never emitting a completion signal (stuck session)

Module 5 should define fallback behaviours for all of these.

### 13. Auto-summarisation has no failure mode

Module 1 defines auto-summarisation for stale sessions but doesn't address: what if the summary API call fails? Does it retry? How often does the background process check? What if the app is quit before summarisation completes? Is it a background task that runs on app launch?

### 14. No cost/performance consideration

The spec adds a summary generation API call at the end of every session. That's an additional LLM call per conversation. For a user doing multiple check-ins per day across several projects, plus auto-summarisation of stale sessions, the API cost could increase significantly. The roadmap should note this and consider whether summaries could be generated locally or deferred.

### 15. Process Profile modification flow is vague

Module 2 defines the ProcessProfile entity but doesn't specify the UI or mechanism for modifying it. The spec says it "can be updated user-initiated or AI-suggested during Execution Support" — but Module 9 (Execution Support) doesn't list this as something to build. How does the user change their process profile? Through conversation? A settings screen? Both?

### 16. No versioning strategy for the prompt system

Module 3 replaces 14 templates with a new Layer 1/2/3 system. Users can override prompts via UserDefaults. What happens to existing user overrides when the template keys change? The migration needs to either preserve them (mapped to new keys) or reset them with a notification.

---

## E. Testing Harness Considerations

### 17. The roadmap's "write tests" guidance is too vague

Each module ends with "write tests that verify X, Y, Z" but doesn't specify the testing approach. Given we want an isolated testing harness, the roadmap should specify:
- A dedicated test target/scheme separate from the main app
- Mock LLM responses (don't hit real APIs in tests)
- A test harness UI within the app (a hidden dev screen) for manual integration testing of each module against real API calls
- Snapshot testing for prompt composition (so you can verify prompts don't change unexpectedly)

### 18. Module ordering allows more parallelism than stated

The roadmap says Modules 1-3 can be parallel, then everything is linear. But Module 6 (Exploration) doesn't *actually* depend on all of Module 5 — it only needs the ConversationManager's basic pipeline. And Module 10 (Adversarial Review Integration) doesn't depend on Modules 8 or 9 at all, only on Module 7 (Definition) and Module 2 (Deliverables). The dependency map is over-constrained.

---

## F. Integration with Existing App

### 19. No mention of how existing UI wires to new system

The spec describes replacing managers but doesn't address the views. ChatView, OnboardingView, CheckInView, ProjectReviewView, RetrospectiveView all exist and are wired to the old managers. Module 11 should include a view migration step, or each mode module (6-9) should include updating the corresponding view.

### 20. Focus Board integration is missing

The Focus Board is the app's primary view and the main entry point for AI interactions. The roadmap doesn't address how the new mode system integrates with it. Where does the user see "this project is in Exploration mode"? Where do mode transition prompts appear? This is a UX design question that affects implementation.

---

## Summary of Priority Issues

| Priority | Issue | Affects |
|----------|-------|---------|
| **Critical** | SwiftData references should be GRDB | All modules |
| **Critical** | Module 5 too large, needs splitting | Modules 5-11 |
| **High** | Existing conversation/document tables not accounted for | Modules 1-2 |
| **High** | Artifact presentation system undefined | Modules 7-8 |
| **High** | MODE_COMPLETE signal parsing unspecified | Module 5 |
| **High** | No incremental integration strategy | All modules |
| **Medium** | Token budget contradiction | Module 4 |
| **Medium** | Error handling absent | Module 5 |
| **Medium** | Action support in Definition/Planning contradictory | Modules 7-8 |
| **Medium** | Auto-summarisation failure modes | Module 1 |
| **Low** | Process Profile modification flow vague | Modules 2, 9 |
| **Low** | Dependency map over-constrained | Scheduling |
| **Low** | Prompt versioning migration | Module 3 |

---

## Recommended Approach: Testing Harness

When building begins, set up an isolated `AISystemV2` directory within PMServices with its own test target, plus a hidden dev screen in the app for manual testing against real API calls. Each module gets built and tested in isolation before any existing code is touched. The old managers continue to work throughout development. Integration happens incrementally, one mode at a time, with the old manager only removed once its replacement is verified working end-to-end.
