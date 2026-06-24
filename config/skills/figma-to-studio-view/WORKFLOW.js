export const meta = {
  name: 'figma-to-studio-view',
  description: 'Build a pixel-accurate M@S Studio Lit view from a region manifest via parallel component agents',
  whenToUse: 'Invoked by the figma-to-studio-view skill after the region manifest is approved. Fans out one agent per UI region, integrates into one wired component, then validates against Figma.',
  phases: [
    { title: 'Regions', detail: 'one agent per UI region → template + CSS fragments' },
    { title: 'Integrate', detail: 'assemble fragments into mas-<view>.js + css.js + 6-file wiring' },
    { title: 'Validate', detail: 'harness screenshot vs Figma, per-region diff' },
    { title: 'Repair', detail: 'cheap targeted CSS patch of off-spec regions, max 3 rounds', model: 'haiku' },
  ],
}

// args = the approved region manifest (see manifest-schema.md).
// Accept it as an object OR a JSON string (the runtime may hand large args back as a string).
let manifest = args
if (typeof manifest === 'string') {
  try { manifest = JSON.parse(manifest) } catch (e) { manifest = null }
}
if (!manifest || !manifest.view || !Array.isArray(manifest.regions)) {
  throw new Error('WORKFLOW requires args = the approved region manifest { view, viewLabel, columns, regions, ... } (object or JSON string). Got type: ' + typeof args)
}

// The AEM server serves the WORKTREE, so all files MUST be written there — not the
// main mas/ repo. A relative "studio/src/..." path is ambiguous (the integrator may
// resolve it against the eslint cwd = mas/), which 404s the harness. Always pass and
// use the ABSOLUTE worktree root. The SKILL must populate manifest.worktreeRoot with
// the active worktree's absolute path (it knows the cwd); the workflow refuses to guess.
const WORKTREE_ROOT = manifest.worktreeRoot
if (!WORKTREE_ROOT) {
  throw new Error('manifest.worktreeRoot is required (absolute path to the worktree the AEM server serves). The skill sets this from the current working directory before launching the workflow.')
}

const FRAGMENT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['templateFragment', 'cssBlock', 'swcImports'],
  properties: {
    templateFragment: { type: 'string', description: 'Lit html`...` snippet for this region only. Use the canonical tag/class shapes from component-registry.md.' },
    cssBlock: { type: 'string', description: 'CSS rules for this region only (no :host duplication unless this region owns it). Plain CSS string, no css`` wrapper.' },
    swcImports: { type: 'array', items: { type: 'string' }, description: "SWC import paths this region needs in swc.js, e.g. '@spectrum-web-components/action-button/sp-action-button.js'. [] if none." },
    notes: { type: 'string', description: 'Anything the integrator must know (slot wiring, a getter this region expects, etc.)' },
  },
}

const INTEGRATE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['componentPath', 'cssPath', 'wiredFiles', 'lintClean'],
  properties: {
    componentPath: { type: 'string' },
    cssPath: { type: 'string' },
    wiredFiles: { type: 'array', items: { type: 'string' }, description: 'The 6-file-contract files actually edited' },
    lintClean: { type: 'boolean' },
    summary: { type: 'string' },
  },
}

const VALIDATE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['converged', 'regionDiffs'],
  properties: {
    converged: { type: 'boolean', description: 'true when every region is within ~2px / correct color / correct typography' },
    screenshotPath: { type: 'string' },
    regionDiffs: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['region', 'withinSpec', 'diff'],
        properties: {
          region: { type: 'string' },
          withinSpec: { type: 'boolean' },
          diff: { type: 'string', description: 'e.g. "row height: figma=68, rendered=56" — empty when withinSpec' },
          kind: { type: 'string', enum: ['structural', 'visual'], description: 'structural = readable from code without a screenshot; visual = needs pixels' },
        },
      },
    },
  },
}

// These reference docs live alongside this script in the skill dir. The SKILL passes
// manifest.skillDir (the absolute path to this skill's directory — it knows where it's
// installed: ~/.claude/skills/... or <repo>/.claude/skills/...). Falls back to the repo
// skill path if omitted.
const SKILL_DIR = manifest.skillDir || `${WORKTREE_ROOT}/.claude/skills/figma-to-studio-view`
const REGISTRY = `${SKILL_DIR}/component-registry.md`
const TOKENMAP = `${SKILL_DIR}/token-mapping.md`

