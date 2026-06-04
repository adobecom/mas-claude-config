# PM spec-authoring path in mas-claude-config

**Date:** 2026-06-04
**Branch:** `pm-spec-path`

## Goal

Give product managers — onboarded into the full project with a `mas/` checkout
and Claude Code — a lean, code-grounded spec-authoring toolset. PMs bring
product judgment; the codebase brings ground truth. The output is a dev-ready
MWPW ticket.

## Context / decisions

- Earlier exploration of a Claude Desktop plugin was abandoned: Desktop PMs
  can't run stdio MCP (corp-jira) or Scout (local-checkout-only), and can't run
  the `.sh` installer. Onboarding PMs into the project instead removes every one
  of those constraints — they get the same environment as devs.
- Code-as-source-of-truth is the point: with a local checkout, Scout semantic
  search grounds specs in real files/symbols, not guesses.

## Install mode: `./install.sh --pm`

New MODE alongside `full` / `config` / `plugins` / `mcp`. Installs:

- PM skills (2 new) + existing `jira-ticket-creator` + `start-ticket`
- Read/research MCP: corp-jira, Scout, GitHub, Odin (all usable — PM has checkout)
- Root + subdir CLAUDE.md (specs ground in real architecture docs)
- User-level guardrail hooks (secret-leak, concise-output) — harmless, kept

Skips dev-only tooling: eslint/prettier PostToolUse hooks, build, nala,
worktrees, PR babysitter, shell helpers.

## New skills (2 — filing is reused, not rebuilt)

1. **`pm-spec-author`** — interviews the PM (problem, users, acceptance
   criteria, scope), grounds the spec via Scout (code) + Odin (content) + the
   CLAUDE.md architecture docs, drafts a structured MWPW spec: Problem → Users →
   Proposed change → Acceptance criteria → Affected files/fragments → Open
   questions. Hands the spec body to `jira-ticket-creator` to file.
2. **`pm-prior-art`** — searches Jira (corp-jira MCP) + GitHub for duplicates
   and dependencies before authoring.

Reuse: filing goes through the existing `jira-ticket-creator` (already handles
MWPW required fields via corp-jira). No new ticket-filing code — DRY.

## What it deliberately skips (YAGNI)

No new ticket-filer, no Desktop/plugin path, no PM-specific MCP servers (the 4
existing ones cover it).

## Verification

- `./install.sh --pm` installs PM skills + 4 read MCPs, skips dev hooks/build/
  nala/worktrees/babysitter.
- `install.sh --help` / usage lists the new mode.
- bash syntax OK; drift-check clean.

## Risk

Low. New mode is additive; existing modes untouched. The only genuinely new
surface is 2 skills + a mode branch in install.sh.
