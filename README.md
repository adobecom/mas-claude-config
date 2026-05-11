# MAS Claude Code Configuration

Team Claude Code setup for [Merch at Scale (MAS)](https://github.com/adobecom/mas) development.

## What This Is

This repo bundles the Claude Code configuration used by the MAS team — coding rules, skills, commands, agents, Python hooks, plugins, and MCP servers — into a one-command installer with an interactive wizard.

**What gets installed in `mas/.claude/` (project-level):**

| Component | Count | What it does |
|-----------|-------|--------------|
| Coding rules | 15 files | Conventions for Lit, Spectrum, fragments, testing, git workflow |
| Skills | 24 | `/start-ticket`, `/review-pr`, `/nala-writer`, `/nala-runner`, `/sync-with-main`, ... |
| Commands | 13 | `/audit-changes`, `/build-swc`, `/mas-lint-fix`, `/mas-test`, `/tickets`, ... |
| Agents | 15 | Specialized agents for fragment ops, NALA authoring, card development, ... |
| Hooks | 16 scripts | ESLint + Prettier on save, **secret-leak prevention**, session tracking, compaction prep |
| Mental models | 1 | `mas-architect` — reviewer-style mental model for pre-submission self-review (`/mental-model:mas-architect:plan`, `:question`, `:self-improve`) |
| Plugins | Up to 10 | context7, superpowers, playwright, chrome-devtools, commit-commands, figma, challenge, ... |

**What gets installed in `~/.claude/` (user-level, all projects):**

| Component | What it does |
|-----------|--------------|
| Secret-leak hooks | Block writes containing PATs, AWS keys, PEM keys, etc. (override marker: `<!-- secret-ok: reason -->`) |
| `/scan-secrets` command | One-shot audit for existing credentials on disk |
| `claude-mas` shell helper | `claude-mas MWPW-XXX` opens Claude Code in that worktree (auto-creates if missing); `mas` cds to main repo |
| MCP servers | 3: corp-jira, adobe-wiki, fluffyjaws (see [MCP Servers](#mcp-servers) below) |

**Plus**: a `wt` worktree manager script in `adobe/worktrees/` for running multiple MAS branches simultaneously on different ports.

## Quick Start

```bash
# Clone this repo as a sibling to your mas/ checkout
cd ~/Web/adobe  # or wherever your mas/ directory lives
git clone https://github.com/adobecom/mas-claude-config.git

# Run the interactive wizard
cd mas-claude-config
./install.sh
```

The wizard will:
1. Detect your MAS repo path
2. Copy all config files into `mas/.claude/`
3. Walk you through plugin selection
4. Configure each MCP server (with explanations)
5. Set up the worktree manager

## Prerequisites

- **node v20+** and **npm**
- **Claude Code CLI** — [install guide](https://claude.ai/code)
- **gh CLI** — required (no GitHub MCP). [install guide](https://cli.github.com) + run `gh auth login`
- **uv** — required (used by the auto-format + secret-leak hooks). `brew install uv` if missing — the wizard will check.

## Partial Re-runs

```bash
./install.sh --config-only      # Update config files only (no plugin/MCP prompts)
./install.sh --plugins-only     # Re-configure plugins only
./install.sh --mcp-only         # Re-configure MCP servers only
./install.sh --non-interactive  # Silent install with all defaults
```

## MCP Servers

The wizard sets up three MCP servers. GitHub is intentionally **not** an MCP — we use the `gh` CLI directly (one less PAT to manage, no `npm install -g`).

### corp-jira
- **Purpose:** Read/create/update Jira tickets from Claude
- **Used by:** `/start-ticket`, `/tickets`, `/jira-ticket-creator`
- **Source:** `Adobe-AIFoundations/adobe-mcp-servers` → `src/corp-jira` (cloned to `adobe/adobe-mcp-servers/`)
- **Upstream docs:** [src/corp-jira/README.md](https://github.com/Adobe-AIFoundations/adobe-mcp-servers/tree/main/src/corp-jira) — full troubleshooting, transport modes, tool reference

**Getting your PAT** (the wizard prompts for it):

1. Open https://jira.corp.adobe.com/secure/ViewProfile.jspa
2. Click **Personal Access Tokens** in the left sidebar
3. Create a new token (any name; default scopes are fine)
4. Copy the token — Jira shows it once

**Verify your PAT works** before pasting it into the wizard:

```bash
curl -H "Authorization: Bearer YOUR_PAT_TOKEN" \
     -H "Accept: application/json" \
     "https://jira.corp.adobe.com/rest/api/3/myself"
```

Expected: a JSON body with your user info. A 302 or 401 means the PAT is invalid, expired, or lacking permissions.

**CAPTCHA challenge:** If the response includes `X-Authentication-Denied-Reason: CAPTCHA_CHALLENGE`, your Jira account is locked. Open https://developer-paas.pe.corp.adobe.com and unlock — access restores immediately.

**Manual reconfigure** (if the wizard skipped it or you need to update the PAT):

```bash
claude mcp remove corp-jira     # if a stale entry exists
./install.sh --mcp-only         # re-runs only the MCP setup
```

### adobe-wiki
- **Purpose:** Read, search, update, and comment on Adobe Wiki pages (wiki.corp.adobe.com)
- **Useful for:** runbooks, internal docs, PR-context lookup
- **Source:** Same monorepo (`Adobe-AIFoundations/adobe-mcp-servers` → `src/adobe-wiki`)
- **Upstream docs:** [src/adobe-wiki/README.md](https://github.com/Adobe-AIFoundations/adobe-mcp-servers/tree/main/src/adobe-wiki) — tool reference, PlantUML/asset support, Confluence storage format

**Getting your PAT**:
1. Open https://wiki.corp.adobe.com → click your avatar → **Settings** → **Personal access tokens**
2. Create a token (any name; default scopes are fine), copy it
3. Paste into the wizard when prompted

### FluffyJaws
- **Purpose:** Search Adobe internal Slack, wiki, Jira, AEM docs, pipelines, and tenants
- **Used by:** `/start-ticket` context gathering, AEM/Adobe questions
- **Setup:** Requires the `fj` CLI (Adobe internal — get it from `go/fluffyjaws` or a teammate). The wizard runs `fj login` if not authenticated.

> **GitHub:** Use `gh pr create`, `gh pr edit`, `gh api`, etc. directly. The wizard checks that `gh` is installed and authed; instructs `gh auth login` if not.

> **MAS content fragments:** The `mas-mcp-server` source isn't on `origin/main` yet (lives on the unmerged MWPW-183572 branch). When it lands on main, this section will return.

> **NALA:** The nala skills (`/nala-writer`, `/nala-runner`, `/nala`) are included in the config bundle and work without any MCP server.

## Shell Helpers

The wizard installs two shell functions into `~/.zshrc` and `~/.bashrc` (inside a managed block — safe to re-run, idempotent):

```bash
claude-mas MWPW-123456   # opens Claude Code in that worktree (creates via 'wt new' if missing)
claude-mas main          # opens Claude Code in main mas repo
claude-mas               # same as 'claude-mas main'
mas                      # cd into main mas repo
```

After `./install.sh` finishes, `source ~/.zshrc` (or restart your shell) once to start using them.

## Secret-Leak Prevention

Three PreToolUse hooks installed at user level:

- **`secret_leak_gate.py`** — blocks Write/Edit/MultiEdit/Bash if it detects credentials (GitHub/Figma/Slack PATs, AWS keys, AEM/Jira tokens, PEM keys, db URIs with auth, high-entropy strings in `.claude/` paths). Override: `<!-- secret-ok: <reason ≥3 chars> -->`.
- **`pr_secret_scan.py`** — runs on `gh pr create`/`gh pr edit` and scans the diff vs `origin/main` + the PR body.
- **`/scan-secrets`** slash command — one-shot audit of existing credentials sitting in `~/.claude/`, `mas/.claude/`, and `mas-claude-config/`. Outputs redacted findings.

Existing credentials surfaced by `/scan-secrets` should be **rotated** (not just deleted from the file) — if they leaked to a backup, the rotation is what protects you.

## Mental Models

The bundle ships a `mas-architect` mental model — a YAML knowledge base capturing review patterns from MAS architectural reviewers (npeltier, yesil, honstar, afmicka). It's an **on-demand tool**, not an ambient rule. Reach for it when you want a concrete check; don't wait for it to fire automatically.

### When to use

- **Before submitting a PR**: `/mental-model:mas-architect:plan "<what you're about to implement>"` — surfaces red-flags the model knows reviewers will catch (scope creep, duplicated utilities, dead code, naming concerns)
- **When checking a specific concern**: `/mental-model:mas-architect:question "Would the architect flag a method named renderSearchControls()?"`
- **Through the challenge plugin**: `/challenge <PR_URL>` spawns a `mas-architect` agent alongside Architect/Adversary/Simplifier for a multi-lens stress test

### How it stays accurate

The model is grounded in real PR review data — every red_flag, value, and vocabulary entry cites the PR and quote it came from. To keep it current:

```bash
# Refresh patterns from the configured architect_reviewers list
/mental-model:mas-architect:self-improve
```

Self-improve queries the GitHub API for each reviewer in `expertise.yaml`'s `architect_reviewers` field, harvests new patterns from their recent comments, and appends evidence with per-quote provenance. **Recommended cadence: monthly.** Quarterly, also review the `architect_reviewers` list against who's actually reviewing PRs — when reviewers rotate, the list should rotate with them.

### When NOT to use

- Pure CSS or test-only changes (low architectural-feedback density)
- Changes that don't touch `io/`, `studio/src/`, or `web-components/src/`
- Quick hotfixes where consultation cost > benefit

## Updating

When the config evolves, pull the latest and re-run:

```bash
cd mas-claude-config
git pull
./install.sh --config-only   # Re-apply config without re-configuring MCPs/plugins
```

Your existing `.env`, `settings.local.json`, and MCP tokens are never overwritten.

### Migration notes (for upgraders)

When `./install.sh` finishes, it surfaces drift from previous wizard versions:

- **Old Jira MCP clone** at `adobe/remote-corp-jira-mcp/` — the Jira MCP moved to `Adobe-AIFoundations/adobe-mcp-servers`. The wizard prints a warning and suggests `rm -rf` to clean up the old clone. Your Jira PAT is preserved in `~/.claude/mcp.json` — only the entry-point path is updated.
- **Stale `mas` MCP entry** in `~/.claude/mcp.json` pointing to a now-missing `mas-mcp-server/` path — the wizard prints a warning and suggests `claude mcp remove mas`. (The MAS MCP was removed from the wizard pending `mas-mcp-server` landing on `origin/main`.)
- **GitHub MCP** — if you had it from a previous version, it's left untouched. The wizard no longer prompts for it. Remove it manually with `claude mcp remove github` if you want.

All migration notes are advisory — the wizard never auto-deletes anything from your machine.

## Customizing

**Personal coding preferences:** Add them to `~/.claude/CLAUDE.md` (global, not in the repo).

**Local permission overrides:** Use `mas/.claude/settings.local.json` — this file is gitignored and never overwritten by the installer.

**CLAUDE.md guidance:** Keep CLAUDE.md files small and only where they document non-obvious context. The repo's root + `io/` + `studio/` + a few `studio/src/<area>/` files are intentionally the only ones — see `config/rules/claude-md-hygiene.md` for the full pattern. Don't add one per folder; use `.claude/rules/<topic>.md` for path-scoped guidance instead.

**Worktree workflow:** After installing, see `adobe/CLAUDE.md` for the full worktree documentation.

## Contributing

If you improve a skill, rule, or hook and want to share it with the team:

1. Make your changes in your live `mas/.claude/` directory (as normal)
2. In this repo, run `./export.sh` to pull the updated files in (sanitized)
3. Review the diff, commit, and push

```bash
cd mas-claude-config
./export.sh
git diff                  # review what changed
git add -A && git commit -m "chore: update config bundle"
git push
```

## What's NOT Included

| Item | Why |
|------|-----|
| `settings.local.json` | Contains personal permission overrides and may have credentials |
| `~/.claude/mcp.json` | Contains personal API tokens |
| `.claude/data/` | Session-specific data (conversation logs, model cache) |
| `.claude/plans/` | Ephemeral per-ticket work |
| Skills/agents archives | Deprecated content |
