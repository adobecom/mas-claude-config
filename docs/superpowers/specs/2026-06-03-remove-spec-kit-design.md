# Remove Spec Kit from the MAS Claude config bundle

**Date:** 2026-06-03
**Branch:** `remove-spec-kit`

## Problem

The May-11+ bundle work added the Spec Kit workflow (14 `speckit-*` skills + a
`.specify/` scaffold). The team is not using it — last real spec authored
2026-05-19, two stale since March. It is dead registry weight and introduces a
third planning system alongside Superpowers (`brainstorming → writing-plans`)
and the native MAS flow (`start-ticket → audit-wave`), creating
"which-one-do-I-use" ambiguity.

## Constraint discovered

Spec Kit left one load-bearing artifact: `mas/.specify/memory/constitution.md`,
referenced by `mas-claude.md` and `config/rules/coding.md` as the canonical
coding-principles doc. The bundle never shipped a copy — the file existed only
in the local, gitignored working copy. So the constitution had to be rescued
into version control **before** any deletion.

## Changes

### Canonical repo (`mas-claude-config`)

1. Rescued `constitution.md` → `config/rules/constitution.md` (stripped the
   Spec-Kit "Sync Impact Report" header and rewrote the amendment process to
   reference the bundle path; all coding principles preserved verbatim).
2. Deleted 14 `config/skills/speckit-*` dirs.
3. Repointed references off `.specify/`:
   - `config/rules/coding.md` → `.claude/rules/constitution.md`
   - `mas-claude.md` → `.claude/rules/constitution.md` (+ removed `<!-- SPECKIT -->` stub)
4. Removed stray `/speckit.*` mentions in `config/rules/mental-models.md` and
   `config/skills/start-ticket/skill.md` (Phase 6 now hands off to the
   Superpowers pipelines the team actually uses).
5. README skill count 29 → 15.

`install.sh` needed no edits — it `rsync`s the whole `config/` tree, so the new
rules file installs and the deleted skills disappear automatically.

### Local working copy (`mas/`)

Deleted installed `mas/.claude/skills/speckit-*`, stale `mas/specs/MWPW-*`, and
the `mas/.specify/` scaffold (all gitignored scratch; reconstructable via
reinstall).

## Verification

- `grep -riE "speckit|\.specify"` across all shipped files → clean.
- README skill count matches `ls config/skills/*/` → 15 = 15.
- Both constitution references resolve to a file `install.sh` installs.
- Net diff: +238 / −2338 across 20 files.

## Risk

Low. The only irreplaceable artifact (constitution) was committed first.
Everything else is dead skills or gitignored scratch. Rollback = revert the PR.
