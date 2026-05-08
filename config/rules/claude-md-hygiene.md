# CLAUDE.md Hygiene

## Rule

CLAUDE.md is a **progressive disclosure** mechanism, not an "annotate everything" pattern. Per Anthropic's official guidance, files load lazily on-demand when Claude reads files in that directory.

**Where to put what:**

| Location | Purpose |
|---|---|
| `~/.claude/CLAUDE.md` | Personal preferences across all projects |
| `<project>/CLAUDE.md` | Project-wide guidance every session loads — keep small, point at rules files |
| `<project>/.claude/rules/<topic>.md` | Path-scoped rules referenced by the project CLAUDE.md ("if writing tests → read testing.md"). Load on-demand. |
| `<project>/<subdir>/CLAUDE.md` | **Only when needed** — when a subdirectory has genuinely non-obvious conventions Claude can't infer from the code |
| `<project>/CLAUDE.local.md` | Personal overrides, gitignored |

## Guardrails

1. **Keep each file under 200 lines.** Past that, Claude's adherence drops measurably (Anthropic docs).
2. **Specific over vague.** "Use getter pattern for templates" beats "follow conventions".
3. **Only things Claude can't infer.** Don't restate what `package.json` and the file tree already show.
4. **No conflicting rules across nested files.** Closer-to-cwd wins precedence; conflicts get arbitrary resolution.
5. **Use markdown structure** — headers, bullets, tables. Walls of prose lose attention.

## Anti-patterns

- ❌ One CLAUDE.md per folder "for documentation" → if it's documentation, put it in `README.md`, not `CLAUDE.md`
- ❌ Auto-generating CLAUDE.md content from session activity (e.g., claude-mem-style activity logs) → noise that crowds out real guidance
- ❌ Long preambles, vague rules, narrative prose → wastes context, lowers signal
- ❌ Restating obvious things ("This is a JavaScript file") → trains Claude to skim past the file
- ❌ Per-folder CLAUDE.md as a "TODO marker" or "this folder exists" stub → just delete the file

## How to decide if a subdirectory CLAUDE.md is worth keeping

Ask: would I write the same content in a `README.md` for a colleague who's never seen the codebase? If yes, it's documentation — keep it (or move it to `README.md`). If it's just "this folder contains tests" or "auto-generated activity log", delete it.

## In this repo

The project intentionally has a small number of substantive subdirectory CLAUDE.md files:

- `io/CLAUDE.md` — IO Runtime / fragment pipeline architecture
- `studio/CLAUDE.md` — Studio web app architecture
- `studio/src/aem/CLAUDE.md` — AEM client patterns
- `studio/src/fields/CLAUDE.md` — Field component patterns
- `studio/src/placeholders/CLAUDE.md` — Placeholders + ProseMirror integration
- `studio/src/reactivity/CLAUDE.md` — Store / ReactiveController patterns
- `studio/src/rte/CLAUDE.md` — Rich text editor architecture

Each documents real architecture that can't be inferred from filenames. Don't add more without a clear reason.

## Reference

- [How Claude remembers your project](https://code.claude.com/docs/en/memory.md)
- [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices.md)
