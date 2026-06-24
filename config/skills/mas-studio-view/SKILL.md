---
name: mas-studio-view
description: Correct patterns for registering a new page/view in M@S Studio — PAGE_NAMES, Store namespace, studio.js getter, side-nav item, router wiring, Lit component structure, shared table styles. Use whenever building or modifying a Studio list/table view.
type: project
---

# M@S Studio View Patterns

> Reference card for wiring a Studio view by hand. To generate a whole view from a Figma frame automatically (decompose → build → validate against Figma), use the **`figma-to-studio-view`** workflow skill — it embeds these same rules.

## The 5-file wiring contract

Every Studio view requires exactly these changes. Missing any one means the view never appears in the app.

| File | What to add |
|---|---|
| `studio/src/constants.js` | `PAGE_NAMES.MY_VIEW: 'my-view'` |
| `studio/src/store.js` | `Store.myView: { list: { data, loading } }` |
| `studio/src/studio.js` | import + `get myView()` getter + include in `render()` |
| `studio/src/mas-side-nav.js` | `<mas-side-nav-item>` with `?selected` + `@nav-click` |
| `studio/src/router.js` | No change needed — `navigateToPage` sets `Store.page` generically |

### constants.js

```js
export const PAGE_NAMES = {
    // existing entries…
    MY_VIEW: 'my-view',
};
```

### store.js — minimal Store namespace + pageValidator

Add the new page name to the `pageValidator` allowlist — missing this causes navigation to silently fall back to Welcome with no error:

```js
// 1. pageValidator allowlist (store.js ~line 242) — REQUIRED or navigation silently falls back to WELCOME
const validPages = [
    // … existing …
    PAGE_NAMES.MY_VIEW,    // ← add this
];

// 2. Store namespace
myView: {
    list: {
        data: new ReactiveStore([]),
        loading: new ReactiveStore(false),
    },
},
```

Add the namespace alongside `promotions`, `translationProjects`, `bulkPublishProjects`.

### studio.js

```js
// 1. Import (alongside other view imports at top)
import './my-view/mas-my-view.js';

// 2. Getter (follow existing pattern — each view has one)
get myView() {
    if (this.page.value !== PAGE_NAMES.MY_VIEW) return nothing;
    return html`<mas-my-view></mas-my-view>`;
}

// 3. Include in render() main-container html template
${this.myView}
```

### mas-side-nav.js — enabling a disabled stub

If the nav item already exists as `disabled`, replace it:

```js
// BEFORE (disabled stub)
<mas-side-nav-item label="Collections" disabled>
    <sp-icon-aspect-ratio slot="icon"></sp-icon-aspect-ratio>
</mas-side-nav-item>

// AFTER (wired)
<mas-side-nav-item
    label="Collections"
    ?selected=${Store.page.get() === PAGE_NAMES.MY_VIEW}
    @nav-click="${router.navigateToPage(PAGE_NAMES.MY_VIEW)}"
>
    <sp-icon-aspect-ratio slot="icon"></sp-icon-aspect-ratio>
</mas-side-nav-item>
```

For views guarded by `isMasAdmin()`, wrap in the same conditional as Promotions.

---

## Lit component structure

### File placement

```
studio/src/<view>/
    mas-<view>.js          component
    mas-<view>-css.js      styles
studio/test/<view>/
    mas-<view>.test.js     tests (wtr, not jest)
```

### Component skeleton

```js
import { html, LitElement, nothing } from 'lit';
import { repeat } from 'lit/directives/repeat.js';
import ReactiveController from '../reactivity/reactive-controller.js';
import Store from '../store.js';
import styles from './mas-<view>-css.js';

class Mas<View> extends LitElement {
    static styles = styles;
    static properties = {
        items: { type: Array, state: true },
        loading: { type: Boolean, state: true },
    };

    constructor() {
        super();
        this.items = Store.<view>?.list?.data?.get() ?? [];
        this.loading = Store.<view>?.list?.loading?.get() ?? false;
        this.reactiveController = new ReactiveController(this, [
            Store.<view>?.list?.data,
            Store.<view>?.list?.loading,
        ].filter(Boolean));
    }

    render() {
        if (this.loading) return html`<div class="loading-container"></div>`;
        return html`…`;
    }
}

customElements.define('mas-<view>', Mas<View>);
export default Mas<View>;
```

