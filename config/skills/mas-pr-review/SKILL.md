---
name: mas-pr-review
description: Deep MAS-aware PR review for Milo or MAS pull requests using parallel domain agents (security, correctness, MAS contracts, coverage). Default to multi-agent fan-out; degrade to single-pass for narrow PRs. Verifies findings against current source before posting. Activates on "/mas-pr-review", "review PR", "review this PR", "second pass review", "another round of review", "audit PR", "deep PR review".
tags: [pr, review, multi-agent, mas, milo]
triggers:
  - "/mas-pr-review"
  - "review PR"
  - "review this PR"
  - "second pass review"
  - "another round of review"
  - "audit PR"
  - "deep PR review"
---

# MAS-aware PR Review

## Purpose

One skill for reviewing MAS or Milo PRs. Default behavior fans out four parallel domain agents (security, correctness/races, MAS-side integration, coverage/dead-code), dedupes and verifies their findings, then posts the synthesized review via `gh pr review` after explicit user confirmation.

Falls back to a single-agent pass for genuinely narrow PRs. Distinct from `pr-exec-review` (which produces Obsidian artifacts for stakeholders) and `adversarial-swarm` (which audits branches, not PRs).

## Inputs

- PR number or URL (required — `5915` or `https://github.com/adobecom/milo/pull/5915`)
- Repo (optional — inferred from URL; defaults to `adobecom/milo` if just a number is given in a Milo context, `adobecom/mas` in a MAS context)
- Optional flags:
  - `--quick` — force single-pass mode
  - `--deep` — force multi-agent mode regardless of size gate
  - `--no-post` — produce synthesis in chat, don't ask about posting

Parse the PR ref and flags from the user message; if PR is missing, ask.

## Phase 1 — Fetch

Run in parallel via Bash:
- `gh pr view <N> --repo <repo> --json title,author,body,additions,deletions,files,baseRefName,headRefName,labels,url`
- `gh pr diff <N> --repo <repo>` → write to `/tmp/pr<N>-diff.patch`
- `gh api repos/<repo>/pulls/<N>/reviews --jq '.[] | {user: .user.login, state: .state, body: .body[0:300]}'`

Capture the changed-files list and total LOC. **Do not read the full diff into your own context** — let agents read from the cached file path.

## Phase 2 — Pick the mode

**Default to multi-agent.** Use single-pass only when ALL of these are true:
- Total LOC under ~300 (excluding `dist/`, generated bundles, `.md`)
- Files in a single subsystem (e.g. only `libs/blocks/foo/`, or only `studio/src/fields/`)
- No file in MAS-bridge globs (see below)
- No new exported functions / public API surface

Override flags take precedence over the heuristic.

The asymmetry: picking single-pass when you should have gone multi-agent misses bugs. Picking multi-agent when single-pass would have sufficed costs ~400K tokens. Lean thorough.

## Phase 3 — Conditional gate: MAS-integration agent

Skip the MAS-integration agent if no file in the diff matches `libs/blocks/{merch,merch-card*,caas}/`, `libs/features/{personalization/preview*,mas}/`, `libs/deps/mas/`, or `mas/web-components/src/`. Saves ~100K tokens on Milo-only PRs that don't cross into MAS territory. This is the only conditional.

## Phase 4 — Fan out the agents

Dispatch all selected agents in a **single message with multiple `Agent` tool calls** (concurrent, `run_in_background: true`). Each agent gets the cached diff path, the PR URL, and live source paths. Each agent prompt is self-contained — they do not see this skill or session history.

Source paths to include in every agent prompt:
- Milo: `__ADOBE_DIR__/milo/libs/` (current main, may differ from PR branch)
- MAS web-components: `__MAS_DIR__/web-components/src/`
- MAS studio: `__MAS_DIR__/studio/src/`
- MAS IO: `__MAS_DIR__/io/`

**Rot resistance**: agent prompts must instruct verification against *current source*, not against any contracts enumerated in this skill. The skill encodes WHERE to look, not WHAT is there.

### Agent A — Security