function regionPrompt(region) {
  return [
    `You implement ONE region of the M@S Studio "${manifest.viewLabel}" table view: the **${region.name}** region.`,
    `You return STRUCTURED DATA ONLY — a template fragment + CSS for this region. You do NOT write files; an integrator assembles all regions.`,
    ``,
    `Read first (mandatory): ${REGISTRY} and ${TOKENMAP}.`,
    `Use the canonical tag/class shapes the registry defines for "${region.name}". Do not invent alternatives.`,
    ``,
    `Region reuse verdict: ${region.reuseVerdict}${region.reuseCandidate ? ` (candidate: ${region.reuseCandidate})` : ''}.`,
    region.reuseVerdict === 'use' ? `Because the verdict is "use", your templateFragment wires the existing shared pattern; cssBlock should be minimal or empty.` : ``,
    region.reuseVerdict === 'extend' ? `Because the verdict is "extend", read ${region.reuseCandidate} and mirror its structure; only add what this view needs.` : ``,
    ``,
    `NO-ASSUME RULE (non-negotiable): reuse the STRUCTURE (tags, classes, the canonical shape), but NEVER assume the MEASUREMENTS. Every spacing, font size, color, and proportion comes from the Figma values below — even under a "use"/"extend" verdict. A reused pattern with the wrong pixel values is still wrong. If Figma and the canonical default disagree, Figma wins; encode the override in cssBlock.`,
    `Figma measurements for this region (px / labels / color map): ${JSON.stringify(region.measurements)}. Apply each to within ~2px / exact color.`,
    `Table-level constants: rowHeight=${manifest.rowHeight}px, cellPadding=${manifest.cellPadding}px, headerHeight=${manifest.headerHeight}px.`,
    region.name === 'table-header' || region.name === 'data-table'
      ? `Columns in DOM order: ${JSON.stringify(manifest.columns)}. Use each column's class + flexGrow token.`
      : ``,
    ``,
    `TOKEN RESOLUTION: map every Figma color/spacing/type value to a Spectrum CSS custom property via ${TOKENMAP}. If a value is NOT in that table, verify the correct token with context7 MCP (search "@spectrum-web-components" "<token>") before using it — do NOT guess a token name or hardcode a hex when a token exists.`,
    `Rules: no ::part selectors (CSS custom properties only); no inline styles; use \`nothing\` not ''; sort icon = sp-icon-order; divider = <hr class="section-divider"> not sp-divider; status-cell class goes on the inner div not the sp-table-cell host.`,
    `Return templateFragment (Lit html), cssBlock (plain CSS), swcImports (array).`,
  ].filter(Boolean).join('\n')
}

function integratePrompt(regionResults, round) {
  return [
    `Assemble a complete, production M@S Studio Lit view from these per-region fragments and wire it into Studio.`,
    `View: ${manifest.view} (label "${manifest.viewLabel}"). This is integration round ${round}.`,
    ``,
    `Region fragments (name → {templateFragment, cssBlock, swcImports, notes}):`,
    JSON.stringify(regionResults, null, 2),
    ``,
    `OWN THE SEAMS: each region agent only sized its own region; the GAP BETWEEN regions is yours. After assembling, set explicit inter-region spacing so regions don't sit flush (a classic bug: page-header divider has margin-bottom 0 and the filter-bar has margin-top 0 → they touch/overlap). From the Figma frame, the divider→search gap and header→table gap are real measured values (e.g. divider bottom-margin ~14px, filter-bar bottom-margin ~20px before the table). Verify no two adjacent regions have 0+0 margins at their boundary.`,
    ``,
    `CRITICAL — write ALL files under the ABSOLUTE worktree root ${WORKTREE_ROOT}. The AEM dev server serves THIS worktree; writing to the main mas/ repo instead 404s the harness and the view renders blank. Never use a bare relative "studio/src/..." path.`,
    `Produce TWO files at ${WORKTREE_ROOT}/studio/src/${manifest.view}/:`,
    `  - mas-${manifest.view}.js — LitElement importing styles, ReactiveController on Store.${manifest.view}.list, render() composing the region templateFragments in order: page-header, filter-bar, data-table(header+rows). Use \`get #privateGetter()\` for big fragments, repeat() with key fn for rows.`,
    `  - mas-${manifest.view}-css.js — exports an array: [tableHeaderBaseStyles, tableBodyBaseStyles, tableCellBaseStyles, tableColumnIconStyles, tableSelectedRowStyles, css\`<all region cssBlocks merged + :host + flex-grow token overrides from columns>\`].`,
    ``,
    `Then wire the 6-file contract (all files under ${WORKTREE_ROOT}/):`,
    `  1. studio/src/constants.js — add PAGE_NAMES.${manifest.view.toUpperCase().replace(/-/g, '_')}: '${manifest.view}'`,
    `  2. studio/src/store.js — add '${manifest.view}' to the pageValidator allowlist AND a Store.${manifest.view} = { list: { data: new ReactiveStore([]), loading: new ReactiveStore(false) } } namespace`,
    `  3. studio/src/studio.js — import the component + a getter guarded by PAGE_NAMES + render it`,
    `  4. studio/src/mas-side-nav.js — add the nav item with ?selected + @nav-click`,
    `  5. add every swcImports entry to studio/src/swc.js (dedup against existing)`,
    `Idempotent: if a wiring line already exists (re-run), do not duplicate it.`,
    ``,
    `Finally run eslint on the two new files (cwd ${WORKTREE_ROOT}): \`npx eslint studio/src/${manifest.view}/*.js\`. Report lintClean.`,
    `Return componentPath, cssPath, wiredFiles, lintClean, summary — with ABSOLUTE paths under ${WORKTREE_ROOT}.`,
  ].join('\n')
}

