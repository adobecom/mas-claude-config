# Studio UI Component Registry

The **consistency engine** for `figma-to-studio-view`. Every build consults this before implementing a region, so colleagues reuse canonical patterns instead of reinventing them. When you build a genuinely new reusable region, **add it here** — that is how the team converges.

Each entry answers one question for the reuse-matcher: *for this Figma region, is there already a canonical implementation, and do I reuse / extend / build?*

> Reuse verdicts: **use** (drop in as-is), **extend** (parameterize an existing component), **build** (no canonical exists — implement, then register it here).

---

## Shared style modules (always reuse — never reinvent)

All in `studio/src/common/styles/table-styles.css.js`. Import the named exports; never copy their CSS.

| Export | Provides | Notes |
|---|---|---|
| `tableHeaderBaseStyles` | `.item-table` header: `--mod-table-header-background-color: gray-50`, `12px` top corner radius on first/last head cell | Gives the "card" header look for free — **use `class="item-table"` on `sp-table` and you do not need a manual border** |
| `tableBodyBaseStyles` | `.item-table sp-table-body { border: none }` | — |
| `tableCellBaseStyles` | `sp-table-cell { display:flex; align-items:center }` + the **`.status-cell` / `.status-dot`** pattern (see below) | Status dots are owned here |
| `tableColumnIconStyles` | `.table-icon-cell`, `.table-icon-cell--chevron { padding: 29px }`, `.table-icon-cell--checkbox { padding: 22px }` | Pre-built spacing for fixed leading columns |
| `tableSelectedRowStyles` | `sp-table-row[selected]` blue-200 background | Needed whenever `selects="multiple"` |
| `loadingContainerFlexStyles` | `.loading-container--flex` centering | For the skeleton/spinner state |
| `ghostButtonStyles` | `.ghost-button` transparent button | Toolbar/quiet actions |

`skeletonStyles` lives separately in `studio/src/common/skeleton-styles.css.js` (loading rows).

---

## Existing table/list views (reuse candidates)

Survey these before building. The reuse-matcher scores a Figma view against them.

| Component | Path | Structure | Reuse for |
|---|---|---|---|
| `mas-select-items-table` | `studio/src/common/components/mas-select-items-table.js` | **The canonical selectable table.** Checkbox + configurable columns + status + actions. Already parameterized. | Any multi-select table — **extend this first** before building |
| `mas-promotions-items-table` | `studio/src/promotions/mas-promotions-items-table.js` | Icon + name in first column, status, actions | Views where col 1 is icon+text |
| `mas-translation` | `studio/src/translation/mas-translation.js` | Read-only list, no selection | Simple read-only lists |
| `mas-placeholders` | `studio/src/placeholders/mas-placeholders.js` | Editable cells, inline RTE | Views with in-cell editing |
| `mas-settings-table` | `studio/src/settings/mas-settings-table.js` | Settings rows | Config/settings tables |
| `mas-bulk-publish` | `studio/src/bulk-publish/mas-bulk-publish.js` | Selectable + bulk action bar | Tables with a bulk-action footer |
| `mas-collections` | `studio/src/collections/mas-collections.js` | Checkbox + expand chevron + 7 cols + **expand rows with sub-tabs** + amber/green status | Expandable parent/child tables |

**Reuse decision tree** (the matcher applies this per view):

```
≥50% columns match mas-select-items-table?      → extend it; add only new columns
First column is icon + name?                     → start from mas-promotions-items-table
Read-only, no selection?                         → start from mas-translation
Expandable rows / sub-tabs?                       → start from mas-collections
None of the above?                                → build; import the shared style modules
```

---

## Reusable UI regions

The decomposer names regions using **these canonical names**. The integrator assembles them in this order.

### `page-header` — title + CTA + divider
- **Verdict: build per view** (no shared component yet), but follow this exact shape:
- `<div class="page-header"><div class="title-row"><h1>…</h1><sp-button variant="accent">…</sp-button></div><hr class="section-divider"/></div>`
- `h1`: from Figma "Collections" text node (~22–24px, weight 700, gray-900)
- CTA: `sp-button variant="accent"` with `<sp-icon-add slot="icon">`
- **Divider: use `<hr class="section-divider">`, NOT `sp-divider`** — `sp-divider` renders an empty shadow DOM in the harness. CSS: `border:none; border-top:1px solid var(--spectrum-gray-300); width:100%`.

### `filter-bar` — search + count + filter pills
- **Verdict: build per view**, two-row shape:
- Row 1: `<sp-search>` (width ~290px) + `.result-count` (gray-600, 14px), `gap: 12px`
- **Pill-shaped search:** Figma search fields are usually fully-rounded pills (radius = half the 32px height = 16px). `sp-search`'s inner input radius derefs `--spectrum-corner-radius-100` (=8px) — overriding `--spectrum-search-border-radius`/`--mod-textfield-corner-radius` on the host does NOT change it. The reliable fix: set `--spectrum-corner-radius-100: 16px` scoped to the search's class (e.g. `.translation-search { --spectrum-corner-radius-100: 16px; }`). Scope it to the search selector so it doesn't affect other 8px-radius components.
- Row 2: filter pills, `gap: 12px`, `flex-wrap: wrap`
- **Filter pills: `sp-action-button size="m"`** (NOT `quiet`, NOT `sp-picker` — pickers render checkmarks without options) with `<sp-icon-chevron-down slot="icon-right" size="s">`. Pill radius: `--spectrum-actionbutton-border-radius: 16px`.
- Trailing "Add filter": `sp-action-button size="m" quiet` with `<sp-icon-add slot="icon">`.

