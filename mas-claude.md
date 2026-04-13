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
- Avoid changes to `io/` unless strictly necessary — this is npeltier's domain and changes require strong justification
- Use `fj chat "question"` for Adobe/AEM questions
- Use context7 MCP for Spectrum/Lit docs before implementing
- When adding new functions/constants intended to be tested, export them from the module *before* writing the test — skip this and the first test run will fail with a module resolution error (learned from DESTRUCTIVE_TOOLS incident)
- For MWPW-* branch audits, follow the wave structure (Wave 0 sync → Wave 1 ship blockers → Wave 2 dead code → Wave 3 hardening → Wave 4 coverage) via the `audit-wave` skill; update the plan doc as each item lands
- After any security fix (auth, URL validation, prompt injection, ReDoS), run the full relevant test suite and report the pass/fail delta vs baseline in your summary — never claim a security fix is done without that delta

## Conditional Context (Read BEFORE working in these areas)

- If writing or modifying code → read `.claude/rules/coding.md`
- If working with fragments or variations → read `.claude/rules/fragments.md`
- If creating PRs or commits → read `.claude/rules/git-workflow.md`
- If writing or running tests → read `.claude/rules/testing.md`
- If cleaning up after changes → read `.claude/rules/dead-code-cleanup.md`
- If planning, creating PRs, or reviewing code → read `.claude/rules/mental-models.md`
- For full coding principles with examples → `.specify/memory/constitution.md`

## graphify

This project has a graphify knowledge graph at graphify-out/.

### Context Navigation
1. ALWAYS query the knowledge graph first — read graphify-out/GRAPH_REPORT.md for god nodes and community structure
2. If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
3. Only read raw files if the user explicitly says so
4. After answering an architecture question that required reading raw files, save the answer using: `graphify save-result --question "Q" --answer "A" --type query --nodes NODE1 NODE2`