function validatePrompt() {
  const port = manifest.aemPort || 3044
  const harness = `http://localhost:${port}/studio/design-system/examples/${manifest.view}-harness.html`
  return [
    `Visually validate the ${manifest.viewLabel} Studio view against its Figma reference.`,
    `Figma reference: fileKey=${manifest.figmaFileKey}, nodeId=${manifest.figmaScreenNodeId} (use the Figma MCP get_screenshot).`,
    `Rendered: navigate Playwright MCP to ${harness} and screenshot the mas-${manifest.view} element.`,
    `(If the harness 404s, say so in a diff with region "harness" — the skill will create it.)`,
    ``,
    `Compare PER REGION. For each of these regions report withinSpec + a diff string: ${manifest.regions.map(r => r.name).join(', ')}.`,
    `Spec = within ~2px spacing, correct Spectrum color, matching font size/weight/case, matching column proportions.`,
    `Check especially: row height (=${manifest.rowHeight}px), cell padding (=${manifest.cellPadding}px), status dot colors, filter pill shape, divider visibility, column width ratios.`,
    `IMPORTANT diagnosis: if MULTIPLE SWC controls look unstyled (e.g. sp-search renders as a square black-bordered raw input, buttons look wrong, nothing has Spectrum chrome), that is almost always a HARNESS problem — the harness <sp-theme> must use system="spectrum-two" (NOT theme="spectrum") and load BOTH /studio/libs/spectrum.css and /studio/style.css. Report that as a single diff with region "harness" rather than flagging every control; the skill fixes the harness, not the component CSS.`,
    `converged = every region withinSpec. Return regionDiffs for all regions.`,
    `For EACH diff also set "kind": "structural" if it is readable from code/markup without a screenshot (extra/missing column, wrong column count, checkbox column that shouldn't exist, missing region, wrong element) or "visual" if it needs the pixels (spacing, color, radius, font). This lets the repair step skip a screenshot round for structural fixes.`,
  ].join('\n')
}

// Cheap targeted repair: edit ONLY the off-spec regions' CSS/markup in the existing files.
// No full re-integrate, no re-wiring. Runs on the cheap tier.
function patchPrompt(offSpec) {
  return [
    `Targeted fix for the M@S Studio "${manifest.viewLabel}" view at ${WORKTREE_ROOT}/studio/src/${manifest.view}/mas-${manifest.view}.js + mas-${manifest.view}-css.js (already exist and are wired — do NOT re-wire, do NOT touch other files). Use these ABSOLUTE paths; the AEM server serves this worktree.`,
    `Edit ONLY what these specific diffs call for; leave everything else untouched:`,
    ...offSpec.map((d) => `  - [${d.region}] ${d.diff}`),
    ``,
    `Apply the registry's known fixes where relevant (read ${REGISTRY} only if a fix is non-obvious): search pill → \`--spectrum-corner-radius-100: 16px\` scoped to the search class; table bottom corners → \`overflow: hidden\` on the sp-table; unstyled SWC → harness theme (report as region "harness", don't edit component); inter-region gap → explicit margin so adjacent regions aren't flush.`,
    `Make the minimal edit with the Edit tool, then run eslint (cwd ${WORKTREE_ROOT}): \`npx eslint studio/src/${manifest.view}/*.js\`. Return componentPath, cssPath, wiredFiles (the two edited files, absolute), lintClean, summary.`,
  ].join('\n')
}

