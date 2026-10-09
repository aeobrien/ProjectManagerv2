# Technical brief: Frictionless calorie + macro tracker with Apple Health + Open Food Facts + LLM label capture

## 0) Platform decision: OpenNutriTracker base, Flutter, Xcode

### Why this base

OpenNutriTracker already gives you the two hardest "daily use" primitives:

* **Barcode scanning** (packaged food workflow)
* A food database layer powered by **Open Food Facts + FoodData Central**

It's also explicitly cross-platform Flutter, and you can still run/debug the iOS app inside **Xcode** (Runner workspace) as part of the normal Flutter workflow.

### What we'll add

* **Apple Health (HealthKit)** energy burn ingestion (active calories)
* The **"base target + earned calories = allowance"** model and UI
* **Recipes** (including LLM-assisted creation)
* **LLM-assisted "add missing food once"**, with optional OFF contribution
* **Quick-add estimate** (raw kcal/macro entry with no food reference)
* A "friction bar" pass: recents, quick-add, defaults, and fast correction tools
* **Gentle notification reminders** for meal logging
* **Data export** for backup and portability

### What we may need to change in the base

Before building on top of OpenNutriTracker, an initial audit is required to identify:

* Navigation patterns that conflict with the target UX (e.g., too many taps to log)
* Data display choices that don't align with the vision (e.g., the absence of the "earned calories" breakdown, or visual styling that uses shame language for overages)
* Schema limitations that need extending (e.g., no quick-add type, no recipe model)
* Any existing features that add clutter and should be hidden or removed for this use case

This audit is a Phase 1 task. The goal is to understand what to *keep*, what to *extend*, and what to *strip out* before writing new code.

---

## 1) Non-negotiable requirements

### UX/behaviour

* Log a barcode food in **< 10 seconds**.
* Add a missing food in **< 60 seconds** (LLM-assisted).
* Quick-add a raw estimate in **< 5 seconds**.
* Recents, favourites, and portion memory must ship alongside the logging infrastructure — they are core product, not polish.
* The app must work when offline for all logging workflows. LLM features degrade gracefully (capture photo, queue for processing when online).
* Exercise adjustment must be **transparent** and **instantly current**:
  * show base target
  * show earned calories from Apple Health
  * show resulting allowance
  * data must be accurate when the screen renders (background sync, not pull-to-refresh)
* Retroactive logging (filling in yesterday) must use identical workflows to today's logging.
* In-progress logging state must persist across app switches and interruptions.
* No streaks, no shame-based visual language, no red/warning styling for overages.

### Data

* Barcode lookup uses Open Food Facts API as primary.
* The system must support "add once, never again":
  * local store always
  * optional OFF submission path (not required to log)

### Platform constraints

* Runs on iOS via Xcode (debug + build).
* Claude Code-friendly: small modules, tests, clear boundaries.
* Must integrate with Apple Health active energy burned.

---

## 2) Architecture overview

### Core layers (clean boundaries)

1. **Domain**
   * Calories/macros calculations
   * Allowance model (base + earned = allowance)
   * Recipe nutrition math
   * Weekly aggregation logic

2. **Data**
   * Local database (foods, recipes, logs, daily stats cache)
   * OFF client
   * FoodData Central client (optional fallback for non-barcoded foods)
   * Data export module (JSON)

3. **Integrations**
   * HealthKit ingestion (Active Energy Burned) — background observer pattern
   * Barcode scanning (already exists in base)
   * LLM extraction service (photo → structured nutrition JSON)
   * LLM recipe builder (text/URL → ingredient list → nutrition resolution)
   * Local notification scheduler

4. **UI**
   * Today dashboard (with instant-load cached stats)
   * Log food (barcode / search / recents / favourites)
   * Quick-add estimate
   * Recipe builder (manual + LLM-assisted)
   * "Food not found" capture flow
   * Settings (targets, notification preferences, HealthKit permissions, data export)

### Local storage

* Use and extend the on-device database from OpenNutriTracker.
* Priority: deterministic, simple migrations, easy backup/export.
* DailyStats should be **materialised** (stored, not recomputed on every screen load) and updated incrementally when log entries change. This ensures the Today screen loads instantly regardless of database size.

---

## 3) Data model (minimum viable schema)

