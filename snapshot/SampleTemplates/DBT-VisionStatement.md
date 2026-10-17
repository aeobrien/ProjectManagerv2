## Vision Statement: A DBT Skills Practice System for Real Life

### What this app is

This app is a **personal DBT skills practice system**.

Its purpose is to help a user:

* Identify recurring behavioural patterns through structured chain analysis
* Build concrete, reusable skills plans for those patterns via an AI-guided workshop
* Practise and apply DBT skills in the moment, with minimal friction
* Track skill use, target behaviours, and emotional patterns over time through a structured diary card
* Accumulate evidence about which skills actually work, and refine plans accordingly

At its core, the app treats difficult emotions as **valid signals that can be responded to skilfully** — not problems to be eliminated, distortions to be corrected, or failures of character.

The app does not assume the user knows anything about DBT. It teaches what is needed, when it is needed, in the context of actually using it — not as a prerequisite.

---

### The goal behind the goal

The app's deeper aim is not:

* "Feel less"
* "Think more rationally"
* "Stop being emotional"
* "Optimise your responses"
* "Eliminate distress"

The real goal is:

> **To help the user build a reliable repertoire of skills they can reach for when emotions are intense, urges are strong, or old patterns are pulling — so that they suffer less, not by feeling less, but by responding more skilfully.**

Success looks like:

* Faster recognition of familiar chains before they reach the problem behaviour
* Increasing skill use in moments that previously led to avoidance, withdrawal, or impulsive action
* Growing confidence in "I have something I can do when this happens"
* Reduced frequency and intensity of target behaviours over time
* More willingness to engage with difficult situations rather than avoid them

The app does not try to make emotions quieter. It helps the user **act skilfully even when emotions are loud.**

---

### The dialectic at the centre

The app is built on DBT's foundational dialectic: **acceptance AND change**.

This is not a slogan. It is a structural design constraint that shapes every interaction:

* The app **validates** the user's emotional response before coaching a skill. Every run includes a moment of "this makes sense" before "here's what to try."
* The app never implies that the user's emotions are wrong, distorted, or excessive. Emotions are treated as understandable responses to context — and as signals that a skill might help.
* The app holds two things simultaneously: "Your reaction is valid given your history and context" AND "there may be a more skilful response available to you."

If the app collapses into only acceptance (validation without action), it becomes a comfort tool that doesn't build skills. If it collapses into only change (coaching without validation), it becomes invalidating. The design must prevent both collapses.

This dialectic is operationalised in the agent's behaviour, the run mode flow, and the language used throughout the app. It is not an abstract principle — it is a testable design requirement.

---

### What the app is not

This app is explicitly **not**:

* A replacement for therapy (it is a self-directed skills practice tool, and it should say so clearly)
* A diagnostic tool
* A mood tracker for its own sake
* A journaling app (reflective journaling is a separate concern; this app captures structured data for skills practice)
* A self-help content library or psychoeducation course
* A "positive thinking" or affirmation tool
* A generic chatbot that provides emotional support
* A crisis intervention tool (though it surfaces crisis resources and maintains a personal safety plan)

It does not aim to:

* Eliminate distress
* Argue with emotions
* Teach the user to "think differently"
* Provide reassurance as a substitute for skill use
* Replace comprehensive DBT treatment

The app is honest about what it is: **DBT-informed self-help**. It is not comprehensive DBT, which requires individual therapy, group skills training, between-session coaching, and a therapist consultation team. It borrows DBT's structure, skills, and analytical methods and makes them available for self-directed practice. Where a pattern may benefit from professional support, the app says so directly.

---

### The mental model the app is built on

The app is grounded in a specific view of emotional and behavioural patterns:

* Emotions are **valid responses** to internal and external events, not errors to be corrected
* Behavioural patterns are **learned chains** — sequences of events, vulnerabilities, thoughts, feelings, body sensations, urges, and actions that unfold in a recognisable order
* Problem behaviours (avoidance, withdrawal, impulsive action, rumination) persist because they serve a **short-term function** — they provide relief, escape, or protection — even when their long-term cost is high
* Change happens through **skill use**: inserting a different response at a specific point in the chain, repeatedly, until the new response becomes available under pressure
* Skill use is the **mechanism** — not insight, not understanding, not motivation. Understanding why a pattern exists is useful context; practising a different response is what changes the pattern
* Both acceptance and change are necessary. Acceptance without change is stagnation. Change without acceptance is invalidation. The synthesis is: **"This is real, this is hard, and I have something I can do."**

The app treats DBT as a **skills operating system**:

* Map the chain (what happens, in what order, and why it keeps happening)
* Find the insertion points (where in the chain could a skill change the outcome?)
* Select and practise skills (from a defined, evidence-based library)
* Log skill use and outcomes (so that what works becomes visible)
* Review and refine (update plans based on accumulated evidence)

The user is the practitioner. The app provides structure, guided analysis, a skills library, and a tracking system. The agent helps the user analyse their patterns and build plans, but the user practises the skills and accumulates the evidence.

---

### How the app should feel

The app should feel:

* **Warm, direct, and validating** — it acknowledges what the user is experiencing before moving to action
* **Practical rather than therapeutic** — it is a tool, not a session
* **Structured rather than open-ended** — every interaction has a clear shape and a clear endpoint
* **Predictable** — the same flow every time, the same screen order, no surprises
* **Calm under pressure** — when the user is activated, the app gets simpler, not more complex
* **Physically responsive** — interactions should feel tactile through subtle haptic feedback on sliders, completions, and confirmations. The app should feel good to use. (This is a polish-level concern to be addressed after core functionality is stable.)

It should never feel like:

* It's disappointed in the user
* It's lecturing or teaching at the user
* It's performing empathy instead of helping
* It's a chatbot trying to have a conversation
* It's unpredictable or different each time
* It assumes the user already understands DBT concepts

The tone is: *"This makes sense. And — here's a skill for right now."*

---

### The role of the agent

The agent is not a therapist, guru, or emotional support chatbot.
It is a **DBT skills plan design partner**.

The app builds skills plans *with* the user, not *for* them. The user's own description of their experience is the primary input. The agent's role is to structure that description into a chain analysis, help the user find where skills could be inserted, and assemble a concrete, reusable plan.

The agent's responsibilities are to:

* Walk the user through chain analysis using open, curious questioning — not telling the user what happened, but helping them map the sequence themselves
* Validate the user's emotional experience before and during every change-oriented move
* Help the user identify recurring patterns across episodes — not just the single instance being discussed
* Map the user's answers onto DBT's analytical structures (chain links, vulnerability factors, skill insertion points) while keeping the user's own language front and centre
* Select and parameterise skills from the curated DBT skills library, presenting them with brief rationales
* Produce consistent, validated, reusable skills plan objects
* **Explain DBT concepts in-context**: when introducing a concept (chain, skill insertion point, opposite action, etc.) for the first time, the agent briefly explains what it means and why it matters — in plain language, woven into the conversation, not as a separate lesson

The agent should always prioritise:

* Validation before change strategies
* Skill practice over explanation
* Specificity over general advice ("Use TIPP — here, cold water on your face for 30 seconds" over "try a distress tolerance skill")
* Brevity over completeness
* One clear recommendation over multiple options (in Run mode; Workshop can present 2–3 options since the user is in a reflective state)

The agent's output must follow the same **reduced-text-density constraints** as the rest of the app: short sentences, no paragraphs, progressive disclosure for detail. When the user is in Workshop mode, agent responses should be concise and conversational — not essays. Text-to-speech support for agent output is desirable for users with reading fatigue or processing differences, and should be considered for post-MVP.

The agent operates within strict constraints:

