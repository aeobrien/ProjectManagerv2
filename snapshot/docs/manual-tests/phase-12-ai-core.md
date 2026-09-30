# Phase 12: AI Core — Manual Test Brief

## Automated Tests
- **24 tests** in 4 suites, passing via `cd Packages/PMServices && swift test`

### Suites
1. **LLMRequestConfigTests** (3 tests) — Validates request configuration defaults, model selection, and token limit settings for Anthropic and OpenAI backends.
2. **ActionParserTests** (10 tests) — Validates parsing of [ACTION:...] blocks from AI response text into typed AIAction enum values across all 11 action types, including malformed and missing blocks.
3. **ActionExecutorTests** (6 tests) — Validates execution of parsed actions, generation of BundledConfirmation objects for user approval, and error handling for invalid actions.
4. **ContextAssemblerTests** (5 tests) — Validates token budgeting, conversation history truncation under token limits, and system prompt assembly for each conversation type.

## Manual Verification Checklist
- [ ] LLMClient sends a well-formed HTTP request to the Anthropic API when configured for Anthropic
- [ ] LLMClient sends a well-formed HTTP request to the OpenAI API when configured for OpenAI
- [ ] LLMClient retries on transient HTTP errors and eventually returns a response or error
- [ ] APIKeyProvider retrieves a key from environment variables when set
- [ ] APIKeyProvider retrieves a key from the Keychain when stored
- [ ] ActionParser correctly extracts all 11 action types from a multi-action AI response
- [ ] ActionParser returns an empty list when no [ACTION:...] blocks are present
- [ ] ActionExecutor generates a BundledConfirmation for each parsed action
- [ ] ContextAssembler truncates conversation history when it exceeds the token budget
- [ ] ContextAssembler selects the correct system prompt for each ConversationType (general, checkIn, onboarding, review, retrospective, reEntry)
- [ ] PromptTemplates contain non-empty system prompts for all six conversation types

## Files Created/Modified
### New Files
- `Packages/PMServices/Sources/PMServices/AI/LLMClient.swift` — HTTP-based client supporting Anthropic and OpenAI APIs with retry logic and token counting
- `Packages/PMServices/Sources/PMServices/AI/ActionParser.swift` — Parses [ACTION:...] blocks from AI responses into typed AIAction enum with 11 action types
- `Packages/PMServices/Sources/PMServices/AI/ActionExecutor.swift` — Executes parsed actions and generates BundledConfirmation for user approval
- `Packages/PMServices/Sources/PMServices/AI/ContextAssembler.swift` — Token budgeting, conversation history truncation, and system prompt assembly by conversation type
- `Packages/PMServices/Sources/PMServices/AI/PromptTemplates.swift` — System prompts for each ConversationType