### FoodItem

* `id` (uuid)
* `source` (OFF | FDC | Local | LLM)
* `barcode?`
* `name`
* `brand?`
* `servingSizeGrams?`
* `nutritionPer100g`:
  * kcal, protein_g, carbs_g, fat_g
  * (optional later: fibre, sugar, salt)
* `lastUsedAt`
* `lastUsedGrams?` (portion memory — stores the last quantity the user logged for this item)
* `userVerified` (bool)
* `correctedAt?` (timestamp — set when user edits a previously-saved food item, used to flag affected log entries)

### Recipe

* `id`
* `name`
* `ingredients[]`:
  * `foodItemId`
  * `grams`
* `servings` (int)
* `source` (manual | LLM)
* computed totals + per-serving macro cache

### LogEntry

* `id`
* `timestamp`
* `mealSlot?` (breakfast | lunch | dinner | snack — suggested by time of day, nullable)
* `type` (food | recipe | quickAdd)
* `refId?` (foodItemId | recipeId — nullable, null for quickAdd entries)
* `gramsOrServings?` (nullable for quickAdd)
* `quickAddData?` (for type=quickAdd only):
  * `kcal` (required)
  * `protein_g?`
  * `carbs_g?`
  * `fat_g?`
  * `label?` (optional freetext, e.g. "pub lunch")
* `computedSnapshot`:
  * kcal, protein_g, carbs_g, fat_g
  * `sourceItemCorrected` (bool — flagged true if the referenced FoodItem has been corrected since this entry was logged)
* `isDraft` (bool — true if this entry was started but not completed, e.g. user was interrupted mid-log)

### DailyStats (materialised)

* `date`
* `intakeKcal`, `intakeProtein`, `intakeCarbs`, `intakeFat`
* `activeCalories` (cached from HealthKit)
* `activeCaloriesLastUpdated` (timestamp)
* `baseTarget`
* `allowance` (computed: baseTarget + activeCalories)
* `remaining` (computed: allowance - intakeKcal)

Updated incrementally: when a LogEntry is added/edited/deleted, update the corresponding DailyStats row. When HealthKit reports new active calories, update the activeCalories field.

### Snapshot correction mechanism

When a user edits a FoodItem (e.g. discovers the LLM-extracted data was wrong):

