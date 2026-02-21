# Phase 13: Chat UI — Manual Test Brief

## Automated Tests
- **9 tests** in 1 suite, passing via `cd Packages/PMFeatures && swift test`

### Suites
1. **ChatViewModelTests** (9 tests) — Validates initial state defaults, sending a text message and receiving an AI response, sending a voice message, action parsing from AI responses, bundled confirmation flow with checkbox selection, follow-up message handling, and clearing conversation history.

## Manual Verification Checklist
- [ ] ChatView displays a project selector and conversation type selector at the top
- [ ] Selecting a project and conversation type configures the chat context correctly
- [ ] Typing a message in the input bar and sending it appends the user message to the message list
- [ ] An AI response appears in the message list after sending a user message
- [ ] Toggling voice input in the chat input bar switches to VoiceInputView for dictation
- [ ] When the AI response contains [ACTION:...] blocks, a pending confirmation bar appears
- [ ] The confirmation bar displays checkboxes for each proposed action
- [ ] Unchecking an action excludes it from the confirmed set
- [ ] Confirming the selected actions executes them and clears the confirmation bar
- [ ] Follow-up messages maintain conversation context from prior exchanges
- [ ] Clearing the conversation resets the message list and confirmation state
- [ ] The message list scrolls to the latest message automatically

## Files Created/Modified
### New Files
- `Packages/PMFeatures/Sources/PMFeatures/Chat/ChatViewModel.swift` — AI chat interface ViewModel with context assembly, action parsing, bundled confirmation flow, and conversation history management
- `Packages/PMFeatures/Sources/PMFeatures/Chat/ChatView.swift` — Full SwiftUI chat interface with project/conversation type selectors, message list, voice input toggle, pending confirmation bar, and input bar