* It selects skills from the curated library; it does not invent new skills or techniques
* It follows deterministic workshop stages; it does not freestyle
* It produces validated JSON; it does not output unstructured advice
* It validates before it coaches; it does not skip to change strategies
* In crisis situations, it defers to the safety plan and static crisis resources; it does not attempt to provide crisis support via generative responses

---

### Guided discovery and validation

The agent uses open, curious questioning to help the user map their own chains — not persuasion, not lecture, not pre-packaged analysis.

In **Workshop mode**, the agent asks questions like:
* "Walk me through what happened — what was the first thing you noticed?"
* "What were you feeling in your body at that point?"
* "What did you do next? And what happened after that?"
* "What was that behaviour doing for you in the short term?"

The agent's job is to help the user see the chain *as a chain* — a sequence with identifiable links — rather than as "I just felt bad and then I avoided it."

Before every transition from analysis to action, the agent validates:
* "It makes sense that you [withdrew / avoided / shut down] — that was protecting you from [what the chain analysis revealed]. And — let's look at whether there's a skill that could give you that protection without the cost."

This validation-before-change pattern is **mandatory, not stylistic**. It reflects DBT's core dialectical stance and must be preserved even when compressed for brevity.

To prevent validation from becoming mechanical through repetition, skills plans store **2–3 validation variants** rather than a single static statement. These rotate across runs and can be lightly contextualised with the current emotion captured in the run (e.g., incorporating "the frustration" or "the urge to withdraw" from the capture screen). For experienced users, validation may also be expressed as a brief visual signal (colour shift, icon) alongside a short text line, rather than requiring the user to read a full sentence they've seen many times.

In **Run mode**, the user is activated and needs execution support. Validation is compressed to a single line but never absent. The app shows something like: "This pattern makes sense. Here's your skill." Then it walks the user through the skill steps.

---

### Target hierarchy

The app maintains an explicit **target hierarchy** that determines what gets prioritised:

1. **Life-threatening behaviours** (self-harm, suicidal urges) — highest priority. If present, the app surfaces the safety plan and crisis resources before anything else.
2. **App-interfering behaviours** (not practising skills, not completing diary cards, avoiding the app when activated, using the app compulsively without behaviour change). These are addressed through review prompts and gentle re-engagement. **Important**: disengagement is treated as neutral data, not as a problem to be solved. The app avoids demand-avoidance triggers (common in AuDHD profiles). Re-engagement prompts must be radically low-demand: "Welcome back. Quick check-in?" — never "Let's review why you were away." After prolonged absence, the app defaults to a "welcome back" state with an easy on-ramp (one quick run or one diary card), not a review of the gap.
3. **Quality-of-life interfering behaviours** (avoidance, withdrawal, impulsive decisions, emotional shutdown, relationship neglect — the patterns the user is building skills plans for).

This hierarchy is not just a conceptual framework. It is **built into the app's logic**:

* If diary card data or run captures indicate level-1 concerns, the app interrupts normal flow to surface the safety plan
* If engagement data indicates level-2 concerns (prolonged absence, high run volume without skill use), the app offers a low-friction re-entry point
* Normal skills practice operates at level 3

The user is told about this hierarchy during onboarding. It is framed as: "The app always checks in on the most important things first."

---

### Principles guiding the design

#### 1. Frictionless when activated

When the user is distressed, emotionally flooded, or dysregulated:

* Inputs must be minimal (taps and sliders, not typing)
* Choices must be constrained (one recommended skill, not a menu)
* Language must be short and concrete
* Completion must be possible in under 3 minutes
* Voice input must be available on every free-text field
* A **"just give me a skill" rapid path** must exist for moments when even the standard run flow is too much — skip plan selection, skip capture, go straight to a skill

The app assumes the user is **not at their best** when they need it most. Every design decision in Run mode must pass the test: "Could someone do this while crying, furious, or frozen?"

