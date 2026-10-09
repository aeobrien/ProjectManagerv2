# Project Manager

**Vision Statement & Conceptual Glossary**
*Revised after adversarial review*

---

## 1. Overall Intention (Vision Statement)

The purpose of this system is to **turn ideas into finished things**.

It exists to:

* capture ideas thoroughly enough that they don't need to live in your head,
* break ambitious projects down into concrete, achievable steps,
* maintain focus on a small number of active projects at a time,
* make progress visible and momentum sustainable,
* and provide an AI collaborator that understands each project deeply enough to help at every stage — from the initial spark through to completion.

This is **not** a project tracker. Tracking is a side effect, not the goal. The system is biased toward **action over motion** — toward practical steps that move a project forward, not administrative overhead that feels like progress but isn't. Planning is valuable only insofar as it makes doing easier. If maintaining the system ever feels like a chore, the system has failed.

The system is explicitly designed for a user with ADHD and executive dysfunction. This is not an afterthought or an accessibility layer — it is a **foundational design principle** that shapes every interaction. Specifically:

* **Minimal friction everywhere.** Every interaction should feel like it's moving you forward, not like administrative overhead. Voice input is the primary interaction mode. Check-ins are conversations, not forms.
* **Small, concrete steps.** Large ambiguous tasks cause paralysis. The system breaks everything down into steps where the next action is always obvious and achievable.
* **Visible, frequent progress markers.** Ticking things off provides momentum. The hierarchy is designed so there are always things to complete, even within larger efforts.
* **Protection against novelty-seeking.** New ideas are exciting and dangerous. The system provides a structured way to capture and plan new ideas that scratches the itch without derailing current focus. Getting the idea down — defined, structured, and saved — is enough. It's there to come back to. Critically, the capture process itself must not become the distraction — a 30-second voice note must always be an option (see Quick Capture).
* **No sustained willpower required.** The system works on bad days. It doesn't require discipline to maintain. It doesn't punish inconsistency. It adapts.
* **Friction should never create shame or resistance to opening the app.** The system's constraints (focus limits, diversity rules, check-in prompts) exist to help, not judge. If any element of the system makes the user dread opening it, that element has failed — regardless of how theoretically sound it is.

### The Goal of the Goal

The deeper purpose is twofold:

1. **Complete more projects.** Not by working harder, but by being more systematic — knowing what the next step is, knowing where it fits, knowing what "done" looks like, and having a collaborator that helps you stay on track.

2. **Reduce the cognitive load of having many ideas.** Ideas that live only in your head compete for attention, cause anxiety, and create a persistent sense of being behind. Ideas that are captured, defined, and stored in a trusted system can be set aside with confidence. They haven't vanished. They're there when you're ready.

The system succeeds when projects actually finish, when good ideas don't get lost, and when having 40 projects in various states feels manageable rather than overwhelming.

---

## 2. Core Design Principles

1. **Action over motion** — Planning is only valuable if it leads to doing. The system is biased toward getting started, not perfecting the plan.
2. **The system adapts to you — you do not adapt to the system** — If you're fighting the structure, that's a design failure, not a user failure.
3. **Avoidance is information, not failure** — A stalled project is a signal to investigate, not a reason to feel guilty. The system surfaces patterns without judgement.
4. **Honesty is designed for, not demanded** — Progress check-ins should feel like talking to a thoughtful collaborator, not a performance review. Honest reporting leads to better support; dishonest reporting leads to worse recommendations.
5. **Capture the spark, protect the focus** — New ideas get captured fast (as fast as a 30-second voice note) so they feel properly recorded. Then they wait their turn. The excitement of a new idea should never override the commitment to current work. Equally, the capture process itself should never become an extended distraction from current work.
6. **If it can't be measured, it's underspecified** — Every task needs a clear definition of done. Every milestone needs a clear end state. Vagueness is the enemy of progress. *Exception: creative and exploratory work may use timeboxed sessions as a valid alternative to binary completion criteria (see Timeboxing).*
7. **Friction in the right places** — Low friction for doing work, checking in, and capturing ideas. Higher friction for switching active projects, abandoning commitments, or starting new things before finishing current ones.
8. **Time pessimism by default** — Estimates are systematically optimistic (the planning fallacy). The system builds in realistic buffers and learns from the gap between estimated and actual effort over time.
9. **Accountability through partnership, not surveillance** — The AI is a collaborator that notices patterns, asks good questions, and creates gentle accountability — not an overseer that judges performance. The system never tracks streaks, never gamifies progress, and never presents comparative productivity metrics. Analytics exist for reflection, not evaluation.
10. **Completeness over perfection** — A finished project that's 80% of the original vision is worth more than an unfinished project that's pursuing 100%. The system should help recognise when "good enough" is genuinely good enough, and the AI should be able to suggest simplifying a definition of done when perfectionism is stalling progress.
11. **Data belongs to the user** — The system asks for deep trust. That trust requires knowing the data is portable, exportable, and safe. The user must always be able to extract their project data, documentation, and history in a usable format.

