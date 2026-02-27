# Module 6: Exploration Mode — Integration Test Procedure

**Module:** 6 (Exploration Mode)
**Checkpoint type:** Integration — real API conversations required
**Prerequisites:** Modules 1-5b implemented and passing (316 automated tests)
**Estimated time:** 30-45 minutes

---

## Setup

### 1. Configure an API Key

Before testing, ensure you have a valid LLM API key configured:

1. Build and launch the app: `xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'` then run from Xcode or DerivedData
2. Navigate to **Settings** (gear icon in the sidebar)
3. In the **AI Assistant** section:
   - Set **Provider** to your provider (Anthropic or OpenAI)
   - Enter your **API Key**
   - Set **Model identifier** (e.g. `claude-sonnet-4-20250514` for Anthropic, `gpt-4o` for OpenAI)

### 2. Create Test Projects

You'll need at least 2-3 projects in the database. If the Focus Board is empty:

1. Go to **Project Browser** → click **+** to create a new project
2. Create at least these projects:
   - "Test Project Alpha" — any category, idea/exploration state
   - "Test Project Beta" — any category
   - "Established Project" — if you have one with existing phases/milestones, great; otherwise create one and add some structure manually

### 3. Open the Dev Screen

1. Go to **Settings** (bottom of sidebar)
2. Scroll to the bottom — you should see **AI System V2 (Dev)** section (DEBUG builds only)
3. Click **Open Dev Screen**
4. The dev screen should open as a sheet with:
   - Header bar: title "AI System V2 Dev Screen", Project picker, Mode picker
   - Session info bar: showing "Project: None | Mode: exploration | No session"
   - Empty message area with placeholder text
   - Input bar (disabled until a session starts)

---

## Test 1: Basic Exploration Conversation (New Project)

**Goal:** Verify the full pipeline works end-to-end: session start → multi-turn conversation → signal detection → session completion.

### Steps

1. **Select a project** from the Project picker (e.g. "Test Project Alpha")
2. **Verify** the Mode picker shows "exploration" (should be default)
3. **Click "Start Session"**
   - Session info bar should update to show "Session: active"
   - Input field should become enabled
   - A session should be created in the database

4. **Send an opening message** describing a project idea:
   > "I want to build a habit tracking app that's specifically designed for people with ADHD. The core insight is that most habit trackers assume consistent motivation, but ADHD brains don't work that way."