Voice input is not a convenience feature. It is an accessibility requirement. When the user is activated, typing may be impossible. Speaking is often easier. Voice is transcribed locally using an on-device model (e.g., Whisper). Raw audio is never stored, transmitted, or sent to any external service. Only the transcribed text enters the data pipeline.

---

#### 2. Predictability over novelty

The app should behave the same way every time:

* Same screen order in Run mode
* Same stage sequence in Workshop mode
* Same diary card layout every day
* Same interaction patterns throughout

This is not just good UX. It is a specific accommodation for neurodivergent users, informed by documented autism-adapted DBT practices that emphasise stable environments, consistent routines, and reduced cognitive load from unpredictability. (See the research report for the evidence base.)

Variation should come from the *user's patterns and choices*, not from the app's behaviour.

---

#### 3. Accessible to complete beginners

The app must be usable by someone who has never heard of DBT. **No prior knowledge of DBT is required.**

This means:

* No DBT jargon appears without explanation. When a concept is introduced for the first time (chain, skill insertion point, opposite action, distress tolerance, etc.), the app explains it briefly in plain language, in context.
* The agent introduces concepts conversationally during Workshop — not as a lecture, but woven into the guided discovery process. "What you're describing is what's called a 'chain' — a sequence where one thing leads to the next. Let's map yours out."
* The skill library uses plain-language descriptions alongside DBT terminology. "Opposite Action" is accompanied by "Doing the opposite of what the emotion is pushing you to do."
* Onboarding provides a brief interactive orientation that gives the user just enough conceptual scaffolding to participate, using concrete examples rather than abstract definitions.
* The app never assumes the user understands the structure of DBT, the four modules, or the therapeutic rationale. It makes these visible and learnable through use.

Education is embedded in the doing, not separated from it. The user learns DBT by using the app, not by studying before they can start.

---

#### 4. Skills practice over explanation

The app always asks:

* "Did you use a skill?"
* "Which one?"
* "What happened?"

Knowing about a skill is not the same as using one. The research evidence is clear: **skills use mediates DBT outcomes** — not skills knowledge, not insight, not understanding. The app's entire design drives toward: practise a skill, log the outcome, build evidence about what works.

Explanation is available (the skills library includes brief rationale for each skill), but it is never the primary path. The primary path is always: recognise the pattern → select a skill → do it → log it.

---

#### 5. Validation is structural, not decorative

Validation in this app is not a warm tone or empathetic copy. It is a **required step in the interaction flow**.

Before every change-oriented move (recommending a skill, prompting action, suggesting a commitment), the app or agent validates:

* The emotion makes sense given the context
* The current behaviour served a function
* The difficulty is real, not imagined

This is then followed by the change move:

* And — here's a skill that might help
* And — here's what you could try next time
* And — what will you do in the next 5 minutes?

Skipping validation to get to the skill faster is a design failure, even in compressed Run mode. One line of validation is sufficient. Zero lines is not.

---

#### 6. Small, concrete steps

Skill instructions should be:

* Numbered, ordered, and short
* Completable even on bad days
* Specific enough to follow without interpretation ("Hold ice cubes for 60 seconds" not "try a distress tolerance technique")
* Observable in their outcomes

The app favours:

* 1–5 minute skill practice
* Checklist-style instructions (3–5 steps max)
* Timer-supported actions where relevant
* Concrete sensory and behavioural instructions over abstract concepts

---

#### 7. The diary card is infrastructure

The diary card is not a journaling feature. It is the **control system** that drives the app's behaviour.

It tracks: emotions, urges, target behaviours, skill use, and user-defined custom dimensions (e.g., avoidance, connection).

It feeds: the recommendation engine (which skills plan to suggest, which skill to recommend), risk monitoring (escalation rules), review prompts (patterns that trigger revision), and the evidence layer (trends, correlations, progress).

The diary card should be:

