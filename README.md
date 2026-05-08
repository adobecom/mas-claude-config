# MAS Claude Code Configuration

Team Claude Code setup for [Merch at Scale (MAS)](https://github.com/adobecom/mas) development.

## What This Is

This repo bundles the Claude Code configuration used by the MAS team — coding rules, skills, commands, agents, Python hooks, plugins, and MCP servers — into a one-command installer with an interactive wizard.

**What gets installed:**

| Component | Count | What it does |
|-----------|-------|--------------|
| Coding rules | 15 files | Conventions for Lit, Spectrum, fragments, testing, git workflow |
| Skills | 24 | `/start-ticket`, `/review-pr`, `/nala-writer`, `/nala-runner`, `/sync-with-main`, ... |
| Commands | 13 | `/audit-changes`, `/build-swc`, `/mas-lint-fix`, `/mas-test`, `/tickets`, ... |
| Agents | 15 | Specialized agents for fragment ops, NALA authoring, card development, ... |
| Hooks | 13 scripts | ESLint + Prettier on save, session tracking, compaction prep |
| Mental models | 1 | `mas-architect` — reviewer-style mental model for pre-submission self-review (`/mental-model:mas-architect:plan`, `:question`, `:self-improve`) |
| Plugins | Up to 10 | context7, superpowers, playwright, chrome-devtools, commit-commands, github, figma, challenge, ... |
| MCP servers | Up to 4 | corp-jira, GitHub, MAS fragments, FluffyJaws |
| Worktree manager | 1 script | Run multiple MAS branches simultaneously on different ports |

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
- **gh CLI** — [install guide](https://cli.github.com) + run `gh auth login`
- **uv** — the wizard will offer to install this if missing

## Partial Re-runs

```bash
./install.sh --config-only      # Update config files only (no plugin/MCP prompts)
./install.sh --plugins-only     # Re-configure plugins only
./install.sh --mcp-only         # Re-configure MCP servers only
./install.sh --non-interactive  # Silent install with all defaults
```

## MCP Servers

The wizard sets up the following MCP servers:

### corp-jira
- **Purpose:** Read/create/update Jira tickets from Claude
- **Used by:** `/start-ticket`, `/tickets`, `/jira-ticket-creator`
- **Setup:** Requires a [Jira Personal Access Token](https://jira.corp.adobe.com) — the wizard prompts for it
- **Source:** Cloned from `adobecom/remote-corp-jira-mcp`

### GitHub
- **Purpose:** Interact with GitHub PRs, issues, and repos
- **Used by:** `/review-pr`, `/mas-pr-creator`
- **Setup:** Can use your existing `gh auth` or a separate [GitHub PAT](https://github.com/settings/tokens)

### MAS Content Fragments
- **Purpose:** Search, create, and publish AEM content fragments
- **Used by:** `/test-mcp`, fragment operations, bulk publish
- **Setup:** Points to `mas/mas-mcp-server/`. The wizard builds it if needed.
- **Note:** Requires separate IMS authentication: `cd mas/mas-mcp-server && npm run auth`

### FluffyJaws
- **Purpose:** Search Adobe internal Slack, wiki, Jira, AEM docs, pipelines, and tenants
- **Used by:** `/start-ticket` context gathering, AEM/Adobe questions
- **Setup:** Requires the `fj` CLI (Adobe internal — get it from `go/fluffyjaws` or a teammate). The wizard runs `fj login` if not authenticated.
- **Note:** If `fj` isn't installed yet, the wizard will print instructions. Re-run `./install.sh --mcp-only` after installing.

> **NALA:** The nala skills (`/nala-writer`, `/nala-runner`, `/nala`) are included in the config bundle and work without any MCP server.

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
