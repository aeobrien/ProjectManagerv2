## Vision Statement: A CBT System Builder for Real Life

### What this app is

This app is a **personal cognitive systems builder**.

Its purpose is to help a user:

* Understand recurring mental and behavioural patterns
* Design clear, evidence-based CBT protocols for those patterns
* Apply those protocols *in the moment*, with minimal friction
* Learn, over time, which beliefs actually need updating and which don’t
* Reduce suffering by changing *mechanisms*, not by forcing positivity or suppressing thoughts

At its core, the app treats thoughts and behaviours as **modifiable systems**, not personal failures or character traits.

---

### The goal behind the goal

The app’s deeper aim is not:

* “Think better thoughts”
* “Stop feeling bad”
* “Optimise productivity”
* “Eliminate negative emotion”

The real goal is:

> **To help the user build trust in their own ability to respond skilfully to their mind, even when it is loud, repetitive, or unhelpful.**

Success looks like:

* Less time trapped in unproductive loops
* Faster recovery from emotional spikes
* Fewer boom–bust cycles driven by avoidance or overcompensation
* A growing sense of *agency* rather than control

The app does not try to make the mind quiet.
It helps the user stop being *run* by it.

---

### What the app is not

This app is explicitly **not**:

* A replacement for therapy
* A diagnostic tool
* A mood tracker for its own sake
* A self-help content library
* A journaling app that accumulates insight without action
* A motivational app
* A “positive thinking” or affirmation tool
* An optimisation or productivity maximiser

It does not aim to:

* Eliminate distress
* Argue with emotions
* Force reframes
* Provide comforting explanations instead of behavioural change

Insight is welcome, but **behavioural learning** is the primary mechanism.

---

### The mental model the app is built on

The app is grounded in a specific view of the mind:

* Thoughts are **automatic predictions**, not truths
* Emotions are **signals**, not instructions
* Behaviours can maintain problems even when they feel relieving
* Beliefs change through **experience**, not persuasion
* Repetition + attention + outcome feedback is what rewires patterns

The app treats CBT as a **debugging framework**:

* Identify the loop
* Identify the maintaining behaviour
* Form a testable hypothesis
* Run an experiment
* Log what actually happened
* Update the model

The user is the debugger. The app is the debugging environment — it provides structure, visibility, and tools, but the user runs the process.

---

### How the app should feel

The app should feel:

* **Calm, neutral, and non-judgemental**
* **Practical rather than therapeutic**
* **Grounded rather than inspirational**
* **Supportive without being coddling**
* **Competent rather than clever**

It should never feel like:

* It’s disappointed in the user
* It’s trying to convince the user of something
* It’s performing empathy instead of helping

The tone is: *”Let’s look at what’s happening and test something small.”*

---

### Onboarding and psychoeducation

The app should help the user develop the *vocabulary* to describe their patterns, not assume they already have it.

The first Workshop experience should include a lightweight psychoeducation element: what’s a maintaining behaviour, what’s a hot thought, why do we test rather than argue. This is not content for its own sake — it’s the minimum conceptual scaffolding needed for the user to participate in their own formulation.

---

### The role of the agent

The agent is not a guru or coach.
It is a **CBT protocol design partner**.

The app builds protocols *with* the user, not *for* them. User agency extends to shaping the formulation itself, not just acting on it. The agent’s role is to scaffold the user’s own pattern recognition, not to present finished analyses for approval.

Its responsibilities are to:

* Ask the questions that help the user clarify what’s actually happening
* Scaffold the user’s identification of repeatable patterns rather than one-off stories
* Guide the user toward surfacing maintaining behaviours gently but clearly
* Support the user in translating vague distress into concrete, testable targets
* Produce consistent, reusable protocols collaboratively
* Select and parameterise micro-scripts from a curated library that the user can rely on when stressed

The agent should always prioritise:

* Precision over verbosity
* Specificity over general advice
* Behavioural experiments over reframes
* Simplicity over completeness

---

### Discovery over instruction

The agent uses open, curious questioning to help the user generate their own hypotheses — not persuasion, not lecture, not pre-packaged analysis.

The agent never tells the user what their pattern is. It asks questions that help the user see the pattern themselves.

This applies primarily in **Workshop mode**, where the user has bandwidth for reflection and guided discovery is essential. In **Run mode**, the user is activated and needs execution support, but even there, a brief moment of self-generated insight (e.g., "What does this thought predict?") should be preserved where possible. Guided discovery is compressed in Run mode but never fully absent.

---

### Principles guiding the design

#### 1. Frictionless in moments of activation

When the user is distressed, tired, or dysregulated:

* Inputs must be minimal
* Choices must be constrained
* Language must be short and actionable
* Completion must be possible in under a few minutes

The app assumes the user is *not at their best* when they need it most.

The app should support voice input as a primary interaction method, transcribed locally using an on-device model (e.g., Whisper) to preserve privacy. Voice input is not a convenience feature; it is an accessibility requirement. When the user is activated, typing may be the hardest thing to do. Speaking is often easier. Local transcription ensures that raw audio never leaves the device.

