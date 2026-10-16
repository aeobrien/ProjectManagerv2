# Module 7: Definition Mode — Manual Test Procedure

## Prerequisites
- App builds and launches successfully
- At least one project exists with a completed Exploration session (so deliverables are seeded)
- AI System V2 Dev Screen accessible via Settings

---

## Test 1: Artifact Display — Inline Card

**Steps:**
1. Open AI Dev Screen
2. Select a project and set mode to **Definition**
3. Start a session
4. Chat with the AI until it produces a `[DOCUMENT_DRAFT]` block

**Expected:**
- A purple-bordered card appears below the assistant message
- Card shows the deliverable type and draft version (e.g. "Vision Statement — Draft v1")
- Card shows a 3-4 line preview of the draft content
- Card has "Tap to review" hint text

---

## Test 2: Artifact Overlay — Review Sheet

**Steps:**
1. From Test 1, tap/click the inline artifact card

**Expected:**
- A sheet/overlay opens with full document content
- Header shows deliverable type and version
- Content is scrollable and markdown-rendered
- Footer has three buttons: "Request Revision", "Approve & Save"
- "Dismiss" button in header closes the sheet

---

## Test 3: Approve & Save Flow

**Steps:**
1. From Test 2, click "Approve & Save"

**Expected:**
- Sheet dismisses
- System message appears: "{type} approved and saved."
- Deliverable status bar updates the type to green (completed)
- The deliverable is persisted (verify by restarting session — statuses load from DB)

---

## Test 4: Request Revision Flow

**Steps:**
1. Trigger another draft via conversation
2. Open the artifact overlay
3. Click "Request Revision"

**Expected:**
- Sheet dismisses without saving
- User can continue chatting to request changes
- Next draft from AI appears as a new version (e.g. "Draft v2")

---

## Test 5: Deliverable Status Bar

**Steps:**
1. Start a Definition session on a project with seeded deliverables

**Expected:**
- A status bar appears below the session info bar
- Each deliverable type is listed with a colored dot:
  - Gray = pending
  - Orange = in progress (after a draft is received)
  - Green = completed (after approval)
- Bar only appears when mode is Definition and statuses exist

---

## Test 6: Multi-Deliverable Workflow

**Steps:**
1. Complete one deliverable via approve flow
2. Continue chatting — AI should move to the next deliverable
3. Receive and approve the second draft

**Expected:**
- Each deliverable gets its own draft history
- Status bar updates independently per deliverable
- Version numbers are per-type (not global)

---

## Test 7: Two-Step Completion

**Steps:**
1. Complete all deliverables in a Definition session
2. Observe the AI's completion behaviour

**Expected:**
- AI first summarises what was produced and asks for confirmation (NO signal tags in this message)
- After user confirms, AI emits MODE_COMPLETE, DELIVERABLES_PRODUCED signals in a separate message
- Completion banner appears only after the signal message

---

## Test 8: Deliverable Seeding from Exploration

**Steps:**
1. Run an Exploration session to completion (with PROCESS_RECOMMENDATION signal)
2. Click "Complete Session" to save the summary
3. Start a new Definition session on the same project

**Expected:**
- Deliverable status bar shows the recommended types as pending (gray dots)
- These were seeded during exploration completion

---

## Test 9: Session Context Continuity

**Steps:**
1. Start a Definition session, receive a draft, but don't approve
2. Pause the session
3. Resume the session on the same project

**Expected:**
- Previous messages reload
- Deliverable statuses reload from database
- Conversation can continue from where it left off
