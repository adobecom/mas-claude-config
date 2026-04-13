# Testing Rules

## Local Test Requirements

- NALA local tests require ports 8080 (AEM) and 3000 (proxy)
- Check with `lsof` and run `/start-mas` if needed
- For Milo NALA tests, ensure AEM server is running with `aem up`
- Run proxy from `@studio/` with `npm run proxy` when AEM server starts locally

## Tools

- Use nala-mcp when working with NALA tests
- Use Playwright MCP for automated browser testing
- Use Chrome DevTools MCP for console error analysis

## After Code Changes

- Run `npm run build` after changes in `web-components/` (runs tests + compiles)
- Run linter on every modified file (eslint only on modified files)
