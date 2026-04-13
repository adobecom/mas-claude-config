---
name: adversarial-swarm
description: Spawn 6 parallel adversarial sub-agents to audit a worktree or diff range from distinct personas (security, auth, ReDoS, dead-code, API contract, performance), then dedupe and rank findings via coordinator. Use for compressed multi-day audits. Activates on "adversarial swarm", "parallel audit", "swarm audit".
tags: [audit, parallel, adversarial, swarm, security]
triggers:
  - "adversarial swarm"
  - "parallel audit"
  - "swarm audit"
  - "adversarial-swarm"
  - "swarm this branch"
---

# Adversarial Audit Swarm

## Purpose

Compress multi-day wave audits into a single afternoon by running 6 specialized adversaries in parallel, then deduping findings. Complements `audit-wave` — use swarm for *discovery*, audit-wave for *execution*.

## When to Use

- Branch has 1000+ LOC delta vs main
- Time-boxed review window (need findings today)
- Multiple feature areas touched (swarm parallelizes well when diffs are independent)

**Don't use for:**
- Small PRs (overhead > benefit)
- Single-feature branches (one Explore agent suffices)
- Performance-critical audits needing profiler runs (use chrome-devtools-mcp directly)

## Execution

### Phase 1: Scope

- Diff range: default `main...HEAD`, override via user message
- Capture file list: `git diff <range> --name-only`
- Capture LOC delta: `git diff <range> --stat | tail -1`

### Phase 2: Dispatch Swarm

Use `superpowers:dispatching-parallel-agents` for the mechanics. Spawn **6 Explore subagents in one message** (single Agent tool block with 6 tool_use entries). Each gets:

| # | Persona | Focus |
|---|---------|-------|
| 1 | **Security/Injection** | XSS, SQLi, prompt injection, command injection, DOMParser misuse, unsafe innerHTML |
| 2 | **Auth/Authz** | Auth bypass, missing token validation, hardcoded secrets, dev-namespace leakage, IMS misuse |
| 3 | **ReDoS & Input Validation** | Catastrophic regex, unbounded input, missing length caps, URL parsing bugs |
| 4 | **Dead Code** | Unused exports, unreachable branches, orphaned helpers, commented-out blocks, deprecated configs coexisting with replacements |
| 5 | **API Contract Drift** | Changed response shapes, removed fields, silently widened types, breaking param reorder |
| 6 | **Performance/Memory** | Memory leaks, missing cleanup in disconnectedCallback, unbounded arrays, sync work in render, N+1 queries |

### Subagent Prompt Template

Each subagent gets this prompt (swap `<PERSONA>` and `<FOCUS>`):

```
You are a <PERSONA> adversary auditing a code diff range for a pre-review pass.

Scope: files in `<DIFF_RANGE>` — get the list with `git diff <DIFF_RANGE> --name-only`.

Focus exclusively on: <FOCUS>

For each finding, output one JSON object per line (JSONL):
{"file": "path/file.js", "line": 123, "severity": "critical|high|medium|low", "title": "one-line", "repro": "one-sentence how to reproduce or why it's broken", "fix_sketch": "one-sentence suggested fix"}

Rules:
- Only report issues you can cite with file:line
- Do NOT propose refactors outside your persona
- Rank severity honestly — critical = ship blocker, low = nice-to-have
- Skip findings already covered by existing tests (grep for the symbol in test/ dirs)
- Return under 30 findings; pick the highest-severity ones if you have more
```

### Phase 3: Coordinator Dedup

After all 6 return:
1. Parse each JSONL output into a list
2. Dedupe by `(file, line)` — if multiple personas flagged the same location, merge titles and keep highest severity
3. Sort by severity (critical → low), then by file
4. Write to `.claude/plans/<TICKET>-swarm-findings.md` with this structure:

```markdown
# <TICKET> Adversarial Swarm Findings

Generated: <timestamp>
Diff range: <range>
Personas: security, auth, redos, dead-code, api-contract, performance

## Critical (N)
- `file:line` — title (from: persona1, persona2) — repro → fix sketch

## High (N)
- ...

## Medium (N)
...

## Low (N)
...

## Deduped out
- `file:line` — merged under Critical #3 (auth + security agreed)
```

### Phase 4: Handoff to audit-wave

Present the summary to the user with total count per severity and ask:
> "Ready to feed these into `audit-wave` as Wave 1 (critical+high) and Wave 3 (medium+low)?"

If yes, invoke the `audit-wave` skill and populate the plan doc's Wave 1/3 sections from the findings file.

## Token Budget Notes

- 6 parallel Explore agents ≈ 6 × ~3-5k tokens of tool output
- Keep each agent's prompt under 500 tokens
- Cap per-agent findings at 30 to prevent context bloat
- Coordinator reads JSONL (cheap) not full agent transcripts

## Related

- `audit-wave` — execution framework for findings produced here
- `superpowers:dispatching-parallel-agents` — parallel agent mechanics
- `.claude/rules/coding.md` — problem-solving priority (DELETE > MODIFY > ADD)