### `data-table` — the table shell
- **Verdict: use shared style modules.** `<sp-table class="item-table" emphasized selects="multiple">` → `tableHeaderBaseStyles` gives the card look. Columns via flex-grow tokens (below).
- **`selects="multiple"` adds a checkbox column** — only include it if Figma shows row checkboxes. Translation/read-only lists omit it.
- **Bottom corners:** `tableHeaderBaseStyles` rounds only the TOP corners (12px on the head cells). If the table has a `border-radius` + border (card look), the last body row stays square and crops the rounded bottom corners. Fix: add `overflow: hidden` to the `sp-table` rule. Safe when row actions use `sp-action-menu` (it portals its popover to the overlay layer). If the table has inline-expanding content (expand-rows), do NOT use `overflow: hidden` — instead round the last row's first/last cell via `border-bottom-left-radius`/`border-bottom-right-radius: 12px`.

### `table-header` — `sp-table-head`
- One `sp-table-head-cell.<class>` per column (classes below). Sort icon: **`sp-icon-order`** (registered) — `sp-icon-sort-down` is NOT in the `swc.js` bundle; to use it, add to `studio/src/swc.js` and rebuild.

### `status-cell` — status dot + label
- **Verdict: use `tableCellBaseStyles`.** Structure: `<sp-table-cell><div class="status-cell"><div class="status-dot <color>"></div>Label</div></sp-table-cell>`.
- The `class="status-cell"` goes on the **inner `div`**, never on the `sp-table-cell` host.
- Colors (owned by `tableCellBaseStyles`): `.status-dot.green` = published, `.status-dot.blue` = modified (default mapping). **Per-view override:** if Figma shows a different color (Collections uses **amber** for Modified), add `.status-dot.yellow { background-color: var(--spectrum-yellow-700) }` in the view CSS — and **re-declare `width/height/border-radius` on `.status-dot` directly** (the shared rule nests them inside `.status-cell` via CSS nesting, which can drop in some contexts).

### `action-menu` — the `···` row menu
- **Verdict: use as-is.** `<sp-action-menu placement="bottom-end" quiet><sp-icon-more slot="icon"></sp-icon-more>` + `<sp-menu-item><sp-icon-… slot="icon">Label</sp-menu-item>` per action.

### `expand-row` — chevron + sub-tabs + child rows
- **Verdict: reuse `mas-collections` pattern.** Expand cell: `<sp-table-cell class="expand-cell">` with a `<button class="expand-button">` toggling `sp-icon-chevron-right` ↔ `sp-icon-chevron-down`. Expanded panel: a full-width `sp-table-row.subtabs-row` containing `<sp-tabs>` + child `sp-table-row.child-row`s.

### `empty-state`
- **Verdict: use `selectItemsFormSectionStyles` `.items-empty-state`** (dashed border, gap 12px) for the no-results panel.

---

## Column class → flex-grow token map

Default ratios live in `studio/style.css:409-414`. **Override per view** by computing `ratio = (figmaPixelWidth / totalUsableWidth) × 10`.

| Figma column | Cell class | flex-grow token | Default |
|---|---|---|---|
| Title / Name (primary) | `title` | `--table-content-title-flex-grow` | 1.6 |
| Fragment/item name | `name` | `--table-content-name-flex-grow` | 1.4 |
| Type / Template / Category | `offer-type` | `--table-content-offer-type-flex-grow` | 0.4 |
| Last modified by | `last-modified-by` | `--table-content-last-modified-by-flex-grow` | 0.7 |
| Price | `price` | `--table-content-price-flex-grow` | 0.7 |
| Offer ID / SKU | `offer-id` | `--table-content-offer-id-flex-grow` | 0.3 |
| Status | `status` | `--table-content-status-flex-grow` | 0.3 |
| Actions (⋯) | `actions` | `--table-content-actions-flex-grow` | 0.2 |
| Expand chevron | `expand-cell` | fixed (`flex: 0 0 40px`) | — |
| Path / URL | `path` | no token — set `flex-grow` + `font-size:12px` directly | — |

Worked example (Collections, total usable ≈ 1088px): title 251px → 2.3, template 117 → 1.07, created-by 123 → 1.13, last-modified 139 → 1.28, path 225 → 2.07, status 121 → 1.11, actions 112 → 1.03.

---

## Cell measurement defaults (from Figma `get_design_context`)

These are the values to read off the Figma frame, with Collections as the reference baseline:

| Property | Where to read in Figma | Collections value |
|---|---|---|
| Row height | `Row N` frame `height` | 68px |
| Header height | `Header Row` frame `height` | 44px |
| Cell left padding | text node `x` within cell | 20px |
| Host horizontal padding | `Main Content Area` → `Page Header` `x` | 32px |
| Page-header top padding | `Page Header` `y` | 32px |
| Divider gap above | `Divider` `y` − title-row bottom | 12px |
| Filter row gap | spacing between `Picker` instances | 12px |
| Status dot | `status_light` instance size | 8px |

---

## How to extend this registry

When a build creates a new reusable region (e.g. a date-range filter, a bulk-action bar):
1. Land it in `studio/src/common/` if truly shared, or the view dir if view-specific.
2. Add a row to the relevant section above with **path + verdict + the exact tag/class shape**.
3. If it supersedes a "build per view" entry, change that verdict to **use**/**extend** and point at it.

The registry only earns its keep if it stays current. A stale entry that points at a renamed file is worse than no entry — verify the path exists before relying on it.
