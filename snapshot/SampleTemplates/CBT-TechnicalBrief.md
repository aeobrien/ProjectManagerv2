## Technical brief: CBT Protocol Builder + Runner

### Document purpose

Define the complete product/technical specification for a CBT-based app that:

* turns recurring mental patterns into **structured protocols** via an agent-led workshop
* supports **fast, low-friction “run mode”** in the moment
* relies on **behavioural experiments + outcome logging** to retrain beliefs over time
  …and does so in a way that operationalises the vision statement (agency, evidence, neutrality, reduced salience, repetition over brilliance).

---

# 1) Product scope

## 1.1 In scope

* Protocol authoring via guided agent workflow (“Workshop mode”)
* Protocol execution (“Run mode”) optimised for low cognitive load
* Structured logging and review loops (charts, summaries, protocol revision prompts)
* A deterministic, validated JSON protocol format with versioning
* Safety gating and escalation copy (non-clinical; encourages professional support when needed)
* Local-first storage with optional encrypted sync/export
* A small set of built-in protocol templates (CBT, plus ACT-style defusion as a permitted technique)

## 1.2 Explicitly out of scope

* Diagnosis, treatment claims, clinical triage, crisis intervention beyond signposting
* Freeform journaling as a primary function (only optional notes within runs)
* “Feel-good” chatbot reassurance loops
* Infinite conversation without protocol output
* Social features (feeds, posting, commenting)
* Ads, dark patterns, engagement-maximisation

---

# 2) Success criteria

## 2.1 Primary success metrics (behavioural)

* Median “Run” completion time ≤ 5 minutes
* ≥ 60% of runs include a behavioural step (experiment/opposite action/values action)
* Belief strength decreases over repeated runs for targeted protocols (within-user trend)
* Protocol revision rate reflects learning (protocols evolve, rather than stagnate)

## 2.2 Secondary success metrics (experience)

* Low abandonment mid-run
* Users can create a new protocol in ≤ 10 minutes with agent help
* Users report increased confidence in “I know what to do when this shows up”
* Time-to-first-completed-run (target: within first session of app use)
* 7-day and 30-day return rates (tracked, not optimised — these are diagnostic, not targets)
* “Minimum effective dose” identification: what is the fewest number of runs at which users begin to show belief-strength shifts? Design onboarding to get users past this threshold.

## 2.3 Anti-metrics (guardrails)

* Increasing daily time spent in app is **not** a success metric
* Excessive reliance on chatbot (high chat volume with low protocol output) is a failure mode
* Optimising for return-rate at the expense of clinical integrity is a failure mode. Engagement metrics inform design; they do not drive it.

---

# 3) System overview

The product has two primary modes plus an evidence layer:

1. **Run Mode** (fast, minimal, action-led)
2. **Workshop Mode** (agent-led protocol construction)
3. **Evidence & Review** (charts, summaries, protocol revision prompts)

Everything revolves around two core objects:

* **Protocol** (reusable plan)
* **Run** (a single execution instance of a protocol)

---

# 4) Architecture

## 4.1 High-level components

* **Client App** (iOS/macOS first, or iOS-only initially)

  * UI + local database
  * protocol runner engine
  * lightweight rules engine for “recommended next step”
  * on-device speech-to-text engine (e.g., Whisper) for voice input transcription
* **Agent Service** (LLM-backed)

  * structured workshop interview
  * JSON protocol generation
  * JSON validation + repair loop
  * safety classifier (non-clinical: self-harm cues → show resources)
* **Sync/Backup (optional)**

  * encrypted cloud sync (user-controlled)
  * export/import of protocol library + run history
* **Analytics (optional, privacy-first)**

  * local-only analytics by default
  * opt-in anonymous telemetry (crash, performance) with no content

## 4.2 Data flow principles

* **Local-first**: runs and protocol library stored on-device
* **Minimise sensitive content**:

  * structured fields preferred (sliders/toggles)
  * free text optional and clearly flagged as sensitive
* **Agent never needs your full history**:

  * only send the minimum context required to build/modify a protocol
  * summarise on-device where possible
