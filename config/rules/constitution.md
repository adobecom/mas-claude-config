# MAS (Merch at Scale) Constitution

## Core Principles

### I. Code Quality & Simplicity (NON-NEGOTIABLE)

Changes MUST follow this priority order: **(1) delete code, (2) modify existing
code, (3) add new code** — adding is the last resort and MUST be justified.
Before any edit, the author MUST be able to state the root cause in one
sentence and confirm the change is the smallest possible fix.

Rules:

- A value queried from the DOM 2+ times in a component MUST be promoted to a
  getter; no repeated `querySelector` in render paths.
- The same logical pattern appearing 2+ times MUST be expressed as data +
  iteration, not duplicated branches.
- 4+ intermediate variables in a function is a signal to extract a helper.
- `nothing` MUST be used for conditional removal in Lit templates, not `''`.
- Shared utilities (`hydrate.js`, `merch-card.js`, root `/src/*.js`) MUST NOT
  be modified when a component-level getter, conditional render, or CSS-only
  solution would suffice. Justify any shared-file change in the PR.
- No TypeScript, no inline styles, no inline comments unless the user
  explicitly asks. Variable names MUST NOT start with `_`.

**Rationale**: MAS spans three repos and many consumers (CC, Express, DA).
Every line in a shared file multiplies blast radius; every duplicated branch
multiplies the locales/variants where a future bug can hide. Simplicity here
is a safety property, not an aesthetic one.

### II. Test Discipline (NON-NEGOTIABLE)

Every feature or bug fix that touches `web-components/src/`, `studio/src/`, or
`io/` MUST be accompanied by tests at the right layer, and those tests MUST
pass before merge.

Rules:

- **Unit (WTR)** for component logic, getters, hydration helpers, store
  reducers. Failing or skipped tests MUST be re-enabled or deleted with
  written justification — `.skip` / `xfail` requires a "remove after X"
  condition in code.
- **NALA (E2E)** for studio flows and rendered card behavior on consumer
  pages. Required ports (8080 AEM, 3000 proxy) MUST be running locally
  before claiming a NALA pass.
- After any security-relevant fix (auth, URL validation, prompt injection,
  ReDoS), the full relevant test suite MUST be run and the pass/fail delta
  vs baseline reported in the PR summary. No "security fix is done" claim
  without that delta.
- New functions or constants intended to be tested MUST be exported from the
  module **before** the first test run; missing exports cause module-
  resolution failures that hide real signal.
- Tests MUST NOT mock the database or fragment pipeline when an integration
  path is the unit of risk; mocking past a known-fragile boundary is grounds
  for rejection.

**Rationale**: MAS renders prices and CTAs that drive revenue. A regression
that escapes to prod costs more than the time to write a test. The unit /
NALA split exists because Studio bugs and consumer-page bugs surface at
different layers — both layers MUST be covered when changes can affect them.

### III. User Experience Consistency

User-facing surfaces (MAS Studio UI, rendered merch cards on consumer pages)
MUST behave consistently across locales, variants, and consumers.

Rules:

- One variation per locale per fragment. Creating a duplicate MUST fail with
  a clear error, never silently rename or "uniquify".
- Fragment field fallbacks MUST NOT use variant-specific defaults. Use the
  generic shape (`field.multiple ? [] : ''`) or configuration, never a
  hard-coded variant name.
- Variation detection MUST be based on `previewFragmentForEditor` data and
  `default-locale-id` from the editor context store. Custom or duplicated
  variation logic from `mas/io` is forbidden.
- Spectrum Web Components MUST be imported via `/studio/src/swc.js`, not
  per-component. Styling MUST use CSS custom properties — `::part` selectors
  are forbidden.
- Locale fallback bugs MUST be diagnosed using the documented chain
  (`debug-cross-project-locale` skill), distinguishing parent vs variation
  and default vs regional locale before any code change.

**Rationale**: MAS content reaches users in dozens of locales across multiple
consumer apps. Inconsistent behavior across locales or variants is the most
common class of user-visible bug; the rules above eliminate the slip-prone
distinctions that produce it.

### IV. Performance & Bundle Discipline

Changes that affect rendered cards or bundle output MUST preserve published
performance budgets and MUST keep build artifacts in sync with source.

Rules:

- After any change in `web-components/`, `npm run build` MUST be run and the
  resulting `dist/*.js` MUST be committed in the same change. A source-only
  change that ships without the rebuilt bundle is incomplete.
- After any change consumed by Milo, the Milo MAS feature bundle
  (`milo/libs/features/mas/` → `dist/mas.js` and `../../deps/mas/`) MUST be
  rebuilt and verified before claiming the change is visible downstream.
- Card render paths MUST NOT introduce `setTimeout` or `MutationObserver`
  unless explicitly required and justified in the PR.
- New code paths in render or hydrate MUST avoid synchronous network calls
  and MUST avoid forcing layout in loops.
- Performance-sensitive features MUST declare a measurable budget in the
  spec's Success Criteria (e.g., p95 render under N ms, bundle delta under
  N KB) and the PR MUST report the measured value against that budget.

**Rationale**: The `dist/` ↔ source decay trap is the single most common
"my change doesn't work in Milo" failure mode in this repo. The bundle
discipline rules above make that failure impossible to ship. Performance
budgets exist because card rendering is on the critical path for purchase
flows; degradation is a revenue event, not a polish concern.

