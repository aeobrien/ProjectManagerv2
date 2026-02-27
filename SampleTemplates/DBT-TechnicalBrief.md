## Technical Brief: DBT Skills Plan Builder + Runner

### Document purpose

Define the complete product/technical specification for a DBT-based app that:

* turns recurring behavioural patterns into **structured skills plans** via an agent-led workshop grounded in chain analysis
* supports **fast, low-friction "run mode"** for in-the-moment skills coaching
* maintains a **diary card** as the central monitoring and control system
* uses **skill use logging + outcome tracking** to build evidence about what works over time
* holds the **acceptance AND change dialectic** as a structural design constraint throughout

…and does so in a way that operationalises the vision statement (validation before change, skills use as the mechanism, predictability, frictionless when activated, neurodivergence-informed design, honest limits, accessible to complete beginners).

---

# 1) Product scope

## 1.1 In scope

* Skills plan authoring via guided agent workflow ("Workshop mode") grounded in chain analysis
* Skills plan execution ("Run mode") optimised for low cognitive load, emulating DBT between-session coaching
* A **"Quick Skill"** rapid-access path for moments when even standard Run mode is too much
* A structured diary card as a daily monitoring instrument and control system
* Structured logging and review loops (charts, summaries, plan revision prompts)
* A deterministic, validated JSON skills plan format with versioning
* A curated DBT skills library organised by the four canonical modules, distinguishing in-the-moment skills from preparation skills
* A personal safety plan module, accessible from anywhere in the app
* Target hierarchy logic built into the recommendation and escalation engines
* Safety gating and escalation (non-clinical; encourages professional support when needed)
* A home screen that ties all modes together with clear, personalised next actions
* Local-first storage with optional encrypted sync/export
* Neurodivergence-informed design as a primary constraint (not an accessibility add-on)
* Alexithymia accommodation throughout (body-sensation-first pathways, "I don't know" options)

## 1.2 Explicitly out of scope

* Diagnosis, treatment claims, clinical triage, crisis intervention beyond signposting
* Comprehensive DBT (this is DBT-informed self-help; comprehensive DBT requires individual therapy, group skills training, between-session coaching with a therapist, and a consultation team)
* Freeform journaling as a primary function (only optional notes within runs and diary cards)
* "Feel-good" chatbot reassurance loops or emotional support conversation
* Infinite conversation without skills plan output
* Social features (feeds, posting, commenting)
* Ads, dark patterns, engagement-maximisation
* Skill invention by the agent (the agent selects from the curated library; it does not create new skills)

---

# 2) Success criteria

## 2.1 Primary success metrics (behavioural)

* Median "Run" completion time ≤ 3 minutes
* ≥ 80% of runs include a completed skill practice step
* Skills use frequency increases over time (within-user trend) — this is the primary mediator of DBT outcomes
* Target behaviour frequency decreases over repeated runs for targeted skills plans (within-user trend)
* Diary card completion rate ≥ 5 of 7 days per week (sustained)
* Skills plan revision rate reflects learning (plans evolve based on evidence, rather than stagnate)

## 2.2 Secondary success metrics (experience)

* Low abandonment mid-run
* Users can create a new skills plan in ≤ 10 minutes with agent help (quick build option: ≤ 5 minutes)
* Users report increased confidence in "I have something I can do when this happens"
* Time-to-first-completed-run (target: within first session of app use, within 15 minutes of first launch)
* Skill diversity increases over time (user draws from multiple modules, not just one)
* Chain interruption point moves earlier over time (user recognises patterns sooner)
* 7-day and 30-day return rates (tracked, not optimised — these are diagnostic, not targets)

## 2.3 Anti-metrics (guardrails)

* Increasing daily time spent in app is **not** a success metric
* Excessive reliance on chatbot (high chat volume with low skills plan output) is a failure mode
* Runs that skip skill practice and only capture emotion are a failure mode (the app must drive toward action, not just logging)
* Optimising for return-rate at the expense of clinical integrity is a failure mode. Engagement metrics inform design; they do not drive it.

---

# 3) System overview

The product has three primary modes, a rapid-access path, and a daily monitoring instrument:

1. **Run Mode** (fast, minimal, skills-coaching-led)
2. **Workshop Mode** (agent-led skills plan construction via chain analysis)
3. **Evidence & Review** (charts, summaries, plan revision prompts)
4. **Quick Skill** (emergency bypass — skip plan selection, skip capture, go straight to a skill)
5. **Diary Card** (daily structured monitoring — the control system)

Plus a **Home Screen** that ties everything together with personalised recommendations.

Everything revolves around four core objects:

* **Skills Plan** (reusable plan, produced by Workshop, executed in Run mode)
* **Chain Template** (the analytical model within a skills plan — the recurring pattern being targeted)
* **Run** (a single execution instance of a skills plan)
* **Diary Card Entry** (a single daily monitoring record)

---

# 4) Architecture

## 4.1 High-level components

* **Client App** (iOS/macOS first, or iOS-only initially)

  * UI + local database
  * skills plan runner engine
  * diary card engine
  * recommendation engine (which plan to suggest, which skill to recommend)
  * target hierarchy evaluator
  * escalation rules engine
  * tapering evaluator (detects when to reduce prompts and transition to maintenance)
  * on-device speech-to-text engine (e.g., Whisper) for voice input transcription
* **Agent Service** (LLM-backed)

  * structured workshop interview (chain analysis + skills plan construction)
  * slot-filling state manager (tracks which chain template fields are populated regardless of input order)
  * JSON skills plan generation
  * JSON validation + repair loop
  * safety classifier (non-clinical: self-harm cues → show safety plan + resources)
  * validation-before-change enforcement (agent must validate before every change-oriented output)
* **Sync/Backup (optional)**

  * encrypted cloud sync (user-controlled)
  * export/import of skills plan library + run history + diary card data
* **Analytics (optional, privacy-first)**

  * local-only analytics by default
  * opt-in anonymous telemetry (crash, performance) with no content

## 4.2 Data flow principles

* **Local-first**: runs, diary card entries, and skills plan library stored on-device
* **Minimise sensitive content**:

  * structured fields preferred (sliders/toggles/constrained lists)
  * free text optional and clearly flagged as sensitive
* **Agent never needs your full history**:

  * only send the minimum context required to build/modify a skills plan
  * summarise on-device where possible
  * diary card history is never sent to the agent; only aggregated patterns are used locally
* **Voice input transcribed locally**: voice input is transcribed on-device using a local model. Raw audio is never stored, transmitted, or sent to any external service. Only the resulting text enters the data pipeline.

## 4.3 LLM integration contract (strict)

The agent does **not** directly change app state.
It outputs:

* a **Skills Plan JSON** (or skills plan patch)
* optional "explanations" strictly separated from machine-readable output
* **validation statements** (acceptance/validation language) that are structurally required before any change-oriented output

Agent output must follow **reduced-text-density constraints**: short sentences, no paragraphs, progressive disclosure for detail. Agent responses in Workshop mode should be concise and conversational — not essays.

Client accepts a skills plan only if it passes:

* schema validation
* constraint validation (length, required fields, allowed enums)
* safety rules (no harmful advice, no medical instructions)
* dialectic check: every skills plan must include a `validation_statements` field (the acceptance half of the dialectic)

The agent may customise skill scripts within template boundaries but may not invent new skill types or mechanisms. All skills in a generated plan must reference a valid `skill_id` from the curated skills library (see Section 15).

If invalid:

* client requests a repair from agent with the validation errors (automatic loop)

---

# 5) Skills Plan JSON spec (v1)

## 5.1 Skills Plan object

Required fields:

* `id` (UUID)
* `version` (semver: `1.0.0`)
* `name` (short, user-facing label)
* `summary` (1–2 sentences, validating tone — describes the pattern without judgement)
* `target_behaviour` (the specific behaviour being targeted for change)
* `hierarchy_level` (enum: `life_threatening`, `therapy_interfering`, `quality_of_life`)
* `when_to_use` (list of triggers / prompting events)
* `chain_template` (see Section 5.4)
* `skill_sequences` (ordered list of skill selections mapped to chain insertion points)
* `diary_card_schema` (what to track daily for this target)
* `capture_fields` (ordered list of fields to show in Run capture)
* `measures` (what to rate before/after in runs)
* `review_rules` (when/how to prompt revision)
* `safety` (copy + links/resources; region-aware UK by default)
* `status` (enum: `active`, `paused`, `completed`, `archived`)
* `validation_statements` (array of 2–3 acceptance-side framings for this pattern, used in rotation across runs — e.g., ["It makes sense that you avoid reaching out — rejection feels genuinely dangerous given your history", "The urge to withdraw is protecting you from something real", "Of course this pattern shows up when you're already depleted — it's been your go-to for a long time"]. Contextualised at runtime by incorporating the current emotion from capture.)
* `commitment` (the user's stated commitment from the end of Workshop — what they will try. See Section 5.6 for lifecycle.)

Optional:

* `completion_summary` (user-generated summary of what skills they built)
* `maintenance_card` (minimal plan for if the pattern returns: key trigger, best skill, reminder of what worked)
* `tags` (context tags: time of day, location, relationship, etc.)
* `exclusions` (when not to use this plan)
* `defaults` (default slider values, recommended skill)
* `standardised_measures`: array of measure objects, each containing:
  * `measure_id` (e.g., "PHQ-9", "GAD-7")
  * `frequency` (e.g., "weekly", "fortnightly")
  * `last_administered` (timestamp)
  * `scores[]` (timestamped history)
* `escalation_rules`: array of rule objects, each containing:
  * `trigger` (e.g., "no completed runs in 14 days", "target behaviour frequency increasing over 3 weeks", "diary card indicates life-threatening behaviours")
  * `action` (e.g., "show safety plan", "show escalation prompt", "suggest professional support", "pause plan and show review")
* `skill_type` (enum: `in_the_moment`, `preparation` — see Section 15.4)
* `plain_language_descriptions` (object mapping DBT terms used in this plan to brief plain-language explanations, shown on first encounter)

## 5.2 Run object

* `run_id`, `plan_id`, `timestamp_start`, `timestamp_end`
* `run_type` (enum: `standard`, `quick_skill`, `preparation`)
* capture payload (structured)
* chain recognised (which chain template was active)
* skill selected (referencing `skill_id`)
* skill completed (boolean)
* skill_steps_completed (how many steps of the skill checklist were done)
* commitment_made (what the user committed to doing next)
* before/after measures (emotion intensity, urge strength)
* outcome tags
* `emotion_unknown` (boolean — true if user selected "I don't know" for emotion)
* optional free-text note (clearly marked as sensitive)

## 5.3 Diary Card Entry object

* `entry_id`, `date`, `timestamp`
* `emotions[]`: array of { `emotion` (from constrained list, including "I don't know"), `intensity` (0–100) }
* `urges[]`: array of { `urge_type` (from constrained list), `intensity` (0–100) }
* `body_sensations[]`: array of { `sensation` (from constrained list) } — always available as alternative/supplement to emotion
* `target_behaviours[]`: array of { `behaviour_id` (from active plans — max 3 plans contribute; see Section 8.1), `occurred` (boolean), `notes` (optional, one line) }
* `skills_used[]`: array of { `skill_id`, `context` (optional, one line) }
* `custom_dimensions[]`: array of { `dimension_id` (e.g., "avoidance", "connection"), `rating` (0–5 or boolean) }
* `overall_distress` (0–100)
* `body_distress` (0–100, optional — parallel to overall_distress for users who read somatic signals more easily)
* `optional_note` (one line, voice or text)

## 5.4 Chain Template model

Required field in Skills Plan object:

* `chain_template`: object containing:
  * `prompting_event` (what triggers the chain — situation type)
  * `vulnerability_factors[]` (what makes the user more susceptible: sleep, stress, time of day, social context, masking load, etc.)
  * `links[]`: ordered array of objects, each containing:
    * `type` (enum: `thought`, `emotion`, `body_sensation`, `urge`, `action`)
    * `description` (the user's own language for this link)
    * `skill_insertion_point` (boolean — could a skill change the chain here?)
    * `recommended_skill_id` (if insertion point is true — references the curated library)
  * `problem_behaviour` (the target behaviour the chain leads to)
  * `consequences`: object containing:
    * `short_term_function` (what relief/protection the problem behaviour provides)
    * `long_term_cost` (what it maintains or worsens)

This structure makes the chain analysis a coherent functional model. It enables: the agent to see *why* each skill was chosen (it targets a specific link in the chain), the user to understand the sequence rather than just the outcome, and the review process to evaluate whether skill insertion points are shifting earlier in the chain over time.

The chain template is progressively built across Workshop Stages 1–4. Note that the agent uses a slot-filling approach — fields can be populated in any order as the user provides information, even if it arrives out of the nominal stage sequence (see Section 6.1).

## 5.5 Validation constraints (important)

* Skill scripts must be ≤ 240 characters (forces brevity)
* Skill step instructions must be ≤ 120 characters each (forces concreteness)
* `when_to_use` entries ≤ 80 chars
* At least one skill in `skill_sequences` must be "actionable" (has a timer or checklist)
* Chain templates must include at least one `skill_insertion_point`
* All `skill_id` references must resolve to a valid entry in the curated skills library
* `validation_statements` must be present, non-empty, and contain 2–3 entries
* All enums must be from controlled lists to keep the system consistent
* `hierarchy_level` must be set; no plan exists without a target priority
* Each validation statement must be ≤ 200 characters (forces conciseness while allowing warmth)

## 5.6 Commitment lifecycle

Commitments follow a defined lifecycle:

* **Created**: in Workshop Stage 8 or Run Screen E
* **Active**: visible on home screen and plan dashboard; recommendation engine reminds user of active commitment on the Run start screen
* **Replaced**: when a new run of the same plan is completed with a new commitment, the previous commitment is replaced (not stacked)
* **Cleared on completion**: when a plan moves to `completed` status, its commitment is cleared
* **Not tracked as success/failure**: commitments are reminders, not obligations. Unfulfilled commitments are never surfaced as failures or guilt prompts. The app simply shows the current active commitment and moves on.

Commitments are visible on:
* The home screen (for the highest-priority active plan)
* The plan dashboard (for each plan individually)
* Run Screen A (as a reminder: "You committed to trying [X] next time this showed up")

---

# 6) Workshop Mode (agent-led) workflow

Workshop produces either:

* **New skills plan** (full build or quick build)
* **Revision** of existing skills plan (patch)

## 6.1 Workshop stages (structured, slot-filling)

The agent follows a stage structure for guidance, but uses a **slot-filling approach** to populating the chain template. If the user provides information out of order (e.g., describes consequences while talking about the prompting event), the agent fills that slot silently and acknowledges it, then asks only about missing slots. This accommodates the associative, non-linear thinking style common in AuDHD users.

The stages provide scaffolding and a suggested flow — not a rigid gate sequence. The agent tracks a "state of completeness" for the Skills Plan JSON and focuses questions on unfilled fields.

User-facing explanations are kept short. The agent validates the user's experience at every stage transition.

**Agent output density**: all agent responses must be concise — short sentences, no paragraphs. The agent explains one thing at a time and waits for the user's response. Progressive disclosure for detail.

**In-context education**: when a DBT concept is introduced for the first time in a Workshop (chain, skill insertion point, opposite action, etc.), the agent explains it briefly in plain language, woven into the conversation: "What you're describing is what we call a 'chain' — a sequence where one thing leads to the next. Let's map yours out." The agent never assumes the user already knows DBT terminology.

Note: Voice input (see Section 12.5) is the primary suggested input method for all Workshop stages, since the user needs to think aloud rather than compose precise text.

### Workshop time budget

* **Total Workshop target**: ≤ 10 minutes (full build); ≤ 5 minutes (quick build)
* **Per-stage target turn count** (indicative, not hard limits):
  * Stage 1 (Describe episode): 3–5 turns
  * Stage 2 (Walk the chain): 6–10 turns
  * Stage 3 (Target behaviour): 2–3 turns
  * Stage 4 (Insertion points): 3–5 turns
  * Stage 5 (Select skills): 3–5 turns
  * Stage 6 (Diary card config): 1–2 turns
  * Stage 7 (Review rules): 1–2 turns
  * Stage 8 (Commitment): 1–2 turns
  * Stage 9 (Generate JSON): 0 turns (automatic)
* If the Workshop approaches 10 minutes, the agent should begin converging: use reasonable defaults for unfilled optional fields, confirm with the user, and generate the plan.

### Workshop persistence

* Workshop state is auto-saved after each stage (or after each meaningful exchange within a stage).
* If the user abandons the Workshop mid-way, partial progress is preserved.
* On return, the app offers: "You were building a plan for [pattern]. Want to continue where you left off?" — one tap to resume.
* The `workshop_state` object tracks: current stage, all populated slots, conversation history summary, and timestamp.

### Quick Build option

For the first Workshop or when the user wants speed over depth:

* The agent walks through a minimal flow: describe the episode → identify the problem behaviour → select one skill → commit.
* This produces a valid but minimal skills plan (sparse chain template, one skill, default review rules).
* The plan is flagged as `quick_build: true` and the app suggests revision after 3 runs: "You've used this plan a few times. Want to fill in more detail?"
* Quick build skips: detailed chain walking (Stage 2 is abbreviated), diary card customisation (uses defaults), review rule customisation (uses defaults), standardised measures.

### Stage 1 — Describe a recent episode

Purpose: Get a concrete behavioural episode on the table — not an abstract pattern, but a specific thing that happened.

Inputs:

* "Walk me through a recent time this happened" (voice or text — open prompt)
* Emotion at the time (pick from constrained list + intensity slider; "I don't know" option available)
* What did you end up doing? (voice or text)

Expected agent behaviour:

* Listen, reflect neutrally, validate ("That sounds like it was really difficult")
* If the user selects "I don't know" for emotion, pivot to body sensations: "That's completely fine. What did you notice in your body?"
* Identify whether this matches an existing skills plan (suggest) or is a new pattern (continue workshop)
* Do NOT analyse or interpret yet — just capture
* If the user provides chain-relevant information (e.g., mentions consequences, vulnerability factors), silently fill those slots

Output:

* Raw episode description
* Candidate pattern label + confidence
* Any chain template slots populated incidentally

### Stage 2 — Walk the chain (guided discovery)

Purpose: Map the episode as a chain — prompting event → vulnerability factors → links → problem behaviour → consequences.

Agent guides the user through the chain, focusing on **missing slots**:

* "Let's slow this down. What happened first — what was the prompting event?"
* "Were there things that made you more vulnerable that day? Sleep, stress, something earlier?"
* "After the prompting event, what was the first thing you noticed? A thought? A feeling in your body?"
* "And then what happened next?"
* "What did you end up doing?" (the problem behaviour)
* "What did that behaviour do for you in the short term?"
* "And what did it cost you?"

Expected agent behaviour:

* Use open, curious questioning — the user maps their own chain
* **Body-sensation-led discovery**: "What did you notice in your body?" is an equal-status starting point to "What were you feeling?" For users with alexithymia, the chain can be built from body sensations and behaviours, with emotions added later or left as "unknown"
* Validate at each link: "That makes sense — when you felt [X], of course the urge was to [Y]"
* Help the user see the chain *as a sequence* rather than as "I just felt bad and avoided it"
* Keep the user's own language; do not substitute clinical terminology unless the user prefers it
* If the user jumps ahead or circles back, fill slots as they come — don't force the linear order
* Converge on a clear chain with identifiable links
* If quick build: abbreviate to 3–4 turns, accepting a sparser chain template

Output:

* `chain_template` (prompting event, vulnerability factors, links[], problem behaviour, consequences)

### Stage 3 — Identify the target behaviour and hierarchy level

Purpose: Name the specific behaviour being targeted, and classify it in the target hierarchy.

Agent asks:

* "Looking at this chain, what's the behaviour you most want to change?"
* "Is this something that puts you at risk of harm?" (hierarchy classification)

Expected agent behaviour:

* Help the user be specific: not "avoidance" in general, but "not replying to messages from friends when I feel anxious"
* Classify the target in the hierarchy (life-threatening → therapy-interfering → quality-of-life)
* If life-threatening, surface the safety plan and encourage professional support before continuing
* Explain the hierarchy briefly on first encounter: "The app checks on the most serious things first — anything that puts you at risk of harm gets top priority. Then things that get in the way of using the app. Then the patterns you want to change."
* Validate: "It makes sense that this behaviour has been hard to change — it's been protecting you from [short-term function]. And — let's find a skill that could give you that protection differently."
* Acknowledge masking as a valid target if the user identifies it: "Masking isn't always a problem — sometimes it's a reasonable choice. Let's look at when it costs you more than it protects you."

Output:

* `target_behaviour`
* `hierarchy_level`

### Stage 4 — Find skill insertion points (guided discovery)

Purpose: Identify 2–3 links in the chain where a skill could have changed the outcome.

Agent asks:

* "Looking at this chain, where do you think things could have gone differently?"
* "If you could rewind to [specific link], what might you have done instead?"
* "Is there an earlier point where you could have noticed what was happening?"

Expected agent behaviour:

* Scaffold the user's own identification of insertion points before suggesting alternatives
* Explain the concept on first encounter: "An insertion point is a moment in the chain where doing something different could change what happens next. We're looking for those moments."
* Map each insertion point to a link in the chain template
* Validate: "It makes sense that you didn't catch it there — that's a hard moment to be aware. And — that's exactly the kind of moment a skill could help with."
* Converge on 2–3 realistic insertion points

Output:

* `skill_insertion_points[]` (annotated on the chain template)

### Stage 5 — Select and parameterise skills

Purpose: Choose specific DBT skills for each insertion point, from the curated library.

Must include:

* 1 rapid skill (≤ 60 seconds — e.g., TIPP, paced breathing, grounding)
* 1 short skill (2–5 minutes — e.g., opposite action, check the facts, pros and cons)
* Optional: a skill for a different insertion point in the chain

Expected agent behaviour:

* Select skill templates from the curated DBT skills library (see Section 15) based on:
  * the type of chain link at the insertion point (thought → emotion regulation skills; urge → distress tolerance skills; action → opposite action; interpersonal trigger → interpersonal effectiveness skills)
  * the intensity level (high intensity → distress tolerance first; lower intensity → emotion regulation or interpersonal effectiveness)
  * sensory considerations (flag skills with sensory components for user confirmation)
  * skill type: if the target involves an upcoming interpersonal interaction, recommend preparation skills with "preparation run" framing
* In Workshop (reflective state): present 2–3 options with one-line rationales; user selects. Choice is appropriate here — the user is co-designing the plan.
* Explain each skill briefly on first encounter: "TIPP uses cold to trigger your body's dive reflex — it's a fast way to bring the intensity down. You'd hold cold water to your face for about 30 seconds."
* Parameterise scripts with the user's specific language and context
* Scripts must be concrete, numbered steps — not abstract instructions

Output:

* `skill_sequences[]` (each referencing a valid `skill_id` from the library, with parameterised scripts)

### Stage 6 — Configure diary card tracking

Purpose: Define what gets tracked daily for this target.

Defaults (auto-suggested, user confirms):

* Target behaviour occurrence (binary)
* Urge intensity for the primary urge in the chain
* Skills used (from the skills assigned in this plan)
* One custom dimension if relevant (e.g., avoidance level, connection attempts)

Expected agent behaviour:

* Suggest defaults based on the chain analysis
* Keep it minimal — every added field increases daily friction
* Warn if the user already has 3 active plans contributing to the diary card: "You've got 3 plans being tracked already. Adding more fields might make the daily check-in take too long. Want to keep the defaults minimal, or swap out tracking for another plan?"
* User can accept defaults or customise

Output:

* `diary_card_schema` for this plan

### Stage 7 — Set review rules and standardised measures

Review rule defaults:

* After 5 runs → review prompt
* If target behaviour frequency not decreasing after 3 weeks of diary card data → suggest revision
* If skill marked "not helpful" 3+ times → suggest replacing that skill

Agent suggests relevant standardised measures (post-MVP):

* If target involves low mood/avoidance → suggest PHQ-9
* If anxiety/worry → suggest GAD-7

User confirms or declines. If accepted, the user completes the measure as a baseline.

Output:

* `review_rules[]`
* `standardised_measures[]` (if accepted; post-MVP)

### Stage 8 — Commitment

Purpose: The user makes a specific, small commitment to try the plan.

Agent asks:

* "When this chain starts running next, what's the one thing you'll try?"
* "What skill will you reach for first?"

This is not a vague intention. It is a specific, concrete commitment: "Next time I notice the urge to not reply, I'll do 60 seconds of paced breathing before deciding."

Commitment strategies are an explicit DBT mechanism for motivation and behaviour change.

The commitment enters the lifecycle defined in Section 5.6: active until the next run of this plan produces a new commitment.

Output:

* `commitment` (stored in the skills plan)

### Stage 9 — Generate JSON + validate

Agent outputs skills plan JSON.
Client validates; if errors, client triggers repair loop.

At each stage, the agent progressively builds the chain template, reflecting the emerging analysis back to the user with validation: "So when [prompting event] happens and you're already [vulnerability], you notice [link 1], then [link 2], and by the time [link 3] hits, the urge to [problem behaviour] is very strong — because [problem behaviour] gives you [short-term function], even though it costs you [long-term cost]. That makes complete sense. And — here's where we can insert a skill."

### Stage validation (structural)

Each Workshop stage transition must include validation language from the agent. This is verified via the `workshop_state` object, which tracks `validation_present: true` for each stage. The repair loop rejects stage transitions where validation is absent.

---

# 7) Home Screen

The home screen is the user's landing point when they open the app. It ties all modes together and ensures the user always has a clear next action.

## 7.1 Home screen contents

Ordered by priority (target hierarchy):

1. **Safety interrupt** (if diary card data or escalation rules indicate life-threatening concerns): full-screen safety plan surface — takes priority over everything else.

2. **Diary card prompt** (if not completed today): "Ready for today's check-in?" — one tap to start, one tap to dismiss. Not guilt-inducing.

3. **Welcome back state** (if absent 3+ days): instead of a review prompt, the home screen shows a low-friction re-entry point: "Welcome back. Quick check-in?" with one-tap access to a diary card or a quick run. No meta-review of the absence.

4. **Suggested plan** (from recommendation engine): the single most relevant plan based on diary card patterns, time of day, and recent activity. Shown as a card with: plan name, brief reason ("Avoidance has been high this week"), and a "Start run" button.

5. **Active commitment** (if any): "You committed to: [commitment text]" — shown as a subtle reminder, not a demand.

6. **Quick Skill button**: persistent, prominent access to the Quick Skill path (see Section 7.3). Always visible.

7. **Quick links**: Workshop (build a new plan), Plan library, Evidence & Review, Safety plan.

8. **Workshop resume** (if a Workshop is in progress): "You were building a plan for [pattern]. Continue?" — one tap to resume.

## 7.2 Home screen logic

* The recommendation engine determines which plan to suggest (see Section 12.2)
* If the user has no active plans, the home screen guides them to onboarding → Workshop
* If all plans are completed/archived, the home screen congratulates skill development and offers to build a new plan or maintain existing maintenance cards
* The home screen never shows a blank or ambiguous state
* Layout is stable — same structure every time, only content changes

---

# 8) Run Mode workflow (in-the-moment)

Goal: **fast, low friction, minimal typing, skills-practice-first — with validation preserved as a structural requirement**.

Run mode emulates DBT between-session coaching: brief, skills-focused, aimed at generalising skills to real contexts.

Design priority: efficacy over speed. Do not drop validation or skill practice steps to save time. Manage cognitive load through smart defaults, skip options, and voice input instead.

## 8.1 Run flow: 6 screens (with skip options on 2)

### Screen A — Start Run (Plan selection)

Contents:

* Search bar (plan names + triggers)
* "Suggested" section (top 3) based on:

  * diary card patterns (recent high urges/target behaviours)
  * time of day tags
  * last used plans
  * active commitment ("You committed to trying TIPP next time this showed up")

Controls:

* Tap plan to start
* "I'm not sure" → Quick Triage (see below)
* Safety plan button (always present, unobtrusive)
* Quick Skill button (always present — "I just need a skill right now")

For **preparation runs** (interpersonal effectiveness plans): the plan card shows "Preparation run — review before your conversation" framing instead of the standard "Start run."

### Screen B — Capture + Chain Recognition (30–60 seconds)

Purpose: Quick chain identification — not detailed analysis, just enough to match the current state to a chain template and pick the right skill.

Exact contents (ordered):

1. **Emotion** (pick up to 2 from constrained emotion list; "I don't know / something I can't name" option prominently available; emotional thermometer slider 0–100)
2. **Body signals** (tick list from constrained body sensation list — always shown, not hidden behind emotion selection)
3. **Body distress thermometer** (0–100, parallel to emotional thermometer — available for users who read somatic signals more easily)
4. **Urge** (single-choice list from the plan's chain template: avoid/withdraw/scroll/shut down/lash out/check/ruminate/etc.)
5. **Situation** (optional one-line text or voice input, placeholder "What's happening?")
6. **Chain recognition**: app shows the chain template and highlights the likely current position. "Looks like you're at [link]. Sound right?" (tap to confirm or adjust)

**Alexithymia routing**: if the user selects "I don't know" for emotion, the app:
* Does not dead-end or require emotion selection to proceed
* Weights body signals and urge intensity more heavily for skill recommendation
* Logs `emotion_unknown: true` in the run object
* Routes toward body-based or distress tolerance skills on Screen C

Controls:

* Primary: "Next"
* Secondary: "Skip capture" (keeps friction low; logs minimal run with just the plan used)

### Screen C — Validate + Orient (15–30 seconds)

Purpose: The dialectic in miniature. Validation (acceptance), then orientation to skill (change).

This screen is the structural enforcement of the acceptance-AND-change dialectic. It is brief but never absent.

Contents:

* **Validation line**: pulled from the plan's `validation_statements` array (rotated across runs, lightly contextualised with the current emotion/body state from Screen B capture). E.g., "This makes sense — the urge to avoid is protecting you from something real."
* **Skill recommendation**: one clear recommendation based on the chain insertion point and current intensity. "Here's your skill: [skill name]." In Run mode, ONE skill is shown by default — not 2–3 options. This reduces decision fatigue for activated users.
* **Brief rationale**: one line (e.g., "This targets the urge before it becomes action")

Controls:

* Primary: "Let's go" (proceeds to skill execution)
* Secondary: "See alternatives" (de-emphasised; shows 2 alternatives from the plan if tapped)

This screen is **not skippable**. Validation is a structural requirement. The screen is designed to take 10–15 seconds to read and one tap to proceed.

### Screen D — Do (skill execution)

App shows **one skill**, walked through step by step.

Contents:

* Skill name + brief plain-language description (e.g., "TIPP — cold water" / "Uses cold to trigger your body's dive reflex and bring intensity down fast")
* Numbered steps (3–5 max), each ≤ 120 characters
  * e.g., "1. Get cold water or ice. 2. Hold to your face for 30 seconds. 3. Breathe slowly. 4. Notice the shift."
* If timed: a timer button (start/pause) — prominent, calm
* If checklist: tappable steps that mark as done
* Sensory note if applicable (e.g., "If cold is too intense, try cool water instead")
* For **preparation skills**: the screen shows "Review your script" framing with the parameterised DEAR MAN/GIVE/FAST script, and a "Rehearse" prompt

Controls:

* Primary: "Done"
* Secondary: "Switch skill" (shows alternatives — visually secondary, not prominent)
* "Mark as not helpful" (feeds review)

### Screen E — Outcome + Commit (30–60 seconds)

Contents:

* Emotion now (thermometer slider; "I don't know" option available)
* Urge now (thermometer slider)
* Skill completed? (yes/partially/no)
* Outcome tags (multi-select):

  * "Intensity dropped"
  * "Stayed the same but I tolerated it"
  * "Got worse"
  * "I used the skill but did the target behaviour anyway"
  * "I didn't use the skill"
* **Commitment step**: "What will you do in the next 5 minutes?" (tap-to-select from common options: "Go back to what I was doing," "Reach out to someone," "Do something I've been avoiding," "Rest," "Try another skill" — or one-line voice/text). This commitment replaces the previous one for this plan (see Section 5.6).
* For **preparation runs**: "How did the conversation go?" (post-interaction logging, with option to log later)
* Optional note (one line)

Controls:

* Primary: "Save & close"
* Secondary: "Skip to close" (screen is partially skippable — outcome tags can be skipped, but skill completion and commitment are encouraged)

### Screen F — Summary (skippable)

Brief auto-generated summary: "You noticed [emotion] at [intensity], used [skill name], and [outcome tag]. Next: [commitment]."

Contents:

* Auto-generated run summary
* Diary card auto-update prompt: "Log this to today's diary card?" (one tap)
* "Was this run helpful?" (thumbs up/down — feeds review data)

Controls:

* "Save & close"
* "Skip" (screen is skippable)

## 8.2 Quick Triage (when user taps "I'm not sure")

Contents:

* 3-question wizard:

  1. "What's the strongest urge right now?" (list from constrained urge list)
  2. "How intense?" (thermometer, 0–100)
  3. "Is this about a relationship, an action you're avoiding, an emotion you can't stand, or something else?" (category tap)
     Output:
* Suggests best-matching skills plan or offers to build a new one (Workshop)
* If intensity is very high (≥ 80) and urge involves self-harm: surface safety plan first

## 8.3 Quick Skill (rapid-access path)

Entry points: home screen button, safety plan "I need a skill right now" link, Run Screen A.

Purpose: skip plan selection, skip capture, go straight to a skill for users in crisis or who know exactly what they need.

Flow:

1. **Pick a skill**: show recently used skills and favourites, organised by type (rapid / short). One tap to select.
2. **Do the skill**: same as Screen D — numbered steps, timer if applicable.
3. **Done**: brief confirmation. Optional: "Log this?" (creates a minimal run record with `run_type: quick_skill`).

This path does not capture emotion, chain recognition, or detailed outcomes. It is an **emergency bypass** for when even 3 minutes is too much. Data capture is sacrificed for speed.

The Quick Skill path does not replace Run mode — it complements it for high-urgency moments.

## 8.4 Low-Capacity Mode

When the user is in shutdown, meltdown, or executive depletion, the standard run flow may be too much even with skip options.

Low-capacity mode is triggered by:
* Emotion/body distress intensity ≥ 80 on Screen B capture
* User skips capture twice in a row
* User taps a manual "low energy" toggle (available on Screen A and home screen)

When active:
* Skip chain recognition entirely
* Go directly to a rapid distress tolerance skill (TIPP, paced breathing, grounding)
* Defer commitment prompt to summary screen (optional)
* Minimal logging: plan used + skill attempted + completion status

Low-capacity mode is not a separate mode — it's an adaptive shortening of the standard Run flow.

## 8.5 Crisis pathway (interrupts normal flow)

If at any point during Run mode the user's inputs indicate life-threatening behaviours (self-harm urges at high intensity, explicit crisis content in text/voice):

1. Immediately surface the safety plan (full screen, clear, calm)
2. Show static crisis resources (pre-written, not LLM-generated)
3. Offer to continue the run only after the user acknowledges the safety plan
4. Log the event for escalation rule evaluation

This is a non-negotiable interrupt. It takes priority over all other run flow.

---

# 9) Diary Card

The diary card is a **daily monitoring instrument** that exists independently of runs. It is the control system that makes the app intelligent.

## 9.1 Diary card flow (≤ 90 seconds)

The user completes the diary card once per day, at a time they choose (configured during onboarding; can be changed in settings).

The diary card is a single scrollable screen, not a multi-step wizard. All fields are taps, sliders, and constrained lists. No required free text.

**Active plan cap**: a maximum of **3 active skills plans** contribute target behaviour and skill-use fields to the diary card. If the user has more than 3 active plans, only the 3 highest-priority plans (by target hierarchy level, then recency) populate the card. An expandable "Show all" section provides access to the remaining plans' fields. This preserves the 90-second completion target.

Contents (ordered):

1. **Emotions today** (pick up to 3 from constrained emotion list; intensity thermometer 0–100 for each; "I don't know / something I can't name" option available)
2. **Body sensations today** (pick from constrained body sensation list — always available, not contingent on emotion selection)
3. **Body distress** (single thermometer, 0–100 — optional, parallel to overall distress)
4. **Strongest urge today** (pick from constrained urge list; intensity 0–100)
5. **Target behaviours** (for each active plan within the 3-plan cap: "Did [target behaviour] happen today?" — yes/no toggle)
6. **Skills used** (for each active plan within the cap: "Did you use a skill today?" — if yes, which one from the plan's assigned skills)
7. **Custom dimensions** (if configured — e.g., "Avoidance level today" 0–5; "Did you reach out to someone?" yes/no)
8. **Overall distress** (single thermometer, 0–100)
9. **Optional note** (one line, voice or text)

Controls:

* "Done" (saves and shows a brief "you're done" confirmation)
* "Skip today" (logs a minimal entry with just the date — better than nothing)

## 9.2 Diary card as control system

The diary card feeds:

* **Recommendation engine**: recent diary card data determines which skills plan the app suggests in Run mode (Screen A). If avoidance has been high for 3 days, suggest the plan targeting avoidance. If a specific urge is spiking, suggest the plan that addresses it.
* **Risk monitoring**: if diary card entries indicate life-threatening behaviours (target behaviour flagged as self-harm, extremely high distress), the app surfaces the safety plan at next launch.
* **Review prompts**: diary card trends trigger plan revision. E.g., "Target behaviour occurred 5 of 7 days this week despite skill use — time to revise the plan?"
* **Evidence layer**: diary card data populates the dashboards and trend charts in Evidence & Review mode.
* **Tapering evaluator**: sustained improvement on diary card metrics triggers the tapering protocol (see Section 12.6).
* **Engagement monitoring**: see Section 11.1 (disengagement detection) for the engagement monitoring approach and its "welcome back" framing.

## 9.3 Diary card timing and reminders

* User configures preferred time during onboarding (supports "window-based" timing — e.g., "morning" or "evening" rather than requiring a specific clock time)
* One notification per day at the configured time (silent by default — no sounds)
* The notification is brief: "Ready to check in?" — not guilt-inducing, not elaborate
* Reminders are nudges that expire, not tasks that pile up. If the user misses a day, there is no "overdue" state — just today's card.
* If the user opens the app and hasn't done today's diary card, a gentle prompt appears (dismissible in one tap)

---

# 10) Evidence & Review

## 10.1 Skills plan dashboard (per plan)

Contents:

* Run count
* Skill use log: which skills, how often, completion rate
* Target behaviour frequency (from diary card — trend line)
* Urge intensity trend (from diary card — line chart)
* Outcome tag distribution (what happens after skill use)
* Chain interruption point trend: are skills being used at earlier links in the chain over time?
* "Not helpful" flags per skill
* Active commitment (current)
* Standardised measure trends (line chart, when available — post-MVP)

Controls:

* "Revise plan" (launches Workshop revision path)
* "Archive plan"
* "Export plan JSON"
* "Reset metrics" (does not delete raw data; just resets summary views)

## 10.2 Global dashboard (across all plans)

Contents:

* Total skill use frequency (trend line — the most important single metric)
* Skill diversity chart (how many different skills from how many modules)
* Overall distress trend (from diary card)
* Diary card completion rate
* Active plans summary
* Standardised measure trends (if any — post-MVP)

## 10.3 Weekly review (optional, user-controlled)

Contents:

* 3–5 insight cards max:

  * "This week: avoidance urges were highest in the evenings"
  * "You used TIPP 4 times this week — up from 2 last week"
  * "Opposite Action was marked 'not helpful' twice — want to try a different skill?"
  * "Your PHQ-9 score this week: 12, down from 15 two weeks ago" (when standardised measures are available — post-MVP)
* "One suggested revision"
* Optional micro-reflection prompt (1–2 taps, not journaling):
  * "What helped most this week?" (pick from skills used)
  * "Where did you catch the chain earliest?" (pick from plans)

Controls:

* "Ignore"
* "Revise now"
* "Remind me next week"

Principle: review is **sparse and calm**, not gamified.

## 10.4 Skills plan completion

When review data shows sustained improvement (e.g., target behaviour frequency consistently below a threshold for 4+ weeks, user self-report of reduced pattern activation):

1. Prompt the user to summarise what they learned: "What skill made the biggest difference? What do you know now that you didn't before?"
2. Generate a brief "if this returns" maintenance card: a minimal plan containing the key trigger, the best skill, and a reminder of what worked. This card lives in a "Completed" section of the plan library.
3. Track completed plans separately from archived ones — completion is a positive outcome; archiving is neutral.
4. Clear the active commitment for this plan.

Note: Standardised measures (PHQ-9, GAD-7, etc.) are NOT administered during runs or diary cards — this would add too much friction. They are administered as standalone prompts at the frequency specified in the plan. The app surfaces a brief "time for a check-in" notification and presents the questionnaire outside of any specific run or diary card entry.

---

# 11) Safety, privacy, and ethics

## 11.1 Safety architecture

Safety in this app is **first-class infrastructure**, reflecting DBT's origin in treating high-risk presentations.

### Personal safety plan

* Built during onboarding (deferred to after first Workshop/Run — see Section 16)
* Contains: warning signs, coping strategies (user's own), people to contact (names + numbers), professional resources, emergency numbers
* **All content is user-entered or static/pre-written. The LLM never generates safety plan content.**
* Accessible via a persistent, unobtrusive button visible in all modes
* Surfaced automatically when triggered by diary card data, run captures, or escalation rules

### Acute risk detection

During Workshop, Run mode, and diary card:

* Lightweight classifier for self-harm cues in text/voice input and structured field responses

If triggered:

* Immediately surface the safety plan (full screen)
* Show static crisis resources (UK numbers/links — pre-written, tested)
* Encourage contacting a professional or trusted person
* Do NOT use the LLM to generate any crisis-related content
* Allow user to continue only after acknowledging the safety plan
* Log the event for escalation rule evaluation

### Chronic non-response detection (MVP: diary-card-only)

**MVP escalation rules** operate without standardised measures (which are deferred to post-MVP). All MVP escalation triggers use diary card data only:

* Target behaviour frequency increasing or stable despite consistent skill use over 3+ weeks (from diary card trends)
* Multiple plans with no improvement on diary card metrics
* Distress trend increasing over 2+ weeks despite regular skill use
* High-intensity urges (≥ 80) on 5+ of the last 7 diary card entries

**Post-MVP escalation rules** (when standardised measures are enabled):
* Sustained lack of improvement or worsening on standardised measures (e.g., PHQ-9 increase ≥ 5 points over 2 administrations)

If triggered:

* Show a calm, non-alarmist message acknowledging that this pattern may benefit from professional support
* Provide relevant resources (therapist directories, GP referral info, NHS self-referral for Talking Therapies)
* Frame as part of the stepped-care model, not as an app failure or user failure
* Allow the user to acknowledge and continue, or to pause the plan

### Disengagement detection

Disengagement is treated as **neutral data, not a failure state**. The app distinguishes two types:

* **Disengagement-as-avoidance**: target behaviours are still active, skill use has dropped, the user may be struggling → gentle, low-demand re-engagement
* **Disengagement-as-success**: target behaviours have resolved, skills are internalised → the tapering system handles this (see Section 12.6)

Detection and response:

* No diary card entries for 3+ days → at next app launch, show a **"Welcome back" state** (not a review prompt). One-tap access to a quick diary card or a quick run. No meta-review of the absence. No "You've been away for X days" messaging. Just: "Welcome back. Quick check-in?"
* No completed runs or diary entries for 14+ days → disengagement escalation: "Want to check in?", "Archive your plans for now?", "Need support?" (with resource links). Still low-demand, still no guilt framing.

### Compulsive use detection

Refined detection (not blunt thresholds):

* If > 5 runs in 24 hours **AND** (no skill completed **OR** distress trend increasing) → externalisation prompt: "You've done several runs today. Try one action outside the app now."
* If > 5 runs in 24 hours **BUT** distress decreasing and skills being completed → no intervention (this may be productive intensive practice)
* Optionally lock Workshop/Run behind cooldown (user setting)

## 11.2 Privacy defaults

* Everything stored locally by default
* Optional passcode/Face ID
* Optional encrypted sync
* Export requires explicit user action
* Clear "What gets sent to the agent" disclosure:

  * structured fields only by default
  * free text only when user initiates Workshop or revision
  * never the full diary card history, run history, or plan library
* **Server-side data retention**: agent service does not retain user content after the session ends. If content is logged for safety monitoring, retention is limited to 24-hour ephemeral logs for abuse detection only, with defined access controls. No content is retained beyond this window.
* **No third-party sharing**: no analytics partners, no advertising, no research sharing without explicit opt-in consent.
* **Voice data policy**: raw audio is never stored or transmitted; only transcribed text enters the pipeline (see Section 12.5).

---

# 12) Technical implementation details

## 12.1 Storage

* Local database (SQLite/Core Data/Realm — implementation choice later)
* Tables/collections:

  * Skills Plans
  * Runs
  * Diary Card Entries
  * Safety Plan
  * Review Events
  * Standardised Measure Administrations (post-MVP)
  * Workshop State (for save/resume)
  * User Settings
  * Commitments (linked to plans)
* Versioned migrations for skills plan schema updates

## 12.2 Recommendation engine and adaptation logic

The recommendation engine is a deterministic rules engine that uses diary card data, run history, and contextual signals to drive suggestions.

### Contextual signals considered

* Diary card trends (recent target behaviour frequency, urge patterns, skill use patterns)
* Time of day, day of week
* Recency of last run
* Recent run outcomes (improving/stable/worsening)
* Current emotional intensity (if captured via diary card or run)
* Active commitments (did the user commit to trying a specific skill?)
* Target hierarchy (life-threatening concerns always surface first)
* Tapering status (is the user in maintenance mode for any plan?)

### Adaptation types

* Which skills plan to suggest on the home screen and Run start screen
* Which skill within a plan to recommend on Screen C
* Whether to suggest a full run, a quick skill, or just a diary card check-in
* Whether to prompt a review instead of a run
* Whether to surface the safety plan
* Whether to trigger tapering (see Section 12.6)
* Whether to activate low-capacity mode suggestions

### Decision logic (rules table)

* If diary card indicates life-threatening target behaviour → surface safety plan before anything else
* If diary card hasn't been completed today → prompt diary card before suggesting a run
* If last run was <2 hours ago and intensity was low → suggest "try acting outside the app" instead of another run
* If the user has an active commitment → remind them of it on the home screen and Run start screen
* If time matches a known high-activation period (from diary card data) → proactively suggest the relevant plan
* If standardised measure is due → prompt measure (post-MVP)
* If skill diversity is low (>80% of skill use from one module) AND target behaviour persists AND skill completion rate is high AND outcome improvement is minimal → suggest trying a skill from a different module. Otherwise, do not enforce diversity — some patterns genuinely require skills from a single module.
* Intensity very high (≥ 80) → recommend distress tolerance skills first (TIPP, grounding, paced breathing); consider activating low-capacity mode
* Emotion unknown (alexithymia routing) → recommend body-based or distress tolerance skills
* Urge = "avoid" + plan targets avoidance → recommend opposite action
* Urge = "lash out" or "argue" → recommend interpersonal effectiveness skills (preparation run framing)
* Late-night + high distress → recommend rapid distress tolerance + one small commitment

## 12.3 Target hierarchy evaluator

The target hierarchy evaluator runs at every app launch and after every diary card entry:

1. Check for life-threatening indicators (diary card target behaviours flagged as self-harm, high distress + self-harm urge, acute risk classifier triggers)
   * If present → surface safety plan, interrupt normal flow
2. Check for app-interfering indicators:
   * Prolonged absence (3+ days no diary card): show **"Welcome back"** state with low-friction re-entry (one quick run or one diary card). NOT a review prompt. NOT a "why were you away" message.
   * High run volume without skill use: gentle prompt to try skills outside the app.
   * Plans with zero runs: gentle suggestion to try a run.
3. Otherwise → normal flow (suggest relevant plan based on diary card patterns via home screen)

## 12.4 Agent service interface

Endpoints (conceptual):

* `workshop.start`
* `workshop.nextStep`
* `workshop.resume` (for Workshop persistence)
* `plan.generate`
* `plan.patch`
* `plan.repair`

Each returns:

* user-facing text (optional — must include validation language before any change-oriented content; must follow reduced-text-density constraints)
* machine-readable JSON block
* validation metadata (including `validation_present: true`)
* `workshop_state` update (populated slots, current stage, completeness)

## 12.5 Voice input pipeline

* On-device Whisper model (suggest `whisper-small` or `whisper-base` for latency; `whisper-medium` if accuracy is prioritised)
* **Optimistic UI**: the app buffers audio and allows the user to proceed to the next screen before transcription completes. Transcription catches up in the background. The user is never blocked by a "thinking" spinner.
* Real-time transcription displayed as user speaks (streaming confidence)
* No audio persistence — raw audio is discarded after transcription
* Text post-processing: punctuation, basic cleanup
* **Edit-before-confirm** (required, not optional): after transcription, the user sees the text and can edit before confirming. This is a requirement, not a UI nicety — transcription accuracy varies significantly for users with speech differences, accented speech, or emotional activation.
* **Text input parity**: text input must be equally accessible to voice input. The text field is always visible alongside the microphone button — never hidden behind it.
* Microphone button available on all free-text fields throughout the app
* Voice input is the recommended input method for:
  * Situation descriptions and optional notes in Run mode
  * All Workshop stages, since the user needs to think aloud rather than compose precise text
  * Optional diary card notes

## 12.6 Tapering protocol

The tapering evaluator runs weekly, after diary card data is aggregated:

**Trigger conditions** (all must be met):
* Target behaviour frequency below threshold for 4+ consecutive weeks (from diary card)
* Skill use for this plan is consistent (used in ≥ 3 of last 4 weeks)
* No escalation rules currently triggered for this plan

**When triggered**:
* Suggest maintenance card transition: "This plan has been working well for 4 weeks. You may not need it actively any more — here's a maintenance card for if this pattern returns."
* Reduce proactive plan suggestions for this plan (lower its recommendation priority)
* Offer to transition diary card tracking from daily to weekly check-in for this plan's dimensions
* Suggest practising skills without the app and logging the outcome later

**Tapering is a suggestion, not automatic**: the user confirms or declines. The plan remains fully active until the user agrees to transition.

**Distinction from disengagement**: tapering applies to plans where improvement is sustained. Disengagement detection (Section 11.1) applies when the user stops engaging without improvement. The two systems are complementary.

## 12.7 Validation pipeline

* JSON schema validation
* Constraint validation (field lengths, required fields, enum membership)
* Skill library reference validation (all `skill_id` references resolve)
* Dialectic check (`validation_statements` present, non-empty, contains 2–3 entries)
* Content policy checks (no medical instructions, no harmful content)
* If fail → repair loop with explicit error list

---

# 13) Constrained lists (emotion, urge, body sensation)

These lists are used throughout the app: diary card, Run mode capture, Workshop stages, Quick Triage. The vocabulary is designed for the target audience — plain language, not clinical jargon, with manageable list sizes that avoid both paralysis (too many options) and frustration (too few).

## 13.1 Constrained emotion list (16 items + escape)

Grouped by category for visual organisation, but presented as a flat selectable list:

**High-energy difficult**: Angry, Anxious, Panicked, Frustrated, Overwhelmed
**Low-energy difficult**: Sad, Numb, Empty, Exhausted, Ashamed
**Mixed/other**: Guilty, Jealous, Disgusted, Confused, Lonely
**Positive** (for diary card "emotions today"): Content

**Escape option**: "I don't know / something but I can't name it" — always available, prominently placed, does not dead-end the flow. Routes to body-sensation-based skill selection.

Design rationale: 16 items is manageable without scrolling on most devices. Categories aid scanning without requiring the user to understand emotion theory. The escape option is critical for alexithymia accommodation — estimated 50–65% of autistic adults experience clinically significant alexithymia.

## 13.2 Constrained urge list (12 items)

* Avoid / withdraw
* Shut down / go numb
* Lash out / snap
* Run away / flee
* Scroll / zone out
* Drink / use substances
* Not eat / restrict
* Binge / overeat
* Self-harm
* Ruminate / overthink
* Mask / hide how I feel
* Check / seek reassurance

Design rationale: derived from common DBT target behaviours plus AuDHD-relevant urges (mask, shut down, flee). "Mask / hide how I feel" is included because masking is a pervasive pattern for autistic users that the chain analysis framework can accommodate. "Self-harm" is included to enable risk detection routing.

## 13.3 Constrained body sensation list (12 items)

* Tight chest
* Tight jaw / clenched teeth
* Stomach drop / nausea
* Racing heart
* Numbness / no sensation
* Tingling / buzzing
* Heavy limbs
* Restless / can't be still
* Shallow breathing
* Hot face / flushing
* Lump in throat
* Headache / pressure

Design rationale: body sensations are the primary entry point for users with alexithymia. The list covers the most commonly reported somatic correlates of high-intensity emotional states. Items use plain language ("tight chest" not "thoracic tension"). The list is always available alongside or instead of emotion selection — it is not a fallback for when emotion selection fails; it is an equal-status alternative.

---

# 14) Expected behaviours (edge cases)

## 14.1 User is exhausted / low compliance

* Allow "Skip capture" in Run mode and still log a minimal run (just plan used + skill attempted)
* Offer Quick Skill path (skip everything, go straight to a skill)
* Low-capacity mode activates automatically at high intensity (see Section 8.4)
* Offer single rapid skill with timer (60 seconds)
* Diary card "Skip today" option (logs date only — better than nothing)
* Prevent long text walls in all modes

## 14.2 User wants to vent

* Provide an optional one-line note (Run mode and diary card)
* Prompt: "Do you want to build a plan for this pattern?" (→ Workshop)
* No infinite conversation mode. The agent always steers toward structured output.

## 14.3 Skills plan isn't working

* After 3 weeks of diary card data with target behaviour not decreasing → prompt revision:
  * Change skill selection (try a different skill at the same insertion point)
  * Change insertion point (intervene earlier in the chain)
  * Revisit the chain analysis (is the chain template still accurate?)
  * Consider professional support (if multiple plans show no improvement)
* After 3 runs where skill is marked "not helpful" → suggest replacing that specific skill

## 14.4 User uses the app compulsively

* Refined detection: >5 runs/day AND (no skill completed OR distress increasing) → externalisation prompt
* If >5 runs/day BUT distress decreasing and skills being completed → no intervention
* Suggest: "You've used the app several times today. Try one skill outside the app now — and check in on the diary card tonight."
* Optionally lock Workshop/Run behind cooldown (user setting)

## 14.5 User is deteriorating

* Escalation rules (see Section 11.1) are evaluated after each diary card entry, and weekly
* MVP escalation uses diary card data only (target behaviour trends, distress trends, skill use patterns)
* Post-MVP: also evaluated after each standardised measure administration
* If triggered: show calm escalation prompt with professional support resources
* User can acknowledge and continue, pause the plan, or archive it
* This is framed as part of stepped care, not as failure

## 14.6 User has no active plans

* First launch: guide directly to onboarding → Workshop
* All plans completed/archived: congratulate skill development, offer to build a new plan or maintain existing maintenance cards
* The app should always have a clear "what to do next" — never a blank screen (home screen handles this)

## 14.7 Conflicting target hierarchies

* If the user has plans at multiple hierarchy levels, the app always prioritises higher levels
* Life-threatening plans are checked first at every app launch
* The user is told about this during onboarding and it is reinforced in the plan dashboard

## 14.8 User cannot identify emotions (alexithymia)

* "I don't know" option available on all emotion selection screens (Run mode, diary card, Workshop)
* If selected: route to body-sensation-based and distress tolerance skills
* Log `emotion_unknown: true` for pattern analysis
* If "I don't know" is selected repeatedly (>50% of entries over 2+ weeks): the app gently introduces body-sensation vocabulary as the primary pathway, reducing emphasis on emotion labels without removing them
* The agent in Workshop mode offers body-sensation-led chain building as an equal-status alternative

---

# 15) Curated DBT Skills Library

The app maintains a curated library of evidence-based DBT skill templates, organised by the four canonical modules. The agent selects and parameterises skills from this library; it does not invent new skills.

## 15.1 Skill template structure

Each template contains:

* `skill_id` (unique identifier)
* `module` (enum: `mindfulness`, `distress_tolerance`, `emotion_regulation`, `interpersonal_effectiveness`)
* `name` (e.g., "TIPP", "Opposite Action", "DEAR MAN", "Observe")
* `plain_language_name` (brief description for users unfamiliar with DBT — e.g., "Doing the opposite of what the emotion pushes you to do")
* `skill_type` (enum: `in_the_moment`, `preparation` — see Section 15.4)
* `indication` (when to use — chain link types, intensity levels, urge types)
* `contraindications` (when not to use)
* `intensity_range` (recommended intensity range: e.g., "high" for TIPP, "moderate" for Check the Facts)
* `steps` (ordered list of concrete instructions, each ≤ 120 characters)
* `example_scripts` (parameterised text templates — the agent inserts user-specific language and context)
* `duration_estimate` (e.g., "30 seconds", "2–5 minutes")
* `timer_required` (boolean — does this skill use a timer?)
* `sensory_notes` (any sensory considerations — e.g., "involves cold water", "involves physical movement", "requires quiet environment")
* `sensory_alternatives` (alternative instructions for users with sensory sensitivities)
* `evidence_basis` (brief citation or rationale)

## 15.2 Skills by module (initial library — MVP)

### Mindfulness

* **Observe** ("Notice without reacting"): Notice internal/external experience without reacting. Steps focus on concrete present-moment anchors (breath, body sensations, environmental sounds, objects).
* **Describe** ("Put words to what's happening"): Put words to the experience. "I'm noticing the urge to avoid. I'm noticing tension in my chest."
* **Non-judgmental stance** ("Drop the second layer"): Notice the emotion without the secondary layer ("I shouldn't feel this way"). Reframe to: "I'm feeling [X]. That's what's here right now."
* **Wise Mind** ("Find the middle ground"): Access the synthesis of emotional mind and rational mind. Steps guide the user through acknowledging both, then asking: "What does my wise mind say about this?"

### Distress Tolerance

* **TIPP (Temperature)** ("Cold to calm down fast"): Cold water on face / ice cubes to trigger the dive reflex and reduce physiological arousal. Sensory note: flag for sensory sensitivity, offer cool water alternative.
* **TIPP (Intense exercise)** ("Move to shift the feeling"): Brief intense physical activity (star jumps, running in place) to metabolise stress hormones. 60–90 seconds.
* **TIPP (Paced breathing)** ("Slow breathing to settle"): Slow exhale-focused breathing. Inhale 4, exhale 8. Timer-supported.
* **TIPP (Paired muscle relaxation)** ("Tense and release"): Tense and release muscle groups while breathing. Steps for 3 muscle groups.
* **Radical Acceptance** ("Stop fighting what is"): "This is what is happening. I don't have to like it. Fighting reality doesn't change it." Steps guide through acknowledging facts, releasing the fight, and turning the mind.
* **Pros and Cons** ("Weigh it up quickly"): Quick structured evaluation: pros of acting skilfully, cons of acting skilfully, pros of the problem behaviour, cons of the problem behaviour. Template pre-filled from chain analysis.
* **Distract with ACCEPTS** ("Shift your attention"): Activities, Contributing, Comparisons, Emotions (opposite), Pushing away, Thoughts (other), Sensations.

### Emotion Regulation

* **Check the Facts** ("Is this fitting the situation?"): Is the emotional response fitting the actual situation? Steps guide through: what is the prompting event (facts only), what are my interpretations, what are other possible interpretations, does my emotion fit the facts?
* **Opposite Action** ("Do the opposite of what the emotion pushes"): When an emotion is pushing toward an unhelpful action, deliberately do the opposite. Steps are parameterised from the chain analysis (e.g., "The urge is to not reply. Opposite action: reply within 5 minutes, even if it's brief.").
* **Build Mastery** ("Do one competence-building thing"): Do one thing today that builds competence. Pre-populated from user context.
* **PLEASE (Physical health basics)** ("Check the basics"): Check in on: Physical illness, Eating, mood-Altering substances, Sleep, Exercise. Brief checklist.

### Interpersonal Effectiveness

* **DEAR MAN** ("Make a request or say no") (preparation skill): Describe, Express, Assert, Reinforce, stay Mindful, Appear confident, Negotiate. Steps parameterised with the user's specific situation.
* **GIVE** ("Keep the relationship") (preparation skill): Gentle, Interested, Validate, Easy manner. Steps for a specific interaction.
* **FAST** ("Keep your self-respect") (preparation skill): Fair, no unnecessary Apologies, Stick to values, Truthful. Checklist before/during a difficult interaction.

## 15.3 Agent's role with the skills library

In Workshop Stage 5, the agent:

1. Selects appropriate skill templates based on the chain analysis (link type at insertion point, intensity, urge type)
2. Parameterises them with the user's specific language and context (e.g., inserting the user's specific avoidance behaviour into an Opposite Action script)
3. Presents 2–3 options with one-line rationales; user selects (choice is appropriate in Workshop — the user is in a reflective state)
4. Flags sensory considerations for user confirmation
5. Explains each skill briefly on first encounter, using the `plain_language_name`

In Run mode (Screen C), the recommendation engine:

1. Selects **one** skill based on current intensity, urge type, emotion (or body state if emotion unknown), and the plan's skill sequences
2. Shows this single recommendation prominently, with "See alternatives" de-emphasised
3. The agent is not involved in Run mode skill selection — this is a deterministic, rules-based decision

The agent does NOT generate novel skills. Scripts generated by the agent must stay within the template's structure. The agent may adapt language, examples, and specific instructions to the user's context but may not alter the skill's core mechanism or steps.

## 15.4 Skill types: in-the-moment vs preparation

The skills library distinguishes two temporal categories:

**In-the-moment skills**: designed to be used during or immediately after the triggering event. The user can step away, open the app, and practise the skill alone.
* Includes: all Mindfulness skills, all Distress Tolerance skills, all Emotion Regulation skills
* Run mode framing: standard ("Here's your skill. Let's go.")

**Preparation skills**: designed to be reviewed and rehearsed *before* an anticipated interaction. The user prepares a script or checklist, then uses it during the interaction, then logs the outcome afterwards.
* Includes: DEAR MAN, GIVE, FAST (Interpersonal Effectiveness)
* Run mode framing: "Preparation run — review before your conversation"
* Screen D shows the parameterised script for review and rehearsal
* Screen E asks "How did the conversation go?" with option to log later
* These plans may also include in-the-moment skills for managing activation before/after the interaction (e.g., paced breathing before a difficult conversation)

---

# 16) First Use / Onboarding

On first launch, before the first Workshop, the app provides a brief (~2 minute) interactive orientation.

## 16.1 Content

The orientation assumes **zero DBT knowledge**. It introduces four concepts using concrete examples, not clinical definitions:

* What's a chain — "Something happens → you feel something → you do something → it costs you something. That sequence is a chain. We all have them."
* What's a skill — "A skill is a specific thing you can do at a specific point in the chain to change what happens next. Not 'think positive' — more like 'hold cold water to your face for 30 seconds to bring the intensity down.'"
* What the diary card is — "A quick daily check-in that helps the app learn your patterns and suggest the right skills."
* What a skills plan is — "A reusable plan that connects your chain to your skills, so when the pattern shows up, you know exactly what to do."

This is not a content library or a course. It's the minimum conceptual scaffolding needed for the user to participate in their own chain analysis and skill selection.

## 16.2 Flow

* The orientation ends by launching the first Workshop with the framing: "Let's try this with something real."
* First Workshop defaults to **quick build** (minimal chain + one skill) — depth increases through revision.
* Skippable for users who already understand the DBT model.

## 16.3 Onboarding load management

**Target**: first-completed-run within 15 minutes of first launch.

To achieve this, the following are **deferred to after the first Workshop and first Run**:

* Safety plan setup (strongly encouraged but not blocking)
* Diary card timing preference (defaults to evening; changeable later)
* Baseline standardised measures (post-MVP in any case)

The user experiences the core loop (chain → skill → outcome) before being asked to configure anything else.

**Interruptible and resumable**: if the user drops off mid-onboarding, the app picks up where they left off. No restart required.

## 16.4 Safety plan setup (post-first-run)

* After the first completed run, the app prompts the user to build a personal safety plan
* This is strongly encouraged but skippable ("I'll do this later")
* The safety plan setup is a simple form: warning signs, coping strategies, people to contact, professional resources, emergency numbers
* Pre-populated with UK crisis resources; user adds personal contacts and strategies

## 16.5 Diary card setup (post-first-run)

* User selects preferred diary card timing (morning, evening, or custom window)
* User can add custom dimensions beyond the defaults (e.g., avoidance, connection)
* Notification preference (silent by default; can enable vibration)

## 16.6 Baseline measures (optional, post-MVP)

* If the user agrees, complete a baseline PHQ-9 and/or GAD-7
* This provides a starting point for standardised measure tracking
* Skippable — can be set up later via the plan's standardised measures configuration

---

# 17) Visual design system

## 17.1 Design principles

* Warm, calm, low-stimulation — not clinical, not "therapy aesthetic," not playful
* Low contrast fatigue (no harsh whites at night; dark mode as default option)
* Minimal ornamentation
* Clear hierarchy; one primary action per screen
* No streaks, badges, confetti, or dopamine bait
* **No sounds**: the app is silent. No notification sounds, no completion sounds, no UI sounds.
* **Haptic feedback**: subtle haptic feedback on sliders, completions, and confirmations. Configurable (on/off). This is a polish-level concern for after core functionality is stable.
* **Predictable layout**: screens do not rearrange, reflow, or change structure between sessions
* **Reduced text density**: prefer visual indicators over text wherever possible

## 17.2 Components

* **Emotional thermometer**: the primary intensity input — a vertical slider with colour gradient (cool to warm), replacing numeric 0–100 labels with visual intensity. Large, thumb-friendly. The thermometer is a documented adaptation from autism-focused DBT work.
* **Body distress thermometer**: parallel to the emotional thermometer, for users who read somatic signals more easily than emotional labels. Same visual design.
* **Chips**: for emotion/urge/body sensation/context tags — large tap targets, clear labels. Plain language throughout.
* **Cards**: plan suggestions, skill options — one card per option, no nesting
* **Timer**: prominent but calm, for timed skill practices
* **Checklist**: max 5 items, tappable, no nested complexity — for skill steps
* **Voice input**: microphone button available on all free-text fields. Text field always visible alongside — never hidden behind the microphone. Tap to speak; transcription appears in real-time. User can edit before confirming.
* **Chain visualiser**: a simple vertical flow diagram showing the chain links in order, with skill insertion points highlighted. Used in Workshop (being built) and Run mode (Screen B — chain recognition).
* **"You're done" confirmation**: a brief, clear end-state screen shown after diary card completion and run completion. No ambiguity about whether the interaction is finished.

## 17.3 Typography & language

* Short sentences
* No moral language ("should," "failed," "good," "bad")
* Copy style: "Here's your skill" / "What will you do next?" / "This makes sense" / "Not helpful"
* Validation language is always present before action language
* **Plain language first**: avoid clinical jargon in user-facing copy. DBT terms are accompanied by plain-language descriptions (e.g., "Opposite Action — doing the opposite of what the emotion pushes you to do"). Technical terms are used in the data layer but not required in the UI.
* Sensory notes on skills with physical components (e.g., "Involves cold water — skip if this is difficult for you")

## 17.4 Sensory customisation (neurodivergence-informed)

* Dark mode (default option, not just available)
* Reduced contrast option
* No sudden animations or transitions
* No auto-playing audio or video
* Haptic feedback configurable (on/off)
* Font size adjustable (respects system Dynamic Type and Bold Text)
* **Post-MVP**: dyslexia-friendly font option, monospace option, adjustable interface density (comfortable vs compact spacing)

---

# 18) Traceability: vision → features

* **Acceptance AND change (the dialectic)** → Screen C (validate + orient) is non-skippable; `validation_statements` (2–3 variants, rotated) required in every plan; agent validates before every change-oriented output
* **Skills use as the mechanism** → skill practice is the core run action; skills use frequency is the primary success metric; diary card tracks skill use daily; review surfaces skill effectiveness data
* **Chain analysis as the analytical engine** → Workshop Stages 1–4 build the chain template (slot-filling approach); Run Screen B includes chain recognition; chain insertion points determine skill selection
* **Target hierarchy** → `hierarchy_level` required on every plan; target hierarchy evaluator runs at every launch and diary card entry; life-threatening concerns always surface first
* **Diary card as control system** → daily monitoring instrument independent of runs; feeds recommendation engine, risk monitoring, review prompts, tapering evaluator, and evidence layer; capped at 3 active plans for manageability
* **Frictionless when activated** → 6-screen runs (2 skippable), Quick Skill rapid path (skip everything), low-capacity mode (auto-adapts at high intensity), rapid skill option (60 seconds), voice input throughout, emotional thermometer over numeric scales, skip options on capture
* **Predictability** → same screen order always, same diary card layout always, same workshop stage structure always, same home screen layout always, no layout changes between sessions
* **Neurodivergence-informed** → emotional thermometer, body distress thermometer, alexithymia accommodation ("I don't know" option, body-sensation-first pathways), reduced text density, concrete stepwise instructions, sensory notes on skills, sensory customisation, "you're done" signals, gentle about gaps, low-capacity mode, PDA-aware disengagement framing, masking as recognised pattern
* **Accessible to complete beginners** → no DBT jargon without explanation; plain-language skill names; in-context education during Workshop; onboarding uses concrete examples not definitions; agent explains concepts conversationally on first encounter
* **Validation is structural** → Screen C is not skippable; validation language precedes all change-oriented content; `validation_statements` is a required field with 2–3 variants that rotate across runs; Workshop stage transitions require `validation_present: true`
* **Commitment strategies** → Workshop Stage 8 captures commitment; Run Screen E includes commitment step; commitment lifecycle defined (created → active → replaced → cleared); recommendation engine reminds user of active commitments; commitments visible on home screen and plan dashboard
* **Skills practice over explanation** → primary run path is recognise → skill → do → log; skill library is a reference, not a curriculum; no psychoeducation blocking the action path; Quick Skill path for maximum urgency
* **Interpersonal skills as preparation** → skills library distinguishes in-the-moment from preparation skills; Run mode adapts framing for preparation runs; user rehearses before interaction, logs outcome after
* **Data as feedback** → no streaks, no badges, no gamification; review is sparse and calm; stagnation framed as information, not failure; micro-reflection prompts in weekly review
* **Measurement as infrastructure** → MVP escalation rules use diary card data only; standardised measures extensible beyond PHQ-9/GAD-7 (post-MVP); escalation rules evaluate trends; plan completion pathway based on sustained improvement
* **Internalisation and tapering** → tapering protocol evaluates sustained improvement weekly; maintenance card transition; reduced prompts; diary card frequency reduction; success celebrated as positive outcome
* **Less use over time** → success metrics not tied to engagement; prompts to act outside app; plan completion pathway with maintenance cards; tapering protocol; the app celebrates skill internalisation
* **Honest limits** → escalation rules, stepped-care framing, professional support recommendations, clear "this is DBT-informed self-help, not comprehensive DBT" positioning
* **Home screen** → ties all modes together; always shows one clear next action; personalised recommendations; safety plan always accessible; Quick Skill always accessible; welcome-back state for returning users
* **Privacy** → local-first, on-device voice transcription, no third-party sharing, minimal data to agent, diary card history never sent to agent, 24-hour ephemeral server logs only, no sounds
* **Safety as infrastructure** → personal safety plan built post-first-run, accessible everywhere, surfaced automatically by risk signals; crisis content is static, never LLM-generated; MVP escalation works without standardised measures

---

# 19) MVP cut (what to build first)

MVP must include:

* Home screen (with recommendation engine, suggested plan, diary card prompt, Quick Skill button)
* Skills plan library (create, view, archive)
* Run mode (6 screens, 1 non-skippable [Screen C — validate + orient], 2 skippable [Screen B capture, Screen F summary])
* Quick Skill rapid-access path
* Low-capacity mode (auto-activation at high intensity)
* Workshop mode (agent-guided with slot-filling approach, chain analysis, skill selection, save/resume, quick build option)
* Diary card (daily monitoring instrument with reminders, 3-plan cap, body sensation support)
* Constrained emotion, urge, and body sensation lists with "I don't know" option
* JSON validation + repair loop
* Curated DBT skills library (at least 3–4 skills per module, covering the most common patterns, with in-the-moment/preparation distinction)
* Skills plan dashboard (basic charts: skill use, target behaviour trend, urge trend)
* Personal safety plan module
* Target hierarchy logic (life-threatening → app-interfering → quality-of-life)
* Basic escalation rules using diary card data only (acute risk → safety plan; chronic non-response → gentle prompt; disengagement → welcome-back state)
* Tapering protocol (maintenance card transition when improvement sustained)
* Commitment lifecycle (create, display, replace, clear)
* Local storage + export/import
* Voice input pipeline (with optimistic UI and edit-before-confirm)
* Safety resources screen (static, UK-focused)
* In-context DBT concept explanations (agent and UI)

Defer:

* Encrypted sync
* Global dashboard (across all plans)
* Advanced analytics (chain interruption point tracking, skill diversity analysis)
* Standardised measures (PHQ-9, GAD-7) and standardised-measure-dependent escalation rules
* Therapist integration (diary card sharing, progress exports)
* Multi-device continuity
* Sensory customisation beyond dark mode (font options, interface density)
* Text-to-speech for agent output
* Haptic feedback polish

---

# 20) Regulatory and Governance Considerations

* An app that uses an LLM to adapt skill recommendations based on health data may be classified as a medical device by the MHRA, depending on intended purpose and claims made.
* The product should be designed to be compatible with:
  * NICE's Evidence Standards Framework (ESF) for digital health technologies
  * NHS England's Digital Technology Assessment Criteria (DTAC)
* Specific design implications:
  * Adaptive algorithms must be auditable (the curated skills library + deterministic recommendation engine + rules-based escalation support this)
  * Claims must be evidence-based (avoid clinical treatment claims without supporting evidence)
  * Data handling must comply with UK GDPR
  * The target hierarchy evaluator and escalation rules must be testable and documentable
  * Safety plan content and crisis resources must be static and pre-approved, not LLM-generated
* The app is explicitly positioned as a **DBT-informed self-help tool**, not a clinical treatment programme. This is the most defensible regulatory position for a first version.
* This section should be reviewed with legal/regulatory counsel before any public release or NHS engagement.