* **Voice input transcribed locally**: voice input is transcribed on-device using a local model. Raw audio is never stored, transmitted, or sent to any external service. Only the resulting text enters the data pipeline.

## 4.3 LLM integration contract (strict)

The agent does **not** directly change app state.
It outputs:

* a **Protocol JSON** (or protocol patch)
* optional “explanations” strictly separated from machine-readable output

Client accepts protocol only if it passes:

* schema validation
* constraint validation (length, required fields, allowed enums)
* safety rules (no harmful advice, no medical instructions)

The agent may customise intervention scripts within template boundaries but may not invent new intervention types or mechanisms. All interventions in a generated protocol must reference a valid `intervention_id` from the curated intervention library (see Section 15).

If invalid:

* client requests a repair from agent with the validation errors (automatic loop)

---

# 5) Protocol JSON spec (v1)

## 5.1 Protocol object

Required fields:

* `id` (UUID)
* `version` (semver: `1.0.0`)
* `name` (short)
* `summary` (1–2 sentences, neutral)
* `when_to_use` (list of triggers)
* `hot_thought_templates` (list)
* `maintaining_behaviours` (list of typed behaviours)
* `targets`:

  * `target_belief` (single sentence)
  * `target_loop` (e.g., rumination, avoidance)
* `capture_fields` (ordered list of fields to show in Run capture)
* `interventions` (ordered, typed, with scripts)
* `experiments` (0+ structured experiments)
* `measures` (what to rate before/after)
* `review_rules` (when/how to prompt revision)
* `safety` (copy + links/resources; region-aware UK by default)
* `status` (enum: `active`, `paused`, `completed`, `archived`)

Optional:

* `completion_summary` (user-generated summary of what was learned)
* `relapse_prevention_card` (minimal protocol: key trigger, updated belief, best intervention)

* `tags` (context tags)
* `exclusions` (when not to use; e.g., panic attack protocol vs grief)
* `tone` (always neutral; stored for consistency)
* `defaults` (default slider values, recommended interventions)
* `standardised_measures`: array of measure objects, each containing:
  * `measure_id` (e.g., "PHQ-9", "GAD-7")
  * `frequency` (e.g., "weekly", "fortnightly")
  * `last_administered` (timestamp)
  * `scores[]` (timestamped history)
* `escalation_rules`: array of rule objects, each containing:
  * `trigger` (e.g., "PHQ-9 increase ≥ 5 points over 2 administrations", "no completed runs in 14 days", "3+ protocols with no improvement")
  * `action` (e.g., "show escalation prompt", "suggest professional support", "pause protocol and show review")

## 5.4 Formulation model

Required field in Protocol object:

* `formulation`: object containing:
  * `trigger_appraisal_links[]`: array of objects mapping `trigger` → `appraisal` (hot thought) → `emotion` → `behaviour`
  * `maintaining_cycles[]`: array of objects, each containing:
    * `behaviour`
    * `short_term_function` (what relief it provides)
    * `long_term_cost` (what it maintains or worsens)
    * `target_intervention_id` (which intervention addresses this)

This structure makes the formulation a coherent model rather than a collection of independent fields. It enables: better agent reasoning during protocol revision (the agent can see *why* each intervention was chosen), clearer user understanding of the maintaining cycle, and the conceptual integration that distinguishes CBT from simple coping strategies.

The formulation object is progressively built across Workshop Stages 1–4.

## 5.2 Run object

* `run_id`, `protocol_id`, `timestamp_start`, `timestamp_end`
* capture payload (structured)
* chosen intervention(s)
* completion status
* before/after measures
* optional free-text note (clearly marked)

## 5.3 Validation constraints (important)

* Scripts must be ≤ 240 characters (forces brevity)
* `when_to_use` entries ≤ 80 chars
* At least one intervention must be “actionable” (timer/checklist)
* If any experiment exists, it must include:

  * `prediction`
  * `steps`
  * `measures`
  * `success_criteria`
* All enums must be from controlled lists to keep the system consistent

---

# 6) Workshop Mode (agent-led) workflow

