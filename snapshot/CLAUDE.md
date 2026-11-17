# Project Manager — CLAUDE.md

This file is read by every Claude Code instance working on this project. It defines the project overview, architecture, conventions, and institutional knowledge.

---

## Overview

Project Manager is a native macOS/iOS application (SwiftUI) for a single user to capture, plan, structure, and track personal projects. It features an integrated AI collaborator accessible via voice or text, a Focus Board enforcing work-in-progress limits and category diversity, a four-tier project hierarchy (Phase → Milestone → Task → Subtask), and sync with an external Life Planner system. It is designed from the ground up for a user with ADHD and executive dysfunction — this shapes every interaction.

---

## Architecture

**Pattern:** MVVM (Model-View-ViewModel) with protocol-oriented dependency injection

**Key principles:**
- ViewModels are `@Observable` classes (or `ObservableObject` if targeting older APIs)
- Views contain zero business logic — they bind to ViewModel properties and call ViewModel methods
- All data access goes through repository protocols (defined in Domain, implemented in Data)
- Services are injected via protocols, enabling mock-based testing at every level

**Modularisation:** Swift Package Manager with 6 packages in a strict dependency hierarchy (see Package Layers below)

**Target platforms:**
- macOS 14+ (Sonoma)
- iOS 17+

**Key technologies (decisions from domain research):**
- SwiftUI for all UI
- **GRDB** for local SQLite persistence (SwiftData rejected — lacks FTS, aggregate queries, dynamic predicates)
- **Point-Free's SQLiteData** (built on GRDB) for CloudKit sync, or custom sync layer if SQLiteData doesn't fit
- **Point-Free's swift-dependencies** for dependency injection across all packages
- **WhisperKit** for local on-device voice transcription (Apple Silicon optimised, pure Swift)
- LLM APIs (Anthropic, OpenAI) for AI chat
- **Apple NLContextualEmbedding + GRDB** for project knowledge base (RAG) — brute-force cosine similarity over stored vectors, no separate vector store needed at our corpus scale
- **FlyingFox** for the local REST integration API (pure Swift, async/await, zero dependencies)

---

## Package Layers

```
PMFeatures       → PMServices, PMDesignSystem, PMData, PMDomain, PMUtilities
PMServices       → PMData, PMDomain, PMUtilities
PMDesignSystem   → PMDomain, PMUtilities
PMData           → PMDomain, PMUtilities
PMDomain         → PMUtilities
PMUtilities      → (nothing — Foundation only)
```

**Rules:**
- Dependencies flow strictly downward. Never import a higher layer.
- PMDomain has ZERO framework dependencies. Pure Swift types, protocols, enums, and business logic only.
- Protocols are defined in PMDomain. Concrete implementations live in PMData or PMServices.
- PMDesignSystem contains reusable SwiftUI components. It may reference Domain types (for display) but never Data or Services.
- Each package has its own test target.

---

## Build & Test Commands

```bash
# Build the full project (macOS)
xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'

# Test app-level tests (includes ProjectManagerTests target)
xcodebuild test -scheme ProjectManager -destination 'platform=macOS,arch=arm64'

# Test a specific package via SPM (from its directory)
cd Packages/PMUtilities && swift test
cd Packages/PMDomain && swift test
cd Packages/PMData && swift test
cd Packages/PMDesignSystem && swift test
cd Packages/PMServices && swift test
cd Packages/PMFeatures && swift test

# Regenerate Xcode project after changing project.yml
xcodegen generate
```

**Project generation:** The Xcode project is generated from `project.yml` using XcodeGen. After any changes to targets, dependencies, or settings, run `xcodegen generate` to regenerate.

---

