# Vision statement: a frictionless, personal calorie + macro tracker that rewards real activity

## Purpose

Build a calorie and macro tracking tool that is so low-friction you'll actually use it every day — not because you're "being disciplined", but because the app makes the right behaviour the path of least resistance. The system should feel like a practical instrument: quick, calm, reliable, and motivating.

The core emotional promise is: **"If I move more, I earn more food — and the app recognises that fairly and transparently."**

## The problem it solves

Most calorie trackers fail for one of three reasons:

1. **Friction**: logging meals is annoying, repetitive, and slow, so usage drops.
2. **Demotivation**: exercise doesn't meaningfully change the day's target, or it changes in a way that feels punitive/opaque.
3. **Data entry burden**: you repeatedly re-enter foods or manually type label info, which turns tracking into admin.

This app exists to remove those failure modes — and it does so with explicit awareness that the user may have ADHD, executive function variability, or a brain that treats small obstacles as impassable walls.

---

## Guiding principles

### 1) Frictionlessness above all

If it isn't fast, it won't be used. Every design decision should be judged by:

* Can I log this in under 10 seconds?
* Can I correct mistakes without hassle?
* Does it reduce effort over time (learns my habits, recents, favourites)?

Friction-reduction features (recents, favourites, portion memory, quick-add) are **core product**, not polish. They must ship alongside the logging infrastructure, not after it.

### 2) "Earned calories" must be explicit and motivating

The app must reflect real-world activity in a way that's psychologically helpful, not discouraging. It should show:

* **Base target** (your chosen daily goal)
* **Exercise/active calories** (from Apple Health)
* **Updated allowance**
* **Remaining** (or surplus) clearly

The app shouldn't silently move goalposts. It should make the logic visible and fair.

### 3) "Add it once, never again"

If a packaged food isn't in the database, adding it should be painless:

* Create it locally immediately so logging can continue
* Make it reusable forever
* Optionally contribute it back to the shared open database so next time it's there

### 4) Forgiving by default

The app must treat gaps, missed days, and imperfect data as normal — not as failures.

* **No streaks.** No streak counters, no "you broke your streak" messaging. Streaks reward consistency but punish interruption, and for an ADHD brain, a broken streak often triggers all-or-nothing abandonment ("I missed two days, why bother continuing").
* **No shame language.** Numbers going over target are information, not judgments. No red text, no frowning faces, no "over budget!" warnings. The app should present overages neutrally (e.g., "200 over target") and optionally frame them in weekly context ("still 400 under for the week").
* **Every day is a blank slate.** Opening the app after a gap should feel exactly like opening it on day one — clean, welcoming, ready to use.
* **Retroactive logging must be exactly as frictionless as logging for today.** Missing dinner last night and wanting to add it the next morning should be a trivial operation — same workflows, same speed, just with a date/time picker pre-set to yesterday.

### 5) Local-first, personal tool

This is primarily for one user. It should work offline for logging, feel immediate, and never block you because a service is down. Sync and sharing can exist later, but the first version prioritises speed and reliability.

**Note on API costs**: the app uses a cloud LLM (Claude API) for label extraction and recipe generation, which has a per-call cost. This is a conscious trade-off: better quality extraction justifies a small marginal cost. The app should be designed so that LLM calls are optional enhancers — the core logging loop never depends on them, and the user is never blocked by a failed or unavailable API call.

### 6) Simple > comprehensive

This is not a "do everything wellness platform." It's a focused tracker:

* Calories
* Macros
* Exercise-adjusted allowance
* Recipes/meals you actually eat
* A lightweight weekly view

Everything else is optional.

### 7) Support the ADHD brain explicitly

The app is designed for a brain that has variable executive function, limited working memory, and a low tolerance for tedious multi-step processes. This means:

* **Working memory support**: every screen should contain enough context that you never need to remember what you were doing. If you're logging a food, the product name, current portion, and running calorie total should all be visible simultaneously. No "remember the number from the previous screen" patterns.
* **State preservation ("Where was I?" recovery)**: if you get interrupted mid-log (a text comes in, you switch apps, you get distracted), the app should preserve your in-progress state. Getting back to where you were should require zero effort. Draft states must be persistent, not volatile.
* **Task completion signals**: when you log something, the feedback should be immediate and satisfying — a subtle animation, a number updating, a clear "done" signal. ADHD brains need completion cues to close the task loop. Without them, the task feels unfinished even after it's done.
* **Decision fatigue reduction**: minimise the number of choices per interaction. Don't ask "which meal?" and "how many grams?" and "confirm?" as three separate steps if they can be combined or defaulted. Every decision point is an opportunity to abandon the task.
* **Estimation over precision**: the app should support rough estimates ("about 500 kcal") as readily as precise gram-based entries. Imprecise data logged is infinitely more valuable than precise data abandoned.
* **Gentle reminders**: time-based notifications are enabled by default as working-memory aids ("You haven't logged lunch — want to add something?"). They should be warm, optional, easy to dismiss, and never guilt-inducing. The tone should be closer to "Hey, just a nudge" than "You missed lunch!"

---

## What the end product should feel like

### Home screen (the "Today" dashboard)

A single, glanceable view that answers:

* How much have I eaten?
* How much have I earned through activity?
* What's my remaining allowance?
* Am I roughly on track?

It should show a clear breakdown:

* **Base target:** e.g. 1,900 kcal
* **Active calories earned:** +650 kcal
* **Today's allowance:** 2,550 kcal
* **Consumed:** 1,480 kcal
* **Remaining:** 1,070 kcal

Plus macro progress bars (protein/carbs/fat).

**Emotional design requirements for the Today screen:**

