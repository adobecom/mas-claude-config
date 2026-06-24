# Region Manifest Schema

The single handoff artifact that flows through the whole pipeline:

```
decomposer ─▶ manifest ─▶ reuse-matcher ─▶ (you approve) ─▶ workflow ─▶ integrator
```

Every agent reads it and writes back to it. It is the resume point: if a build is interrupted, re-running with the same manifest skips finished work. Colleagues can hand-edit it to correct a measurement or override a reuse decision before the workflow runs.

## Shape

```json
{
  "view": "collections",
  "viewLabel": "Collections",
  "figmaFileKey": "GDDRLo3S7fz0SMRefpJOpx",
  "figmaScreenNodeId": "21462:158313",
  "totalUsableWidth": 1088,
  "columns": [
    { "class": "title",            "label": "Collection title", "figmaWidth": 251, "flexGrow": 2.3,  "contentType": "text", "hasSortIcon": true },
    { "class": "offer-type",       "label": "Template",         "figmaWidth": 117, "flexGrow": 1.07, "contentType": "text" },
    { "class": "name",             "label": "Created by",       "figmaWidth": 123, "flexGrow": 1.13, "contentType": "text" },
    { "class": "last-modified-by", "label": "Last modified by", "figmaWidth": 139, "flexGrow": 1.28, "contentType": "text" },
    { "class": "path",             "label": "Path",             "figmaWidth": 225, "flexGrow": 2.07, "contentType": "secondary-text" },
    { "class": "status",           "label": "Status",           "figmaWidth": 121, "flexGrow": 1.11, "contentType": "status" },
    { "class": "actions",          "label": "Actions",          "figmaWidth": 112, "flexGrow": 1.03, "contentType": "action-menu" }
  ],
  "regions": [
    {
      "name": "page-header",
      "figmaNodeId": "21462:158318",
      "measurements": { "paddingTop": 32, "titleFontSize": 24, "dividerGapAbove": 12, "ctaLabel": "Create collection" },
      "reuseVerdict": "build",
      "reuseCandidate": null,
      "status": "pending",
      "templateFragment": null,
      "cssBlock": null,
      "swcImports": []
    },
    {
      "name": "filter-bar",
      "figmaNodeId": "21462:158326",
      "measurements": { "searchWidth": 290, "rowGap": 12, "pillRadius": 16, "pills": ["Collection type","Template","Personalization","Status","Created by","Last modified by"], "hasAddFilter": true },
      "reuseVerdict": "build",
      "reuseCandidate": null,
      "status": "pending",
      "templateFragment": null,
      "cssBlock": null,
      "swcImports": []
    },
    {
      "name": "status-cell",
      "figmaNodeId": "21462:158371",
      "measurements": { "dotSize": 8, "gap": 6, "colorMap": { "PUBLISHED": "green", "MODIFIED": "yellow" } },
      "reuseVerdict": "use",
      "reuseCandidate": "tableCellBaseStyles .status-cell",
      "status": "pending",
      "templateFragment": null,
      "cssBlock": null,
      "swcImports": []
    },
    {
      "name": "expand-row",
      "figmaNodeId": "21462:158375",
      "measurements": { "tabs": ["Locale","Promotion","Grouped variation"], "childRowHeight": 68 },
      "reuseVerdict": "extend",
      "reuseCandidate": "mas-collections expand pattern",
      "status": "pending",
      "templateFragment": null,
      "cssBlock": null,
      "swcImports": []
    }
  ],
  "rowHeight": 68,
  "cellPadding": 20,
  "headerHeight": 44
}
```

## Field reference

**Top level**
| Field | Set by | Meaning |
|---|---|---|
| `view` | you | kebab page name (`collections`) → `PAGE_NAMES.COLLECTIONS`, file dir |
| `viewLabel` | you | human label for side-nav + `<h1>` |
| `figmaFileKey` / `figmaScreenNodeId` | decomposer | the **drilled** screen frame (≥1200px wide), not the section |
| `totalUsableWidth` | decomposer | sum of flex-column pixel widths; the ratio denominator |
| `columns[]` | decomposer | one per table column, in DOM order |
| `rowHeight` / `cellPadding` / `headerHeight` | decomposer | px from `get_design_context` |
| `opusValidator` | you (optional) | `true` → run the validator on Opus for sharper diffing on high-stakes runs (default Sonnet) |
| `worktreeRoot` | you (optional) | absolute path to the worktree the AEM server serves; all files are written here (NOT the main mas/ repo). Defaults to the active worktree. |
| `skillDir` | you (optional) | absolute path to this skill's own directory (where component-registry.md/token-mapping.md live). Defaults to <worktreeRoot>/.claude/skills/figma-to-studio-view. |

**`columns[]`** — `class` (canonical column class, see `component-registry.md`), `label`, `figmaWidth` (px), `flexGrow` (= `figmaWidth/totalUsableWidth×10`), `contentType` (`text` | `secondary-text` | `status` | `action-menu` | `icon-text` | `checkbox` | `expand`), `hasSortIcon`.

**`regions[]`**
| Field | Set by | Meaning |
|---|---|---|
| `name` | decomposer | canonical region name from the registry |
| `figmaNodeId` | decomposer | the region's frame id (for re-screenshotting just that region) |
| `measurements` | decomposer | region-specific px/labels/maps — whatever that region needs |
| `reuseVerdict` | matcher | `use` \| `extend` \| `build` |
| `reuseCandidate` | matcher | path/identifier of the thing to reuse (null if build) |
| `status` | workflow | `pending` → `done` → `needs-fix` (validator sets `needs-fix` with a `diff` note) |
| `templateFragment` | region agent | the Lit `html\`…\`` snippet for this region (string) |
| `cssBlock` | region agent | the CSS rules for this region (string) |
| `swcImports` | region agent | SWC imports this region needs added to `swc.js` (array of import paths) |

## Lifecycle / resume

- The **decomposer** fills everything except the matcher/agent fields.
- The **matcher** fills `reuseVerdict` + `reuseCandidate`.
- **You** review and may hand-edit any field (fix a measurement, force a verdict).
- The **workflow** runs region agents (fill `templateFragment`/`cssBlock`/`swcImports`, set `status: done`), then the integrator assembles, then the validator may flip a region to `needs-fix` with a diff.
- Re-running the workflow with the saved manifest re-runs only `pending`/`needs-fix` regions — finished ones return their cached fragments.

Persist the manifest to `.claude/plans/<TICKET>-manifest.json` (gitignored, like other planning artifacts).