5. **Verify the response:**
   - [ ] The AI responds in a conversational, exploratory tone
   - [ ] The response appears in the message list with "AI" label in green
   - [ ] Your message appears with "You" label in blue
   - [ ] The AI asks clarifying questions (not jumping to structure/planning)
   - [ ] No loading spinner left hanging after response arrives
   - [ ] Check if any signals appear (they shouldn't this early — signal bar should be hidden)

6. **Continue the conversation** for 3-5 more turns, covering:
   - Why this matters to you personally
   - What's in scope vs out of scope
   - Key challenges (technical, design, behavioral science)
   - Who it's for specifically

7. **Watch for the AI to summarize and recommend:**
   - After sufficient exploration, the AI should summarize its understanding
   - It should propose a process recommendation (which deliverables to create)
   - Look for signal chips appearing in the signal bar and on the message

8. **Check for completion signals:**
   - [ ] `MODE_COMPLETE(exploration)` signal chip appears (green)
   - [ ] `PROCESS_REC` signal chip appears (blue)
   - [ ] Possibly `SUMMARY` and `DEPTH` signals
   - [ ] The "Complete Session" button appears (green tint) in the session info bar

9. **Click "Complete Session":**
   - [ ] A system message appears: "Session completed. Summary generated with X decisions, Y progress items."
   - [ ] Session info bar returns to "No session"
   - [ ] Input field becomes disabled again

### What to watch for (potential issues)

- **API errors:** If you see red "Error:" system messages, check your API key configuration
- **Slow responses:** Normal for first message (cold start). Subsequent messages should be faster
- **Missing signals:** If the AI doesn't emit `[MODE_COMPLETE: exploration]` after a thorough conversation, it may need more turns, or the Layer 2 prompt may need tuning
- **Garbled signals:** If signals appear but look wrong (e.g. wrong type, truncated content), note the exact text for debugging

---

## Test 2: Challenge Network Behavior

**Goal:** Verify the AI pushes back appropriately during Exploration — clarifying, not critiquing.

### Steps

1. Select a different project or clear messages and start a new session
2. **Send deliberately vague or contradictory messages:**

   Turn 1:
   > "I want to build something that helps people be more productive and also more creative and also more relaxed."

   - [ ] The AI should ask what you mean, noting the potential tension between these goals
   - [ ] It should NOT say "this sounds too ambitious" or evaluate feasibility

   Turn 2:
   > "It's for everyone. Like, literally anyone could use it."

   - [ ] The AI should push back gently on "everyone" — who specifically?
   - [ ] Tone should be curious, not dismissive

   Turn 3:
   > "I want it to be a deeply personal creative tool but also commercially viable with millions of users."

   - [ ] The AI should surface the potential contradiction between "deeply personal" and "millions of users"
   - [ ] This is the kind of fundamental contradiction the spec says IS worth raising early

3. **Verify challenge network calibration:**
   - [ ] AI asks "what do you mean?" questions when language is vague
   - [ ] AI surfaces contradictions gently
   - [ ] AI does NOT evaluate market viability, timeline feasibility, or technical difficulty
   - [ ] AI does NOT propose structure, phases, tasks, or documents
   - [ ] Tone stays warm and collaborative throughout

---

## Test 3: Session Lifecycle (Pause/Resume/End)

**Goal:** Verify session state transitions work correctly through the UI.

### Steps

1. Start a new session on any project
2. Send 2-3 messages to build up conversation history

3. **Click "End Session":**
   - [ ] System message appears: "Session ended by user."
   - [ ] Session becomes nil, info bar shows "No session"
   - [ ] Input field disables

4. **Start a new session** on the same project:
   - [ ] If the old session was paused (not ended), it should resume with previous messages
   - [ ] If ended, a fresh session starts with empty messages
   - [ ] Mode picker should still work before starting

5. **Test the "Clear" button:**
   - [ ] Click "Clear" — all messages disappear
   - [ ] Session is nil
   - [ ] Can start a fresh session afterward

---

## Test 4: Mode Picker and Sub-Mode Behavior

**Goal:** Verify the mode/sub-mode pickers work and affect session behavior.

### Steps

1. **Check mode picker options:**
   - [ ] "exploration" is listed and is the default
   - [ ] "definition" is listed
   - [ ] "planning" is listed
   - [ ] "executionSupport" is listed

2. **Select "executionSupport":**
   - [ ] A "Sub-mode" picker should appear
   - [ ] Sub-mode options: None, checkIn, returnBriefing, projectReview, retrospective

3. **Select a different mode, then switch back to exploration:**
   - [ ] Sub-mode picker hides when not in executionSupport
   - [ ] Session info bar updates to reflect current mode

4. **Start a session in exploration mode:**
   - [ ] Verify the AI's first response is conversational/exploratory (not structured/action-oriented)
   - [ ] This confirms the correct Layer 2 prompt is being used

---

## Test 5: Error Handling

**Goal:** Verify the app handles errors gracefully.

### Steps

1. **Test with no project selected:**
   - [ ] "Start Session" button should be disabled when no project is selected
   - [ ] Input field should be disabled

2. **Test with invalid API key:**
   - Temporarily change API key in Settings to something invalid
   - Start a session and try to send a message
   - [ ] Error message appears as a system message in the chat
   - [ ] App doesn't crash
   - [ ] Can clear and retry after fixing the key

3. **Test rapid sending:**
   - While a response is loading, the send button should be disabled
   - [ ] Loading spinner appears during API call
   - [ ] Can't double-send

---

## Test 6: Signal Display Verification

**Goal:** Verify all signal types display correctly in the UI.

This test may require multiple conversations or deliberately guiding the AI toward different signals.

### Expected signals in Exploration mode:

| Signal | When it appears | Display |
|--------|----------------|---------|
| `MODE_COMPLETE` | AI believes exploration is done | Green chip |
| `PROCESS_RECOMMENDATION` | With MODE_COMPLETE, lists recommended deliverables | Blue chip in signal bar |
| `PLANNING_DEPTH` | With MODE_COMPLETE, suggested planning depth | Blue chip |
| `PROJECT_SUMMARY` | With MODE_COMPLETE, concise project summary | Blue chip |
| `SESSION_END` | If AI signals end of session | Orange chip |

### What to verify:

- [ ] Signal chips appear on the relevant message row (bolt icon + capsule chips)
- [ ] Signal bar at the bottom shows the most recent signals with more detail
- [ ] Action count shows if any actions were parsed (shouldn't happen in exploration mode)
- [ ] Multiple signals on one message display correctly side by side

---

## Checklist Summary

After completing all tests, verify:

- [ ] At least 3 real multi-turn Exploration conversations completed successfully
- [ ] AI behavior matches Exploration mode specification (clarifying, not critiquing)
- [ ] Challenge network works appropriately (pushes for clarity, surfaces contradictions)
- [ ] MODE_COMPLETE signal fires and is parsed correctly
- [ ] PROCESS_RECOMMENDATION signal contains sensible deliverable suggestions
- [ ] Session lifecycle (start/end/complete/clear) works without errors
- [ ] Signal display (chips, signal bar) renders correctly
- [ ] Error handling is graceful (no crashes, clear error messages)
- [ ] Mode/sub-mode pickers work correctly
- [ ] No visual glitches (layout, scrolling, loading states)

---

## Known Limitations

- **No automatic session persistence across app restarts** — sessions are created in the database but the dev screen doesn't auto-restore a previous session on reopen. You need to start/resume manually.
- **Process recommendation not yet written to ProcessProfile** — The signal is parsed and displayed, but the automatic write-back to the project's ProcessProfile entity is deferred to Module 10 (Integration & Polish).
- **No transition to Definition mode** — After completing Exploration, the app doesn't automatically prompt to start Definition. This is wired in Module 10.
- **Exploration mode only** — Definition, Planning, and Execution Support modes have their pipelines built but aren't integration-tested until their respective modules (7, 8, 9).

---

## If Something Goes Wrong

1. **API returns errors:** Check Settings → AI Assistant for valid provider/key/model. Check Console.app for `com.projectmanager.app` > `ai` category logs.
2. **Session won't start:** Ensure a project is selected. Check Console for `ai` category errors.
3. **Signals not detected:** The AI may not be emitting signals in the expected format. Check Console logs for "AIDevScreen response: X signals" messages. If 0 signals consistently, the Layer 2 prompt may need tuning.
4. **App crashes:** Check the Xcode console for the crash log. Note the stack trace and file a bug.
5. **Messages not scrolling:** The scroll-to-bottom is tied to `onChange(of: messages.count)` — if it's not working, it's a SwiftUI timing issue. Try resizing the window.
