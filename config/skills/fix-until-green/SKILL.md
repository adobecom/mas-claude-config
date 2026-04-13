---
name: fix-until-green
description: Autonomous implement→test→patch loop with max-iteration budget. Writes code, runs tests, parses failures, patches exports/imports/logic, re-runs until green or budget exhausted. Use for well-scoped implementation tasks with clear test signal. Activates on "fix until green", "iterate until tests pass", "autonomous fix loop".
tags: [autonomous, test, iteration, fix-loop]
triggers:
  - "fix until green"
  - "iterate until tests pass"
  - "autonomous fix loop"
  - "fix-until-green"
  - "run until passing"
---

# Fix Until Green — Autonomous Implement/Test/Patch Loop

## Purpose

Close well-scoped tickets autonomously by iterating implement → test → diagnose → patch until the test suite is green or a max-iteration budget is exhausted. Proven on DESTRUCTIVE_TOOLS enforcement (47 tests, 4-failure improvement in one session).

## When to Use

✅ Good fit:
- Task has clear, fast test signal (unit tests, not E2E)
- Scope is narrow (1-3 files)
- Failure modes are known: missing exports, import paths, assertion tweaks
- User is confident in the implementation direction

❌ Don't use:
- Architectural decisions still open — use `brainstorming` first
- E2E tests with 5+ min runtime (budget spent on runtime, not fixes)
- Tests are the uncertainty — use TDD skill instead
- Security fixes without characterization tests — use `audit-wave` instead

## Execution

### Phase 1: Contract

Before the loop, explicitly capture:
- **Test command**: exact invocation (e.g., `npm test -- --grep "DESTRUCTIVE_TOOLS"`)
- **Success signal**: what output means green? (e.g., "0 failing" or exit code 0)
- **Max iterations**: default 10, confirm with user if task is complex
- **Files in scope**: list the files you may edit — never edit outside this list mid-loop
- **Rollback point**: current commit SHA, so a bad loop can be reset

Record all of this in a TaskCreate entry for the run. Use TaskUpdate at each iteration.

### Phase 2: Baseline Run

Run the test command ONCE before any changes:
- Record baseline pass/fail counts
- If already green with no changes → halt, tell user no-op

### Phase 3: Implementation Pass

Write the initial implementation. Then enter the loop.

### Phase 4: The Loop

```
for iteration in 1..max_iterations:
    run test command
    parse output: new_pass_count, new_fail_count, failure_messages
    if new_fail_count == 0:
        goto success
    if new_pass_count < baseline_pass_count:
        # regression — we broke something passing
        halt and report regression
    diagnose failures:
        - module not found → check exports, imports, paths
        - assertion mismatch → re-read impl, decide: bug in code or bug in test
        - type error → fix types
        - timeout → investigate, do NOT bump timeout
    apply smallest patch to address top failure
    TaskUpdate iteration status
continue
```

### Phase 5: Halt Conditions

Halt immediately (do NOT keep iterating) if:
- **Regression**: previously-passing tests now fail
- **Scope creep**: diagnosis points at a file outside scope → stop and ask user to widen scope
- **Same failure 2x in a row**: you patched for it and it didn't move — escalate
- **Budget exhausted**: hit max_iterations
- **Infrastructure failure**: test runner crash, port conflict, missing dependency

Never "fix" by deleting failing tests unless the user explicitly authorized it.

### Phase 6: Success Report

On green, produce a report:
```
Fix-until-green report:
  Iterations used: <N>/<max>
  Baseline: <pass>/<fail>
  Final: <pass>/<0>
  Files touched: <list>
  Commits: <none — user reviews first>
Ready for review. Commit? (awaiting user)
```

**Do NOT auto-commit.** Always leave the final commit to the user.

### Phase 7: Failure Report

On halt without green:
```
Fix-until-green halted:
  Reason: <regression | scope creep | stuck | budget>
  Iterations used: <N>/<max>
  Baseline: <pass>/<fail>
  Current: <pass>/<fail>
  Unresolved failures:
    - <test name>: <last error>
  Files touched: <list>
  Suggested next step: <concrete action>
```

## Anti-Patterns

- ❌ Silently bumping timeouts to make flaky tests pass
- ❌ Adding `.skip` or `.only` to dodge failures
- ❌ Catching exceptions to swallow errors
- ❌ Auto-committing at green without user review
- ❌ Widening scope mid-loop to fix "related" bugs
- ❌ Running the loop without a baseline — you won't detect regressions

## Related

- `superpowers:test-driven-development` — use this instead when tests don't exist yet
- `superpowers:systematic-debugging` — use this when failure mode is unclear
- `.claude/rules/testing.md` — test infra requirements (ports, env)