---

## 3. High-Level System Shape

The system consists of three layers:

### 1. Project Intelligence (AI Collaborator)

The AI layer that understands each project deeply and assists at every stage.

Responsibilities:

* Guide the initial brain dump and discovery process for new projects
* Help define vision, scope, milestones, and tasks through collaborative conversation
* Conduct adversarial review of plans (scaled to project complexity)
* Provide ongoing check-in conversations with full project context
* Notice patterns — stalled projects, avoidance, poorly defined tasks, unrealistic estimates
* Suggest task decomposition when things feel stuck
* Suggest scope reduction when perfectionism is stalling progress
* Update project documentation based on voice check-ins
* Generate return briefings when re-entering dormant projects
* For software projects: coordinate with external coding tools (e.g. Claude Code) that can update progress automatically

The AI has access to all project data: vision statements, technical briefs, milestones, tasks, progress history, and check-in transcripts. When you talk to it about a project, it already knows the full context. You never start from scratch.

The AI is **not** an autonomous agent. It does not make changes without the user's involvement. It proposes, suggests, questions, and updates documentation — but the user drives decisions.

**The AI adapts its behaviour to the user's current state.** On a bad day, when the user just wants to log what happened and move on, the AI should not surface avoidance patterns, suggest decomposition, or probe for problems. It should accept the update, confirm it, and let the user go. Pattern detection and deeper analysis are for good days and dedicated review sessions — not for every interaction. The user can control the depth of check-ins (quick log vs full conversation), and the AI should default to matching the user's energy rather than always pushing for depth.

---

### 2. Project Structure (Data & Organisation)

The core data model that represents projects and their components.

Responsibilities:

* Store the full hierarchy: Projects → Phases → Milestones → Tasks → Subtasks
* Maintain project metadata: vision statements, technical briefs, categories, deadlines, time estimates
* Track progress, blocked/waiting states, and completion
* Enforce focus limits and diversity constraints
* Provide the Focus Board view
* Sync relevant data to the Life Planner system
* Support full data export in a portable format

This layer is the **single source of truth** for all project data. It replaces the previous Markdown-based system with a proper database (see Technical Considerations).

---

### 3. User Interface (macOS + iOS)

The surface through which the user interacts with everything.

Responsibilities:

* Display the Focus Board (Kanban view of active project tasks)
* Provide project browsing, searching, and filtering across the full project pool
* Host the AI chat interface for brain dumps, check-ins, and planning conversations
* Display and allow editing of project documentation (vision statements, technical briefs)
* Show the roadmap view (chronological display of phases, milestones, and tasks)
* Accept voice input as the primary interaction mode, with text as a fallback
* Provide Quick Capture from anywhere in the app (and via widget/shortcut)
* Prompt for check-ins when they're overdue (snoozable, never blocking)
* Deliver notifications on iOS for time-sensitive reminders (waiting items due, overdue check-ins), managed carefully to avoid notification fatigue

The interface runs natively on macOS and iOS (SwiftUI), with data synced between devices. The iOS app is particularly important for capturing ideas and doing voice check-ins while walking.

---

## 4. Conceptual Glossary

This glossary defines *meaning*, not implementation.

---

### Project

A meaningful endeavour with intent, identity, and a desired outcome.

Examples:

* A macOS/iOS app (e.g. "Project Manager")
* A music EP
* A hardware instrument build
* Clearing out and reorganising the house
* An art installation
* A picture frame with an e-paper display

Properties:

