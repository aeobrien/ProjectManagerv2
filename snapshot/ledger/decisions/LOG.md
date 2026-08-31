# Decision Log

## Format

Each decision is recorded with context, options considered, and rationale. Decisions are numbered sequentially.

---

## DEC-001: GRDB over SwiftData for persistence

**Date:** 2026-02-20
**Phase:** 0 (Scaffolding) / 2 (Data Persistence)
**Context:** Needed to choose local database technology. SwiftData is Apple's native ORM; GRDB is a mature SQLite wrapper.
**Options:**
1. SwiftData — Apple-native, tight SwiftUI integration
2. GRDB — Full SQLite control, FTS, aggregate queries, dynamic predicates
**Decision:** GRDB
**Rationale:** SwiftData lacks full-text search (FTS), aggregate queries, and dynamic predicates — all required for the project browser search, analytics, and filtered queries. GRDB provides direct SQLite access with Swift-native APIs.

---

## DEC-002: WhisperKit for voice transcription

**Date:** 2026-02-20
**Phase:** 10 (Voice Input)
**Context:** Needed on-device speech-to-text for privacy and offline use.
**Options:**
1. WhisperKit — Pure Swift, Apple Silicon ANE optimised
2. whisper.cpp — C++ with Swift bindings, broader platform support
**Decision:** WhisperKit
**Rationale:** Pure Swift, best Apple Neural Engine utilisation, simpler build integration.

---

## DEC-003: FlyingFox for Integration API

**Date:** 2026-02-20
**Phase:** 23 (Integration API)
**Context:** Needed a lightweight local HTTP server for external tool integration (Claude Code, etc.).
**Options:**
1. Vapor — full-featured web framework (heavyweight)
2. Swifter — lightweight HTTP server
3. FlyingFox — pure Swift, async/await, zero dependencies
**Decision:** FlyingFox
**Rationale:** Zero dependencies, async/await native, lightweight. Ideal for a local-only REST API.

---

## DEC-004: XcodeGen for project generation

**Date:** 2026-02-20
**Phase:** 0 (Scaffolding)
**Context:** Managing Xcode project files with 6 SPM packages is complex. Needed to choose between manual Xcode project, XcodeGen, or SPM-only.
**Decision:** XcodeGen with `project.yml`
**Rationale:** Keeps project configuration in a readable YAML file, avoids Xcode project merge conflicts, regenerable.

---

## DEC-005: NLContextualEmbedding + GRDB for RAG

**Date:** 2026-02-20
**Phase:** 18 (Knowledge Base)
**Context:** Needed on-device vector search for project knowledge base. Corpus is small enough that brute-force cosine similarity works.
**Options:**
1. sqlite-vss — SQLite vector extension
2. FAISS — Facebook's vector search library
3. Apple NLContextualEmbedding + GRDB — store vectors in SQLite, brute-force search
**Decision:** Apple NLContextualEmbedding + GRDB
**Rationale:** No separate vector store needed at the project's corpus scale. Uses Apple's built-in embeddings, stored alongside all other data in GRDB/SQLite.

---

## DEC-006: swift-dependencies for DI

**Date:** 2026-02-20
**Phase:** Future (to be integrated)
**Context:** Needed dependency injection across 6 packages for testability.
**Decision:** Point-Free's swift-dependencies
**Rationale:** Lightweight, composable, works well with Swift's type system and SPM packages.

---

*Decisions extracted from session log and CLAUDE.md. Future decisions should be logged here as they are made.*