---

#### 2. Consistency over cleverness

The agent must produce:

* Consistent protocol structures
* Predictable JSON schemas
* Reusable intervention patterns

This allows:

* Trust
* Learning
* Comparison over time
* System-level improvements

Variation should come from the *problem*, not from the agent’s style.

The app draws from a defined library of evidence-based intervention templates. The agent selects and parameterises interventions; it does not invent them. Each intervention template has: indication boundaries, contraindications, steps, example prompts, and success criteria. This mirrors how manualised CBT works in trials and services: defined methods, applied flexibly, but not invented ad hoc. The agent’s creativity is in *how it helps the user understand and apply* an intervention — not in *what the intervention is*.

---

#### 3. Behaviour over explanation

The app always asks:

* “What will you *do* differently?”
* “What are we testing?”
* “What happened?”

Insight without action is treated as incomplete work.

---

#### 4. Small, testable steps

Interventions should:

* Be doable even on bad days
* Feel slightly uncomfortable but safe
* Generate observable outcomes

The app favours:

* 2–10 minute actions
* Delays rather than prohibitions
* Experiments over rules

---

#### 5. Repetition with reflection

The app's value is not only in-the-moment interruption; it is in the systematic accumulation of evidence across repeated cycles.

Every run generates data. That data feeds a review process. Review leads to protocol refinement. Refinement leads to better runs. This loop *is* the treatment, not a feature of the treatment.

The app should prompt review at defined intervals, not leave it to user initiative.

---

#### 6. Data as feedback, not judgement

Measurements exist to:

* Update beliefs
* Reveal patterns
* Inform revisions

They are not:

* Scores
* Grades
* Proof of failure

The app should never imply that “no improvement” means “you did it wrong.”

---

#### 7. Measurement as clinical infrastructure

Measurement is part of the treatment, not a reflection on it.

The app establishes baselines when a protocol is created, tracks standardised symptom measures periodically (e.g., PHQ-9, GAD-7), and uses pre-defined decision rules to trigger protocol revision, escalation prompts, or completion signals.

This is distinct from gamification. Standardised measures are clinical tools that inform what happens next — they are not scores, grades, or engagement metrics. The false dichotomy between “measurement as judgement” (which the app rightly opposes) and “measurement as clinical infrastructure” (which it must embrace) should be explicitly rejected.

---

#### 8. Agency without blame

The app consistently reinforces:

* Thoughts arise automatically
* Patterns were learned for a reason
* Change is a skill, not a moral victory

Responsibility is framed as **capacity to respond**, not fault.

---

#### 9. Honest about its own limits

The app is designed for self-directed use, but it recognises that self-direction has boundaries.

The app should proactively acknowledge when a pattern may benefit from professional support — not as a failure state, but as a legitimate protocol output and a natural part of the CBT stepped-care model.

Escalation signals (sustained deterioration, chronic non-response, crisis indicators) should be built into the protocol logic, not handled as edge cases.

The long-term architecture should support optional human support integration (therapist messaging, coach check-ins), even if the MVP doesn't implement it.

---

### How the app helps over time

In the short term:

* It interrupts spirals
* It reduces time lost to rumination or avoidance
* It provides a script when the user’s own words fail

In the medium term:

* It weakens specific unhelpful beliefs
* It reduces reliance on maladaptive coping behaviours
* It builds confidence in delayed, values-based action

In the long term:

* The user internalises the process
* The app becomes a reference, not a crutch
* The user recognises patterns earlier and responds faster

The ideal outcome is that the app is needed **less**, not more.

However, the app must deliver recognisable value within the first few uses — not because engagement is a goal, but because a tool that isn't used cannot help. The onboarding experience should get the user to a completed run as quickly as possible, so they experience the loop before deciding whether to continue. This is not engagement optimisation; it is minimum-effective-dose design.

---

### The ethical centre

The app’s north star is:

> **Help the user suffer less by understanding and changing the mechanisms that keep them stuck — without invalidating their experience or over-promising control.**

If a future feature:

* Increases engagement but weakens agency
* Feels reassuring but avoids behavioural change
* Encourages dependence on the app rather than skill development
* Avoids recommending professional support in order to retain users within the app

…it should be rejected.

---

#### Privacy by design

The app treats all user cognitive and emotional data as sensitive by default.

* Data is stored locally first. Nothing leaves the device without explicit user action.
* The app collects the minimum data necessary for the protocol to function.
* No third-party sharing of any user content, ever.

---

#### Regulatory awareness

The app's claims, data handling, and adaptive algorithms exist within a regulatory framework. Design decisions must be compatible with UK regulatory expectations (MHRA, NICE ESF, DTAC) even if formal certification is not pursued in the first version. This constrains feature design: the app cannot make clinical treatment claims without evidence to support them, and its adaptive logic must be auditable.