// Model/effort tiers (token optimization):
//  - region agents: tiered by verdict. 'use'/'extend' = wiring an existing pattern → haiku.
//    'build' = a NOVEL component from a detailed spec → SONNET (Haiku ignored the div-track
//    spec and emitted an empty sp-progress-bar in benchmarking; build regions need the stronger model).
//  - patch (repair): targeted edit against a known fix → haiku.
//  - integrator: cross-file wiring/dedup → default model (inherits session), medium effort.
//  - validator: visual diffing + vision → default model, HIGH effort (do NOT downgrade — a weak
//    validator misses diffs or reports vague ones, causing MORE repair rounds = higher net cost).
//    Set manifest.opusValidator=true for high-stakes runs: Opus's sharper diagnosis can be
//    NET-CHEAPER (one precise root-cause beats several vague rounds). Try-and-measure.
const regionOpts = (region) =>
  region.reuseVerdict === 'build' ? { model: 'sonnet', effort: 'medium' } : { model: 'haiku', effort: 'low' }
const PATCH_OPTS = { model: 'haiku', effort: 'low' }
const INTEGRATE_OPTS = { effort: 'medium' }
const VALIDATE_OPTS = manifest.opusValidator ? { model: 'opus', effort: 'high' } : { effort: 'high' }

// ── Phase A: one agent per region (pipeline, no barrier) ───────────────────
phase('Regions')
const regionResults = await pipeline(
  manifest.regions,
  (region) =>
    agent(regionPrompt(region), {
      label: `region:${region.name}`,
      phase: 'Regions',
      schema: FRAGMENT_SCHEMA,
      ...regionOpts(region),
    }).then((out) => ({ name: region.name, ...(out || {}) })),
)
const goodRegions = regionResults.filter((r) => r && r.templateFragment)
log(`${goodRegions.length}/${manifest.regions.length} regions implemented`)
if (!goodRegions.length) throw new Error('No region produced a fragment; aborting before integrate')

// ── Phase B: integrate ONCE (full assemble + 6-file wiring) ────────────────
phase('Integrate')
let integration = await agent(integratePrompt(goodRegions, 1), {
  label: 'integrate', phase: 'Integrate', schema: INTEGRATE_SCHEMA, ...INTEGRATE_OPTS,
})
if (!integration) throw new Error('Integration returned nothing; aborting')

// ── Phase C+D: validate → cheap targeted patch (bounded loop) ──────────────
// Repairs PATCH the existing files (no full re-integrate). Structural diffs
// (manifest-readable: wrong column count, stray checkbox col) are fixed without
// a screenshot; a re-validation screenshot runs only when VISUAL diffs were touched.
let validation = null
const MAX_ROUNDS = 3

for (let round = 1; round <= MAX_ROUNDS; round++) {
  phase('Validate')
  validation = await agent(validatePrompt(), { label: `validate:round-${round}`, phase: 'Validate', schema: VALIDATE_SCHEMA, ...VALIDATE_OPTS })
  if (!validation) { log(`Validation round ${round} returned nothing`); break }
  if (validation.converged) { log(`Converged after round ${round}`); break }

  const offSpec = (validation.regionDiffs || []).filter((d) => d && !d.withinSpec)
  if (!offSpec.length || round === MAX_ROUNDS) {
    log(`Round ${round}: ${offSpec.length} off-spec, stopping (cap=${MAX_ROUNDS})`)
    break
  }
  const hasVisual = offSpec.some((d) => d.kind !== 'structural')
  log(`Round ${round}: patching ${offSpec.length} region(s) [${offSpec.map((d) => `${d.region}:${d.kind || 'visual'}`).join(', ')}]`)

  phase('Repair')
  const patch = await agent(patchPrompt(offSpec), { label: `patch:round-${round}`, phase: 'Repair', schema: INTEGRATE_SCHEMA, ...PATCH_OPTS })
  if (patch) integration = patch

  // Skip the next screenshot re-validation if every diff this round was structural
  // (code-readable) — those don't need pixel confirmation. Visual diffs do.
  if (!hasVisual) { log(`Round ${round}: all structural — skipping re-screenshot`); break }
}

return {
  view: manifest.view,
  component: integration && integration.componentPath,
  css: integration && integration.cssPath,
  wiredFiles: (integration && integration.wiredFiles) || [],
  lintClean: integration ? integration.lintClean : false,
  converged: validation ? validation.converged : false,
  remainingDiffs: validation ? (validation.regionDiffs || []).filter((d) => d && !d.withinSpec) : [],
  screenshot: validation && validation.screenshotPath,
}
