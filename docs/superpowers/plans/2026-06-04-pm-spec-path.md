# PM Spec-Authoring Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `./install.sh --pm` mode that installs a lean, code-grounded spec-authoring toolset for product managers — 2 new skills plus the existing jira/start-ticket skills and read-only MCP — while skipping dev-only tooling.

**Architecture:** Two new skill markdown files under `config/skills/`, and a new `pm` MODE branch in `install.sh` that runs the existing `phase_config` + `phase_mcp` (PM answers the per-server prompts) but skips `phase_pr_babysitter`, `phase_plugins`, `phase_worktrees`, and the dev hook install. Filing reuses the existing `jira-ticket-creator` skill — no new ticket code.

**Tech Stack:** Bash (install.sh), Markdown skills (SKILL.md frontmatter + body), existing MCP servers (corp-jira, Scout, GitHub, Odin).

---

### Task 1: Add the `pm-prior-art` skill

**Files:**
- Create: `config/skills/pm-prior-art/SKILL.md`

- [ ] **Step 1: Write the skill file**

```markdown
---
name: pm-prior-art
description: Search existing MWPW Jira tickets and GitHub issues/PRs for duplicate or related work before authoring a new spec. Use when a PM is about to propose a feature and should check what already exists. Activates on "is there already a ticket", "prior art", "check for duplicates", "has this been done", "related work", "before I spec".
tags: [pm, jira, prior-art, duplicates, mwpw]
---

# PM Prior-Art Search

## Purpose
Before a PM authors a spec, surface existing MWPW tickets and GitHub work so they
don't duplicate effort and can link dependencies. Pairs with `pm-spec-author`.

## When to use
- A PM describes a feature idea and you don't yet know if it exists.
- Always run this BEFORE `pm-spec-author` drafts a spec.

## Steps

1. **Search Jira (MWPW project)** via `mcp__corp-jira__search_jira_issues`:
   - JQL: `project = MWPW AND text ~ "<key terms>" ORDER BY updated DESC`
   - Report open/in-progress matches with key, summary, status, assignee.

2. **Search GitHub** for the same terms:
   - `gh issue list --repo adobecom/mas --search "<terms>" --state all --limit 20`
   - `gh pr list --repo adobecom/mas --search "<terms>" --state all --limit 20`

3. **Summarize for the PM:**
   - Exact duplicates → recommend extending the existing ticket, not a new one.
   - Related work → note as dependencies/links for the new spec.
   - Nothing found → say so explicitly and hand off to `pm-spec-author`.

## Output
A short list: `MWPW-XXXX (status) — summary` and `gh#NN — title`, grouped into
"duplicate", "related", or "none". Never invent ticket numbers — only report
results the MCP/gh actually returned.
```

- [ ] **Step 2: Verify the frontmatter parses**

Run: `awk '/^name:/{print} /^description:/{print substr($0,1,60)}' config/skills/pm-prior-art/SKILL.md`
Expected: prints the `name:` and a truncated `description:` line (confirms valid frontmatter).

- [ ] **Step 3: Commit**

```bash
git add config/skills/pm-prior-art/SKILL.md
git commit -m "feat(pm): add pm-prior-art skill"
```

---

### Task 2: Add the `pm-spec-author` skill

**Files:**
- Create: `config/skills/pm-spec-author/SKILL.md`

- [ ] **Step 1: Write the skill file**

```markdown
---
name: pm-spec-author
description: Interview a product manager and draft a code-grounded, dev-ready MWPW spec — reading real code (Scout), content (Odin), and architecture (CLAUDE.md) so the spec references actual files, variants, fragments, and locales. Use when a PM wants to write a spec, propose a feature, or turn an idea into a ticket. Activates on "write a spec", "spec this out", "I want a feature", "draft a ticket for", "turn this into a spec".
tags: [pm, spec, authoring, mwpw, scout, odin]
---

# PM Spec Author

## Purpose
Turn a PM's feature idea into a developer-ready MWPW spec grounded in the real
codebase and content — not guesses. The PM brings product judgment; this skill
brings codebase/content truth.

## Preconditions
- Run `pm-prior-art` first. If a duplicate exists, stop and recommend extending it.

## Steps

1. **Interview the PM** (one question at a time): problem, target users,
   acceptance criteria, scope boundaries, target locales.

