# 3. Check-In

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