* The active calories value must be accurate the moment the screen renders — no loading spinners, no "pull to refresh" to get the real number. Background sync ensures this.
* If remaining is negative (over target), display it neutrally: e.g. "120 over target" in the same calm visual style, not in red or with warning iconography.
* Optionally show a weekly context line: "This week: 850 under target" — this reframes a single over-day as part of a bigger picture, which is healthier and more accurate.
* Macro progress bars should indicate progress, not pass/fail. A partially filled bar is encouragement, not a judgment.

**Meal grouping:** the day's log entries should be grouped by meal (breakfast / lunch / dinner / snacks), with the meal auto-suggested based on time of day. Meal assignment is present but never mandatory — if you don't want to categorise, the entry goes into a general list. The grouping exists as a cognitive anchor to help reconstruct your day, not as a required data field.

---

## Core workflows

### 1) Log food with a barcode scan

* Scan barcode
* App fetches nutrition data
* You enter quantity (grams / serving / portion)
* Logging instantly updates calories + macros

Quantity entry must be fast and forgiving:

* Default to last-used unit and amount for that product
* Provide quick buttons (e.g. +10g, +50g, ½ serving, 1 serving)
* Support "I ate the whole pack" type shortcuts

### 2) Log a meal/recipe you eat often

You should be able to say "carbonara" and have that mean something stable.

A "recipe" is:

* A set of ingredients with quantities
* A number of servings
* Automatically computed nutrition per serving

Logging a recipe should be one tap + optional portion size.

Importantly: recipes should be optimised for *real usage*, not culinary perfection.

### 3) Add missing foods with LLM-assisted label capture

When a barcode lookup fails or data is incomplete:

* You take a photo of the nutrition label (and optionally the front of pack)
* An LLM extracts the structured nutrition info into a standard JSON format
* The app creates a local food entry immediately (so you can log it now)
* The app offers a "Submit to community database" action later

The goal is: adding a new food should feel like **a 30–60 second task**, not a form-filling session.

### 4) Quick-add estimate (the escape hatch)

When executive function is low, data is unavailable, or you're just in a rush, you should be able to bypass the food database entirely and log raw numbers:

* Tap "Quick Add"
* Enter estimated calories (required) and optionally protein/carbs/fat
* Optionally tag it with a name or meal slot
* Done

This is not a lesser form of logging — it's a first-class workflow. The worst outcome for a tracker isn't imprecise data; it's no data at all. A rough estimate keeps the daily picture intact and the habit alive.

Quick-add entries should be visually distinct in the log (so you can revisit and refine them later if you want), but they count toward daily totals identically.

### 5) Build recipes with LLM assistance

Creating a recipe by manually searching and adding 8+ ingredients is exactly the kind of tedious multi-step admin that kills tracking. The LLM should support recipe creation as well as label extraction:

* **From typed text**: type or paste "200g pasta, 100g pancetta, 2 eggs, 50g parmesan" and the LLM resolves each ingredient to nutrition data and builds the recipe.
* **From a URL**: paste a recipe link and the LLM extracts the ingredient list, resolves nutrition, and creates the recipe entry.
* **Manual fallback**: traditional ingredient-by-ingredient search and add, for when you want precision or the LLM output needs correction.

In all cases, the user confirms/edits the parsed result before saving.

### 6) Exercise automatically adjusts allowance

The app reads active energy from Apple Health and uses it to adjust the day's allowance.

This must be:

* Transparent (shows the numbers)
* Optional (you can choose whether to count exercise calories)
* Instantly up to date (background sync, not pull-to-refresh)

The point is to restore the motivating loop:

> "I moved more, so I can eat more — and the app agrees."

---

## Data model expectations

### Foods

* Barcode-linked foods from shared database
* Locally-created foods (including label-extracted ones)
* Custom "staples" (e.g. "my coffee", "my porridge")

### Meals / Recipes

* Named recipes with ingredient list
* Portioning (servings and per-serving calculation)
* Quick-log support

### Daily log

* Timestamped entries
* Meal grouping suggested by default (breakfast/lunch/dinner/snacks), based on time of day, but never mandatory
* Editable entries (fix quantity, swap food, delete)
* Quick-add entries (raw kcal/macros, no food reference required)
* Retroactive entries (logging for a past date/time must use identical workflows)

### Body goals

* Calorie target
* Macro targets (grams or percentages)
* Optional: protein minimum emphasis

---

## Quality bar for v1

A v1 is successful if:

* You log food most days because it's genuinely easy.
* Barcode scan works often enough to feel magical.
* When it doesn't work, adding foods is not a rage-inducing chore.
* When nothing works (or you can't be bothered), quick-add keeps you logging.
* Exercise-adjusted allowance restores the motivational dynamic you miss.
* You can reliably log your repeat meals without thinking.
* Missing a day or two doesn't make you feel like you've failed.
* Opening the app after a gap feels welcoming, not accusatory.

---

## Non-goals (important to prevent scope creep)

* Social features
* Coaching / AI advice about what to eat
* Full meal planning ecosystem
* Weight prediction models
* Perfect micronutrient tracking (can come later)
* Streak mechanics or gamification that punishes gaps

The tool should stay simple and trustworthy.

---

## North-star outcome

After a week or two of use, the app should feel like it's becoming *yours*:

* Your foods are already in there.
* Your recipes are one-tap logs.
* Your activity is reflected automatically.
* The interface is fast enough that tracking doesn't feel like work.
* A missed day doesn't derail you — it's just an empty page, and today is fresh.

You should be able to say:

> "This is basically MyFitnessPal, but it behaves the way my brain needs it to, and I'm not renting it from a subscription."