**Rules:**
- Use `ReactiveController` (multi-store) — `StoreController` only when you need `controller.value` from a single store
- Use `repeat()` with a key function for all list rendering — never `.map()`
- Use `#privateGetter` for template fragments (`get #headerTemplate()`) — not `renderSomething()` public methods
- No `customElements.define` in `swc.js` — the component is composed inside `studio.js`, not used standalone

---

## Table styles

### Always import from `table-styles.css.js` — never copy from `style.css`

```js
// studio/src/<view>/mas-<view>-css.js
import { css } from 'lit';
import {
    tableBodyBaseStyles,
    tableCellBaseStyles,
    tableColumnIconStyles,
    tableHeaderBaseStyles,
    tableSelectedRowStyles,
} from '../common/styles/table-styles.css.js';

export default [
    tableHeaderBaseStyles,   // header bg, border-radius, .item-table
    tableBodyBaseStyles,     // removes body border
    tableCellBaseStyles,     // flex layout, .status-cell, .status-dot colors
    tableColumnIconStyles,   // .table-icon-cell--chevron, .table-icon-cell--checkbox
    tableSelectedRowStyles,  // blue selected row bg
    css`
        /* view-specific only */
        :host { display: flex; flex-direction: column; width: 100%; padding: 0 24px; box-sizing: border-box; }
        sp-table {
            flex: 1;
            --table-content-title-flex-grow: 2;
        }
    `,
];
```

### Column width tokens (scoped via CSS nesting in `style.css`)

Token names map to exact class names — prefix them and the token silently has no effect:

| Class | Token | Default |
|---|---|---|
| `title` | `--table-content-title-flex-grow` | `1.6` |
| `name` | `--table-content-name-flex-grow` | `1.4` |
| `offer-type` | `--table-content-offer-type-flex-grow` | `0.4` |
| `last-modified-by` | `--table-content-last-modified-by-flex-grow` | `0.7` |
| `status` | `--table-content-status-flex-grow` | `0.3` |
| `actions` | `--table-content-actions-flex-grow` | `0.2` |
| `expand-cell` | fixed `min/max-width: 40px` | — |
| `path` | no token — define explicitly | — |

Override per-view on `sp-table`:
```css
sp-table {
    --table-content-title-flex-grow: 2;
    --table-content-status-flex-grow: 0.55;
}
```

Path column (no token):
```css
sp-table-head-cell.path,
sp-table-cell.path { flex-grow: 1.5; font-size: 12px; color: var(--spectrum-gray-700); }
sp-table-cell.path span { white-space: normal; word-break: break-word; line-height: 1.4; display: block; }
```

### Status cells — use `renderFragmentStatusCell`

The shared helper in `render-utils.js` renders the correct dot class (`green` / `blue` / empty) and handles label capitalization. Always reuse it:

```js
import { renderFragmentStatusCell } from '../common/utils/render-utils.js';
// FRAGMENT_STATUS.PUBLISHED → green dot, FRAGMENT_STATUS.MODIFIED → blue dot
```

Dot classes live in `tableCellBaseStyles` as `.status-dot.green` / `.status-dot.blue`. Never redefine dot colors.

---

## Real codebase references

| Pattern | File |
|---|---|
| Full table view with sort, filter, expand | `studio/src/promotions/mas-promotions.js` |
| Shared table used by collections + placeholders | `studio/src/common/components/mas-select-items-table.js` |
| Fragment variations table | `studio/src/mas-fragment-table.js` |
| Status cell helper | `studio/src/common/utils/render-utils.js` |
| Base table styles (shared exports) | `studio/src/common/styles/table-styles.css.js` |
| Store namespace examples | `studio/src/store.js` — `promotions`, `translationProjects` |
| PAGE_NAMES + FRAGMENT_STATUS | `studio/src/constants.js` |

---

## Never do these

```js
// BAD: copy styles from style.css into a Lit component
// style.css is for HTML prototypes only; Lit uses table-styles.css.js

// BAD: define in swc.js when component is only used inside studio.js
import '@adobecom/mas/studio/src/collections/mas-collections.js'; // no

// BAD: use sp-icon-sort-order-down — not registered, renders as empty space
// Use sp-icon-order instead

// BAD: redefine status dot colors
.status-dot { background-color: green; } // tableCellBaseStyles already owns this

// BAD: add PAGE_NAMES entry without adding Store namespace
// The component constructor will throw trying to read Store.myView?.list

// BAD: forget router — navigateToPage() already calls Store.page.set() generically
// Adding a case to router.js for a simple page is unnecessary
```