1. Mark the FoodItem with `correctedAt` timestamp.
2. Query LogEntries where `refId` matches the corrected FoodItem and `timestamp < correctedAt`.
3. Set `sourceItemCorrected = true` on affected entries.
4. Surface these in the UI: "3 past entries used old data for [food name] — recompute?"
5. If user confirms, recompute snapshots and update DailyStats.
6. If user ignores, old snapshots are preserved (history doesn't silently change).

---

## 4) Core calculations (the "exercise earns food" model)

### Inputs

* `base_target_kcal` (user setting)
* `active_energy_kcal_today` (Apple Health, via background sync)
* `intake_kcal_today` (from materialised DailyStats)

### Outputs

* `allowance = base_target + active_energy`
* `remaining = allowance - intake`

### Display requirement

Today screen must show the *components*:

* Base target
* Earned calories (+)
* Allowance (=)
* Consumed (–)
* Remaining

If remaining is negative, display as "X over target" in neutral styling (no red, no warning icons). Optionally display weekly context: "This week: Y under/over target."

Apple Health's "activeEnergyBurned" quantity type is the data source.

---

## 5) Apple Health integration plan (Flutter → iOS HealthKit)

### Recommended approach: Flutter `health` plugin with background observer

* Use the `health` plugin to read Active Energy Burned.
* **Background sync is the priority.** The Today screen must show accurate data the moment it renders, without requiring user interaction.
* Implementation:
  1. On first launch, request HealthKit permissions.
  2. Set up a HealthKit **observer query** (via platform channel if needed) to receive notifications when new Active Energy Burned data is written. This handles retroactive syncs from Apple Watch, delayed workout logging, etc.
  3. On each update, recompute the day's `activeCalories` and write to the materialised DailyStats row.
  4. Cache the latest value with a `lastUpdated` timestamp so the UI can display freshness if needed.
  5. Fallback: if observer queries aren't feasible via the Flutter plugin, poll on app foreground + every 5 minutes while active.

### Acceptance criteria

* First run prompts user for Health permissions.
* Today screen shows accurate active calories for today without any manual refresh action.
* A walk completed during the day updates "earned calories" automatically within minutes.
* If permissions denied, the UI falls back gracefully (allowance = base target, no error states).

---

## 6) Open Food Facts integration plan

### Barcode lookup

* Call OFF product-by-barcode endpoint; parse nutrition data.
* Prefer per-100g fields (best for gram-based portions).
* **Parsing robustness**: OFF responses vary wildly in completeness and format. The parser must handle: missing fields (fall back to null, don't crash), inconsistent field names, nutrition data in per-serving only (convert to per-100g if serving size is available), and completely empty nutrition objects (treat as "not found").

### Contributing new products

* Must be a "later" step in flow:
  * create local food now
  * offer "contribute back" action later (with queued upload)

### Acceptance criteria

* Scanning common UK groceries returns data often enough to be usable.
* If product not found, app enters "Add Food" mode immediately (no dead end).
* Malformed OFF responses never crash the app or produce silently wrong data.

---

## 7) LLM label capture pipeline (photo → nutrition JSON)

### Provider

**Claude API** (cloud). Better extraction quality justifies the per-call cost and network dependency. The API is used for two distinct workflows: label extraction and recipe generation.

### Offline fallback

When the device is offline and a barcode lookup fails:

1. The app captures the photo and barcode locally.
2. It creates a **draft LogEntry** with a placeholder (or the user can quick-add an estimate).
3. When connectivity returns, the app processes the queued photo through the LLM.
4. The user is notified: "[Product name] nutrition data is ready — review?"
5. If confirmed, the draft entry is updated with accurate data and DailyStats are recomputed.

The user is never blocked from logging because the LLM is unavailable.

### Label extraction flow

1. **Capture**:
   * Photo of nutrition label (required)
   * Optional front-of-pack photo (for product name/brand)
   * Barcode value (if available from the scan that triggered "not found")

2. **Extraction** (Claude API call):
   * System prompt specifying a strict JSON schema
   * Input: image(s) + instruction to extract nutrition data
   * Output JSON schema:

```json
{
  "product_name": "string | null",
  "brand": "string | null",
  "serving_size_grams": "number | null",
  "nutrition_per_100g": {
    "kcal": "number",
    "protein_g": "number",
    "carbs_g": "number",
    "fat_g": "number",
    "fibre_g": "number | null",
    "sugar_g": "number | null",
    "salt_g": "number | null"
  },
  "nutrition_per_serving": {
    "kcal": "number | null",
    "protein_g": "number | null",
    "carbs_g": "number | null",
    "fat_g": "number | null"
  },
  "confidence": "high | medium | low",
  "notes": "string | null"
}
```

3. **Validation** (client-side, before showing to user):
   * Check that kcal ≈ (protein × 4) + (carbs × 4) + (fat × 9), within a 10% tolerance. If mismatch, flag with a warning: "These numbers don't quite add up — please double-check."
   * Check that all required fields are non-null. If any are missing, highlight them for manual entry.
   * If `confidence` is "low", show a more prominent review prompt.

4. **Confirmation UI**:
   * Show parsed numbers in an editable form
   * Highlight any validation warnings
   * User taps "Looks right" or edits individual fields

5. **Save**: local FoodItem saved immediately.

6. **Contribute**: queued contribution payload for OFF (manual "submit" button, never blocks logging).

### Error handling

* If the API call fails: offer manual entry form pre-populated with whatever data is available (barcode, product name from photo if OCR'd).
* If the API returns unparseable output: same fallback to manual form.
* If the API returns partial data (e.g. calories but not fat): show what was extracted, highlight missing fields for manual completion.

### Acceptance criteria

* From "not found" → loggable food in under 60 seconds.
* The flow never blocks logging if the API call fails or returns garbage.
* Validation catches obviously wrong extractions before the user saves.

---

## 8) LLM recipe builder

### Goal

Eliminate the tedium of manually searching and adding 8+ ingredients to build a recipe.

### Supported inputs

1. **Typed ingredient list**: user types or pastes "200g pasta, 100g pancetta, 2 eggs, 50g parmesan" (free-form text).
2. **Recipe URL**: user pastes a link to a recipe page.
3. **Manual build**: traditional ingredient-by-ingredient search and add (always available as fallback).

### LLM-assisted flow (typed text or URL)

1. **Input**: user provides text or URL.
2. **Extraction** (Claude API call):
   * For text: parse ingredient list, resolve each to a quantity and a likely food name.
   * For URL: fetch page content, extract ingredient list, parse as above.
   * Output JSON:

```json
{
  "recipe_name": "string | null",
  "servings": "number | null",
  "ingredients": [
    {
      "name": "string",
      "grams": "number",
      "original_text": "string"
    }
  ]
}
```

3. **Resolution**: for each ingredient, attempt to match against the local food database and OFF. Show the user each match with its nutrition data.
4. **Confirmation UI**: editable list — user can adjust quantities, swap matched foods, or manually search for better matches.
5. **Save**: recipe created with per-serving nutrition computed.

### Acceptance criteria

* User can create a recipe from a pasted ingredient list in under 90 seconds.
* URL-based recipe import works for common recipe sites.
* Manual fallback is always available if LLM output is poor.

---

## 9) Quick-add estimate

### Purpose

A first-class logging workflow for when you can't or don't want to look up a specific food.

### Flow

1. Tap "Quick Add" (always visible, no more than 1 tap from the main logging interface).
2. Enter estimated kcal (required).
3. Optionally enter protein/carbs/fat.
4. Optionally add a freetext label (e.g. "pub lunch", "snack at airport").
5. Optionally assign a meal slot.
6. Save.

### Technical notes

* Creates a LogEntry with `type = quickAdd`, `refId = null`.
* Nutrition data stored directly in `quickAddData` on the entry.
* `computedSnapshot` is populated from `quickAddData`.
* Quick-add entries are visually distinct in the log (e.g. subtle icon or label) so the user can identify them later and optionally replace them with a precise food entry.
* Counts toward daily totals identically to food/recipe entries.

### Acceptance criteria

* Quick-add from tap to saved in under 5 seconds.
* Quick-add entries appear in the daily log and contribute to DailyStats.

---

## 10) Recipe system

### Minimum viable recipes

* Create recipe from existing FoodItems (manual or LLM-assisted)
* Enter grams per ingredient
* Enter servings
* App computes per-serving macros
* One-tap log recipe + adjust servings (½, 1, 1.5, 2)

### Snapshot behaviour

Logging a recipe creates a LogEntry with a `computedSnapshot` based on the recipe's nutrition at the time of logging. Editing the recipe afterwards does **not** retroactively change past logs unless the user explicitly triggers "recompute history" (same mechanism as FoodItem correction).

### Acceptance criteria

* You can create "Carbonara" once and re-log it repeatedly in seconds.
* LLM-assisted recipe creation from a typed ingredient list works end-to-end.
* Editing the recipe doesn't retroactively change past logs unless explicitly chosen.

---

## 11) Frictionlessness features (ship with core, not after)

These features are **not polish**. They are the core product. They must be built alongside the logging infrastructure and available from the first usable build.

### "Make logging fast"

* **Recents list** (foods + recipes), ordered by last used — visible on the primary logging screen.
* **Favourites/pins** — persistent quick-access items.
* **Default portion memory per item** — when you log a food, it defaults to the last quantity you used for that item.
* **Quick increment buttons** for grams/servings (e.g. +10g, +50g, ½, 1, 2).
* **Meal slot auto-suggestion** based on time of day (dismissible, not mandatory).

### "Make correction painless"

* Tap log entry → adjust grams quickly (inline, not a new screen).
* Swipe delete / undo.
* Replace food in entry (swap).

### "Don't lose my work"

* In-progress log entries are saved as drafts if the user navigates away or the app is interrupted.
* Returning to the app restores the in-progress state.

### Acceptance criteria

* Most common breakfast and dinner can be logged with <5 taps.
* Recents list is populated and useful after 2-3 days of use.
* An interrupted logging flow can be resumed without starting over.

---

## 12) Notifications

### Purpose

Gentle time-based reminders that serve as external working memory for ADHD brains.

### Implementation

* Local notifications scheduled based on user-configurable meal times (defaults: breakfast 9am, lunch 1pm, dinner 7pm).
* Notification text should be warm and non-judgmental: "Lunchtime — want to log something?" not "You haven't logged lunch!"
* Tapping the notification opens the app to the logging screen with the relevant meal slot pre-selected.
* User can disable individual meal reminders or all reminders in settings.
* No "you missed a day" notifications. Ever.

### Acceptance criteria

* Notifications fire at configured times.
* Tapping a notification lands on the correct logging context.
* Disabling notifications is a single toggle.

---

## 13) Data export and backup

### Purpose

Protect against data loss and support portability. For a local-first app with no cloud backup, this is a safety net, not a nice-to-have.

### Implementation

* Export all user data (foods, recipes, logs, settings) as a single JSON file.
* Accessible from Settings.
* Import from a previously-exported JSON file (for phone migration or recovery).
* Export should also support CSV for log entries (for users who want to analyse their data in a spreadsheet).

### Acceptance criteria

* Export produces a complete, valid file.
* Import restores all data correctly.
* Round-trip (export → fresh install → import) preserves everything.

---

## 14) Delivery roadmap

This roadmap assumes development with **Claude Code**, which compresses code comprehension and scaffolding tasks significantly.

### Phase 1 (Day 1): Base audit + build + core infrastructure

* Fork OpenNutriTracker, build iOS Runner in Xcode, smoke test barcode scan.
* **Audit the existing codebase**: identify navigation patterns, UI decisions, and schema structures that need to change. Document what to keep, extend, and strip out.
* Extend the data model: add `quickAdd` type to LogEntry, add `mealSlot`, add `isDraft`, add `lastUsedGrams` to FoodItem, add materialised DailyStats table.
* Add minimal unit tests for core nutrition math (per-100g → grams, allowance calculation, macro validation).

**Done when:** App builds and runs on iPhone. Data model supports all required entry types. Core math is tested.

### Phase 2 (Day 2): Allowance model + Today UI + friction foundations

* Implement base target setting.
* Implement allowance calculation (base + active = allowance, remaining = allowance - intake).
* Build Today screen with explicit breakdown (base → earned → allowance → consumed → remaining).
* Implement neutral overage display and optional weekly context line.
* **Build recents list and favourites system** — these must be available the moment food logging works.
* Implement default portion memory (store last-used grams per FoodItem).
* Implement quick increment buttons for quantity entry.
* Implement meal slot auto-suggestion (time-based, dismissible).

**Done when:** Today screen shows a working breakdown. Logging a food updates the screen. Recents populate after first use. Portion memory works.

### Phase 3 (Day 3): Apple Health integration

* Add Health plugin + permissions + background active calories sync.
* Implement HealthKit observer query (or polling fallback) so active calories update automatically.
* Cache result in materialised DailyStats.
* Update allowance breakdown on the Today screen.

**Done when:** A walk changes "earned calories" automatically, and the Today screen is accurate when it loads without manual refresh.

### Phase 4 (Day 4): Quick-add + correction tools

* Build quick-add estimate flow (tap → kcal → optional macros → save).
* Build inline log entry editing (tap entry → adjust grams, no navigation to new screen).
* Build swipe-to-delete with undo.
* Build swap-food-in-entry.
* Implement draft state preservation for interrupted logging flows.

**Done when:** Quick-add works end to end. Editing and deleting log entries is fast. Interrupted logs are recoverable.

### Phase 5 (Day 5–6): LLM label extraction + "Add once, never again"

* Build the "not found" flow: barcode miss → photo capture → LLM extraction → confirm/edit → save.
* Implement the Claude API integration with the specified JSON schema.
* Implement client-side validation (macro/calorie consistency check).
* Implement offline fallback: capture photo + queue, quick-add placeholder, process when online.
* Implement snapshot correction mechanism (corrected food → flag affected entries → offer recompute).

**Done when:** You can add a missing UK product once and re-log it later with barcode or search. Offline path works. Corrections propagate correctly.

### Phase 6 (Day 6–7): Recipes + LLM recipe builder

* Build manual recipe builder (search ingredients, enter grams, set servings, compute per-serving macros).
* Build LLM-assisted recipe creation (typed text → parsed ingredients → nutrition resolution → confirm → save).
* Build URL-based recipe import (URL → fetch → extract → same flow).
* One-tap recipe logging with portion adjustment.

**Done when:** "Carbonara" is a reusable one-tap item. LLM recipe creation from text works end to end.

### Phase 7 (Day 7–8): Notifications + weekly view + export + polish

* Implement local notification scheduling for meal reminders.
* Build lightweight weekly view (7-day summary: daily totals, weekly trend, under/over context).
* Implement JSON and CSV data export.
* Implement JSON data import.
* Final UX pass: ensure no shame language anywhere, verify all overage displays are neutral, confirm retroactive logging works smoothly.

**Done when:** Notifications fire correctly. Weekly view works. Data can be exported and re-imported. The app feels calm and non-judgmental throughout.

---

## 15) Testing strategy

### Unit tests (fast, run on every change)

* Allowance calculation (base + earned = allowance, remaining)
* Per-100g → grams macro math
* Recipe totals → per-serving
* Log entry snapshot behaviour
* Macro/calorie consistency validation (the (P×4 + C×4 + F×9) ≈ kcal check)
* DailyStats incremental update logic
* Weekly aggregation math
* Meal slot time-of-day suggestion logic

### Integration tests (medium, mocked external services)

* OFF lookup parsing — **use a golden dataset of 20+ real OFF responses**, including: complete responses, partial data, missing nutrition, inconsistent field names, per-serving-only data, and empty responses. This is the most fragile integration point.
* LLM JSON schema validation — test against well-formed output, partial output, malformed output, and completely garbage output. Verify graceful fallback in all cases.
* HealthKit read — mocked/sandboxed, including: normal data, zero data, retroactive data arrival, permission denied.
* Notification scheduling — verify correct timing and content.
* Data export/import round-trip.

### Manual acceptance checklist (human)

* "Breakfast in 10 seconds" (using recents or favourites)
* "Barcode not found → added + logged in 60 seconds"
* "Quick-add estimate in 5 seconds"
* "Walk → earned calories updates automatically"
* "Recipe re-log in 5–10 seconds"
* "Create recipe from pasted ingredient list"
* "Log yesterday's dinner today without friction"
* "Get interrupted mid-log, come back, resume"
* "Go over target — no red text, no shame"
* "Miss two days, come back — app feels welcoming"
* "Export data, reimport on fresh install, everything's there"

---

## 16) Known risks and mitigations

### OFF coverage gaps in UK

**Mitigation:**
* Local add flow is first-class (never a dead end)
* LLM label extraction as a fast alternative to manual entry
* Contribution is optional and queued

### HealthKit data variability

**Mitigation:**
* Use Active Energy Burned as baseline (consistent type)
* Background observer query for timely updates, including retroactive syncs
* Cache with `lastUpdated` timestamp for transparency
* Allow toggling exercise adjustment off entirely

### LLM extraction quality

**Mitigation:**
* Client-side macro/calorie consistency validation before saving
* Confidence score from LLM triggers review prompts
* User always confirms/edits before saving — LLM output is a suggestion, not a commit
* Manual entry fallback always available

### LLM API cost

**Mitigation:**
* LLM calls are only triggered for two specific workflows (label extraction, recipe creation) — never for routine logging
* Each added food is cached locally forever, so the same product never triggers a second API call
* Cost per call is small (typically < $0.01 for a label extraction); even heavy use is a few pounds/month

### Offline degradation

**Mitigation:**
* All logging workflows (barcode from cache, recents, favourites, quick-add, manual entry) work fully offline
* LLM-dependent workflows (label extraction, recipe URL import) queue inputs for processing when online
* User can always quick-add an estimate as a placeholder

### Scope creep

**Mitigation:**
* Strict non-goals (no coaching, no social, no "perfect micronutrients", no streaks)
* Every feature must pass the friction test: does this make logging easier or harder?

### Data loss

**Mitigation:**
* JSON export/import as first-class feature
* Export reminder in settings (not automated, but visible)

---

## 17) "Runs in Xcode" clarification

Two supported ways:

1. **Flutter app**: open `ios/Runner.xcworkspace` in Xcode and run/debug normally.
2. **Add-to-app** (later): embed Flutter module in a native host app if you ever want a SwiftUI shell around Flutter screens.

For this build, option (1) is simplest and sufficient.