2. **Ground in real code** using Scout (local checkout):
   - `mcp__scout__search` / `mcp__scout__explain_symbol` to find the real
     components/variants involved (e.g. confirm which merch-card variants exist
     before claiming a new one is needed).
   - Read the relevant `CLAUDE.md` architecture docs for the affected layer.

3. **Ground in real content** using Odin where the spec touches fragments:
   - `mcp__odin-prod__search-aem-content-fragments` to confirm which
     fragments/variants/locales exist — surface content gaps (e.g. "de_DE
     fragment missing") as dependencies.

4. **Draft the spec** in this structure:
   - **Problem** — one paragraph, user-facing.
   - **Target users** — who and in what context.
   - **Proposed change** — what changes, referencing REAL files/variants/fragments.
   - **Acceptance criteria** — testable, PM-authored.
   - **Affected areas** — actual file paths (from Scout) and fragments (from Odin).
   - **Open questions / dependencies** — incl. any content gaps found.

5. **Hand off to filing:** offer to file via the `jira-ticket-creator` skill
   (which handles MWPW required fields). Pass the drafted spec as the description.

## Discipline
- Never claim a file/variant/fragment exists without confirming it via Scout/Odin.
- If Scout returns nothing for a claimed component, say so — don't fabricate paths.
- Keep the spec scannable: one fact per bullet, no preambles.
```

- [ ] **Step 2: Verify the frontmatter parses**

Run: `awk '/^name:/{print} /^description:/{print substr($0,1,60)}' config/skills/pm-spec-author/SKILL.md`
Expected: prints the `name:` and a truncated `description:` line.

- [ ] **Step 3: Commit**

```bash
git add config/skills/pm-spec-author/SKILL.md
git commit -m "feat(pm): add pm-spec-author skill"
```

---

### Task 3: Add the `pm` MODE to install.sh argument parsing

**Files:**
- Modify: `install.sh` (usage comment ~line 5-13, MODE parsing ~line 191)

- [ ] **Step 1: Add `--pm` to the usage comment**

Modify the usage block (after the `--mcp-only` line, currently line 9):

```bash
#   ./install.sh --mcp-only         # MCP servers only
#   ./install.sh --pm               # PM spec-authoring setup (skips dev tooling)
```

- [ ] **Step 2: Add `--pm` to the argument case**

Modify the `case "$1"` block (after the `--mcp-only)` line, currently line 193):

```bash
    --mcp-only)        MODE="mcp"; shift ;;
    --pm)              MODE="pm"; shift ;;
```

- [ ] **Step 3: Verify bash still parses**

Run: `bash -n install.sh && echo OK`
Expected: `OK`

- [ ] **Step 4: Verify the flag is recognized (no "Unknown option")**

Run: `bash -c 'set -- --pm; MODE=full; while [[ $# -gt 0 ]]; do case "$1" in --pm) MODE=pm; shift;; *) echo "BAD: $1"; exit 1;; esac; done; echo "MODE=$MODE"'`
Expected: `MODE=pm`

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat(pm): recognize --pm install mode"
```

---

### Task 4: Add the `phase_pm_intro` banner phase

**Files:**
- Modify: `install.sh` (add function near other phase_* definitions, before the MODE dispatch `case` ~line 1330)

- [ ] **Step 1: Add the intro phase function**

Insert before the `# ─── Main ───` / MODE dispatch section (just before `case "$MODE" in` at ~line 1330):

```bash
# ─── Phase: PM intro ─────────────────────────────────────────────────────────

phase_pm_intro() {
  section "PM Spec-Authoring Setup"
  echo "  Installs the spec-authoring toolset for product managers:"
  echo "  • Skills: pm-spec-author, pm-prior-art, jira-ticket-creator, start-ticket"
  echo "  • Read/research MCP: corp-jira, Scout, GitHub, Odin (answer the prompts)"
  echo "  • Architecture docs (CLAUDE.md) so specs ground in real code"
  echo ""
  echo "  Skips dev-only tooling: build, nala, worktrees, eslint hooks, PR babysitter."
  echo ""
}
```

- [ ] **Step 2: Verify bash parses**

Run: `bash -n install.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "feat(pm): add PM intro banner phase"
```

---

### Task 5: Wire the `pm` MODE into the dispatch