Workshop produces either:

* **New protocol**
* **Revision** of existing protocol (patch)

## 6.1 Workshop stages (deterministic)

The agent must follow this sequence, with user-facing explanations kept short.

Note: Voice input (see Section 11.5) is the primary suggested input method for all Workshop stages, since the user needs to think aloud rather than compose precise text.

### Stage 1 — Define a single instance

Inputs:

* situation (one line, voice or text)
* current hot thought (one line, voice or text)
* emotion + intensity (sliders)
* urge/behaviour (picker)

Expected agent behaviour:

* reflect neutrally
* identify whether this is:

  * a known protocol match (suggest)
  * or a new pattern (continue workshop)

Output:

* candidate pattern label + confidence

### Stage 2 — Extract repeatables (guided discovery)

Agent asks open questions: “When else does something like this show up? What's the thought that keeps coming back?” Agent reflects and sharpens the user's responses. User confirms.

Agent offers hot-thought template suggestions *only if the user is stuck* — not as the primary input method.

Expected agent behaviour:

* use open, curious questioning to help the user identify recurring thoughts
* reduce verbosity
* converge on 2–3 recurring hot thoughts max

Output:

* `hot_thought_templates[]`

### Stage 3 — Identify maintaining behaviours (guided discovery)

Agent asks: “What do you usually do when this thought shows up? What does that do for you in the short term? What does it cost you?”

Agent maps the user's answers to the maintaining-behaviour taxonomy. User confirms the mapping. A pick-from-list becomes a fallback for users who are stuck, not the primary input method.

Expected agent behaviour:

* use the user's own language to map behaviour → function → cost
* reflect the maintaining cycle back to the user for confirmation

Output:

* `maintaining_behaviours[]`

### Stage 4 — Pick one target belief/loop (guided discovery)

Agent asks: “If we could test one thing about this pattern — one prediction your mind is making — what would it be?”

Agent helps the user sharpen the belief into something testable. Agent reflects back candidate formulations only *after* the user has generated their own version.

Expected agent behaviour:

* ensure belief is testable, not global identity judgement
* scaffold the user's own hypothesis generation before offering alternatives

Output:

* `targets.target_belief`

### Stage 5 — Design interventions

Must include:

* 1 micro intervention (≤ 60 seconds)
* 1 short intervention (2–5 minutes)
* optional: rumination scheduling or defusion

Expected agent behaviour:

* select and parameterise intervention templates from the curated intervention library (see Section 15)
* present options with brief rationales; user selects
* parameterise scripts with the user's specific language and context
* scripts must be neutral, non-arguing, and self-compassionate without being motivational

Output:

* `interventions[]` (each referencing a valid `intervention_id` from the library)

### Stage 6 — Design experiments (guided discovery)

Agent scaffolds: “What would it take to find out if [target belief] is accurate? What could you do this week that would give you evidence either way?”

Agent helps shape the user's answer into a structured experiment.

At least one experiment if the pattern is persistent.

Expected agent behaviour:

* scaffold the user's own experiment design before refining it
* create a test with measurable outcomes and a clear prediction

Output:

* `experiments[]`

### Stage 7 — Define run capture and measures

Expected:

* before/after ratings for emotion and belief strength
* optional: urge strength

Output:

* `capture_fields[]`, `measures[]`

### Stage 7.5 — Suggest standardised measures

Agent suggests relevant standardised measures based on the pattern type:

* if target loop involves low mood/avoidance → suggest PHQ-9
* if anxiety/worry → suggest GAD-7

User confirms or declines. If accepted, the user completes the measure as a baseline.

Output:

* `standardised_measures[]`

### Stage 8 — Review rules

Defaults:

* after 5 runs → review prompt
* if no shift after 3 runs → revise scripts/experiment

Output:

* `review_rules[]`

### Stage 9 — Generate JSON + validate

Agent outputs protocol JSON.
Client validates; if errors, client triggers repair loop.

