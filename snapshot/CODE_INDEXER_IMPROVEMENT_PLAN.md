# Code Indexer Improvement Plan

**File:** `ProjectManagerv2/Packages/PMServices/Sources/PMServices/Codebase/CodebaseIndexer.swift`
**Created:** 2026-03-09

---

## Current State

The v2 indexer is a significant improvement over v1. It:
- **Does** respect `.gitignore` via a custom parser (`GitignoreRules` struct, lines 603-777)
- **Does** use `enumerator.skipDescendants()` for efficient directory skipping
- **Does** filter by an allowlist of file extensions (preventing binary file indexing)
- Handles iCloud-evicted file placeholders
- Has a configurable file size limit

However, there are still issues that cause excessive work on repos like Gong (where 24 tracked files ballooned into thousands of scanned files).

---

## Issue 1: Git submodules are traversed in full

**Severity: Critical — this is the primary cause of the Gong problem**

The indexer has zero awareness of git submodules. When it encounters a submodule directory (like `JUCE/`), it recurses into it and indexes the entire third-party framework. Submodule directories are not in `.gitignore` (they're tracked by git), so the gitignore parser won't help.

**Impact on Gong:** The `JUCE/` submodule contains 4,378 files (91MB). The actual project has 17 source files. So ~99.6% of files scanned are irrelevant framework code. This also distorts the overview document — the LLM-generated codebase summary would describe JUCE, not the Gong synthesizer.

**Fix — detect and skip submodules:**

```swift
/// Returns the set of submodule paths relative to the repo root.
private static func submodulePaths(at rootURL: URL) -> Set<String> {
    let gitmodulesURL = rootURL.appendingPathComponent(".gitmodules")
    guard let content = try? String(contentsOf: gitmodulesURL, encoding: .utf8) else { return [] }

    var paths = Set<String>()
    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("path = ") {
            let path = String(trimmed.dropFirst("path = ".count))
            paths.insert(path)
        }
    }
    return paths
}
```

Then in `scanFiles()`, when encountering a directory, check if its relative path is a submodule:

```swift
if submodulePaths.contains(relativePath) {
    enumerator.skipDescendants()
    continue
}
```

**Alternative approach:** Use `git ls-files` instead of filesystem enumeration. By default, `git ls-files` does NOT list submodule contents — it shows the submodule as a single entry. This would solve submodules automatically while also replacing the custom gitignore parser with git's own logic. See Issue 5 for details.

---

## Issue 2: Hardcoded `skippedDirectories` has gaps

**Severity: Medium**

The current hardcoded skip list (line 472-475) contains only 12 entries:
```swift
".git", "node_modules", "build", "DerivedData", ".build", "dist", "target",
"__pycache__", ".venv", "venv", "Pods", ".next"
```

While `.gitignore` rules catch most project-specific exclusions, the hardcoded list serves as a safety net for repos with incomplete or missing `.gitignore` files. It's missing many common directories:

| Missing directory | Common in |
|---|---|
| `cmake-build-*` | C/C++ (CMake) — directly relevant to Gong |
| `.gradle` | Java/Kotlin |
| `out` | Java/Kotlin/Gradle |
| `bin` | Go, C#, general |
| `obj` | C#/.NET |
| `.dart_tool` | Dart/Flutter |
| `.pub-cache` | Dart/Flutter |
| `.terraform` | Infrastructure |
| `__MACOSX` | macOS zip artifacts |
| `.parcel-cache` | Parcel bundler |
| `.turbo` | Turborepo |
| `.expo` | Expo/React Native |
| `.angular` | Angular |
| `vendor` | Go, PHP, Ruby |
| `.nuxt` | Nuxt.js |
| `.cache` | Various |
| `coverage` | Test coverage output |
| `.nyc_output` | NYC/Istanbul coverage |
| `.tox` | Python tox |
| `.pytest_cache` | Python pytest |
| `tmp` | General temp files |
| `.cocoapods` | CocoaPods cache |

**Fix:** Expand the list. This is a low-risk, high-value change — additional entries only prevent scanning of directories that are virtually never source code.

---

## Issue 3: Custom gitignore parser may have edge cases

**Severity: Medium**

The `GitignoreRules` struct (lines 603-777) is a custom reimplementation of gitignore pattern matching. While it handles the most common patterns (`*`, `**`, `?`, negation, directory-only, nested `.gitignore` files), it may diverge from git's actual behaviour in edge cases:

- **Character classes** (`[abc]`, `[0-9]`) are not supported
- **Escaped characters** (`\#`, `\!`) are not handled
- **Trailing spaces** in patterns may not be handled per spec (git allows escaping with `\`)
- **Pattern precedence** between nested `.gitignore` files may differ from git's behaviour in edge cases
- The `fnmatchRecursive` implementation uses backtracking which could be expensive on pathological patterns (e.g., many `*` in sequence)

**Impact:** Most repos use simple patterns so this works fine in practice. But repos with complex `.gitignore` files could see files incorrectly included or excluded.

**Fix (two options):**

**A) Replace with `git check-ignore`:** Shell out to git for definitive answers. This is slower (one process per file or batch) but guaranteed correct.

```swift
// Batch check: pipe paths to git check-ignore --stdin
private func gitCheckIgnore(paths: [String], at rootURL: URL) -> Set<String> {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["check-ignore", "--stdin"]
    process.currentDirectoryURL = rootURL
    // Write paths to stdin, read ignored paths from stdout
}
```

**B) Replace the entire scan with `git ls-files`:** See Issue 5. This eliminates the need for any gitignore parsing entirely.

---

## Issue 4: Repeated string operations for path normalisation

**Severity: Low-Medium**

Every file encountered triggers:
```swift
let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
```

This allocates a new string for every file in the tree. For large repos (thousands of files), this creates significant allocation pressure.

**Fix:** Compute the root path prefix length once and use `String.dropFirst()`:

```swift
// Before the loop:
let rootPrefix = rootURL.path.count + 1  // +1 for the trailing "/"

// In the loop:
let relativePath = String(fileURL.path.dropFirst(rootPrefix))
```

Or, if switching to `git ls-files` (Issue 5), paths are already relative.

---

## Issue 5: Consider replacing filesystem walk with `git ls-files`

**Severity: Architectural suggestion**

The current approach walks the filesystem and reimplements gitignore logic in Swift. An alternative is to use `git ls-files` for git repositories:

```swift
private func getGitTrackedFiles(at rootURL: URL) -> [String]? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["ls-files", "--cached", "--others", "--exclude-standard"]
    process.currentDirectoryURL = rootURL

    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else { return nil }

    return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
}
```

**Benefits:**
- Automatically respects `.gitignore`, `.git/info/exclude`, and global gitignore
- Automatically excludes submodule contents (they appear as a single entry)
- Returns only relative paths — no string manipulation needed
- Matches git's own behaviour exactly — no parser edge cases
- Simpler code — eliminates the entire `GitignoreRules` struct for the git case

**Trade-offs:**
- Requires git to be installed (safe assumption on macOS for developer tools)
- Doesn't work for non-git directories (keep `FileManager.enumerator` as fallback)
- Loses the iCloud-evicted-file detection (would need separate handling)
- Process spawning has overhead, but only once per scan vs. thousands of file stats

**If adopted**, the architecture becomes:

```
scanFiles()
├── isGitRepository? (check for .git directory)
│   ├── YES → git ls-files --cached --others --exclude-standard
│   │         Filter by allowedExtensions
│   │         Apply file size limit
│   │         Detect submodules from .gitmodules (for logging/UI)
│   └── NO  → Fall back to FileManager.enumerator
│             Use expanded hardcoded skip list
│             Use custom GitignoreRules (if .gitignore present)
│             Handle iCloud evicted files
└── Return [URL] file list
```

---

## Issue 6: No progress reporting during file scanning

**Severity: Low**

The `scanFiles()` method returns the complete file list only after full traversal. For large repos, this can take several seconds with no feedback to the user. Progress logging exists for the embedding phase (batch X/Y) but not for scanning.

**Fix:** Accept an optional progress callback:

```swift
private func scanFiles(
    at rootURL: URL,
    sizeLimitMB: Int,
    progress: ((Int) -> Void)? = nil  // called with running file count
) throws -> [URL]
```

---

## Issue 7: The `buildCodebaseSnapshot` reads files sequentially

**Severity: Low**

The snapshot builder (line 254) reads every file with `String(contentsOf:)` sequentially. For repos with many files, this could benefit from concurrent file reads.

This is unlikely to be a bottleneck compared to the embedding phase, but worth noting.

---

## Recommended Implementation Order

1. **Issue 1 (submodule detection)** — This is the single most impactful fix for the Gong problem. Parse `.gitmodules` and skip submodule directories during scanning. Small, self-contained change.

2. **Issue 2 (expand hardcoded skip list)** — Low-risk, quick win. Add the missing common directories.

3. **Issue 4 (path string optimisation)** — Small performance improvement, easy to implement.

4. **Issue 5 (git ls-files)** — Larger architectural change that subsumes Issues 1, 3, and 4. Consider this as a follow-up if the simpler fixes aren't sufficient, or as the long-term target architecture.

5. **Issues 3, 6, 7** — Lower priority polish.

---

## Validation Plan

After implementing fixes, re-index the Gong repo and verify:
- [ ] `JUCE/` submodule is NOT traversed (should see ~17 files, not ~4,400)
- [ ] `xcode/` directory is still skipped (already working via `.gitignore`)
- [ ] `build/` directory is still skipped (already working via hardcoded list + `.gitignore`)
- [ ] Overview document describes the Gong synthesizer, not the JUCE framework
- [ ] Indexing completes in seconds, not minutes
