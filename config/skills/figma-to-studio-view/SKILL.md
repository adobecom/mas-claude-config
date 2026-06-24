---
name: figma-to-studio-view
description: Convert a Figma frame into a pixel-accurate, production Lit view fully wired into M@S Studio. Decomposes the design into named UI regions, decides reuse-vs-build against existing Studio patterns, fans out parallel component agents, integrates into one wired component, and validates against Figma. Use for any new Studio list/table view from Figma.
---

# Figma → Studio View

Turn a Figma Studio screen into a production Lit view, wired into Studio (routing, Store, side-nav, shared styles) and **pixel-validated** against the design. Built to be shared across the team so everyone produces consistent UI from Figma the same way.

## Triggers
- "build this figma design", "implement this Studio view from figma"
- a Figma URL for a Studio page + "new table view" / "new list view"
- "convert figma to studio"

## How it works — two tiers

The work splits into an **interactive orchestrator** (this skill, runs in the main loop, talks to you) and an **autonomous builder** (`WORKFLOW.js`, runs in the background, fans out agents). The seam exists because a background workflow can't ask questions mid-run — so all human-in-the-loop decisions happen here, before the fan-out.

```
SKILL (interactive)                          WORKFLOW.js (autonomous, parallel)
 1. drill Figma → real screen frame
 2. decomposer agent  → region manifest
 3. reuse-matcher agent → verdict/region
 4. ASK you: view name + approve reuse  ───▶  A. one agent per region → {template, css}
 5. launch workflow(manifest) ────────────▶   B. integrator → mas-<view>.js + 6-file wiring
 6. report screenshot diff   ◀────────────    C. validator → per-region Figma diff
 7. offer to register new patterns            (repair loop B→C, off-spec regions only, ≤5×)
```

Supporting docs in this skill dir:
- `component-registry.md` — **the consistency engine.** Canonical Studio patterns + reuse verdicts. Read/extend it.
- `manifest-schema.md` — the handoff JSON that flows through every step.
- `token-mapping.md` — Figma Spectrum values → CSS custom properties.
- `WORKFLOW.js` — the autonomous multi-agent script.

Related skill: **`mas-studio-view`** is the passive reference card for the canonical Studio view-wiring rules (the 6-file contract, Lit component structure, table-style imports, column tokens). This workflow embeds those rules so it's self-contained — but consult `mas-studio-view` when wiring a view by hand or when you need the authoritative house conventions.

> **Scale to the ask.** For a quick one-off or when multi-agent orchestration isn't wanted, skip the workflow and follow the **Manual path** at the bottom — the same phases, done inline by one agent. The workflow is for full views where parallel per-region accuracy pays off. Only launch the workflow when the user has opted into multi-agent orchestration.

### Cost model (token tiering)

The workflow tiers agents by cognitive demand — most tokens go to the *validator*, not the region agents:

| Agent | Model / effort | Why |
|---|---|---|
| region + patch (×6-8) | **haiku / low** | mechanical templating against the registry spec; highest count, lowest judgment |
| integrator (×1) | default / medium | cross-file wiring + dedup; must not break the 6-file contract |
| validator (×1-3) | default / **high** | visual diffing + vision; **never downgrade** — a weak validator misses or vagues diffs → more repair rounds → higher net cost |

Loop efficiency: integrate runs **once**; repairs **patch** the existing files (no full re-integrate); a re-screenshot runs only when a *visual* diff was touched (structural diffs like "stray checkbox column" are fixed from code without a screenshot). Round cap = 3. Empirically this took a ~2.5M-token first run down toward the ~0.65M range a clean run already hit — the savings come from fewer expensive validator/integrate passes, not just the cheaper model.

---

## Step 1 — Drill to the real Figma screen

Parse the URL: `figma.com/design/:fileKey/:name?node-id=:nodeId` (convert `-`→`:` in nodeId).

