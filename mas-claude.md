## Superpowers Workflow

- **Plans** → save to `.claude/plans/TICKET.md` (relative to current working directory — lands in the worktree if working from one)
- **State** → save to `.claude/plans/TICKET-state.json` alongside the plan
- **Resume** → `/resume TICKET` reads state and continues from the right phase

### Pipelines (choose in `/start-ticket` Phase 6)

| Pipeline | Phases |
|----------|--------|
| `plan-only` | brainstorming → writing-plans |
| `plan-build` | plan-only + subagent-driven-development |
| `plan-build-test` | plan-build + nala/mas-test |
| `full` | plan-build-test + review-pr + mas-pr-creator |

**PR creation override:** When `finishing-a-development-branch` reaches Option 2 (Push and Create PR), skip its generic `gh pr create` and invoke `mas-pr-creator` instead — it uses the correct MAS template (Jira URL, Before/After test URLs, screenshots checklist).

**When to use `/challenge` vs `/review-pr`:**
- `/challenge` → architectural stress-test *before* building (adversary/architect/simplifier agents)
- `/review-pr` → convention + quality check *after* building

## Essential Rules (Always Active)

- Branch name = Jira ticket number (e.g., `MWPW-183848`)
- Run `npm run build` after changes in `web-components/`
- Add Spectrum WC imports to `/studio/src/swc.js`, not in component files
- Never use `::part` selectors — use CSS custom properties instead
- Use `?maslibs=local` for MAS components, `?milolibs=local` for Milo features
- No TypeScript. No inline styles. No inline comments unless asked.
- Avoid changes to `io/www/` and `io/www/src/fragment/` unless strictly necessary — these are critical paths and changes require strong justification; the rest of `io/` is fair game
- Use `fj chat "question"` for Adobe/AEM questions
- Use context7 MCP for Spectrum/Lit docs before implementing
- When adding new functions/constants intended to be tested, export them from the module *before* writing the test — skip this and the first test run will fail with a module resolution error (learned from DESTRUCTIVE_TOOLS incident)
- For MWPW-* branch audits, follow the wave structure (Wave 0 sync → Wave 1 ship blockers → Wave 2 dead code → Wave 3 hardening → Wave 4 coverage) via the `audit-wave` skill; update the plan doc as each item lands
- After any security fix (auth, URL validation, prompt injection, ReDoS), run the full relevant test suite and report the pass/fail delta vs baseline in your summary — never claim a security fix is done without that delta
- Never commit `docs/superpowers/` — these are local AI planning artifacts and are already in `.gitignore`
- Prefer concise text: PR descriptions, commit messages, Slack drafts, and summaries should be scannable. Cut preambles, redundant framing, and paragraph-length explanations of what a bullet already says. Each bullet carries one fact. If a section needs context, one sentence is usually enough.

## Conditional Context (Read BEFORE working in these areas)

- If writing or modifying code → read `.claude/rules/coding.md`
- If working with fragments or variations → read `.claude/rules/fragments.md`
- If creating PRs or commits → read `.claude/rules/git-workflow.md`
- If writing or running tests → read `.claude/rules/testing.md`
- If cleaning up after changes → read `.claude/rules/dead-code-cleanup.md`
- If planning, creating PRs, or reviewing code → read `.claude/rules/mental-models.md`
- For full coding principles with examples → `.specify/memory/constitution.md`

