---
name: pr-exec-review
description: Fetch a PR via gh CLI and produce three artifacts — technical critical review, casual-tone reviewer comments, and non-technical executive summary — then save all three to the Obsidian vault under "PR Reviews/". Use when asked for an executive review or PR brief. Activates on "executive review", "exec review PR", "casual review", "pr brief".
tags: [pr, review, obsidian, executive, github]
triggers:
  - "executive review"
  - "exec review"
  - "pr brief"
  - "casual review"
  - "pr-exec-review"
  - "executive summary of PR"
---

# PR Executive Review

## Purpose

Produce three complementary PR reviews in one pass — technical critique (for your own decisions), casual draft (for posting to GitHub), and executive summary (for non-technical stakeholders) — and file all three to Obsidian for later reference.

## Inputs

- PR number or URL (required)
- Repository (optional — default infer from URL or current git remote)

Parse the PR ref from the user message; if missing, ask which PR.

## Execution

### Phase 1: Fetch PR Context

Run in parallel:
```
gh pr view <PR> --repo <repo> --json title,author,body,additions,deletions,files,baseRefName,headRefName,url
gh pr diff <PR> --repo <repo>
gh pr view <PR> --repo <repo> --comments
```

Capture: title, author, body, LOC delta, files touched, diff, existing comments.

### Phase 2: Artifact 1 — Technical Critical Review

Produce a file-by-file critique:
- Findings with `file:line` references
- Severity tags: 🔴 critical / 🟡 suggestion / 🟢 nit
- Check against `.claude/rules/coding.md` principles (DELETE > MODIFY > ADD, getter pattern, no inline styles, no `::part`)
- Load npeltier reviewer values via `mental-model:reviewer-npeltier:question` if files touch `io/`, `studio/src/`, or `web-components/src/`
- Be honest and specific — this is the "what I actually think" version

Format:
```markdown
## Technical Review — <PR title>

### 🔴 Critical
- `file.js:42` — <issue>. Suggested fix: <one line>.

### 🟡 Suggestions
- `file.js:88` — ...

### 🟢 Nits
- ...

### Overall
<1-paragraph verdict: approve / request changes / comment>
```

### Phase 3: Artifact 2 — Casual Reviewer Comments

Rewrite Artifact 1's findings as individual GitHub comments in a collaborative, casual tone:
- No corporate hedging ("it might be nice to consider perhaps...")
- No robot-speak — read like a senior engineer on Slack
- One comment per critical/suggestion finding, grouped by file
- Start with the observation, end with a concrete ask or question
- Skip nits unless they cluster meaningfully

Format:
```markdown
## Casual Reviewer Comments — ready to paste into GitHub

### `path/to/file.js:42`
> <casual 1-3 sentence comment>

### `path/to/other.js:15`
> <casual 1-3 sentence comment>
```

### Phase 4: Artifact 3 — Executive Summary

Non-technical, 5-bullet digest:
- What does this PR change (business language, no jargon)?
- Why does it matter (user/customer impact)?
- Risk level (low/medium/high) with one-sentence rationale
- Is it ready to ship?
- Open questions for stakeholders (if any)

Format:
```markdown
## Executive Summary — <PR title>

**What:** <1 sentence>
**Why it matters:** <1 sentence>
**Risk:** <low|medium|high> — <reason>
**Ready to ship:** <yes|no|not yet> — <reason>
**Open questions:** <bullet list or "none">
```

### Phase 5: Save to Obsidian

Use the Obsidian MCP (`mcp-obsidian`). Target path:
```
PR Reviews/<repo>-<PR_NUMBER>.md
```

Single file containing all three artifacts in order, with a header:
```markdown
# <repo>#<PR> — <title>

Author: @<author>
URL: <pr url>
Reviewed: <YYYY-MM-DD HH:MM>
Files: <N> | +<additions> -<deletions>

---

<Artifact 1: Technical Review>

---

<Artifact 2: Casual Comments>

---

<Artifact 3: Executive Summary>
```

### Phase 6: Report

Return to the user:
- The executive summary inline (fits in a single response)
- Path to the saved Obsidian note
- Offer: "Want me to post the casual comments to the PR?" (requires explicit yes — never auto-post)

## Obsidian MCP Reliability

The Obsidian MCP occasionally fails on first call. On error:
1. Retry once
2. If still failing, save the artifact locally to `.claude/pr-reviews/<repo>-<PR>.md` and report the fallback path
3. Do not block on Obsidian

## Anti-Patterns

- ❌ Auto-posting comments to the PR without explicit user approval
- ❌ Softening the technical review to match the casual tone — keep the honest version separate
- ❌ Skipping the executive summary for "obvious" PRs — the summary is the whole point
- ❌ Burying critical findings under nits

## Related

- `review-pr` — deeper MAS-specific convention enforcement review
- `mental-model:reviewer-npeltier:question` — reviewer values lookup
- `.claude/rules/git-workflow.md` — PR conventions