```
You are auditing PR <PR_URL> for security only.

Scope: XSS / HTML injection in template-literal HTML construction; URL-open / navigation hijack; clipboard injection; prototype pollution in tree-walks / Object.assign patterns; preventDefault timing in capture-phase click handlers.

Diff: <DIFF_PATH>
Live source: __ADOBE_DIR__/milo/libs/ (Milo main) and __MAS_DIR__/ (MAS main).

Constraints: author-only / preview-only code paths are still real attack surface if URL params trigger them. Rate severity accordingly but don't dismiss. Skip style, perf, dead code, observer hygiene, test coverage — other agents cover those.

Output (under 400 words): findings as [SEV] file:line — issue, exploitability, fix. SEV ∈ {CRITICAL, HIGH, MEDIUM, LOW}. One-line verdict at the end.
```

### Agent B — Correctness + races

```
You are auditing PR <PR_URL> for correctness and race conditions only.

Scope: MutationObserver / event-listener hygiene (attach/detach symmetry, capture flag matched on add/remove); event ordering races; WeakMap lifecycle; debounced timer cleanup; idempotence under self-triggered observers; click delegation hit-box / preventDefault scoping including RTL; lifecycle gates (does the gate fire at the right phase — page load vs runtime toggle?).

Diff: <DIFF_PATH>
Live source: __ADOBE_DIR__/milo/libs/ and __MAS_DIR__/.

Critical caution: verify any race-condition claim against current source before including it. Walk through the actual code path (when does flag X get set? when is it read?). False-positive races are the #1 failure mode of correctness audits.

Skip security, MAS contracts, test coverage — other agents cover those.

Output (under 500 words): findings as [SEV] file:line — bug, repro/scenario, fix. SEV ∈ {HIGH, MEDIUM, LOW}. One-line verdict.
```

### Agent C — MAS-side integration

```
You are auditing PR <PR_URL> for MAS-side integration impact only.

Scope: cross-repo contracts that the diff touches. For each MAS-owned element, event, or data-* attribute the diff reads or stamps, verify the contract against *current* MAS source.

Diff: <DIFF_PATH>
MAS source: __MAS_DIR__/web-components/src/ (web components, constants, hydrate)
MAS IO: __MAS_DIR__/io/ (fragment pipeline, placeholder resolution)

Methodology: do NOT rely on memory or prior reviews for what MAS does. For every claim the PR makes about MAS (event payload shape, selector list, attribute name, lifecycle), grep current MAS source and confirm. If the PR's claim has drifted from current MAS source, flag it.

Skip security, races, test coverage.

Output (under 500 words): findings as [SEV] file:line — contract concern, what could break, mitigation in Milo. SEV ∈ {HIGH, MEDIUM, LOW}. Verdict on whether MAS contracts are respected.
```

### Agent D — Coverage + dead code

```
You are auditing PR <PR_URL> for test coverage gaps, TDD discipline, and dead code only.

Scope: untested branches in changed production files; **new exported functions/constants with zero tests**; test structure (one-behavior-per-test, AAA-in-spirit); unused imports/exports/constants introduced by the diff; orphan CSS classes / selectors with no JS assignment; test-quality smells (real timers in debounce tests, config singleton mutation, unkeyed snapshot-style assertions).

Diff: <DIFF_PATH>
Live source: __ADOBE_DIR__/milo/libs/ and __MAS_DIR__/.

Methodology: focus on **changed files only**. Don't survey the whole test landscape. For each new exported function/branch, check whether the test file added in the same PR exercises it.

TDD enforcement (applies to source in studio/src, web-components/src, io/ — NOT nala test-only or pure-CSS diffs):
- A new exported function/constant with **no test at all** is a **HIGH** (block-worthy) coverage finding — call it out explicitly with the symbol name. This is the one case that escalates above MEDIUM.
- Tests that assert multiple unrelated behaviors in one `it()`, or that lack a clear setup→action→assert flow, are **LOW** nits — note them, don't block. Do NOT flag absence of `// Arrange/Act/Assert` comments (the repo forbids inline comments).

Constraints: "alive" means used by production code OR by tests. Test-only usage counts as alive. Dead code findings must cite the symbol name and declaration file:line.

Skip security, correctness, MAS contracts.