* Has a **category** (Software, Music, Hardware/Electronics, Creative, Life Admin, etc. — user-extensible)
* Has a **lifecycle state**: Focused (on the Focus Board), Queued (planned and ready for a slot), Idea (captured but not fully planned), Completed, Paused (temporarily shelved with a reason), or Abandoned
* May have an endpoint (an EP is finished when it's released) or be ongoing (a software app may cycle through periods of active development and maintenance)
* Contains one or more **phases** (or, for lightweight projects, a single implicit phase)
* Has a **vision statement** and optionally a **technical brief** — living documents that capture the project's intent and approach
* Aggregates progress from lower levels
* Is never scheduled directly — scheduling is the Life Planner's domain

A project that is **completed** means all current phases and milestones are done. For ongoing projects (like apps), this means the current body of work is finished; the project becomes queued or paused until new tasks are added. Project data is never deleted — completed and abandoned projects remain accessible.

A project that is **paused** is temporarily shelved for a known reason. The reason is recorded (seasonal, blocked at the project level, deprioritised, waiting on a life event, etc.) so that the system and AI can suggest re-entry at the appropriate time. "Your garden project was paused for winter — spring is coming. Want to refocus it?"

A project that is **abandoned** is an honest acknowledgement that this isn't going to happen, at least not in its current form. Abandoning a project is not failure — it's a decision that frees up focus. The system should make this easy and judgement-free. When abandoning, the system prompts a brief, optional reflection: *What did you learn? Is there a kernel of this idea worth saving for something else?* This is not a guilt exercise — it's a way to extract value from the experience and close the loop cleanly.

**Recurring and maintenance tasks** (e.g. "update dependencies monthly," "back up project files") do not belong in the Project Manager. These are the Life Planner's domain — they are scheduling concerns, not project planning concerns. The Project Manager deals with finite work toward defined outcomes. This boundary is explicit.

---

### Category

A classification of a project's domain, used to enforce diversity on the Focus Board.

Built-in categories:

* Software
* Music
* Hardware / Electronics
* Creative (art, writing, design)
* Life Admin (house, organisation, maintenance)
* Research / Learning

Categories are user-extensible. A project has exactly one category. The category is assigned during project creation and can be changed.

---

### Phase

A broad stage of a project's lifecycle, representing a meaningful chapter of work.

Examples:

* "Phase 1: Core data model and basic UI"
* "Phase 1: Writing and recording"
* "Phase 1: Design and prototyping"

Properties:

* Contains one or more **milestones**
* Has a broad definition of what completion looks like
* Is planned in detail only when it becomes the current focus — future phases are sketched but not fully broken down
* Has an order (phases are sequential, though milestones within a phase may not be)

Phases exist because **mapping out every step from day one is unrealistic**. The end of Phase 1 might change the direction of Phase 2. Having a broad idea of the journey is valuable; having a rigid plan for all of it is counterproductive.

At the end of each phase, the system should prompt a **retrospective**: a conversation with the AI covering what went well, what didn't, what should change for the next phase, and whether the original plan still makes sense. The retrospective is also a natural moment to revise future phase definitions based on what was learned. Retrospective notes are stored on the phase record.

**Lightweight projects** (life admin, small creative projects) may have only a single implicit phase. The system should not force multi-phase structure on projects that don't need it.

---

### Milestone

A meaningful, concrete deliverable or achievement within a phase.

Examples:

* "Sort entertainment for the event"
* "Complete PCB design v1"
* "Finish the vocal recordings"
* "Set up the database schema and sync layer"

Properties:

* Has an **end state** — a clear definition of what "done" looks like (see Definition of Done)
* Has a **deadline** (optional but encouraged) — used for urgency calculations
* Has an optional **priority** (High / Normal / Low) — for ordering when deadlines are absent or equal
* Contains one or more **tasks**
* May have **dependencies** on other milestones — these are advisory (warnings), not hard blocks. The system warns that a dependency hasn't been met but allows the user to proceed if they choose. Creative workarounds should never be prevented by rigid database constraints.
* Progress is accumulated from its child tasks
* May enter a **waiting state** (see Waiting below)

Milestones are the level at which progress feels meaningful. Completing a milestone should feel like a genuine achievement — a tangible step toward the project's vision.

---

### Task

A concrete, practical action that advances a milestone.

Examples:

* "Come up with a shortlist of bands"
* "Request quotes from three lighting companies"
* "Wire the power section of the PCB"
* "Implement the CloudKit sync layer"

Properties:

* Belongs to exactly one milestone
* Has a **definition of done** — a clear, binary statement of completion (see Definition of Done). For creative or exploratory tasks, a timebox ("spend 2 hours exploring texture options") is a valid alternative.
* Has a **time estimate** — how long the user expects it to take, with a system-applied pessimism multiplier
* Has an optional **timebox** — an alternative to estimation: how much time the user is willing to spend (see Timeboxing)
* Has a **deadline** (inherited from milestone if not set explicitly)
* Has an optional **priority** (High / Normal / Low)
* Has an **effort type** — what kind of energy the task requires (see Effort Type)
* May have **dependencies** on other tasks — advisory, not blocking. The system warns but allows override.
* May have a **blocked** or **waiting** state
* Can optionally be broken into **subtasks**

Tasks are the **primary unit of work**. They are what appear on the Focus Board's Kanban view. They are what get ticked off. They should be small enough to complete in a single work session (ideally under 2-3 hours) and specific enough that there's no ambiguity about what "doing this" means.

**If a task feels overwhelming, it's too big.** The system (and AI collaborator) should actively help decompose tasks that are too large or too vague.

---

### Subtask

An optional further breakdown of a task into atomic steps.

Examples:

* Within "Request quotes from three lighting companies":
  * "Research lighting companies in the area"
  * "Draft the enquiry email"
  * "Send emails to three companies"

Properties:

* Belongs to exactly one task
* Has a definition of done
* Is the most granular level of the hierarchy

Subtasks are **not mandatory**. Many tasks are straightforward enough to not need them. Subtasks exist for situations where a task, while conceptually a single action, has enough internal steps that tracking them individually is helpful — particularly when the task spans multiple work sessions or when executive dysfunction makes even a clear task feel too large to begin.

---

### Effort Type

A classification of the kind of energy a task requires.

Categories:

* **Deep Focus** — sustained concentration, problem-solving, coding, writing (high cognitive load)
* **Creative** — open-ended, generative, exploratory work (requires particular headspace)
* **Administrative** — emails, forms, organising, scheduling (often tedious, low complexity)
* **Communication** — phone calls, messages, reaching out to people (social energy required)
* **Physical** — hands-on work, building, woodworking, cleaning (body-based)
* **Quick Win** — small, low-effort tasks that can be knocked off for momentum

Effort type is assigned to tasks (optionally, with AI assistance). It serves two purposes:

1. **Better AI suggestions.** When the system or AI suggests what to work on, effort type allows it to match the task to the user's current capacity. On a low-energy day, suggesting a phone call to someone is worse than suggesting sanding a piece of wood, even if both are "small" tasks.
2. **Focus Board filtering.** The user can filter the Kanban board by effort type to see only tasks matching their current headspace.

Effort type is not a rigid taxonomy — it's a lightweight signal. If the user doesn't assign one, the AI can suggest one during planning or check-ins.

---

### Definition of Done

A clear, binary statement of what completion looks like, required at every level of the hierarchy.

Examples:

* Project: "The app is available on the App Store with all Phase 1 features working"
* Milestone: "All three vocal tracks are recorded, edited, and approved"
* Task: "Shortlist of five bands with contact details and price ranges compiled"
* Subtask: "Three enquiry emails sent"

This concept aligns with Brené Brown's "paint done" — the ability to describe exactly what the finished state looks like. At the project level, this is what the vision statement captures. At lower levels, it's a concrete, testable statement.

If a definition of done cannot be articulated, the item is not ready to be worked on. The AI collaborator should help define these during the planning process.

**For creative and exploratory work**, strict binary completion may not always be appropriate. In these cases, a **timeboxed session** ("spend 2 hours exploring colour palettes") serves as a valid alternative, with the completion criteria being "the timebox was honoured." The system should support this explicitly rather than forcing artificial binary states on inherently iterative work.

**The AI can suggest scope reduction.** If a task or milestone has been in progress for significantly longer than estimated, or if a definition of done is proving unrealistic, the AI can propose simplifying it. "The original plan was to record five vocal takes per track. You've done three and they're strong. Would it be worth calling this done?" This supports the "completeness over perfection" principle.

---

### Blocked State

A declaration that progress on a task or milestone is not currently possible.

Types of block:

* **Poorly defined** — The next step is unclear. *Intervention: AI-assisted task decomposition or redefinition.*
* **Too large** — The task feels overwhelming. *Intervention: Break into subtasks.*
* **Missing information** — Can't proceed without knowing something. *Intervention: Define what information is needed and create a task to obtain it.*
* **Missing resources** — Needs a purchase, a tool, materials. *Intervention: Create a task to obtain the resource.*
* **Decision required** — Stuck at a choice point. *Intervention: AI-assisted decision exploration.*
* **External dependency** — Waiting for someone or something outside the user's control. *See Waiting State.*

When a task is marked as blocked, the system should:

* Record the type of block and any notes
* Suggest alternative tasks within the same project to maintain momentum
* Surface the block during check-ins so it doesn't silently persist
* If blocked tasks accumulate, flag this as a pattern worth investigating

Blocked is a state, not an excuse. But it is also **not a failure** — it is information about what needs to change for progress to resume.

---

### Waiting State

A declaration that the user's part is done, but progress depends on an external response.

Examples:

* "Emailed the venue — waiting for availability confirmation"
* "Ordered the PicoW — waiting for delivery"
* "Submitted the mix for feedback — waiting for notes"

Properties:

* Removes the task from active scheduling (it shouldn't clutter the Focus Board's "to do" column)
* Sets a **check-back date** ("check in 3 days")
* When the check-back date arrives, the system surfaces it: "Still waiting on the venue?"
* If still waiting, the user can re-snooze. If resolved, the task progresses.
* Keeps the item visible in the project overview so it doesn't silently disappear
* No negative signals while waiting — this is healthy progress, not avoidance

Waiting is distinct from Blocked. Blocked means "I can't do my part." Waiting means "I've done my part."

**Accumulation risk:** If many waiting items resolve simultaneously, they could create sudden overwhelm. During AI reviews, the system should note when a large number of waiting items are approaching their check-back dates and flag this proactively.

---

### Focus Board

The Kanban-style view that shows what you're actively working on.

Structure:

* **To Do** — Tasks from all focused projects that are ready to be worked on (left column)
* **In Progress** — Tasks currently being worked on (middle column)
* **Done** — Recently completed tasks (right column)

Constraints:

* Maximum **5 focused projects** at any time (hard limit — configurable, but 5 is the default and recommended cap)
* **Category diversity rule**: No more than **N projects of the same category** (default 2, configurable). This is a hard constraint with an explicit override — if you want three software projects focused, the system asks which one to swap out, but allows an override if you insist. The override creates friction in the right place.
* Projects are focused and unfocused **manually** by the user. The system does not automatically swap projects.

**Task visibility limits:** The ToDo column does **not** show every task from every focused project. Showing 75 tasks would be overwhelming and self-defeating. Instead, the system shows a **limited, curated set** of actionable tasks (default: 3 per project, configurable), selected by: not blocked or waiting → dependency-free → highest priority → soonest deadline → manual sort order. The full task list is always accessible in the project detail view, but the Focus Board shows only what's immediately actionable and manageable. The user can also filter the board by effort type to match their current headspace.

Health signals:

* **Stale**: Projects with no task completions in 7+ days are flagged for review
* **All tasks complete**: When a focused project has no remaining tasks, the system prompts either adding more tasks (if the project continues) or unfocusing/completing the project and replacing it with something else
* **Overdue tasks**: Tasks past their deadline are visually highlighted to draw attention
* **Blocked tasks**: Blocked badge on project header with count
* **Waiting items due**: Items past their check-back date are surfaced
* **Check-in overdue**: Prompt in project header, snoozable. Escalates in visibility over time (3 days → subtle badge, 7 days → visible prompt, 14 days → prominent but still snoozable and never blocking)

The Focus Board is the **daily working view**. It should feel actionable and manageable — never overwhelming. If looking at the Focus Board causes anxiety, there are too many tasks visible, or they're too poorly defined.

**Done column**: Shows recently completed tasks (configurable retention: default last 7 days or last 20 items, whichever is smaller). Older completed tasks move to a "completed tasks" history view accessible from each project's detail page. The Done column exists to provide visible progress and dopamine — it should feel rewarding to see it fill up, and it should stay clean enough not to become clutter.

---

### Quick Capture

A lightweight, zero-friction way to record a new idea without leaving the current context.

Quick Capture is accessible from **anywhere in the app** — a persistent button, a keyboard shortcut on macOS, and a widget/shortcut on iOS. It should take **under 30 seconds**.

The flow:

1. Tap the Quick Capture button (or trigger the shortcut)
2. Record a voice note describing the idea (or type a brief description)
3. Optionally assign a title and category
4. The system creates a project stub in the **Idea** lifecycle state

That's it. No planning conversation, no milestones, no definitions of done. The idea is captured and stored. The full onboarding process happens later, when the user is ready and has the mental bandwidth.

Quick Capture exists because **the moment of inspiration and the moment of planning are usually different moments**. Forcing them together means either the idea gets lost (if you defer) or the current focus gets derailed (if you plan now). Quick Capture separates them.

---

### AI Project Review

A periodic or on-demand conversation with the AI about the state of your active projects.

The AI can see all focused projects, their progress, staleness, blocked tasks, and completion rates. In a review conversation, it might:

* Observe that a project has been stalled for two weeks and ask what's going on
* Notice that all progress has been on one project while others are neglected
* Suggest that a blocked project might benefit from being paused temporarily
* Gently surface the question: "This project has been stalled three times now. Is this still something you want to pursue, or would it be more honest to shelve it and free up the slot?"
* Suggest a project from the queued or paused pool that might be ready for attention — including seasonal awareness for paused projects
* Note if a large number of waiting items are approaching their check-back dates simultaneously

The review is **always user-initiated** or user-prompted (via a reminder, not an unprompted interruption). The AI does not autonomously reorganise the Focus Board.

**Project reviews are where deeper analysis belongs.** Pattern detection, avoidance surfacing, and strategic questions are for review sessions — not for quick check-ins on bad days.

---

### Project Re-Entry

When returning to a project after an extended period of inactivity, the AI generates a **return briefing**: a concise summary of where the project was when it was last active, what was completed, what was in progress, what was blocked, and what the next steps were.

This addresses one of the hardest executive dysfunction challenges: the overwhelming feeling of returning to something you've lost context on. The return briefing should make re-entry feel manageable rather than daunting, answering the question: "Where was I, and what should I do next?"

The return briefing is generated automatically when a project is refocused after being queued, paused, or idle for an extended period.

---

### Time Estimate

An approximation of how long a task will take, used for planning and prioritisation.

Properties:

* Set by the user during task creation (with AI assistance)
* Subject to a **pessimism multiplier** (default 1.5x, adjustable) to counteract the planning fallacy
* The system tracks **estimated vs actual** time over the long term to help calibrate future estimates
* Used by the Life Planner for scheduling blocks — if a task is estimated at 6 hours, the Life Planner can budget 1 hour per day over six days

Time estimates are **not commitments**. They are planning tools. The system should never make the user feel bad about a task taking longer than estimated — this is expected and normal.

---

### Timeboxing

An alternative to estimation: a declaration of how much time you're **willing** to spend rather than how long something will take.

Examples:

* "I'll spend 2 hours on this and see where I get"
* "Maximum 30 minutes — if it's not done, it needs rethinking"
* "Two hours exploring texture options" (for creative/exploratory work where binary completion doesn't apply)

Sometimes the constraint is more useful than the estimate. Timeboxing is especially valuable for:

* Tasks that could expand indefinitely (research, creative exploration, debugging)
* Tasks being avoided — committing to 20 minutes is less intimidating than committing to "however long it takes"
* Creative work where "done" is hard to define — the timebox itself becomes the completion criterion

Timeboxing is offered as an alternative to time estimation, not a replacement. Either approach is valid for any task. During check-ins, the AI should reference timeboxes: "You timeboxed this at 30 minutes — how did that go? Was that enough, or does it need more time?"

---

## 5. The Project Onboarding Process

How a new project goes from an idea to a structured plan.

### Quick Capture (Instant)

The fastest path. A voice note or brief text description, captured in under 30 seconds. Creates a project stub in the Idea state. No planning, no structure. Just getting the idea down. See the Quick Capture glossary entry for details.

### The Brain Dump (When Ready)

When the user has the time and mental bandwidth to flesh out an idea — often a different day from when it was captured — they initiate a full brain dump. The user talks (voice input, typically while walking) about what they want to build, create, or achieve. This can be as unstructured and rambling as needed — the goal is to get the idea out of the head and into the system completely.

The AI listens, then begins a **collaborative discovery conversation**:

* Asking clarifying questions about intent, scope, and desired outcomes
* Probing for complexity the user might not have considered ("If you're building a frame, where will the electronics go? How will you mount it?")
* Exploring what "done" looks like — what is the vision for the finished thing?
* Identifying potential challenges, dependencies, and areas of uncertainty
* Helping the user think about what skills or resources they'll need

This conversation is the most important part of the process. It's where the AI acts as a **challenge network** — helping refine and clarify thinking by questioning assumptions, pointing out things the user hasn't considered, and grounding ambitious ideas in practical reality. The tone is collaborative and supportive, never dismissive.

### Scoping and Planning Depth

The depth of the planning process scales with the project's complexity, determined collaboratively during the discovery conversation. The AI assesses the scope as it learns more about the project and adjusts accordingly:

**For simpler projects** (e.g. a life admin task, a small creative project): The brain dump and conversation lead directly to a set of milestones and tasks. A brief summary of intent replaces a formal vision statement. The whole process might take 15 minutes.

**For medium projects** (e.g. a music EP, a furniture build): The conversation produces a vision statement that captures the creative intent, influences, constraints, and definition of done. Milestones and tasks are defined with some detail. The process might take one or two sessions.

**For complex projects** (e.g. a software application, a major hardware build): The full pipeline is invoked:

1. **Vision statement** — generated collaboratively from the brain dump, capturing the project's philosophy, user experience, success criteria, and design principles
2. **Technical brief** — derived from the vision statement, describing how the project will be built, what technologies or approaches will be used, and what the architecture looks like
3. **Adversarial review** — the vision statement and technical brief are submitted to additional AI reviewers (via automation, e.g. n8n) who critique them independently: Does the vision statement capture the original intent? Does the technical brief faithfully reflect the vision? What's missing, what's contradictory, what problems are overlooked?
4. **Synthesis and revision** — critiques are compiled, overlaps and divergences identified, and the documents are revised to address legitimate concerns
5. **Roadmap extraction** — the revised technical brief is broken down into phases, milestones, and tasks, each modular and independently testable where applicable

At every stage, the user can provide feedback, ask questions, challenge suggestions, and redirect. The process is collaborative, not automated.

### The Outcome

Regardless of complexity, the onboarding process produces:

* A project record with category, vision/intent summary, and definition of done
* A set of **phases** (at minimum one, possibly just a single implicit phase for lightweight projects)
* A set of **milestones** within the current phase, each with a definition of done
* A set of **tasks** within each milestone, each with a definition of done (or timebox), time estimate, effort type, and any dependencies
* Optionally, **subtasks** where tasks warrant further breakdown
* For complex projects: a **vision statement** and **technical brief** stored as documents within the project

The project is now ready to be focused (added to the Focus Board) or left in the Queued state until a slot opens up.

---

## 6. The Check-In System

How progress is tracked and projects are kept alive.

### Voice Check-Ins

The primary mechanism for updating project progress is a **voice conversation with the AI**. The user talks naturally about what they've done, what problems they've encountered, what's changed, and how they're feeling about the project.

The AI, with full context of the project's history and plan, then:

* Marks completed tasks as done
* Updates documentation with progress notes and any new information
* Flags any new issues or blockers mentioned
* Adjusts milestones or tasks if the conversation reveals the plan needs updating
* Asks follow-up questions if something is unclear or if it spots potential problems
* Surfaces patterns it's noticed — **but only during deeper check-ins or project reviews, not during quick logs** (see check-in depth below)

Check-ins should feel like talking to a knowledgeable colleague who genuinely remembers everything about the project. They should not feel like filing a report.

### Check-In Depth

Not every check-in needs to be a deep conversation. The system supports two modes:

* **Quick log**: "I finished the wiring and hit a snag with the power section. Marking wiring as done, flagging power as blocked." The AI confirms the updates and moves on. No analysis, no pattern detection. Under 2 minutes.
* **Full conversation**: A deeper discussion about progress, problems, direction, and strategy. This is where the AI can probe, surface patterns, suggest decomposition, and ask harder questions. 10-20 minutes.

The user chooses the depth. The AI should default to matching the user's energy — if the user gives a brief update, the AI responds briefly. It does not force depth.

### Check-In Frequency

* **After every work session** is ideal — a quick "here's what I did, here's what I ran into" takes 2-3 minutes and keeps everything current
* The system should **prompt for check-ins** when they haven't happened recently — gently escalating in visibility over time. All prompts are **snoozable** and never blocking.
* Check-ins are never mandatory. Missing a check-in is not penalised. But the system should make it easy enough that there's little reason not to.

### Automated Updates (Software Projects)

For software projects being developed with AI coding tools (e.g. Claude Code, Codex), the workflow can be more automated:

* The coding tool works through tasks on the roadmap, running tests and passing to the user for manual verification
* Upon completion, it can update the project's database via a **local integration API**: marking tasks complete, adding implementation notes, flagging new issues discovered during development, and updating documentation
* This keeps the Project Manager in sync with actual development progress without requiring the user to manually transfer information
* Voice check-ins remain valuable even for software projects — for reflecting on direction, discussing problems, and making strategic decisions that the coding tool can't make independently

---

## 7. Relationship with the Life Planner

The Project Manager and the Unified Work Guidance System (Life Planner) are **complementary but distinct** systems with a clear boundary.

### What the Project Manager Owns

* **Project identity** — what is this project, why does it exist, what's the vision
* **Project structure** — phases, milestones, tasks, subtasks, dependencies
* **Project planning** — the AI-assisted brain dump, discovery, and refinement process
* **Project documentation** — vision statements, technical briefs
* **Focus management** — diversity constraints, the Focus Board, active project limits
* **Project-level progress** — which milestones are complete, what percentage of tasks are done, what's blocked

### What the Life Planner Owns

* **Scheduling** — deciding what to work on right now, for how long, in what order
* **Time allocation** — balancing project work with work commitments, life admin, routines, and rest
* **Energy management** — adjusting the day based on capacity
* **Accountability dialogues** — the detailed "what happened with this task" conversations
* **Daily guidance** — "given reality as it is today, what is the most sensible thing to do next?"
* **Recurring and maintenance tasks** — "update dependencies monthly," "back up files," "water the plants." These are scheduling concerns, not project planning concerns.

### Data Flow

Data flows primarily **from the Project Manager to the Life Planner**:

* Active tasks (with time estimates, deadlines, priorities, effort types, and dependencies) are exported for scheduling
* Task completion status is synced back
* The mechanism is a shared database or periodic sync (implementation detail — see Technical Considerations)

The Life Planner does not modify project structure — it doesn't create milestones, redefine tasks, or change dependencies. It consumes what the Project Manager provides and schedules accordingly.

### Long-Term Unification

The vision for both systems is eventual consolidation into a single iOS application. This is a later-stage goal. For now, the separation is clean and functional, and building them independently allows each to be refined without the other's constraints. The important thing is that the interface between them is well-defined so that unification is straightforward when the time comes.

---

## 8. Technical Considerations

These are architectural notes for the technical brief, not implementation decisions.

### Platform

* **macOS and iOS** — native SwiftUI application
* **Single user** — no multi-user or collaboration features required

### Data Storage

* **Local database** (SQLite or equivalent) on each device — not Markdown files, not a remote MySQL server
* **CloudKit** for sync between macOS and iOS — Apple's native sync solution, well-suited to single-user apps in the Apple ecosystem
* An **external sync mechanism** (e.g. writing to a MySQL database on load/sync) for communication with the Life Planner system, which runs on separate hardware
* **Data export**: Full project data exportable in a portable format (JSON or similar) at any time. The user must never feel locked in.

### AI Integration

* **Built into the app** — not an external web interface. The chat system is a native part of the application.
* **API-based** — using LLM APIs (Anthropic, OpenAI, etc.) for the conversational AI
* **Voice input** — Whisper transcription running locally on-device as the primary input method, with text input as a fallback
* **Full project context** — the AI has access to all project data, documentation, and history for whatever project is being discussed
* **Project knowledge base** — a local retrieval system (RAG) that indexes all project text data (check-in transcripts, documents, conversation history, task notes) so the AI can draw on the full history of a project even when it exceeds the LLM's context window. This enables the "AI knows your project deeply" promise to scale to projects of any duration and complexity, without requiring everything to be loaded into every conversation.

### External Integration API

* A **local REST API** (or similar mechanism) that the app exposes, allowing external coding tools (Claude Code, Codex, etc.) to push updates: mark tasks complete, add notes, flag issues, update documentation.

### Scale

* Expected project count: **40-200** total, with 5 focused at any time
* The system should handle browsing, searching, and filtering across the full project pool efficiently
* Documentation (vision statements, technical briefs) should be searchable

### Notifications (iOS)

* Notifications for: waiting items past check-back date, significantly overdue check-ins, approaching deadlines
* Notification frequency must be carefully managed to avoid fatigue — a system that nags loses trust
* All notifications are snoozable and configurable
* No notification for routine prompts (check-in reminders) unless the user opts in — default to in-app prompts only

---

## 9. What Success Looks Like

**On a good day:**

* You open the Focus Board and see a manageable set of tasks matched to your energy.
* You complete a few tasks and see your milestones advancing.
* A new idea strikes while walking. You Quick Capture it in 30 seconds and return to what you were doing.

**On a bad day:**

* You can't face the deep focus task. You filter by Quick Wins and knock off two small things. Progress happened.
* You haven't checked in for a week. The system gently prompts, not scolds. You do a quick log in 90 seconds.
* You mark something as blocked and talk through why. The AI helps you figure out what's actually stopping you — but only if you want that conversation right now.

**When a new idea is exciting:**

* You talk it out fully. The AI helps you think it through, see the complexity, define what done would look like.
* The idea is captured — thoroughly, not as a cryptic post-it note.
* You feel satisfied that it's recorded and can walk away. It's not going anywhere.
* When you come back in six months, the AI generates a return briefing and you understand exactly where things stood and what the next step would be.

**When something isn't working:**

* A project has stalled three times. In a review session, the AI gently raises it. You decide to abandon it, do a brief reflection, and free the slot for something you're actually excited about. This feels like a good decision, not a failure.
* A definition of done turns out to be unrealistic. The AI suggests simplifying it. You agree, and the milestone that was 60% done is now 90% done. Momentum restored.

**Over months:**

* Projects actually finish.
* The Focus Board turns over — projects complete and are replaced by new ones.
* You trust the system to hold your ideas and your plans.
* The AI collaborator feels like it genuinely knows your projects and can have meaningful conversations about them.
* You have a realistic sense of how long things take, informed by actual data.
* You're better at recognising which ideas are worth pursuing and which should be honestly abandoned.
* Having 40+ projects in various states feels manageable, because they're organised, defined, and waiting patiently for their turn.
