# Testing Rules

## TDD Discipline

Applies to source changes in `studio/src/`, `web-components/src/`, and `io/` (excluding `io/www/src/fragment/`). Skip for nala/`*.spec.js` test-only changes, pure-CSS changes, and trivial typo/rename edits.

- **Test-first.** Invoke `superpowers:test-driven-development` before writing implementation code. Write the failing test, watch it fail, then implement.
- **New exported function ⇒ test before merge.** Any new `export`ed function/constant intended to be used must have a test exercising it before the PR merges. (Export the symbol first, then write the test — see the global "export before testing" rule.)
- **One behavior per test.** Each test asserts one behavior and has a name that states it. A test asserting six unrelated things is a smell — split it.
- **AAA in spirit, not letter.** Structure each test as setup → single action → assertions. Do **not** add `// Arrange`/`// Act`/`// Assert` comments (conflicts with the no-inline-comments rule) — the structure should be obvious from the code.

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