Output (under 400 words): three sections — Coverage gaps (incl. untested new exports as HIGH), Test structure nits, Dead code. Each finding cited with file:line. SEV ∈ {HIGH, MEDIUM, LOW}. Verdict on adequacy for the size of the change.
```

## Phase 5 — Synthesize

When all agents return:

1. **Dedupe** — same file:line raised by multiple agents merges into one entry, citing both angles. Convergence is signal — call it out.

2. **Verify every MEDIUM+ finding** against current source before including. Read the cited file:line, check the surrounding context, confirm the claim. **Mandatory** — this is the false-positive filter. If verification fails, drop the finding or downgrade to LOW with note "unverified — author should check."

3. **Resolve severity disagreements** by taking the **producing agent's** severity (the one whose domain it's in), not the max. A coverage agent flagging an untested *branch* is LOW unless the path itself is exploitable; severity comes from the security agent's read of that path, not the coverage agent's anxiety. **Exception:** a new exported function with *zero* tests is the coverage agent's own HIGH (TDD block) — keep it HIGH; this is a deliberate policy, not anxiety.

4. **Rank** — split output into two artifacts:

   **(a) Internal analysis (chat only):** the structured view for the user to inspect — verified-clean / medium / low sections, file:line citations, methodology. This is for the user to vet your work, not for posting.

   **(b) GitHub comment (casual):** what actually gets posted. Short and human, written like a teammate dropping a note in a thread.

   **The value test — every sentence must earn its place.** A reviewer comment is read by the author (who already knows the root cause — they wrote the fix) and by a future human wanting the *verdict*, not a re-explanation. Before including a sentence, ask: **does this tell the author something they don't already know, or that the diff/tests/commit message don't already say?** If no, cut it.
   - **Do NOT** re-explain the root cause back to the author, restate what the code comments already say, or narrate the fix mechanism in detail. That's bloat — it serves no reader. (The author knows; a future reader gets it from the code, tests, and commit.)
   - **Do NOT** write verbose explanations "so an LLM can reference them later." Future LLMs retrieve from code, tests, and git blame — not from decayed PR threads. Durable explanation belongs in the **code comment, commit message, or test name**, not the review comment.
   - **DO** include only what adds value the author lacks: a defect they missed, a non-obvious cross-cutting constraint the diff can't express ("only safe because WCS runs after init"), a justification for a requested change, or a one-line signal that you checked the slip-prone part (parallelism preserved, guard reorder benign).
   - The deep root-cause analysis is for the **internal artifact (a)**, where it helps the user vet your review. Posting it is where its value drops to ~zero.

   - One-line verdict ("LGTM, nice fix" / "approving — looks good" / "few small things").
   - 2-4 sentences of plain-language reasoning about *why* the change works (or doesn't). No section headers.
   - Nits/follow-ups as a trailing bullet or short sentence — not a "## Low" block.
   - **No** "Verified clean" recap, no methodology, no agent-fanout language, no `file:line` audit tables. Citations are fine inline where they add value.
   - Aim for under ~10 lines of body. If it's longer, you're recapping work the author already did.
   - Match the PR's register: a tiny PR gets a tinier comment.

5. **Format the GitHub comment** — markdown, but sparingly. Inline `code` and the occasional bullet, not nested headers.

## Phase 6 — Confirm and post

Show **both** artifacts in chat — the internal analysis first (so the user can vet), then the casual GitHub comment that would actually post. Ask the user:
1. Approve / request changes / comment only?
2. Post the casual version, edit first, or rewrite?
3. (If `--no-post` was passed: skip — both artifacts are the final output.)

On user OK:
```
gh pr review <N> --repo <repo> {--approve|--request-changes|--comment} --body-file /tmp/pr<N>-review.md
```

Verify with `gh api repos/<repo>/pulls/<N>/reviews` after posting.

## Calibration notes — revisit after 3-5 real uses

- **Mode heuristic**: the "single-pass when ALL of: <300 LOC, single subsystem, no MAS-bridge, no new exports" rule is judgment-based. Track when you override it and why. If overriding constantly, tighten the rule.
- **Verification-as-instruction**: this skill instructs you to verify each medium finding against source. Track whether verification actually happens or gets skipped under time pressure. If skipped, consider making it more mechanical (specific grep commands per finding type).