At each stage, the agent progressively builds the formulation object (see Section 5.4), reflecting the emerging chain back to the user: “So when [trigger] happens, you think [appraisal], which makes you feel [emotion], and then you [behaviour] because it gives you [short-term relief], but the cost is [long-term cost]. Does that capture it?”

---

# 7) Run Mode workflow (in-the-moment)

Goal: **fast, low friction, minimal typing, action-first — while preserving clinically validated components**.

Design priority: efficacy over speed. Do not drop clinically validated components to save time. Manage cognitive load through smart defaults, skip options, and voice input instead.

## 7.1 Run flow: 6 screens (with skip options on 2)

### Screen A — Start Run (Protocol selection)

Contents:

* Search bar (protocol names + triggers)
* “Suggested” section (top 3) based on:

  * last used protocols
  * time of day tags
  * recent context tags

Controls:

* Tap protocol to start
* “I’m not sure” → Quick Triage (see below)
* “Emergency resources” link (always present but unobtrusive)

### Screen B — Capture (30–60 seconds)

Exact contents (ordered):

1. **Situation** (optional one-line text or voice input, placeholder “What’s happening?”)
2. **Hot thought** (choose from protocol templates; optional edit)
3. **Emotion** (pick up to 2 from a fixed list; slider 0–100)
4. **Body signals** (tick list: tight chest, jaw, stomach drop, etc.)
5. **Urge** (single-choice list: ruminate/check/avoid/scroll/work/argue/distract/etc.)

Controls:

* Primary: “Next”
* Secondary: “Skip capture” (keeps friction low; logs minimal run)

### Screen C — Brief Guided Discovery (30–60 seconds)

This is the cognitive examination step that distinguishes CBT from simple distraction. It produces the learning that makes runs accumulate into belief change rather than just emotional regulation.

Contents:

* Show the captured hot thought
* “What does this thought predict will happen?” (single-line text or voice input, with common predictions from the protocol as tap-to-select options)
* “What’s an alternative possibility?” (same input method, with protocol-specific alternatives as suggestions)

Controls:

* Primary: “Next”
* Secondary: “Skip to action” (screen is skippable but present by default)

### Screen D — Do (intervention)

App shows **one recommended intervention** (selected from the curated intervention library) and optionally “More options”.

Contents:

* Title (e.g., “Defusion line” / “10-minute delay experiment”)
* One short script line
* If timed: a timer button (start/pause)
* If checklist: 3–5 step checklist

Controls:

* Primary: “Done”
* Secondary: “Switch intervention”
* “Mark as not helpful” (feeds review)

### Screen E — Outcome (30–60 seconds)

Contents:

* Emotion now slider(s)
* Belief strength now (0–100)
* Urge now (optional)
* Outcome tags (multi-select):

  * “Intensity dropped”
  * “Stayed the same but tolerable”
  * “Got worse”
  * “I ruminated anyway”
  * “I avoided”
* “What did you learn from this?” (optional single-line text or voice, with common learning tags: “The prediction didn’t happen,” “It was uncomfortable but tolerable,” “I can handle more than I thought”)
* “One thing to try before the next run:” (optional, single-line, or select from protocol’s experiment steps — this is the homework/forward-planning element)
* Optional note (one line)

Controls:

* “Next”
* “Schedule experiment follow-up” (if an experiment requires later check)

### Screen F — Summary (skippable)

Brief auto-generated summary: “You noticed [hot thought], tested [alternative], and found [outcome tag]. Next step: [forward plan].”

Contents:

* Auto-generated run summary
* “Was this run helpful?” (thumbs up/down — feeds review data)

Controls:

* “Save & close”
* “Skip” (screen is skippable but present by default)

## 7.2 Quick Triage (when user taps “I’m not sure”)

Contents:

* 3 question wizard:

  1. “What’s the main urge?” (list)
  2. “What’s the theme?” (loss/comparison/fear of failure/perfectionism/social threat/uncertainty/etc.)
  3. “How intense?” (0–100)
     Output:
* suggests best-matching protocol or offers to build a new one (Workshop)

---

# 8) Evidence & Review

## 8.1 Protocol dashboard (per protocol)

Contents:

* Run count
* Average pre/post emotion change
* Belief strength trend (line chart)
* Most common urges/maintaining behaviours tags
* Experiment outcomes (pass/fail/notes)
* Standardised measure trends (line chart alongside per-run belief/emotion charts, when available)

Controls:

* “Revise protocol” (launches Workshop revision path)
* “Archive protocol”
* “Export protocol JSON”
* “Reset metrics” (does not delete raw runs; just resets summary)

## 8.2 Weekly review (optional, user-controlled)

Contents:

* 3–5 insight cards max:

  * “This week: rumination urges were highest at 23:00–01:00”
  * “Protocol X reduced emotion by avg 18 points”
  * “Your PHQ-9 score this week: 12, down from 15 two weeks ago” (when standardised measures are available)
* “One suggested revision”
  Controls:
* “Ignore”
* “Revise now”
* “Remind me next week”

Principle: review is **sparse and calm**, not gamified.

## 8.3 Protocol completion

When review data shows sustained improvement (e.g., belief strength consistently below a threshold, standardised measure in remission range, user self-report of reduced pattern activation):

1. Prompt the user to summarise what they learned: "What do you know now that you didn't before?" This captures the generalised skill.
2. Generate a brief "if this returns" relapse-prevention card: a minimal protocol containing the key trigger, the updated belief, and the one intervention that worked best. This card lives in a "Completed" section of the protocol library.
3. Track completed protocols separately from archived ones — completion is a positive outcome; archiving is neutral.

Note: Standardised measures (PHQ-9, GAD-7, etc.) are NOT administered during runs — this would add too much friction. They are administered as standalone prompts at the frequency specified in the protocol. The app surfaces a brief "time for a check-in" notification and presents the questionnaire outside of any specific run.

---

# 9) Visual design system

## 9.1 Design principles

* Neutral, clinical-adjacent but warm (not “therapy aesthetic”)
* Low contrast fatigue (no harsh whites at night; support dark mode)
* Minimal ornamentation
* Clear hierarchy; one primary action per screen
* No streaks, badges, confetti, or dopamine bait

## 9.2 Components

* Sliders: large, thumb-friendly, labelled 0–100
* Chips: for emotion/urge/context tags
* Cards: protocol suggestions
* Timer: prominent but calm
* Checklist: max 5 items, tappable, no nested complexity
* Voice input: microphone button available on all free-text fields. Tap to speak; transcription appears in real-time. User can edit before confirming.

## 9.3 Typography & language

* Short sentences
* No moral language (“should”, “failed”)
* Copy style: “Try this” / “Next step” / “Not helpful”
* Avoid reassurance scripts; focus on observation + action

---

# 10) Safety, privacy, and ethics

## 10.1 Safety gating

### Acute risk detection

During Workshop and optional note entry:

* lightweight classifier for self-harm cues

If triggered:

* stop protocol generation
* show a calm resources screen (UK numbers/links)
* encourage contacting a professional
* allow user to continue only with non-sensitive general content

### Chronic non-response detection

Evaluated after each standardised measure administration, or weekly:

* Sustained lack of improvement or worsening on standardised measures (e.g., PHQ-9 increase ≥ 5 points over 2 administrations)
* Multiple protocols with no belief-strength improvement

If triggered:

* Show a calm, non-alarmist message acknowledging that this pattern may benefit from professional support
* Provide relevant resources (therapist directories, GP referral info, NHS self-referral for Talking Therapies)
* Frame as part of the CBT stepped-care model, not as an app failure
* Allow the user to acknowledge and continue, or to pause the protocol

### Disengagement detection

* Prolonged absence (e.g., no completed runs in 14 days)

If triggered:

* Gentle re-engagement prompt with option to archive protocol or seek support

## 10.2 Privacy defaults

* Everything stored locally by default
* Optional passcode/Face ID
* Optional encrypted sync
* Export requires explicit user action
* Clear “What gets sent to the agent” disclosure:

  * structured fields only by default
  * free text only when user initiates Workshop or revision
  * never the full run history or protocol library unless user explicitly exports
