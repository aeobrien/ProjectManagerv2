# 5. Retrospective

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
