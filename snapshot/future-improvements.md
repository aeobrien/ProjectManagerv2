# Future Improvements

Deferred features and ideas to revisit later. Not prioritised — just captured so nothing gets lost.

---

## New Features

### Task Descriptions
- Tasks currently only have a `name` field for their content
- Add a `description: String?` field for longer-form detail beyond the task name
- AI should be able to set/edit descriptions when creating or updating tasks
- Useful for capturing context, acceptance criteria, implementation notes, etc.

### Per-Project Shopping List
- A shopping list / procurement tracker per project
- Track items needed, with links, prices, and purchased/not-purchased status
- Could live as a tab in Project Detail or as a dedicated entity type
- Open question: model as a new entity (e.g. `ShoppingItem`) or extend existing notes/documents?

---

## UX Fixes (Near-Term)

_(Concrete interaction issues to batch-fix soon)_

- **Auto-start AI message on session start** — When the user hits "Start Session", the AI should automatically send the opening message based on project + mode context, rather than requiring the user to send the first message. The project and mode selection already provide enough intent.
- **Combine approval/revision with message input** — When approving or requesting revisions to an artifact (draft, structure proposal), the current flow is: click approve/revise → dismiss overlay → type follow-up message → send. Instead, the overlay should include a message input field so the user can approve + add context, or request revisions + detail what to change, in a single action.

---

## Pre-Testing Priority

_(Items to address before broader manual testing)_

- **Conversation history UI** — scroll-to-bottom, message grouping
- **Vision/Brief templates** — pre-filled structure for common project types
- **Adaptive onboarding message** — adjust first AI message based on project state
- **Document type filtering** — filter documents list by type in Documents tab

## Post-Testing

_(Items to address after core flows are validated)_

- **Codebase/repo linking** — associate external repos with projects
- **KB indexing of external files** — index linked files into knowledge base
- **Migration system** — GRDB schema migration strategy for updates
- **Retrospective view notes action** — view past retrospective notes from project detail