* **Server-side data retention**: agent service should not retain user content after the session ends. If content is logged for safety monitoring, specify retention period and access controls.
* **No third-party sharing**: no analytics partners, no advertising, no research sharing without explicit opt-in consent.
* **Voice data policy**: raw audio is never stored or transmitted; only transcribed text enters the pipeline (see Section 11.5).

---

# 11) Technical implementation details

## 11.1 Storage

* Local database (SQLite/Core Data/Realm—implementation choice later)
* Tables/collections:

  * Protocols
  * Runs
  * Experiments (embedded or separate)
  * Review events
  * User settings
* Versioned migrations for protocol schema updates

## 11.2 Protocol engine and JITAI adaptation logic

* Loads protocol JSON
* Renders capture fields in specified order
* Evaluates escalation rules (see Section 10.1) after each standardised measure administration or weekly
* Logs outcomes and ties them to protocol version

### Contextual signals considered

* Time of day, day of week
* Recency of last run
* Recent run outcomes (improving/stable/worsening)
* Current emotional intensity (if captured via check-in)
* Active experiment status

### Adaptation types

* Which protocol to suggest
* Which intervention within a protocol to recommend
* Whether to suggest a full run or a micro-intervention
* Whether to prompt a review instead of a run

### Decision logic (rules table)

* If last run was <2 hours ago and intensity was low → suggest “try acting outside the app” instead of another run
* If active experiment is in progress → prompt experiment follow-up instead of a new run
* If time matches a known high-activation period (from historical run data) → proactively suggest the relevant protocol
* If standardised measure due → prompt measure before run
* Intensity high → defusion / grounding / delay experiment
* Urge = “check” → anti-check experiment
* Late-night tag → micro-script + tiny values action

## 11.3 Agent service interface

Endpoints (conceptual):

* `workshop.start`
* `workshop.nextStep`
* `protocol.generate`
* `protocol.patch`
* `protocol.repair`
  Each returns:
* user-facing text (optional)
* machine-readable JSON block
* validation metadata

## 11.5 Voice input pipeline

* On-device Whisper model (suggest `whisper-small` or `whisper-base` for latency; `whisper-medium` if accuracy is prioritised)
* Real-time transcription displayed as user speaks
* No audio persistence — raw audio is discarded after transcription
* Text post-processing: punctuation, basic cleanup
* Microphone button available on all free-text fields throughout the app
* Voice input is the recommended input method for:
  * Situation descriptions and optional notes in Run mode
  * Screen C (guided discovery) in Run mode, since the user is thinking aloud
  * All Workshop stages, since the user needs to think aloud rather than compose precise text

## 11.4 Validation pipeline

* JSON schema validation
* Constraint validation
* Content policy checks (no medical instructions, no harmful content)
* If fail → repair loop with explicit error list

---

# 12) Expected behaviours (edge cases)

## 12.1 User is exhausted / low compliance

* Allow “Skip capture” and still log a run
* Offer single micro intervention with timer
* Prevent long text walls

## 12.2 User wants to vent

* Provide an optional one-line note
* Prompt: “Do you want a protocol for this pattern?”
  No infinite journaling mode.

## 12.3 Protocol isn’t working

* After 3 runs with <10-point improvement → prompt revision:

  * change target belief
  * change experiment difficulty
  * adjust scripts

## 12.4 User uses the app compulsively

* Detect excessive runs without behaviour change
* Suggest: “Try one action outside the app now”
* Optionally lock chat/Workshop behind cooldown (user setting)

## 12.5 User is deteriorating

* Escalation rules (see Section 5.1) are evaluated after each standardised measure administration or weekly
* If triggered: show calm escalation prompt with professional support resources
* User can acknowledge and continue, pause the protocol, or archive it
* This is framed as part of stepped care, not as failure

---

# 13) MVP cut (what to build first)

MVP must include:

* Protocol library
* Run mode (6 screens, 2 skippable)
* Workshop mode (agent-guided with deterministic stages)
* JSON validation + repair loop
* Protocol dashboard basic charts
* Local storage + export/import
* Safety resources screen

Defer:

* encrypted sync
* advanced analytics
* multi-device continuity
* complex customisation

---

# 14) Traceability: vision → features

* **Agency** → action-first interventions, behavioural experiments, minimal reassurance, collaborative formulation
* **Evidence over narrative** → prediction/outcome logging, charts, review rules, standardised measures, escalation logic
* **Guided discovery** → Socratic questioning in Workshop, brief cognitive examination in Run mode
* **Frictionless** → 6-screen runs (2 skippable), skip capture, short scripts, voice input throughout
* **Consistency** → controlled enums, strict JSON schema, validation + repair, curated intervention library
* **Reduced salience** → defusion/rumination scheduling, “not now” scripts, no gamification
* **Less use over time** → success metrics not tied to engagement; prompts to act outside app; protocol completion pathway
* **Collaboration** → user generates hypotheses; agent scaffolds; formulation built together
* **Privacy** → local-first, on-device voice transcription, no third-party sharing, minimal data to agent
* **Honest limits** → escalation rules, stepped-care logic, professional support recommendations

---

# 15) Curated Intervention Library

The app maintains a curated library of evidence-based intervention templates. The agent selects and parameterises interventions from this library; it does not invent new intervention types.

## 15.1 Intervention template structure

Each template contains:

* `intervention_id` (unique identifier)
* `type` (enum: `behavioural_experiment`, `defusion`, `graded_exposure_step`, `behavioural_activation`, `delay_experiment`, `opposite_action`, `rumination_scheduling`, `problem_solving_step`)
* `indication` (when to use)
* `contraindications` (when not to use)
* `steps` (ordered list)
* `example_scripts` (parameterised text templates — the agent inserts user-specific language)
* `duration_estimate`
* `success_criteria`
* `evidence_basis` (brief citation or rationale)

## 15.2 Agent's role

In Workshop Stage 5, the agent:

1. Selects appropriate templates based on the formulation
2. Parameterises them with the user's specific language and context (e.g., inserting the user's hot thought into a defusion script template)
3. Presents them for user selection with brief rationales

The agent does NOT generate novel intervention types. Scripts generated by the agent must stay within the template's structure. The agent may adapt language and examples but may not alter the intervention's core mechanism.

## 15.3 ACT-style defusion (bounded integration)

ACT-style defusion is included as a specific intervention type within the curated library.

* **Indication boundary**: when the maintaining behaviour is rumination or thought-action fusion, and the thought content is not readily testable through behavioural experiment (e.g., existential or identity-level thoughts where "testing the prediction" doesn't apply cleanly).
* **Framing**: it is not a separate therapeutic modality — it is a technique borrowed from ACT and applied within the CBT formulation framework.
* **Priority**: the agent should not default to defusion when a behavioural experiment is feasible. Defusion is a secondary option when direct testing isn't practical.

---

# 16) First Use / Onboarding

On first launch, before the first Workshop, the app provides a brief (~2 minute) interactive psychoeducation sequence.

## 16.1 Content

* What's a hot thought (with examples)
* What's a maintaining behaviour (with examples)
* Why we test rather than argue
* What a protocol is and how it helps

This is not a content library or a course. It's the minimum conceptual scaffolding needed for the user to participate in their own formulation.

## 16.2 Flow

* The sequence ends by launching the first Workshop with the framing: "Let's try this with something real."
* Skippable for users who already understand the model (e.g., those with therapy experience).

---

# 17) Regulatory and Governance Considerations

* An app that uses an LLM to adapt interventions based on health data may be classified as a medical device by the MHRA, depending on intended purpose and claims made.
* The product should be designed to be compatible with:
  * NICE's Evidence Standards Framework (ESF) for digital health technologies
  * NHS England's Digital Technology Assessment Criteria (DTAC)
* Specific design implications:
  * Adaptive algorithms must be auditable (the curated intervention library + deterministic protocol engine support this)
  * Claims must be evidence-based (avoid clinical treatment claims without supporting RCT evidence)
  * Data handling must comply with UK GDPR
* This section should be reviewed with legal/regulatory counsel before any public release or NHS engagement.