## Code Style

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Files | PascalCase, matching primary type | `ProjectRepository.swift` |
| Types (struct, class, enum) | PascalCase | `FocusManager`, `LifecycleState` |
| Protocols | PascalCase, suffix with `Protocol` | `ProjectRepositoryProtocol` |
| Mocks | Prefix with `Mock` | `MockProjectRepository` |
| Test files | Suffix with `Tests` | `FocusManagerTests.swift` |
| ViewModels | Suffix with `ViewModel` | `FocusBoardViewModel` |
| Views | Suffix with `View` | `FocusBoardView` |
| Properties/methods | camelCase | `lifecycleState`, `focusProject()` |
| Constants | camelCase | `maxFocusSlots` |
| Enum cases | camelCase | `.inProgress`, `.quickWin` |

### File Organisation

Each file contains one primary type. Small related types (e.g. a DTO used only by one class) may share a file if they're tightly coupled. Group files by feature within each package:

```
PMDomain/
  Sources/
    Entities/
      Project.swift
      Phase.swift
      Milestone.swift
      Task.swift
      ...
    Enums/
      LifecycleState.swift
      ItemStatus.swift
      ...
    Protocols/
      ProjectRepositoryProtocol.swift
      ...
    Logic/
      FocusManager.swift
      ...
  Tests/
    Entities/
      ProjectTests.swift
      ...
    Logic/
      FocusManagerTests.swift
      ...
```

### ViewModel Patterns

- ViewModels are `@Observable` classes
- One ViewModel per screen/feature (not per view component)
- ViewModels receive repository protocols via init injection
- ViewModels expose published state and methods — views call methods, read state
- No `async` work in init — use explicit `load()` methods
- Error states are exposed as published properties, not thrown

```swift
@Observable
final class ProjectBrowserViewModel {
    private let projectRepo: ProjectRepositoryProtocol

    var projects: [Project] = []
    var errorMessage: String?
    var isLoading = false

    init(projectRepo: ProjectRepositoryProtocol) {
        self.projectRepo = projectRepo
    }

    func loadProjects(filter: LifecycleState?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            projects = try await projectRepo.fetchAll(filter: filter)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### View Patterns

- Views are structs, always
- No business logic in views — only layout and binding
- Every view with meaningful content must have a SwiftUI Preview
- Use `@Environment` for shared dependencies where appropriate
- One primary action per screen (the thing the user came here to do)

### Data Model Patterns

- **Domain types** are pure Swift structs in PMDomain. They have no persistence annotations.
- **Persistence types** (if needed by SwiftData/GRDB) live in PMData and map to/from Domain types.
- If SwiftData is used: `@Model` classes live in PMData, with mapping functions to Domain structs.
- If GRDB is used: `Record` subclasses or `FetchableRecord` types live in PMData.
- JSON encoding: camelCase keys, ISO 8601 dates.

---

## Logging Conventions

**Framework:** `os.Logger` (Apple's unified logging)

**Subsystem:** `com.projectmanager.app`

**Categories** (one per module area):

| Category | Usage |
|----------|-------|
| `data` | Database operations, CRUD, queries |
| `focus` | Focus Board logic, slot management, diversity checks |
| `ai` | LLM API calls, context assembly, response parsing |
| `voice` | Audio recording, Whisper transcription |
| `sync` | CloudKit sync, Life Planner export |
| `ui` | View lifecycle events, navigation, user actions |
| `api` | Integration API requests/responses |
| `export` | Data export/import operations |

**Severity levels:**

| Level | When to use |
|-------|-------------|
| `.debug` | Detailed internal state, useful during development |
| `.info` | Normal operations: "loaded 5 projects", "check-in recorded" |
| `.notice` | Significant state changes: "project focused", "phase completed" |
| `.error` | Recoverable errors: API failure, parse error, sync conflict |
| `.fault` | Unrecoverable errors: database corruption, critical invariant violation |

**Rules:**
- `print()` is **banned**. Use `Logger` for all output.
- Log at method entry for significant operations (`.debug` level)
- Log outcomes (success/failure) for all data mutations and external calls
- Include entity IDs in log messages for traceability
- Never log sensitive data (API keys, full document content)

**Setup in PMUtilities:**

```swift
import os

