# Adobe Monorepo

This directory contains the MAS (Merch at Scale) and Milo repos alongside shared worktree tooling.

```
adobe/
  mas/          # main MAS repo — always on the current working branch
  milo/         # Milo repo
  worktrees/    # wt CLI + all active MAS worktrees
    wt          # worktree manager script
    .ports      # branch → port offset registry
    <BRANCH>/   # each worktree lives here
```

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