* Completable in 90 seconds or less
* Available as a single daily check-in (user chooses when — morning, evening, or whenever works)
* Structured entirely around taps, sliders, and constrained lists (no required free text)
* Consistent in format from day to day
* Capped at a manageable size: a maximum of **3 active skills plans** contribute fields to any single diary card. If the user has more, only the highest-priority plans (by target hierarchy) populate the card, with others accessible via "show all."

The diary card is the data layer that makes everything else intelligent. Without it, the app is just a skill reference with a chatbot. With it, the app is a system that learns and adapts.

---

#### 8. Repetition with review

The app's value is not any single run. It is the **systematic accumulation of skill practice data across repeated cycles**.

Every run generates data. That data feeds the diary card and the evidence layer. The evidence layer surfaces patterns. Patterns prompt review. Review leads to skills plan refinement. Refinement leads to better skill selection in future runs.

This loop *is* the practice, not a feature of the practice.

The app should prompt review at defined intervals (e.g., after 5 runs of a skills plan, or weekly based on diary card trends), not leave it to user initiative. Review prompts should be calm, specific, and actionable: "You've run this plan 5 times. TIPP has been effective 4 times; Opposite Action was marked 'not helpful' twice. Want to revise?"

---

#### 9. Data as feedback, not judgement

Measurements exist to:

* Show what's working
* Reveal patterns
* Inform plan revisions
* Track target behaviour frequency

They are not:

* Scores
* Grades
* Proof of failure
* Engagement metrics

The app should never imply that "no improvement" means "you're not trying." It should frame stagnation as information: "This plan may need revision" or "This pattern might benefit from professional support."

---

#### 10. Measurement as clinical infrastructure

The app establishes baselines when a skills plan is created, tracks standardised symptom measures periodically (e.g., PHQ-9, GAD-7), and uses pre-defined decision rules to trigger plan revision, escalation prompts, or completion signals.

Key metrics (informed by the DBT evidence base):

* **Skills use frequency** — how often skills are practised, from which modules (this is the primary mediator of DBT outcomes)
* **Target behaviour frequency** — are the problem behaviours decreasing?
* **Urge intensity trends** — are peaks becoming more manageable?
* **Skill diversity** — is the user drawing from multiple modules or relying on one? (Diversity is suggested only when a plan is stagnating despite consistent skill use — not as a general rule, since some patterns genuinely require skills from a single module.)
* **Chain interruption point** — is the user recognising chains earlier and intervening sooner?
* **User-defined dimensions** — avoidance level, connection frequency, or other targets personal to the user

Standardised measures (PHQ-9, GAD-7, etc.) are administered as standalone check-ins at defined intervals, not during runs. The app surfaces a brief "time for a check-in" prompt and presents the questionnaire outside of any specific run.

The standardised measures framework should be **extensible** beyond PHQ-9 and GAD-7. Common co-occurring conditions in AuDHD populations (PTSD, eating disorders, OCD, substance use) may benefit from validated instruments (e.g., PCL-5, EDE-Q). The MVP's focus on PHQ-9/GAD-7 is a starting point, not a ceiling.

---

#### 11. Agency without blame

The app consistently reinforces:

* Emotions arise in context — they are not character flaws
* Behavioural patterns were learned for a reason — they served a function
* Change is a skill that improves with practice, not a moral achievement
* Not using a skill is information, not failure
* The target hierarchy exists to keep the user safe, not to judge them

Responsibility is framed as **capacity to respond skilfully**, not fault.

---

#### 12. Honest about its own limits

The app is designed for self-directed skills practice, but it recognises that self-direction has boundaries.

The app should proactively acknowledge when a pattern may benefit from professional support — not as a failure state, but as a legitimate and expected outcome. DBT itself operates within a stepped-care model; recommending professional support is part of the system, not an edge case.

Escalation signals should be built into the app's logic:

* Sustained deterioration on standardised measures
* Persistent target behaviours despite consistent skill use
* Diary card indicators of life-threatening behaviours
* Prolonged disengagement (no runs or diary entries for 14+ days)
* User self-report of worsening

When triggered, the app shows a calm, non-alarmist message with relevant resources (therapist directories, GP referral info, NHS self-referral for Talking Therapies, crisis lines). It frames this as: "This pattern might benefit from more support than an app can provide — and that's a reasonable next step, not a failure."

The long-term architecture should support optional therapist integration (diary card sharing, progress exports), even if the MVP doesn't implement it. This is the most DBT-faithful product path: the app as adjunct to professional support, not replacement for it.

---

### The safety plan

Every user should have a **personal safety plan** accessible from anywhere in the app.

The safety plan is:

* Built during onboarding (or whenever the user chooses)
* A static, non-LLM-generated document containing: warning signs, coping strategies, people to contact, professional resources, emergency numbers
* Accessible via a persistent, unobtrusive button in all modes
* Surfaced automatically if diary card data or run captures indicate life-threatening behaviours

The safety plan is **first-class infrastructure**, not an afterthought. It reflects DBT's origin in treating high-risk presentations and the research report's recommendation that crisis planning be a core design feature.

In crisis-adjacent situations, the app defers entirely to the safety plan and static crisis resources. The LLM is never used to generate crisis-related content. All crisis copy is pre-written, tested, and static.

---

### How the app helps over time

In the short term:

* It interrupts chains before they reach the problem behaviour
* It provides a concrete skill to reach for when the urge is strong
* It reduces time lost to avoidance or emotional shutdown

In the medium term:

* It builds a growing repertoire of practised skills
* It weakens the pull of specific target behaviours through repeated alternative responses
* It strengthens the user's confidence in "I have something I can do when this happens"
* It surfaces patterns the user hadn't noticed (e.g., vulnerability factors, time-of-day effects, trigger categories)

In the long term:

* The user recognises chains earlier and reaches for skills faster
* The skills become internalised — available without the app
* The app becomes a reference and tracking tool, not a crutch
* Target behaviours that once dominated become less frequent, less intense, or more manageable

The ideal outcome is that the app is needed **less**, not more.

However, the app must deliver recognisable value within the first few uses. The onboarding experience should get the user to a completed run as quickly as possible, so they experience the loop — chain recognition → skill → outcome — before deciding whether to continue. This is not engagement optimisation; it is minimum-effective-dose design.

---

### Internalisation and tapering

The vision that the app should be needed less over time must be **engineered, not just stated**.

As target behaviour frequency drops and skill use becomes consistent, the app should gradually:

* Reduce proactive prompts and suggestions for the relevant plan
* Highlight maintenance cards (brief reminders of what worked) over full skills plans
* Suggest practising skills without the app and logging the outcome later
* Transition the diary card from daily to weekly for stabilised targets
* Celebrate skill internalisation as a positive outcome: "This plan has been working well for 4 weeks. You may not need it actively any more — here's a maintenance card for if this pattern returns."