public enum Log {
    public static let data = Logger(subsystem: "com.projectmanager.app", category: "data")
    public static let focus = Logger(subsystem: "com.projectmanager.app", category: "focus")
    public static let ai = Logger(subsystem: "com.projectmanager.app", category: "ai")
    public static let voice = Logger(subsystem: "com.projectmanager.app", category: "voice")
    public static let sync = Logger(subsystem: "com.projectmanager.app", category: "sync")
    public static let ui = Logger(subsystem: "com.projectmanager.app", category: "ui")
    public static let api = Logger(subsystem: "com.projectmanager.app", category: "api")
    public static let export = Logger(subsystem: "com.projectmanager.app", category: "export")
}
```

---

## Testing Conventions

**Framework:** Swift Testing (`@Test`, `#expect`) — preferred for new code. XCTest acceptable for integration tests or if Swift Testing has limitations.

**Rules:**
- Every public method gets at least one test
- Every enum must have tests covering all cases
- Edge cases to always cover: empty arrays, nil/optional values, boundary values (0, max), invalid input
- Mock strategy: protocol-based injection. Every protocol in Domain gets a `Mock` implementation in the test target.
- Tests are named descriptively: `testFocusProject_whenSlotsFull_rejects()`
- No test should depend on another test's state
- Use in-memory database for Data layer tests (no file I/O in unit tests)

**Mock naming:**

```swift
// Protocol in PMDomain
public protocol ProjectRepositoryProtocol {
    func fetchAll(filter: LifecycleState?) async throws -> [Project]
    // ...
}

// Mock in test target
final class MockProjectRepository: ProjectRepositoryProtocol {
    var fetchAllResult: [Project] = []
    var fetchAllError: Error?

    func fetchAll(filter: LifecycleState?) async throws -> [Project] {
        if let error = fetchAllError { throw error }
        return fetchAllResult
    }
}
```

---

## Key Files

| File | Purpose |
|------|---------|
| `ROADMAP.md` | Master phased development plan — what gets built and when |
| `WORKFLOW.md` | Development cycle, debugging protocol, session management |
| `CLAUDE.md` | This file — project conventions and institutional knowledge |
| `docs/session-log.md` | Historical record of what was built, when, and issues encountered |
| `docs/manual-tests/` | Manual test briefs for each phase |
| `ProjectManager-VisionStatement-v3.md` | Vision statement — the "why" and "what" |
| `ProjectManager-TechnicalBrief-v3.md` | Technical brief — the "how" |

---

## Reference Documents

When making design decisions, consult:

1. **Vision Statement v3** — for product intent, ADHD design principles, conceptual glossary
2. **Technical Brief v3** — for data model, AI behavioural contract, Focus Board logic, all feature specifications
3. **ROADMAP.md** — for phase sequencing and deliverables

The vision statement takes precedence on product behaviour questions. The technical brief takes precedence on implementation details. When they conflict, flag it.

---

## Mistakes to Avoid

- **[Build] XcodeGen GENERATE_INFOPLIST_FILE**: macOS app targets need `GENERATE_INFOPLIST_FILE: YES` in build settings, otherwise code signing fails. Always include this for app targets.
- **[Build] PRODUCT_NAME with spaces**: Don't use spaces in `PRODUCT_NAME` (e.g. "Project Manager") — it causes test host path mismatches. Use "ProjectManager" and set the display name separately via `INFOPLIST_KEY_CFBundleDisplayName` if needed.
- **[Build] Test target static library duplication**: When a test target depends on a host app target, do NOT also add the same SPM packages as direct dependencies of the test target. The test gets them through the host app. Adding them separately causes "static library duplication" errors.
- **[Build] SPM scheme test actions**: Auto-generated Xcode schemes for local SPM packages don't include test actions. To run package tests, use `cd Packages/PackageName && swift test` instead of `xcodebuild test -scheme PackageName`.