### V. Investigation Before Implementation

For any debugging or non-trivial change, the author MUST state, **before
editing code**: (1) the hypothesis, (2) the evidence (file:line, log line, or
repro), (3) confidence level (low / medium / high), and (4) what would
falsify the hypothesis.

Rules:

- A failed first hypothesis MUST trigger a revert of assumptions and a
  re-examination, not a layered second fix on top of the first guess.
- For cross-repo symptoms (Odin / MAS Studio / MAS bundle / Milo block /
  consumer page), the responsible layer MUST be identified — with the
  confirming evidence — before any code edit. The five-layer hypothesis
  order in the `debug-merch-card-rendering` skill is the default sequence.
- Memory or skill recall about "file X does Y" MUST be verified against the
  current code before recommending an action based on it.
- Trivial fixes (typo, obvious off-by-one) are exempt from the four-point
  statement but MUST still pass the "one-sentence root cause" bar.

**Rationale**: This repo has burned hours on fixes layered atop unverified
guesses. Forcing the hypothesis + evidence + falsification statement is the
cheapest correctness tool available: it catches wrong-layer investigations
before they cost a wrong-layer patch.

## Additional Constraints

**Stack**: Vanilla JS + Lit web components. No TypeScript anywhere in the
repo. Spectrum Web Components for Studio UI. AEM headless (Odin) as content
source; MAS IO (Adobe IO Runtime) as the fragment/placeholder pipeline.

**Build outputs that MUST stay in sync with source**:

- `mas/web-components/dist/*.js` ← `mas/web-components/src/`
- `milo/libs/deps/mas/*` ← built from `milo/libs/features/mas/`

**Critical paths requiring extra justification**:

- `io/www/` and `io/www/src/fragment/` — fragment pipeline; changes require
  strong written justification in the PR description.
- `hydrate.js`, `merch-card.js`, root `/src/*.js` — shared utilities; see
  Principle I.

**Forbidden by default**:

- Inline styles, inline comments (unless explicitly requested), `_`-prefixed
  variables, `::part` CSS selectors, mocking the fragment pipeline, hard-
  coded variant defaults in fallbacks, committing `.superpowers/` or
  `.claude/plans/` artifacts.

## Development Workflow

**Branch naming**: Branch name = Jira ticket number (e.g., `MWPW-188517`).

**Pull requests** MUST include:

- Link to the Jira ticket: `Resolves https://jira.corp.adobe.com/browse/{BRANCH_NAME}`
- Short description of the change and its motivation.
- Before/After test URLs:
  `https://main--{repo}--{org}.aem.live/` and
  `https://{branch-lowercase}--{repo}--{org}.aem.live/`.
- Screenshots for any visual or UI change.
- Linter MUST be green on all modified files (eslint on modified files only).

**Review gates**:

- For changes in `io/www/`, `io/studio/`, `studio/src/`, or
  `web-components/src/`, the MAS architect reviewer pre-check is invoked
  automatically by the `mas-pr-creator` skill before PR creation; the
  resulting constraints MUST be addressed before opening the PR.
- `/review-pr` is run after building; `/challenge` is reserved for
  architectural stress-tests **before** building.
- A PR is mergeable only when: linter green, unit tests green, NALA tests
  green for affected flows, bundles rebuilt and committed, and PR body
  matches the template above.

**PR and commit prose**: Concise. Lead with one sentence stating what
changed and why. Bullets, one fact per bullet. No restatement of the task,
the bullet, or the commit message in prose. PR-body word limits are
enforced by harness hooks (small/medium/large/xl → 120/200/300/450 words).

## Governance

**Authority**: This constitution supersedes other practices and rules files
in `.claude/rules/` where they conflict. The rules files remain the
operational, conditional guidance ("if writing tests, read testing.md"); the
constitution states the non-negotiables.

**Amendments** require:

1. A PR to the `mas-claude-config` bundle that updates `config/rules/constitution.md`.
2. Review by the MAS architect reviewer for any principle change that
   affects ownership areas (`io/`, `studio/src/`, `web-components/src/`).
4. A migration note in the PR body if the change invalidates in-flight
   plans under `specs/` or `.claude/plans/`.

**Versioning policy** (semantic):

- **MAJOR**: Backward-incompatible removal or redefinition of a principle,
  or replacement of the governance model.
- **MINOR**: A new principle, a new mandatory section, or material
  expansion of an existing principle's rules.
- **PATCH**: Clarifications, wording, examples, or non-semantic edits that
  do not change what is required of contributors.

**Compliance review**: Every PR's review MUST verify compliance with each
Core Principle. Where a deviation is necessary, the PR MUST cite the
specific principle, justify the deviation, and propose a follow-up to
remove it. Unjustified deviations are grounds for rejection.

**Runtime guidance**: For day-to-day operational rules, see
`.claude/rules/` (`coding.md`, `testing.md`, `git-workflow.md`,
`fragments.md`, `dead-code-cleanup.md`, `mental-models.md`,
`claude-md-hygiene.md`). For full coding principles with worked examples,
see this file alongside the rules folder.

**Version**: 1.0.0 | **Ratified**: 2026-05-19 | **Last Amended**: 2026-05-19
