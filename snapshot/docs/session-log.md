# Session Log

## Session 1 — 2026-02-20

### Completed
- **Domain research**: ADHD productivity tools, existing market, AI in project management, Kanban best practices
- **Technical research**: SwiftUI architecture, SwiftData vs GRDB, WhisperKit vs whisper.cpp, vector stores, local HTTP servers
- **Key decisions made**:
  - GRDB for persistence (SwiftData lacks FTS, aggregates, dynamic predicates)
  - WhisperKit for voice input (pure Swift, best ANE utilisation)
  - NLContextualEmbedding + GRDB for RAG (no separate vector store needed)
  - FlyingFox for integration API (lightweight, zero deps, async/await)
  - swift-dependencies for DI (to be added in a future phase)
  - XcodeGen for project generation from `project.yml`
- **Phase 0: Scaffolding** — complete:
  - 6 SPM packages created (PMUtilities, PMDomain, PMData, PMDesignSystem, PMServices, PMFeatures)
  - Strict dependency hierarchy enforced via Package.swift declarations
  - PMUtilities logging system (os.Logger with 8 categories)
  - App entry point with NavigationSplitView sidebar placeholder
  - XcodeGen project spec (project.yml)
  - Smoke tests passing
  - Manual test brief written

### Test Counts
- PMUtilities: 1 test (LogTests)
- PMDomain: 1 test (module access)
- PMData: 1 test (module access)
- PMDesignSystem: 1 test (module access)
- PMServices: 1 test (module access)
- PMFeatures: 1 test (module access)
- ProjectManagerTests: 1 test (app smoke test)
- **Total: 7 tests, all passing**

### Issues Encountered
- XcodeGen: `GENERATE_INFOPLIST_FILE: YES` required for macOS app target
- XcodeGen: `PRODUCT_NAME` with spaces caused test host path mismatch — use "ProjectManager" not "Project Manager"
- Static library duplication: test target must not re-link packages that are already linked by the host app — only depend on the app target
- Auto-generated SPM schemes (PMUtilities, etc.) don't include test actions in Xcode — use `swift test` from package directory instead

### Next Steps
- Phase 1: Domain Models — entities, enums, protocols, FocusManager business logic