A section/page node returns a zoomed-out composite. **Always drill:**
1. `get_metadata` on the nodeId (if it exceeds context, dispatch a subagent to `jq` the saved file for children with `width >= 1200`).
2. Pick the child frame named like the screen (e.g. "Collections – Table View", width 1280).
3. Use that child id for `get_screenshot` (save it — the validation reference) and **`get_metadata`** (the pixel source — see Step 2).

---

## Step 2 — Decompose (agent → manifest)

Dispatch one agent to build the **region manifest** (schema: `manifest-schema.md`). It reads the exact pixel `x/y/width/height` per region and column and fills:
- `columns[]` — class, label, `figmaWidth`, `flexGrow = figmaWidth/totalUsableWidth×10`, contentType, hasSortIcon
- `regions[]` — canonical names from the registry (`page-header`, `filter-bar`, `data-table`, `table-header`, `status-cell`, `action-menu`, `expand-row`, `empty-state`, plus any view-specific region like `progress-cell`), each with `figmaNodeId` + `measurements`
- `rowHeight`, `cellPadding` (text `x` within a cell), `headerHeight` from the frame

**Measurements come from `get_metadata`, NOT `get_design_context`.** `get_metadata` returns the frame tree with real `x/y/width/height` attributes per node — that is the pixel source. `get_design_context` often returns framework *code* (React/Spectrum JSX) with no measurements at all; use it only for code-shape hints, never for spacing. If `get_metadata` exceeds context, save it and have the agent `grep`/parse the saved file (it's XML-like: `<frame id name x y width height>`). Column widths = each header cell's `width`; `totalUsableWidth` = their sum; cell padding = a cell text node's `x`.

This explicit, measured manifest is the mechanism that catches small details — the same discipline that makes the merch-card skill rigorous: extract to a structured table, don't eyeball.

**No-Assume rule.** Reuse the *structure* of a pattern; never assume its *measurements*. Even a region the matcher marks `use`/`extend` must apply the exact Figma spacing/color/typography — a reused shape with default pixel values is still wrong. Figma wins over any canonical default; encode the difference as an override.

**Breakpoints.** Studio is a desktop app, so a single ~1280px frame is usually the only state. If the Figma file has tablet/mobile frames for the view, decompose and validate each — a wide table reflows.

---

## Step 3 — Match reuse (agent → verdict per region)

Dispatch one agent that reads `component-registry.md` + the cited Studio source and sets, per region, `reuseVerdict` ∈ {`use`, `extend`, `build`} + `reuseCandidate`. It applies the registry's decision tree (e.g. ≥50% columns match `mas-select-items-table` → extend it; expandable rows → extend `mas-collections`).

State the headline before asking: *"This view shares ~X% with `mas-select-items-table`; status-cell + action-menu reuse as-is; page-header + filter-bar build."*

---

## Step 4 — Confirm with the user (interactive)

Use `AskUserQuestion` to lock the two things only the user decides:
1. **View name + label** (default derived from the Figma frame name) — drives `PAGE_NAMES`, file dir, side-nav.
2. **Reuse decisions** — present the matcher's verdicts; let them override any `extend`/`build`.

Persist the approved manifest to `.claude/plans/<TICKET>-manifest.json` (gitignored).

---

## Step 5 — Launch the workflow

Call `Workflow` with `{ scriptPath: "<this skill dir>/WORKFLOW.js", args: <approved manifest> }`. Also create the harness first (see "Component test harness") so the validator has something to screenshot.

**Before launching, populate these manifest fields with absolute paths from the current environment** (the workflow refuses to guess them, so it's portable across machines):
- `worktreeRoot` — **required.** Absolute path to the worktree the AEM server serves (your current working directory, e.g. `…/worktrees/<BRANCH>`). All generated files are written here.
- `skillDir` — absolute path to *this* skill's directory (where `component-registry.md` / `token-mapping.md` live). Defaults to `<worktreeRoot>/.claude/skills/figma-to-studio-view` if omitted.
- `aemPort` — the worktree's AEM port (e.g. 3044).

The workflow runs in the background and notifies on completion. It returns `{ component, css, wiredFiles, lintClean, converged, remainingDiffs, screenshot }`.

---

## Step 6 — Report & close the loop

- Relay the screenshot diff. If `converged`, say so plainly; if `remainingDiffs`, list them as `region: figma=X, rendered=Y`.
- If a diff needs a bundle rebuild (e.g. a new `swc.js` icon), call it out — `studio/libs/swc.js` is built; source edits need `npm run build` in `studio/`.
- Write the test file (`studio/test/<view>/`) — TDD rule: new exported symbols need a test before merge.

---

## Step 7 — Keep the registry current (consistency)

If the build produced a genuinely new reusable region, **add it to `component-registry.md`** with its path + verdict + exact tag/class shape, and flip any superseded "build per view" entry to "use"/"extend". This is what makes the next colleague's build consistent with yours.

---

# Reference — what the agents must follow

These are the rules the region/integrator agents inherit. They double as the **Manual path** checklist.

## The 6-file wiring contract

Every new view requires these changes (the integrator does them; verify on review):

| # | File | Change |
|---|---|---|
| 1 | `studio/src/constants.js` | `PAGE_NAMES.<VIEW>: '<view>'` |
| 2 | `studio/src/store.js` — **pageValidator allowlist** | add `PAGE_NAMES.<VIEW>` (missing → silent redirect to Welcome, no error) |
| 3 | `studio/src/store.js` — **Store namespace** | `<view>: { list: { data: new ReactiveStore([]), loading: new ReactiveStore(false) } }` |
| 4 | `studio/src/studio.js` | import + `get <view>()` getter guarded by `PAGE_NAMES` + `${this.<view>}` in render |
| 5 | `studio/src/mas-side-nav.js` | `<mas-side-nav-item>` with `?selected` + `@nav-click` |
| 6 | `studio/src/swc.js` | every SWC import the view needs (dedup) |

`router.js` needs no change — `navigateToPage` sets `Store.page` generically.

## Component rules

- `get #privateGetter()` for template fragments — not `renderSomething()` public methods.
- `repeat()` with a key fn for lists — never `.map()`.
- Status dots: `.status-dot.green`/`.blue` from `tableCellBaseStyles`; per-view color (e.g. amber Modified) → add `.status-dot.yellow` AND re-declare `width/height/border-radius` on `.status-dot` (shared rule nests them and can drop).
- `status-cell` class on the **inner div**, not the `sp-table-cell` host.
- Sort icon: `sp-icon-order` (registered). `sp-icon-sort-down` is NOT bundled — add to `swc.js` + rebuild to use it.
- Divider: `<hr class="section-divider">`, NOT `sp-divider` (empty shadow DOM in harness).
- Filter pills: `sp-action-button size="m"` + `sp-icon-chevron-down slot="icon-right"`, radius via `--spectrum-actionbutton-border-radius: 16px`. Not `sp-picker`.
- No `::part`; no inline styles; `nothing` not `''`.

## Shared style imports (never reinvent)

```js
import {
    tableHeaderBaseStyles, tableBodyBaseStyles, tableCellBaseStyles,
    tableColumnIconStyles, tableSelectedRowStyles, loadingContainerFlexStyles,
} from '../common/styles/table-styles.css.js';
import { skeletonStyles } from '../common/skeleton-styles.css.js';
```
`class="item-table"` on `sp-table` gets the card header (gray-50 bg + 12px top radius) for free — no manual border needed.

## Visual validation checklist (the validator applies this per region)

**Structure** → all columns present + order; page header + CTA; filter rows; expand column if Figma shows it.
**Layout** → column width ratios; row height (read from Figma, often 68px); filter bar height.
**Spacing** → cell padding (often 20px); pill gap (12px); header→table margin; dot→label gap.
**Typography** → header label size/weight/case; cell size/weight; secondary (path) 12px gray-700; status label case.
**Colors** → published `.green`; modified `.blue` (or per-view amber `.yellow`); pill outlined; header bg; selected row.
**Icons** → sort icon non-empty; chevron size `s`; action `sp-icon-more`.

**Convergence:** every region within ~2px, correct color, matching typography/proportions. Max 5 repair rounds; then surface remaining diffs as `region: figma=X, rendered=Y`.

---

## Component test harness

`studio/design-system/examples/<view>-harness.html` — loads the real Lit component with mock data, no Studio auth. The validator screenshots this.

**Three non-obvious requirements** (each costs hours if missed):

0. **`<sp-theme system="spectrum-two" color="light" scale="medium">`** — use `system="spectrum-two"`, NOT `theme="spectrum"`. The wrong attribute loads the wrong token set and SWC components render **unstyled** — e.g. `sp-search` falls back to a raw square `<input>` with a black border instead of a rounded Spectrum field. Match `studio.html` exactly. Also load BOTH stylesheets: `/studio/libs/spectrum.css` AND `/studio/style.css` (the scaffold loads both).
1. **`<body class="spectrum spectrum--medium spectrum--light">`** — Spectrum color tokens (`--spectrum-green-700`, `--spectrum-yellow-700`, …) are scoped to those class selectors in `spectrum.css`. Without them every `var(--spectrum-*)` resolves transparent → status dots invisible, colors gone.
2. **importmap must include every bare specifier from `studio.html`** or the module graph fails with "Failed to resolve module specifier". Include `fragment-client` + all `prosemirror-*` (reached transitively via Store → preview-fragment-store):

```html
<script type="importmap">{"imports":{
  "lit":"/web-components/dist/lit-all.min.js",
  "lit/directives/unsafe-html.js":"/web-components/dist/lit-all.min.js",
  "lit/directives/style-map.js":"/web-components/dist/lit-all.min.js",
  "lit/directives/class-map.js":"/web-components/dist/lit-all.min.js",
  "lit/directives/repeat.js":"/web-components/dist/lit-all.min.js",
  "lit/directives/until.js":"/web-components/dist/lit-all.min.js",
  "lit/directives/keyed.js":"/web-components/dist/lit-all.min.js",
  "fragment-client":"/studio/libs/fragment-client.js",
  "prosemirror-state":"/studio/libs/prosemirror.js",
  "prosemirror-model":"/studio/libs/prosemirror.js",
  "prosemirror-view":"/studio/libs/prosemirror.js",
  "prosemirror-keymap":"/studio/libs/prosemirror.js",
  "prosemirror-schema-basic":"/studio/libs/prosemirror.js",
  "prosemirror-commands":"/studio/libs/prosemirror.js",
  "prosemirror-schema-list":"/studio/libs/prosemirror.js",
  "prosemirror-history":"/studio/libs/prosemirror.js"
}}</script>
<script src="/studio/libs/swc.js" type="module"></script>
```

**Set mock data BEFORE the component imports** (constructor reads Store): import Store, `Store.<view>.list.data.set([...])`, then `await import('/studio/src/<view>/mas-<view>.js')`. Use the exact Figma row data so the diff is direct.

Serve via AEM (`aem up --port <N>`) — not `python3 -m http.server` (Studio source needs AEM module resolution).

---

## Manual path (no workflow)

Same phases, inline, one agent. Use when multi-agent isn't wanted or for a small view:
1. Drill Figma → screenshot + `get_design_context`. Fill the measurement table (rowHeight, cellPadding, per-column widths, status colors).
2. Apply the reuse decision tree from `component-registry.md`; reuse shared style modules.
3. Write `mas-<view>.js` + `-css.js` following the component rules above; wire the 6-file contract.
4. Build the harness; screenshot vs Figma; fix per the validation checklist until ≤2px.
5. Write the test; run eslint; update the registry if you made something reusable.

## HTML prototype (exploration only)

Only when the user explicitly wants to compare against Figma before real code. `studio/design-system/examples/<view>.html` from `scaffold.html`; wrap table in `<div id="content">`; exact short classes; `sp-icon-order`.
