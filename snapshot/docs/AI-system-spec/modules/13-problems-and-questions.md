# The Problems / Questions to Discuss

## 1. Fragmentation
Every AI feature has its own manager class with its own way of calling the LLM:
- `ChatViewModel` — full pipeline (ContextAssembler → ActionParser → ActionExecutor)
- `OnboardingFlowManager` — partial pipeline (ContextAssembler → ActionParser, but custom execution)
- `CheckInFlowManager` — full pipeline + custom avoidance detection
- `ProjectReviewManager` — ContextAssembler only, ignores actions
- `RetrospectiveFlowManager` — ContextAssembler only, ignores actions
- `AdversarialReviewManager` — completely custom, bypasses everything

There's no shared "AI conversation manager" that these all build on. Each reimplements the call-parse-respond cycle.

## 2. Inconsistent Action Handling
The system prompt includes action block documentation in reviews and retrospectives, but those features never parse or execute actions. The AI is essentially being told "you can propose changes" and then having its proposals silently ignored. Should these features support actions? Or should their prompts omit the action block docs?

## 3. Duplicate Return Briefing
Both `ChatViewModel` and `RetrospectiveFlowManager` independently generate return briefings with nearly identical logic.

## 4. Unclear Stage Boundaries
When a user goes from idea capture → onboarding → active project → check-ins → review → retrospective, what exactly is each stage trying to achieve?

- **Quick Capture:** Just getting the idea down before it's forgotten. No AI. Clear.
- **Onboarding:** Is it trying to help the user develop the idea? Validate it? Generate a vision statement? Build a task hierarchy? All of the above? Right now it tries to do everything in 3 exchanges, which may not be enough.
- **Check-ins:** Is it tracking progress? Proposing actions? Detecting avoidance? Providing emotional support? It tries to do all of these simultaneously.
- **Reviews:** Portfolio-level health check. Advisory only — but should it propose actions?
- **Retrospective:** Reflective closure. But it includes action docs in the prompt despite never using them.

## 5. Document Generation Disconnected
Vision statements and technical briefs are generated as a side effect of onboarding, in a completely different pipeline than the main chat or check-in flows. They can be edited in the document editor but can't be regenerated through conversation. The adversarial review can revise them, but through yet another separate pipeline.

## 6. Vision Discovery — Unused Infrastructure
There's a full conversation type, prompts, and ContextAssembler support for `.visionDiscovery` that isn't connected to anything. Was this meant to replace part of onboarding? Be a separate post-import flow? It's unclear how it fits.

## 7. What Should the AI Know and When?
The ContextAssembler provides the same format of project context regardless of conversation type. But different contexts might benefit from different information emphasis:
- Onboarding: no project exists yet, so no context to provide
- Check-ins: recent activity is most relevant
- Reviews: cross-project patterns matter most
- Retrospectives: the full arc of the phase matters
- Return briefings: what was last discussed, what's blocked

## 8. The "What Are We Trying to Achieve" Question
At the highest level, the AI serves these purposes:
1. **Capture & structure** — help the user turn a messy idea into an organised project
2. **Ongoing support** — help the user stay engaged, track progress, surface issues
3. **Critical analysis** — identify problems the user hasn't considered
4. **Reflection** — help the user process completed/abandoned work

Are these the right categories? Should they have clearer boundaries? Should there be a more unified conversation system that can serve all these purposes, with the conversation type just changing the system prompt and available actions?
