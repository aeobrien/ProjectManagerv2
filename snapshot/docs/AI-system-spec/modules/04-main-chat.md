# 1. Main AI Chat

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