The app must distinguish between **disengagement-as-avoidance** (target behaviours are still active, skill use has dropped, the user may be struggling) and **disengagement-as-success** (target behaviours have resolved, skills are internalised, the user doesn't need the app for this pattern). The escalation system handles the first case. The tapering system handles the second.

Maintenance mode is not abandonment. The app retains the user's completed plans, maintenance cards, and historical data, and remains available if a pattern returns.

---

### Onboarding

The app must be usable by someone with zero knowledge of DBT. Onboarding exists to make that possible.

On first launch, the app provides a brief (~2 minute) interactive orientation:

* What's a chain — with a concrete, relatable example (not clinical language)
* What's a skill — with a concrete example of using one
* What the diary card tracks and why (in one sentence)
* What a skills plan is and how it helps (in one sentence)

This is not a course or a content library. It is the **minimum conceptual scaffolding** needed for the user to participate in their own chain analysis and skill selection. The language must be plain, the examples concrete, and the pace fast.

The orientation ends by launching the first Workshop with the framing: "Let's try this with something real."

Skippable for users who already understand the DBT model.

**Onboarding load management**: The target is first-completed-run within 15 minutes of first launch. To achieve this, safety plan setup, diary card timing preference, and baseline standardised measures are all deferred to *after* the first Workshop and first Run. The user should experience the core loop (chain → skill → outcome) before being asked to configure anything else. Onboarding is interruptible and resumable — if the user drops off mid-flow, the app picks up where they left off.

**Workshop pacing**: The first Workshop can be completed as a "quick build" — a minimal chain + one skill — rather than requiring a full 9-stage deep build. Depth increases through revision, not first build. The Workshop can be paused and resumed across sessions, with auto-save after each stage. This accommodates executive dysfunction and the reality that sustained attention for 10 minutes is not always available.

---

### Neurodivergence-informed design

The app is designed with ADHD and autistic needs as primary design constraints, not afterthoughts. These constraints are informed by documented adaptations of DBT for neurodivergent populations (see the research report for the evidence base).

**Predictability**: Every interaction follows the same structure. No layout changes, no surprise modals, no "we've updated the experience" redesigns mid-use.

**Reduced text density**: Short sentences. Visual indicators (emotional thermometer, colour-coded intensity) over numeric scales where possible. Icons alongside or instead of words. No paragraphs of instruction. Agent output follows the same constraint — short, conversational, no walls of text.

**Sensory customisation**: Dark mode, reduced contrast option, no sudden animations or transitions. Sensory notes on skills that involve physical stimuli (e.g., TIPP's cold water — flag for sensory sensitivity, offer alternatives). No sounds — the app is silent by default. Haptic feedback is available and configurable (on/off) as a tactile completion signal on sliders, taps, and run completion.

**Concrete stepwise instructions**: Every skill is delivered as a numbered checklist. Never "try a grounding technique" — always "1. Pick up an object near you. 2. Notice its weight. 3. Notice its texture. 4. Describe it aloud in one sentence."

**Voice-first**: Every free-text field has a microphone button. Transcription is local and real-time. Raw audio is never stored. Text input remains equally accessible — never buried behind the voice option.

**"You're done" signals**: Every interaction has a clear endpoint. The app never leaves the user in an ambiguous state. When a run is complete, it says so. When the diary card is done, it says so.

**Gentle about gaps**: "5 of 7 days this week" not "you missed 2 days." No streaks. No badges. No gamification. If the user hasn't engaged for a while, a radically low-demand prompt: "Welcome back. Quick check-in?" — not a review of why they were away. The app avoids triggering demand avoidance.

**Progressive disclosure**: Default path is fast and minimal. Details available on tap for users who want them. The skill library is a reference, not homework.

**Font and display options**: As a post-MVP consideration, the app should support dyslexia-friendly font options and adjustable interface density. For MVP, the app should respect system-level accessibility settings (Dynamic Type, Bold Text).

#### Alexithymia accommodation

Many autistic adults experience alexithymia — difficulty identifying and labelling emotions. The app must not assume the user can reliably name what they feel.

* The constrained emotion list includes an **"I don't know / something but I can't name it"** option that does not dead-end the flow. Selecting it routes the user to body-sensation-based or distress-tolerance skills rather than requiring emotional identification.
* The emotional thermometer has a parallel **"body distress" thermometer** for users who can read somatic signals more easily than emotional labels.
* Chain analysis in Workshop mode supports **body-sensation-led discovery** as an equal-status starting point: "What did you notice in your body?" is as valid an entry point as "What were you feeling?" The chain can be built from behaviour backwards if that's how the user processes the episode.
* Emotion vocabulary is **scaffolded gradually** through use, not assumed upfront. The agent may gently suggest labels ("Some people might call that frustration — does that fit?") but never insists on them.

#### Masking as a recognised pattern

For autistic users, masking (camouflaging autistic traits to fit social expectations) is a pervasive behaviour pattern that causes significant distress, burnout, and mental health deterioration. The chain analysis framework is well-suited to mapping masking patterns — masking can appear as a vulnerability factor (it drains resources), a target behaviour (the user wants to reduce it), a coping mechanism (it serves a protective function), or all three depending on context.

The app should never frame masking as categorically wrong. Sometimes masking is an adaptive, reasonable choice. The app helps the user examine masking's costs and choose when to deploy it skilfully — the same acceptance-AND-change dialectic applied to everything else. "Masking at work to get through a meeting" and "masking so pervasively that you burn out" are different patterns with different costs, and the chain analysis can distinguish them.

#### Cognitive scaffolding for executive dysfunction

Beyond UX accommodations, the app should support AuDHD cognitive styles at the logic level:

* **Low-capacity mode**: When the user is in shutdown, meltdown, or executive depletion, the app offers a minimal path — skip chain recognition, go directly to a rapid distress tolerance skill, defer logging to later. This is triggered by high intensity in capture, repeated skip behaviour, or a manual "low energy" toggle.
* **Initiation support**: The home screen always shows one clear next action. The user never faces a blank screen or a menu of equal-weight options. The recommendation engine chooses for them; they can override if they want.
* **Time blindness accommodation**: The recommendation engine uses time-of-day patterns from diary card data to proactively prompt the user during historically high-activation periods, rather than relying on the user to notice and initiate.

#### Interpersonal skills and preparation runs

Interpersonal effectiveness skills (DEAR MAN, GIVE, FAST) have a different temporal relationship to their triggering events than other skills. You can hold ice cubes alone; you can't open an app mid-conversation.

The skills library distinguishes between **in-the-moment skills** (distress tolerance, emotion regulation, mindfulness) and **preparation skills** (interpersonal effectiveness). Run mode for preparation skills uses a "preparation run" framing: "You're about to have this conversation. Here's your DEAR MAN script. Review it now." The user reviews and rehearses before the interaction, then logs the outcome afterwards.

---

### The ethical centre

The app's north star is:

> **Help the user suffer less by building a reliable set of skills they can reach for when things are hard — without invalidating their experience, replacing professional support, or creating dependence on the app.**

If a future feature:

* Increases engagement but weakens skill acquisition
* Feels comforting but avoids skill practice
* Provides validation without ever moving to change (collapses the dialectic)
* Provides change strategies without validation (collapses the dialectic the other way)
* Encourages dependence on the app rather than skill internalisation
* Avoids recommending professional support in order to retain users within the app

...it should be rejected.

---

### Privacy by design

The app treats all user emotional, behavioural, and health data as sensitive by default.

* Data is stored locally first. Nothing leaves the device without explicit user action.
* The app collects the minimum data necessary for the skills plan and diary card to function.
* No third-party sharing of any user content, ever.
* Voice input is transcribed on-device. Raw audio is never stored or transmitted.
* The agent receives only the minimum context required to build/modify a skills plan. It never receives the full diary card history or run log.
* Server-side data retention: the agent service should not retain user content after the session ends. If content is logged for safety monitoring, the retention window must be specified (e.g., 24-hour ephemeral logs for abuse detection only) with defined access controls.

---

### Regulatory awareness

The app's claims, data handling, and adaptive algorithms exist within a regulatory framework. Design decisions must be compatible with UK regulatory expectations (MHRA, NICE ESF, DTAC) even if formal certification is not pursued in the first version.

This constrains feature design: the app cannot make clinical treatment claims without evidence to support them, and its adaptive logic (diary card-driven recommendations, escalation rules) must be auditable.

The app is explicitly positioned as a **DBT-informed self-help tool**, not a clinical treatment programme. This framing is honest, and it is also the most defensible regulatory position for a first version.
