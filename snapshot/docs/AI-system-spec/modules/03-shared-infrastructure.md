# Shared AI Infrastructure

## LLMClient
Sends HTTP requests to Anthropic (Claude) or OpenAI (GPT-4o). Supports retries with exponential backoff. API key from UserDefaults or environment variables.

## ContextAssembler
Builds the full payload (system prompt + context + message history) for any conversation. For a given project, it formats:
- Project metadata (name, state, definition of done, notes, original capture transcript)
- Full hierarchy: Phase → Milestone → Task (with status, priority, effort type, deadlines, blocked/waiting state, deferred count) → Subtask
- Frequently deferred tasks (highlighted separately)
- Recent check-ins (last 3, with AI summaries)
- Estimate calibration data (accuracy ratio, suggested multiplier, trend)
- Optional RAG retrieval from a knowledge base

Token budget management: 8000 tokens default, truncates oldest messages first, reserves 1024 for response.

## ActionParser
Regex-based parser that extracts `[ACTION: TYPE]...[/ACTION]` blocks from AI responses. Returns separated natural language and structured action list. Handles placeholder IDs (non-UUID strings generate fresh UUIDs for CREATE actions).

## ActionExecutor
Takes parsed actions and either presents them for confirmation or auto-applies them. Generates human-readable descriptions for the confirmation UI. Executes accepted actions via repository protocols.

## PromptTemplateStore
All prompts are stored as compiled defaults but can be overridden by the user via UserDefaults (exposed in a Settings UI). Templates support `{{variable}}` substitution. 14 templates total, grouped into: Core, Onboarding, Check-ins, Reviews, Chat, Vision Discovery, Document Generation.
