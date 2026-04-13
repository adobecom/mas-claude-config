# MAS Knowledge Index

## Skills

| Task | Skill |
|------|-------|
| Run/fix E2E tests | `nala-runner` |
| Write E2E tests | `nala-writer` |
| Generate page objects | `nala-page-object-generator` |
| Card variant reference | `card-variant-registry` |
| Studio UI navigation | `mas-studio-navigator` |
| Create PR | `mas-pr-creator` |
| I/O Runtime | `io-runtime-master` |
| AEM fragment operations | `mas-aem-integration` |
| Spectrum imports | `spectrum-import-helper` |
| Regional variations | `regional-variations-guide` |
| MAS libs parameters | `maslibs-parameter-guide` |
| New component | `mas-component-generator` |
| Figma → merch card | `figma-to-merch-card` |
| Coding conventions | `mas-coding-conventions` |
| Sync with main | `sync-with-main` |
| WTR tests | `wtr-specialist` |
| Jira ticket | `jira-ticket-creator` |
| Start ticket | `start-ticket` |

## Quick Commands

| Task | Command |
|------|---------|
| Build web components | `npm run build` (in `web-components/`) |
| Start AEM | `aem up` |
| Start proxy | `npm run proxy` (in `studio/`) |
| Run NALA tests | `npx playwright test` |
| Local testing URL | `?maslibs=local` or `?milolibs=local` |
| Lint | `npm run lint:fix` |

## Auto-Loaded Rules (by file path)

| Rule File | Triggers On |
|-----------|-------------|
| `web-component-variants.md` | `web-components/src/variants/**` |
| `field-components.md` | `studio/src/fields/**`, `**/rte/**` |
| `testing-nala.md` | `nala/**`, `**/*.spec.js` |
| `serverless-actions.md` | `io/**` |
| `event-driven-communication.md` | `studio/src/**` |
| `reactive-state-management.md` | `studio/src/reactivity/**` |
