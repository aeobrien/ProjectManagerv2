# Project Manager — Development Workflow

This document defines the exact development cycle for every phase. It is the process contract.

---

## Module Development Cycle

Every phase follows this exact cycle. No exceptions.

### 1. Branch

- Create branch `phase-N/name` from the current main branch
- Verify the project builds cleanly before making any changes
- Read the phase specification in ROADMAP.md and confirm you understand the deliverables

### 2. Build

- Implement all sub-modules listed in the phase specification
- Follow all conventions in CLAUDE.md
- Add logging at every significant operation (see Logging Conventions in CLAUDE.md)
- Keep commits atomic within the branch — commit after each sub-module if practical

### 3. Auto-Test

- Write unit tests for all new public API surface
- Run per-package tests:
  ```bash
  # Test a specific package (from project root)
  cd Packages/PMDomain && swift test

  # Test app-level integration tests
  xcodebuild test -scheme ProjectManager -destination 'platform=macOS,arch=arm64'
  ```
- **All tests must pass before proceeding.** Do not move to integration with failing tests.
- Check test coverage: every public method, every enum case, every computed property, every error path

### 4. Integrate

- Regenerate the Xcode project if project.yml changed:
  ```bash
  xcodegen generate
  ```
- Build the full app:
  ```bash
  xcodebuild build -scheme ProjectManager -destination 'platform=macOS,arch=arm64'
  ```
- Fix any integration issues (missing dependencies, type mismatches, access control)
- Run the full test suite again after integration fixes
- Verify the app launches and the new feature is accessible

### 5. Manual Test Brief

- Write a manual test script at `docs/manual-tests/phase-N-name.md`
- Format:
  ```markdown
  # Phase N: [Name] — Manual Test Brief

  ## Prerequisites
  - [Any setup required]

  ## Test Steps
  1. [Step] → Expected: [outcome]
  2. [Step] → Expected: [outcome]
  ...

  ## Pass Criteria
  - [ ] [Criterion 1]
  - [ ] [Criterion 2]
  ```
- User performs manual testing and provides feedback
- Address any issues before proceeding

### 6. Commit & Merge

- Only after both auto-tests and manual tests pass
- Merge branch to main
- Tag the merge: `phase-N-complete`
- Update session log (`docs/session-log.md`)

---

## Debugging Protocol

When a build or test fails:

1. **Read the full error message.** Don't skim. Copy the exact error.
2. **Identify the root cause.** Trace the error to its origin. Don't guess — understand.
3. **Fix the cause, not the symptom.** If a test fails because of a data model change, fix the model or the test to reflect the correct behaviour — don't just make the test pass.
4. **Re-run the specific failing test** to confirm the fix.
5. **Re-run the full test suite** for the affected package.
6. **Re-build the full app** to catch any ripple effects.
7. **Only proceed when everything passes.**

If you find yourself in a cycle of fixing one thing and breaking another, stop. Read the error chain from the beginning. The root cause is usually earlier than where the symptoms appear.

---

## Session Protocol

### Starting a Session

1. Read `docs/session-log.md` to understand current state
2. Read `ROADMAP.md` to identify the current phase
3. Check git status — ensure you're on the correct branch with a clean working tree
4. Build the project to confirm everything works before making changes
5. Begin the current phase's module cycle

### Ending a Session

1. Ensure all work is committed (no uncommitted changes left behind)
2. Update `docs/session-log.md` with:
   - What was completed
   - Test counts per package
   - Issues encountered and how they were resolved
   - What the next session should start on
3. If a phase is partially complete, note exactly which sub-modules are done and which remain

### Session Log Format

```markdown
# Session Log

## Session N — YYYY-MM-DD

### Completed
- Phase X.Y: [sub-module description]
- [specific details of what was built]

### Test Counts
- PMDomain: N tests
- PMData: N tests
- [etc.]

### Issues Encountered
- [Issue]: [How it was resolved]

### Mistakes to Remember
- [If any — also add these to CLAUDE.md's Mistakes to Avoid section]

### Next Steps
- Phase X.Z: [what needs to happen next]
```

---

## Phase Transition Checklist

Before starting a new phase, verify:

- [ ] Previous phase branch merged to main
- [ ] All tests passing on main
- [ ] App builds and launches cleanly on main
- [ ] Manual test brief completed and approved
- [ ] Session log updated
- [ ] Any new conventions or mistakes recorded in CLAUDE.md

---

## When Things Go Wrong

### Build fails after merge
- Check for dependency conflicts between packages
- Verify access control (public/internal) on types shared across packages
- Check for circular dependencies — they indicate a layer violation

### Test passes in isolation but fails in integration
- Look for shared mutable state (singletons, static vars)
- Check for test order dependencies
- Verify in-memory vs on-disk database confusion

### A phase is taking much longer than expected
- Stop and reassess. Is the phase too large? Consider splitting.
- Is there a blocked decision? Make the decision or simplify.
- Document what's making it difficult in the session log — this is valuable information for future phases.

### A design decision from an earlier phase turns out to be wrong
- Don't patch around it. Fix it properly.
- Create a dedicated fix branch if the change is substantial
- Update CLAUDE.md with what was learned
- Re-run all tests after the fix

---

## Communication Protocol

### What to report to the user
- Phase start: "Starting Phase N: [name]. Building [sub-modules]."
- Phase completion: "Phase N complete. [summary]. [test count] tests passing. Ready for manual testing."
- Blockers: "Blocked on Phase N: [issue]. Options: [A] or [B]. Which do you prefer?"
- Decisions needed: "Phase N requires a decision: [context]. My recommendation is [X] because [reason]. Want to proceed with that?"

### What NOT to do
- Don't silently skip tests
- Don't commit with known failing tests
- Don't make architectural decisions without flagging them
- Don't change conventions established in CLAUDE.md without discussing first
