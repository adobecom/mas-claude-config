---
name: audit-wave
description: Scaffold a 4-wave architectural audit (smoke → security → hardening → deliverables) for a branch with characterization-test discipline. Use for pre-review audits of large MWPW branches (1000+ LOC, multiple features). Activates on "audit this branch", "wave audit", "pre-review audit", "architectural review".
tags: [audit, review, security, wave, pre-review, refactor]
triggers:
  - "audit this branch"
  - "wave audit"
  - "pre-review audit"
  - "architectural review"
  - "start an audit"
  - "audit MWPW"
  - "audit-wave"
---

# Audit Wave — Structured Pre-Review Audit

## Purpose

Codify the "cover before you cut" multi-wave audit methodology proven on MWPW-183572 (25K lines, 81 commits, 18 fixes landed). Use for any large feature branch that needs adversarial review before formal PR review.

## Core Principle

**Cover before you cut.** For any fix touching untested code paths:
1. Write a characterization test that captures *current* behavior
2. Apply the fix
3. Verify the test still passes (behavior-preserving) OR update intentionally (behavior-changing)

Never refactor without a safety net.

## Execution

### Phase 0: Scope

Extract from the user message or current branch:
- Branch name (default: `git branch --show-current`)
- Commit count vs main: `git rev-list --count main..HEAD`
- LOC delta: `git diff main...HEAD --stat | tail -1`
- Files touched: `git diff main...HEAD --name-only`

Ask the user to confirm scope if unclear.

### Phase 1: Plan Doc

Create `.claude/plans/<TICKET>-audit.md` with this structure:

```markdown
# <TICKET> Pre-Review Audit

## Scope
- Branch: <branch>
- Commits ahead of main: <N>
- LOC delta: +<X> -<Y>
- Features: <list>

## Wave 0 — Sync & Baseline
- [ ] Rebase/merge main (conflict recommendations presented to user, NOT auto-applied)
- [ ] Run full test suite — record baseline pass/fail counts
- [ ] Run linter — record baseline warning count

## Wave 1 — Ship Blockers (security, correctness)
- [ ] <finding 1> — characterization test → fix → verify
- [ ] <finding 2> — ...

## Wave 2 — Dead Code Deletion
- [ ] <unused export> — grep confirm zero callers → delete
- [ ] ...

## Wave 3 — Defensive Hardening
- [ ] <defensive fix 1> — ...

## Wave 4 — Test Coverage (modified files only)
- [ ] Add coverage for <file> touched in Wave 1

## Deferred (follow-up tickets)
- <structural improvement 1> — doesn't meet "not breaking functionality" bar
- ...
```

### Phase 2: Adversarial Discovery

Spawn 3 parallel Explore subagents with these personas:
1. **Security** — injection, auth bypass, ReDoS, input validation, URL hardening
2. **Architect** — dead code, duplication, shared-utility misuse, API contract drift
3. **Simplifier** — getters over querySelector, conditional rendering, CSS-solvable problems

Each produces a ranked findings list: `file:line | severity | one-line | reproduction`.

After all return, dedupe and write findings into the appropriate wave in the plan doc.

### Phase 3: Wave Execution

For each wave, execute sequentially:
1. Pick one finding
2. If untested code path → write characterization test FIRST
3. Apply smallest possible fix (coding.md problem-solving priority: DELETE > MODIFY > ADD)
4. Run tests — verify pass/fail delta vs baseline
5. Mark item done in plan doc
6. Commit with scoped message referencing the finding

**Pause at wave boundaries.** Present a status summary and wait for user approval before starting the next wave.

### Phase 4: Wave 0 Merge Conflict Handling

When syncing with main in Wave 0, conflict resolution is **interactive only**:
- Present each conflict with markers + a recommendation
- Explicitly wait for user approval before applying
- Never auto-resolve even "obvious" conflicts

### Phase 5: Deliverables

After Wave 4:
- [ ] Run full test suite — report pass/fail delta vs baseline
- [ ] Run linter — report warning delta
- [ ] Generate PR body via `mas-pr-creator` skill
- [ ] List deferred structural items as follow-up ticket candidates

## Anti-Patterns (from past audits)

- ❌ Whole-component coverage sprints — stay focused on modified files
- ❌ Bundling security fixes with refactors — separate commits
- ❌ Auto-resolving merge conflicts — always interactive
- ❌ Skipping characterization tests for "obvious" fixes
- ❌ Completing multiple waves before user checkpoint

## Related

- `.claude/rules/coding.md` — DELETE > MODIFY > ADD priority
- `mas-pr-creator` skill — PR template and creation
- `mental-model:mas-architect:plan` — load reviewer constraints before planning
