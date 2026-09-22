**Lane:** both

# Project Manager v2

## Overview

A native macOS/iOS application (SwiftUI) for a single user to capture, plan, structure, and track personal projects. Features an integrated AI collaborator accessible via voice or text, a Focus Board enforcing WIP limits and category diversity, a four-tier project hierarchy (Phase > Milestone > Task > Subtask), and sync with an external Life Planner system. Designed from the ground up for a user with ADHD and executive dysfunction — this shapes every interaction.

**Category:** Software
**Platform:** macOS 14+ (Sonoma), iOS 17+
**Architecture:** MVVM with protocol-oriented DI, 6 SPM packages in strict dependency hierarchy
**Status:** All 28 phases implemented; in polish/testing phase

## Key Technologies

| Technology | Purpose |
|-----------|---------|
| SwiftUI | All UI (macOS + iOS) |
| GRDB | Local SQLite persistence (SwiftData rejected) |
| WhisperKit | On-device voice transcription (Apple Silicon) |
| Anthropic/OpenAI APIs | AI chat / collaborator |
| Apple NLContextualEmbedding + GRDB | Project knowledge base (RAG) |
| FlyingFox | Local REST integration API |
| swift-dependencies (Point-Free) | Dependency injection |
| XcodeGen | Xcode project generation from project.yml |

## Package Layers

```
PMFeatures       → PMServices, PMDesignSystem, PMData, PMDomain, PMUtilities
PMServices       → PMData, PMDomain, PMUtilities
PMDesignSystem   → PMDomain, PMUtilities
PMData           → PMDomain, PMUtilities
PMDomain         → PMUtilities
PMUtilities      → (nothing — Foundation only)
```

## Subsystems

| Subsystem | Package | Status | Notes |
|-----------|---------|--------|-------|
| Domain Models | PMDomain | Implemented | Entities, enums, protocols, FocusManager logic |
| Data Persistence | PMData | Implemented | GRDB SQLite, all repositories, cascading ops |
| Data Export/Import | PMData | Implemented | JSON export/import, settings persistence |
| Design System | PMDesignSystem | Implemented | Colour tokens, task cards, health badges, progress components |
| Project Browser | PMFeatures | Implemented | Browse, filter, search, CRUD, navigation shell |
| Hierarchy Management | PMFeatures | Implemented | Full CRUD for phases/milestones/tasks/subtasks |
| Focus Board | PMFeatures | Implemented | Kanban, drag-and-drop, diversity enforcement, health signals |
| Roadmap View | PMFeatures | Implemented | Per-project timeline with dependencies |
| Quick Capture | PMFeatures | Implemented | Text + voice, global shortcut |
| Voice Input | PMServices | Implemented | WhisperKit, waveform, editable transcript |
| AI Core | PMServices | Implemented | LLM client, prompts, context assembly, action parsing |
| Chat UI | PMFeatures | Implemented | Voice/text, project selector, action confirmation |
| Check-In Flow | PMFeatures/PMServices | Implemented | Quick log + full conversation, avoidance detection |
| Project Onboarding | PMFeatures/PMServices | Implemented | Brain dump > discovery > structure > approval |
| Document Management | PMFeatures | Implemented | Markdown editor, version tracking |
| Retrospective Flow | PMFeatures/PMServices | Implemented | Phase-end retrospective, return briefings |
| Knowledge Base (RAG) | PMServices | Implemented | On-device embeddings, vector store, incremental indexing |
| CloudKit Sync | PMData | Implemented | Private DB sync, conflict resolution, offline support |
| iOS App | PMFeatures | Implemented | Tab navigation, adaptive layouts, widget |
| iOS Notifications | PMServices | Implemented | Scheduling, fatigue prevention, snooze |
| Life Planner Export | PMServices | Implemented | MySQL/API export, debounced triggers |
| Integration API | PMServices | Implemented | Local REST API (FlyingFox), auth, audit logging |
| Estimate Calibration | PMFeatures/PMServices | Implemented | Tracking, trends, ADHD-safe guardrails |
| AI Project Reviews | PMFeatures/PMServices | Implemented | Cross-project patterns, stall detection |
| Cross-Project Roadmap | PMFeatures | Implemented | Milestone aggregation across focused projects |
| Adversarial Review | PMFeatures/PMServices | Implemented | Document export, critique import, synthesis |

## Key Documents

| Document | Path | Purpose |
|----------|------|---------|
| Vision Statement v3 | `ProjectManager-VisionStatement-v3.md` | Product intent, ADHD principles, conceptual glossary |
| Technical Brief v3 | `ProjectManager-TechnicalBrief-v3.md` | Data model, AI contract, Focus Board logic, all specs |
| CLAUDE.md | `CLAUDE.md` | Project conventions, architecture, code style |
| WORKFLOW.md | `WORKFLOW.md` | Development cycle, debugging protocol, session management |
| Original Roadmap | `ROADMAP.md` | 28-phase development plan (original format) |
| Session Log | `docs/session-log.md` | Historical build record |
| Future Improvements | `future-improvements.md` | Deferred features and ideas |
| AI System Spec | `docs/AI-system-spec/` | AI system v2 detailed specifications |

## Linked Projects

| Project | Relationship | Notes |
|---------|-------------|-------|
| Ledger (~/Dev/Ledger) | related-to | Dashboard sync goal — bidirectional sync between PM and Claude Code /dashboard |

## Open Questions

- **Dashboard bidirectional sync:** How should Project Manager sync with the Claude Code /dashboard system? Which data flows in which direction? What is the canonical source of truth for shared entities (projects, tasks, status)? What is the sync protocol (Integration API, file-based, direct DB)?
- **AI System V2 stability:** Recent commits show AI System V2 modules 1-6 implemented — is the session infrastructure, exploration mode, and planning/execution parity stable?
- **Manual testing status:** Phase 28 (Polish & Gaps) items identified but session log only covers session 1 — what is the current testing state?
- **Pre-testing priority items:** Conversation history UI, vision/brief templates, adaptive onboarding message, document type filtering — are these addressed?
- **CloudKit sync in practice:** Phase 19 implemented but noted as needing interim backup. Has real-world multi-device sync been tested?

## Component Register

_No physical components — this is a pure software project._

---

*Ledger initialised: 2026-04-04*
