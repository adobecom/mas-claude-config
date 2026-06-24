# Studio View Token Mapping

Figma Spectrum 2 values → CSS custom properties used in `mas-<view>-css.js`.

## Colors

| Figma name | Hex | CSS custom property |
|---|---|---|
| Gray 50 | `#FAFAFA` | `var(--spectrum-gray-50)` |
| Gray 75 | `#F5F5F5` | `var(--spectrum-gray-75)` |
| Gray 100 | `#F0F0F0` | `var(--spectrum-gray-100)` |
| Gray 200 | `#E3E3E3` | `var(--spectrum-gray-200)` |
| Gray 300 | `#CDCDCD` | `var(--spectrum-gray-300)` |
| Gray 400 | `#ABABAB` | `var(--spectrum-gray-400)` |
| Gray 500 | `#868686` | `var(--spectrum-gray-500)` |
| Gray 600 | `#6F6F6F` | `var(--spectrum-gray-600)` |
| Gray 700 | `#5A5A5A` | `var(--spectrum-gray-700)` |
| Gray 800 | `#3D3D3D` | `var(--spectrum-gray-800)` |
| Gray 900 | `#1E1E1E` | `var(--spectrum-gray-900)` |
| Blue 500 | `#2680EB` | `var(--spectrum-blue-500)` |
| Blue 600 | `#1473E6` | `var(--spectrum-blue-600)` |
| Green 500 | `#2D9D78` | `var(--spectrum-green-500)` |
| Green 600 | `#268E6C` | `var(--spectrum-green-600)` |
| Red 500 | `#E34850` | `var(--spectrum-red-500)` |
| Orange 500 | `#E68619` | `var(--spectrum-orange-500)` |

### Status dot colors (defined in `tableCellBaseStyles`)

| Status | Class | Token |
|---|---|---|
| PUBLISHED | `.status-dot.green` | `var(--spectrum-green-700)` |
| MODIFIED | `.status-dot.blue` | `var(--spectrum-blue-800)` |
| DRAFT | `.status-dot` (no modifier) | `var(--spectrum-gray-500)` |

`tableCellBaseStyles` uses **nested CSS** to define `.status-dot` inside `.status-cell`. If CSS nesting isn't supported or the outer `.status-cell` block is overridden, the dots lose their `width`/`height`. Always explicitly define `.status-dot { width: 8px; height: 8px; border-radius: 50%; }` in the component's own CSS to be safe.

**View-specific overrides** (when Figma shows a different color than the shared mapping):
- Collections: MODIFIED → amber/yellow. Add `.status-dot.yellow { background-color: var(--spectrum-yellow-700); }` in the component CSS and use `dotClass = 'yellow'` in `#statusCell()` instead of `'blue'`.
- The `yellow` class must include explicit `width`/`height`/`border-radius` since `tableCellBaseStyles` only defines those on the base `.status-dot` via nested CSS.

## Typography

| Figma style | Font size | Weight | Line height | CSS |
|---|---|---|---|---|
| Body XS | 12px | 400 | 18px | `font-size: var(--spectrum-font-size-75)` |
| Body S | 14px | 400 | 21px | `font-size: var(--spectrum-font-size-100)` |
| Body M | 16px | 400 | 24px | `font-size: var(--spectrum-font-size-200)` |
| Detail S | 11px | 700 | 14px | `font-size: var(--spectrum-font-size-50)` |
| Detail M | 12px | 700 | 15px | `font-size: 12px; font-weight: 700` |
| Heading XS | 18px | 700 | 22.5px | `font-size: var(--spectrum-font-size-400)` |

### Table-specific typography (Studio baseline)

| Element | Default in `table-styles.css.js` | Override when |
|---|---|---|
| Column header label | 12px, 700, uppercase | Figma shows different size/weight/case |
| Row cell content | 14px, 400 | Figma shows different |
| Secondary text (path) | 12px, 400, gray-700 | — always define explicitly (no token) |
| Status label | 12px, 400 | — |

## Spacing

| Figma Spectrum name | Value | CSS usage |
|---|---|---|
| Size 50 | 4px | `gap: var(--spectrum-spacing-50)` |
| Size 75 | 6px | — |
| Size 100 | 8px | `padding: var(--spectrum-spacing-100)` |
| Size 200 | 12px | — |
| Size 300 | 16px | `padding: var(--spectrum-spacing-300)` |
| Size 400 | 20px | — |
| Size 500 | 24px | `padding: var(--spectrum-spacing-500)` |
| Size 600 | 32px | — |
| Size 700 | 40px | — |
| Size 800 | 48px | — |

## sp-table anatomy (Studio)

```
sp-table
  ├─ sp-table-head
  │    ├─ sp-table-checkbox-cell   slot="checkbox-cell"   (40px fixed)
  │    ├─ sp-table-head-cell.expand-cell                   (40px fixed)
  │    └─ sp-table-head-cell.<class>                       (flex-grow via token)
  └─ sp-table-body
       └─ sp-table-row
            ├─ sp-table-checkbox-cell   slot="checkbox-cell"
            ├─ sp-table-cell.expand-cell
            │    └─ <button class="expand-button">
            │         └─ sp-icon-chevron-right size="s"
            ├─ sp-table-cell.<class>
            └─ sp-table-cell.status
                 └─ <div class="status-dot [green|blue]"></div>
                    <span>Label</span>     ← from renderFragmentStatusCell()
```

## Filter bar anatomy (Studio two-row pattern)

```
.filter-bar
  ├─ .filter-row-1                          (search + count + actions)
  │    ├─ sp-search                         (flex: 1, max-width ~300px)
  │    ├─ .item-count                       (gray-600, 14px)
  │    └─ <action buttons>                  (sp-action-button quiet)
  └─ .filter-row-2                          (filter chips)
       ├─ sp-chip-group                     (horizontal scroll)
       └─ sp-field-label                    ("Filters:" label, gray-600)
```

## Page header anatomy

```
.page-header
  ├─ h1                                     (heading-xs 18px/22px, gray-900)
  └─ sp-button variant="accent"             (primary CTA)
```

## Common pitfalls

| Figma observation | Wrong CSS | Correct CSS |
|---|---|---|
| Row looks taller than rendered | `sp-table-row { height: Xpx }` alone | Also set `sp-table-cell { height: Xpx }` — both need the height |
| Cell text too close to edge | Forgetting padding | `sp-table-cell { padding: 0 12px }` (or per Figma value) |
| Header background too light | Custom color | Use `tableHeaderBaseStyles` — it sets the correct Spectrum token |
| Filter chips look filled | Wrong variant | `sp-chip` default is outlined; `variant="filter"` for toggle chips |
| Column order wrong after re-render | CSS order property | Use DOM order in template, not CSS `order:` |
| Icon in header renders empty | Wrong SWC name | Check `studio/design-system/docs/components.md` |
