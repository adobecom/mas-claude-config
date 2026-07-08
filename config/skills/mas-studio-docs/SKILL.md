---
name: MAS Studio Docs Authoring
model: sonnet
effort: medium
description: Author and publish feature documentation for MAS Studio to the DA-backed docs site at mas.adobe.com/docs/<feature>/. Sources content from the actual Studio code (help text, store, components) so docs match shipped behavior, writes pages via the DA source API (admin.da.live), and publishes via Edge Delivery (admin.hlx.page). Use when asked to "document a studio feature", "write OST/feature docs", "add a docs page", "publish to mas.adobe.com/docs", or to wire an in-app Help link to the docs. Mirrors the workflow used to build /docs/ost.
tags: [studio, documentation, da, da.live, edge-delivery, docs, ost, authoring]
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - mcp__claude-in-chrome__tabs_context_mcp
  - mcp__claude-in-chrome__navigate
  - mcp__claude-in-chrome__javascript_tool
  - mcp__claude-in-chrome__computer
  - WebFetch
---

# MAS Studio Docs Authoring

Author + publish feature docs to `mas.adobe.com/docs/<feature>/`, the way the OST docs were built. The docs site is **DA-backed** (`fstab.yaml` mounts `/` → `content.da.live/adobecom/mas/`), rendered by Edge Delivery.

## Principle: docs come from the code, not from memory

Never invent feature behavior. Pull every fact from the source so docs match what ships:

| What to document | Where it lives (example: OST) |
|---|---|
| Step/flow copy, tooltips | in-component help data (e.g. `ost/src/data/help-content.js`) |
| Options / toggles / defaults | the store (e.g. `DEFAULT_PLACEHOLDER_OPTIONS`, slices in `ost/src/store/*.js`) |
| Modes / tabs / types | component constants (e.g. `PANEL_TABS`, `FLOW_LABELS`, `DEFAULT_PLACEHOLDER_TYPES`) |
| Output format | the emit path (e.g. `ost-code-output.getCodeString()` → `{{type osi="…"}}`) |
| Dropdown values (CTA, workflow, modal) | `studio/src/constants.js`, checkout-options component |

`grep`/Scout the feature's `src/` for these before writing a word. If a value isn't in the code, don't state it.

## The DA workflow (no DA UI automation needed)

The DA editor is a doubly-nested shadow-DOM ProseMirror — driving it via clicks is brittle. **Skip it.** Use the DA **source API** from a da.live tab's JS context, where the IMS token is available and same-origin.

### 1. Get a token + check write permission

Open `https://da.live` (any page) in Chrome; the user must be signed in. Then in that tab's JS:

```js
const { token } = await window.adobeIMS.getAccessToken();
const res = await fetch('https://admin.da.live/source/adobecom/mas/docs/<feature>/<page>.html',
  { headers: { Authorization: 'Bearer ' + token } });
res.headers.get('x-da-actions');   // "…=read,write" means you can PUT; "…=read" means STOP
```

`x-da-actions` echoes your effective rights for that path. **`read` only → you cannot write** — that's a DA-config permission gap the user must grant (`da.live/config#/adobecom/`), not a code fix. A brand-new path returns `404` + `read,write` (fine to create).

### 2. Learn the HTML envelope

`GET` an existing page (or the index stub) to see DA's shape:

```html
<body>
  <header></header>
  <main><div><p>…</p></div></main>
  <footer></footer>
</body>
```

Content goes in `<main>`. **Each `<div>` is a section** (rendered with a SECTION-BREAK divider). Use real HTML: `<h1>/<h2>/<h3>`, `<p>`, `<ul><li>`, and `<table><tr><td>…` (DA renders these to EDS tables). Bold lead with `<strong>`.

### 3. PUT the page

Multipart, field name `data`, content-type `text/html`:

```js
const fd = new FormData();
fd.append('data', new Blob([html], { type: 'text/html' }), '<page>.html');
const r = await fetch('https://admin.da.live/source/adobecom/mas/docs/<feature>/<page>.html',
  { method: 'PUT', headers: { Authorization: 'Bearer ' + token }, body: fd });
// 200/201 + JSON with editUrl / previewUrl / liveUrl
```

Build a small `wrap(inner)` + `put(path, inner)` helper and PUT a hub page plus sub-pages (e.g. overview + authoring-modes + placeholder-types + checkout + filters + display-options). Cross-link sub-pages from the hub with `<a href="/docs/<feature>/<page>">`.

### 4. To edit an existing page

GET it, mutate the HTML (prefer `DOMParser` + DOM ops over regex — DA whitespace varies), PUT it back. **Do the read→transform→write entirely inside one `javascript_tool` call and return only status/booleans** — returning the fetched page HTML trips a `[BLOCKED: Cookie/query string data]` content filter.

### 5. Publish (Edge Delivery) — confirm with the user first

Publishing is outward-facing. Only after the user approves, POST preview then live per page:

```js
const base = 'https://admin.hlx.page';
await fetch(`${base}/preview/adobecom/mas/main/docs/<feature>/<page>`, { method:'POST', headers:{Authorization:'Bearer '+token} });
await fetch(`${base}/live/adobecom/mas/main/docs/<feature>/<page>`,    { method:'POST', headers:{Authorization:'Bearer '+token} });
```

Live URL: `https://mas.adobe.com/docs/<feature>/<page>` (also `https://main--mas--adobecom.aem.live/...`). Verify with `WebFetch` after.

## Screenshots (optional, higher maintenance)

UI screenshots go stale on every visual change. If asked: capture the feature in a running Studio (`localhost:<port>/studio.html`), then upload each PNG to DA (`PUT admin.da.live/source/.../*.png`) and reference it. The capture↔upload bytes can't always bridge in automation — if blocked, hand the user a "screenshot → which page → caption" map and let them drop images in the DA editor.

## Wiring in-app Help to the docs

A feature's Help control can open its docs page in a new tab instead of an in-app guide:
`@click=${() => window.open('https://mas.adobe.com/docs/<feature>/<overview>', '_blank', 'noopener')}`.
Removing a now-dead in-app help banner is fair dead-code cleanup, but confirm scope first (contextual tooltips may be worth keeping).

## Checklist

- [ ] Grepped the feature `src/` for help text, options, modes, output format — no invented facts
- [ ] Token obtained from a signed-in da.live tab; `x-da-actions` shows `write` on the target paths
- [ ] Hub page + sub-pages PUT (200/201), cross-linked
- [ ] Rendered cleanly (open `da.live/edit#/adobecom/mas/docs/<feature>/<page>` to eyeball, or WebFetch the live URL)
- [ ] Published only after explicit user approval; verified live
