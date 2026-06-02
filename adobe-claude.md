# Adobe Monorepo

This directory contains the MAS (Merch at Scale) and Milo repos alongside shared worktree tooling.

```
adobe/
  mas/          # main MAS repo — always on the current working branch
  milo/         # Milo repo
  worktrees/    # wt CLI + all active MAS worktrees
    wt          # worktree manager script
    .ports      # branch → port offset registry
    <BRANCH>/   # each worktree lives here (CLAUDE.md and .claude/ symlink back to mas/)
```

## Cross-Project Architecture

Three projects, one pipeline. Reading this should answer: **where does a bug actually live?**

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌────────────────┐
│   Odin AEM  │ ──> │ MAS Studio + │ ──> │ MAS web-    │ ──> │ Milo consumers │
│  (headless) │     │   IO         │     │ components  │     │ (CC, Express,  │
│             │     │              │     │   bundle    │     │  DA, …)        │
└─────────────┘     └──────────────┘     └─────────────┘     └────────────────┘
   content              authoring +           rendering            page assembly
   storage              fragment API          components           + autoblocks
```

### Layer → entry-point files

| Layer | Where it lives | Symptom looks like |
|---|---|---|
| **Odin** (AEM headless) | Odin MCP (`mcp__odin-prod__*`), no local files | Fragment data wrong/missing, locale fallback fails, fragment unpublished |
| **MAS Studio (frontend)** | `mas/studio/src/`, `mas/studio.html` | Authoring UI breaks, fragment edits don't save, locale picker broken |
| **MAS IO** | `mas/io/www/` (fragment pipeline), `mas/io/studio/` (ai-chat, MCP), `mas/io/mcp-server/` | API 500s, placeholder substitution wrong, ai-chat empty bubble, MCP search wrong results |
| **MAS web-components (source)** | `mas/web-components/src/` (e.g. `merch-card.js`, `hydrate.js`, `variants/*.js`) | Card renders wrong, variant CSS off, hydration drops fields |
| **MAS bundle** | `mas/web-components/dist/*.js` (built artifact, also copied into Milo at `milo/libs/deps/mas/`) | Local change "doesn't work" in Milo — usually a missing rebuild |
| **Milo MAS feature** | `milo/libs/features/mas/` — builds to `dist/mas.js` AND `../../deps/mas/` | Same MAS source, but bundled into Milo. `npm run build:bundle` required after src changes. |
| **Milo autoblocks** | `milo/libs/blocks/merch-card-autoblock/`, `libs/blocks/merch-card-collection-autoblock/`, `libs/blocks/merch/` | Block wraps merch-card; bug in *placement/markup* not the card itself |
| **Consumer apps** | `cc.adobe.com`, `express.adobe.com`, DA pages — out of repo | Page integration: wrong block, wrong locale, wrong fragment ID |

### Symptom → likely layer (start your investigation here)

| Symptom | Most likely layer | First thing to check |
|---|---|---|
| Card renders with wrong price | MAS web-components or Odin | Check fragment in Odin MCP → if data is right, check `inline-price.js` |
| Placeholder text not substituted (`{{X}}` visible) | MAS IO fragment pipeline | `io/www/` placeholder resolution; check locale fallback chain |
| Wrong card in CC/Express | Milo block or consumer page | Check the consumer page's block markup + fragment ID first |
| MAS change "doesn't appear" in Milo | Bundle out of sync | `npm run build:bundle` in `mas/` or in `milo/libs/features/mas/` |
| Card rendering broken only on a branch | maslibs/milolibs param mismatch | Confirm the consumer page is loading the branch via `?maslibs=` |
| AI Assistant 500/empty bubble | `mas/io/studio/` (ai-chat action) | See `mas-ai-assistant` and `ai-assistant-deploy` skills |
| Locale variation missing | Odin first, then MAS IO | Confirm fragment exists in Odin in that locale before debugging code |

### Testing modes (`?maslibs=` and `?milolibs=`)

The handler lives at `milo/libs/blocks/merch/merch.js` in `getMasBase()`:

| Param | URL | What it loads |
|---|---|---|
| no param | `…adobe.com/mas` | Production MAS bundle |
| `?maslibs=stage` | `…stage.adobe.com/mas` | Stage MAS bundle |
| `?maslibs=local` | `http://localhost:9001` | Locally served `mas/web-components/dist/` — must have local dev server running |
| `?maslibs=<branch>` | `https://<branch>.aem.live` (or `.page`) | MAS bundle from a specific feature branch |
| `?milolibs=local` | (Milo's own param) | Run consumer page against local Milo libs |
| `?milolibs=<branch>` | Milo branch | Run consumer page against a Milo branch |

**Both can stack:** `?milolibs=local&maslibs=local` runs the local Milo against the local MAS bundle. Useful when a bug spans both repos.

### Three-repo debugging discipline

When a bug crosses repos, do not jump straight to code. State first:

1. **Which layer is the symptom in?** (consumer app / Milo block / MAS bundle / MAS source / IO / Odin)
2. **What confirms the layer?** (URL, network tab, fragment data, build artifact timestamp)
3. **What would falsify it?** (e.g. "if the fragment is right in Odin, this is not an Odin issue — skip there")

Per `mas/CLAUDE.md` Investigation Discipline: state hypothesis + evidence + confidence before editing.

## Worktree Workflow

Use the `wt` script for all worktree operations. Always run it from `__ADOBE_DIR__`.

```bash
# Create a worktree from a branch name or PR URL
bash worktrees/wt new MWPW-123456
bash worktrees/wt new https://github.com/adobecom/mas/pull/672

# Start AEM dev server + proxy for a worktree
bash worktrees/wt start MWPW-123456

# Stop servers
bash worktrees/wt stop MWPW-123456

# List all worktrees with port assignments and status
bash worktrees/wt list
```

## Port Assignment

Each worktree gets a unique offset from `.ports`. The main `mas` repo always uses offset 0.

| Offset | AEM port | Proxy port |
|--------|----------|------------|
| 0      | 3000     | 8080       |
| 1      | 3001     | 8081       |
| 2      | 3002     | 8082       |
| …      | …        | …          |

Studio URL pattern: `http://localhost:<AEM_PORT>/studio.html`

## What `wt new` Does Automatically

1. Fetches and checks out the branch as a git worktree under `worktrees/<BRANCH>/`
2. Fixes git worktree metadata (AEM CLI compatibility)
3. Assigns the next available port offset
4. Patches `studio/proxy-server.mjs` to respect `PROXY_PORT` env var
5. Patches `studio.html` for dynamic proxy port and IMS auth relay (see below)
6. Symlinks `node_modules` from the main `mas` repo
7. Symlinks `.env` from the main `mas` repo so Nala/Playwright picks up IMS credentials

## IMS Authentication (Non-3000 Ports)

IMS only accepts `localhost:3000` as a registered redirect URI. All worktrees on non-3000 ports use a relay:

1. Visiting port N stores `imsRelayPort=N` in `sessionStorage` and sends IMS to `localhost:3000`
2. `localhost:3000` receives the token and relays back to port N automatically

This relay is patched into every `studio.html` by `wt new`. If a worktree was created manually, apply the patch by running:

```bash
bash -c 'source worktrees/wt; patch_studio_html worktrees/<BRANCH>/studio.html'
```

## Notes

- Worktrees for the same branch cannot coexist — create a new local branch first if needed
- `node_modules` is symlinked from `mas/`, so run `npm install` in `mas/` when dependencies change
- The `mas/studio.html` is also patched locally (not committed) to support the IMS relay as port 3000 receiver