**Files:**
- Modify: `install.sh` (MODE dispatch `case`, after the `mcp)` branch ~line 1359-1361)

- [ ] **Step 1: Add the `pm)` branch**

Modify the dispatch `case` — insert after the `mcp)` branch closes (after its `;;`, before `esac`):

```bash
  mcp)
    phase_mcp
    ;;
  pm)
    print_banner
    phase_pm_intro
    phase_prerequisites
    phase_config
    INSTALLED_CONFIG=true
    phase_user_skills
    phase_secret_hooks
    phase_mcp
    info "PM setup installed. Try: /pm-prior-art or /pm-spec-author in Claude Code."
    ;;
esac
```

Note: `phase_config` rsyncs the whole `config/` tree, so the two new PM skills
install automatically — no per-skill wiring needed. The dev-only phases
(`phase_pr_babysitter`, `phase_plugins`, `phase_worktrees`, `phase_shell_helpers`)
are intentionally omitted. `phase_secret_hooks` is kept (guardrail, harmless for PMs).

- [ ] **Step 2: Verify bash parses**

Run: `bash -n install.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Verify the dispatch reaches the pm branch**

Run: `grep -A12 '^  pm)' install.sh`
Expected: shows the `pm)` branch with `phase_pm_intro`, `phase_config`, `phase_mcp`, and NO `phase_pr_babysitter`/`phase_worktrees`/`phase_plugins`.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat(pm): wire --pm mode dispatch (config + read MCP, skip dev tooling)"
```

---

### Task 6: Document the PM path in README + update skill count

**Files:**
- Modify: `README.md` (install-options section + skills count row)

- [ ] **Step 1: Find the current skill count and options text**

Run: `grep -nE "\| Skills \| [0-9]+|--config-only|--mcp-only" README.md`
Expected: shows the Skills count row (currently 15) and the install-options block.

- [ ] **Step 2: Bump the skills count from 15 to 17**

Modify the Skills row (replace `15` with `17` — the two new PM skills):

```
| Skills | 17 | `/start-ticket`, `/mas-pr-review`, `/mas-pr-creator`, `/pm-spec-author`, `/pm-prior-art`, ... |
```

- [ ] **Step 3: Document the `--pm` option**

In the install-options code block (the one listing `--config-only`, `--plugins-only`, `--mcp-only`), add:

```bash
./install.sh --pm               # PM spec-authoring setup (skills + read MCP, no dev tooling)
```

- [ ] **Step 4: Verify the count matches reality**

Run: `echo "README: $(grep -oE '\| Skills \| [0-9]+' README.md)"; echo "actual: $(ls -d config/skills/*/ | wc -l | tr -d ' ')"`
Expected: README says 17; actual dir count is 17.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs(pm): document --pm mode and bump skill count to 17"
```

---

### Task 7: Final verification

- [ ] **Step 1: Full bash syntax check**

Run: `bash -n install.sh && echo OK`
Expected: `OK`

- [ ] **Step 2: drift-check is clean for the new skills**

Run: `bash drift-check.sh 2>&1 | tail -8`
Expected: no "backup only / live only" drift for `pm-spec-author` or `pm-prior-art` beyond the expected not-yet-installed-locally note (the bundle is the source of truth; that note is benign).

- [ ] **Step 3: Confirm the two skills are discoverable**

Run: `for s in pm-spec-author pm-prior-art; do test -f config/skills/$s/SKILL.md && echo "✓ $s" || echo "✗ $s MISSING"; done`
Expected: `✓ pm-spec-author` and `✓ pm-prior-art`.

- [ ] **Step 4: Confirm --pm skips dev tooling in dispatch**

Run: `awk '/^  pm\)/,/;;/' install.sh | grep -E "babysitter|worktrees|plugins|shell_helpers" && echo "LEAK: dev phase present" || echo "✓ no dev phases in pm mode"`
Expected: `✓ no dev phases in pm mode`

---

## Notes for the implementer

- Skills install via `phase_config`'s `rsync -a config/ → .claude/`; you never
  register skills individually.
- `phase_mcp` already prompts per-server with sensible defaults — the PM just
  answers yes/no. No code change to MCP setup is needed for `--pm`.
- Reuse, don't rebuild: filing goes through the existing `jira-ticket-creator`.
  Do NOT add a new ticket-creation skill.
