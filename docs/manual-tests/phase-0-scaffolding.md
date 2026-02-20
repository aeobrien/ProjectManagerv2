# Phase 0: Scaffolding — Manual Test Brief

## Prerequisites
- macOS 14+ (Sonoma)
- Xcode 16.3+
- XcodeGen installed (`brew install xcodegen`)

## Test Steps

1. **Generate the project:**
   ```bash
   cd /Users/aidan/Dev/ProjectManagerv2
   xcodegen generate
   ```
   → Expected: "Created project at .../ProjectManager.xcodeproj"

2. **Open in Xcode:**
   ```bash
   open ProjectManager.xcodeproj
   ```
   → Expected: Xcode opens, all 6 packages visible in the navigator, no unresolved dependencies

3. **Build the app:**
   - Select the "ProjectManager" scheme, target "My Mac"
   - Build (Cmd+B)
   → Expected: Build succeeds with no errors

4. **Run the app:**
   - Run (Cmd+R)
   → Expected: App launches, shows a sidebar with "Focus Board", "All Projects", "AI Chat", "Settings" and a detail area showing "Phase 0: Scaffolding Complete"

5. **Run tests:**
   - Product → Test (Cmd+U)
   → Expected: Tests pass (ProjectManagerTests target runs, including the smoke test)

6. **Run PMUtilities tests via SPM:**
   ```bash
   cd Packages/PMUtilities && swift test
   ```
   → Expected: 1 test passes (LogTests > "All logger categories are accessible")

## Pass Criteria
- [ ] Project generates from project.yml without errors
- [ ] App builds and launches on macOS
- [ ] Sidebar navigation is visible with placeholder sections
- [ ] App-level tests pass via Xcode
- [ ] PMUtilities package tests pass via `swift test`
- [ ] No warnings or errors in the build
