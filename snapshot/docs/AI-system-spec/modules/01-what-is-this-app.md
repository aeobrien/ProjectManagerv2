# What Is This App?

Project Manager is a native macOS/iOS app (SwiftUI) for a single user to capture, plan, structure, and track personal projects. It's designed specifically for someone with ADHD and executive dysfunction — this shapes every interaction.

## Core Concepts

**Four-tier project hierarchy:**
- **Project** — a meaningful endeavour with intent and a desired outcome
- **Phase** — a major stage of work (e.g. "Foundation", "Core Features", "Polish")
- **Milestone** — a concrete checkpoint within a phase (e.g. "User authentication working")
- **Task** — a single unit of work within a milestone, with status (toDo / inProgress / done / waiting / blocked), priority (low / normal / high), and effort type (quickWin / deepFocus / admin / creative / physical)
- **Subtask** — a checkbox item within a task

**Project lifecycle:** idea → active → paused → completed / abandoned

**Focus Board:** The main view. Shows a curated set of "focused" projects (WIP-limited, category-diverse). Each focused project shows its current tasks in a kanban-style column. The Focus Board enforces limits: max focus slots, max per category, visible tasks per project.

**Check-ins:** Periodic conversations with the AI about a specific project. Two depths: Quick Log (brief update, minimal questions) and Full Conversation (deeper reflection on progress, blockers, avoidance patterns). Check-ins record what was discussed and track task avoidance (tasks the user doesn't mention get their "times deferred" counter incremented).

**Documents:** Markdown documents attached to projects. The two most important are the **Vision Statement** (detailed spec of intent — what the project IS, why it exists, design principles, definition of done) and the **Technical Brief** (architecture, technology choices, data model, implementation order). These are auto-generated during onboarding but editable afterwards.

**Categories:** User-defined groupings like Software, Music, Hardware, Creative, Life Admin, Research/Learning. Used for Focus Board diversity enforcement.

**Quick Capture:** A lightweight entry point for jotting down project ideas as raw text. Creates an "idea" state project stub. No AI involved.
