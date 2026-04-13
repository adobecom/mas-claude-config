---
name: nala-runner
description: "Run, debug, and fix NALA E2E tests. Handles test execution with npm run nala, environment pre-flight checks, failure diagnosis, and automated fixing. Use when running tests, debugging failures, fixing broken tests, or checking if tests pass. Activates on: 'run nala', 'nala test', 'fix nala', 'nala failing', 'debug nala', 'check tests', 'test this'."
---

# NALA Test Runner

You are an expert at running, debugging, and fixing MAS NALA E2E tests.

## CRITICAL RULES

1. **ALWAYS use `npm run nala`** — NEVER use `npx playwright test` directly
2. **ALWAYS run pre-flight checks** before executing tests
3. **Read the test files before fixing** — understand what the test does before changing it
4. **Max 3 fix iterations** — if a test still fails after 3 fixes, ask the user

## Phase 1: Parse Intent

Determine what to run and whether this is run-only or fix mode.

**Run mode indicators:** "run", "execute", "check", "test this"
**Fix mode indicators:** "fix", "failing", "broken", "debug", "not passing"

**Extract target from user message:**
- Tag: `@commerce-fries-css` → `-g=@commerce-fries-css`
- File: `fries_css.test.js` → `fries_css.test.js`
- Component name: "fries tests" → find the tag by grepping spec files
- All: no target specified → run all tests (confirm with user first)

**To find test tag from component name:**
```bash
grep -r "name: '@" nala/studio/ --include="*.spec.js" | grep -i "{component}"
```

## Phase 2: Pre-flight Checks

Run these checks BEFORE executing any test:

```bash
# Check AEM server (port 8080)
lsof -i :8080 | head -3

# Check proxy (port 3000)
lsof -i :3000 | head -3
```

**If either port is down:**
1. Tell the user the services need to be started
2. Invoke `/start-mas` skill to start them
3. Wait for services to be ready before continuing

**Check auth state (for studio tests only):**
```bash
test -f nala/.auth/user.json && echo "Auth state exists" || echo "No auth state - will authenticate on first run"
```

## Phase 3: Execute Tests

### Command Reference

```bash
# By tag (most common)
npm run nala local -g=@tag

# By file
npm run nala local fries_css.test.js

# All tests (rare, confirm first)
npm run nala local

# With headed mode (for debugging)
npm run nala local -g=@tag mode=headed

# With UI mode (Playwright Test UI)
npm run nala local -g=@tag mode=ui

# With debug mode (Playwright Inspector)
npm run nala local -g=@tag mode=debug

# Against a feature branch
npm run nala {branch-name} -g=@tag

# With milolibs
npm run nala local -g=@tag milolibs=local
```

### Project Auto-Detection

- Tags containing `@mas-docs` → `mas-docs-chromium` project (no auth)
- Tags containing `@mas-studio` → `mas-studio-chromium` project (requires auth)
- Default → auto-detected by `nala.run.js` from test file location

### Timeout

Tests have a 45-second timeout with 30-second expect timeout. If the test needs more time, do NOT add arbitrary timeouts. Instead, use proper Playwright waiting:
```javascript
await expect(element).toBeVisible({ timeout: 30000 });
```

## Phase 4: Parse Output

After test execution, extract:

1. **Pass/fail summary:** Look for "X passed", "X failed", "X skipped" in output
2. **Failing test name:** The test title line before the error
3. **Error type:** Timeout, assertion, element not found, etc.
4. **Expected vs actual:** For assertion failures
5. **Failed step:** Which `test.step()` failed (step-1, step-2, etc.)

## Phase 5: Fix Mode

When in fix mode and a test fails:

### Step 1: Locate the 3 related files

For any failing test, find:
1. **Test file:** The `.test.js` file that failed
2. **Spec file:** The corresponding `.spec.js` file (in `specs/` sibling directory)
3. **Page object:** The `.page.js` file (in parent directory)

For studio.test.js failures, the related files are:
1. `nala/studio/studio.test.js`
2. `nala/studio/studio.spec.js`
3. `nala/studio/studio.page.js`

### Step 2: Read all 3 files

Always read the test, spec, and page object files BEFORE making any changes. Understand what the test is asserting and why.

### Step 3: Match failure to pattern

| Failure Pattern | How to Detect | Fix |
|-----------------|---------------|-----|
| CSS value mismatch | `expected 'rgb(X)' received 'rgb(Y)'` | Update `cssProp` object in page object with actual value |
| Element not found | `locator.waitFor: Timeout`, `waiting for locator` | Update selector in page object. Check the live page to find correct selector |
| Timeout waiting for card | `waitForCardsLoaded` timeout | Ensure `studio.waitForCardsLoaded()` is called. Check if card exists with the fragment ID |
| Fragment not found | No card matches filter, empty results | Verify `data.cardid` in spec file matches an existing fragment |
| Auth redirect | Page URL contains `auth.services.adobe.com` | Delete `nala/.auth/user.json` and re-run (forces fresh auth) |
| Assertion text mismatch | `expected 'X' to contain 'Y'` | Update expected text in test or spec `data` object |
| Spectrum component not ready | Spectrum element actions fail | Add `await expect(element).toBeVisible()` before interacting |
| Lazy loading timeout | Cards never appear after navigation | Ensure `scrollIntoViewIfNeeded()` and `waitForCardsLoaded()` are used |
| Promise.allSettled partial | Some validations pass, others fail | Read the individual failure reasons from the results array |
| Stale auth | `401` or `403` network errors | Delete `nala/.auth/user.json` and re-run |
| Strict mode violation | `locator resolved to X elements` | Make selector more specific in page object |
| Navigation timeout | `page.goto: Timeout` | Check if AEM server is running, try `mode=headed` to see what's happening |

### Step 4: Apply fix

- **CSS value changes:** Update the `cssProp` object in the page object. Use the ACTUAL value from the error message.
- **Selector changes:** Update the locator in the page object. Use `[slot="..."]` attributes first, then `[data-testid]`, then component tag+attribute.
- **Test logic changes:** If the test flow needs updating (new step, different assertion), modify the test file.
- **Spec data changes:** If fragment IDs or test data changed, update the spec file.

### Step 5: Re-run

After applying a fix, re-run the same test:
```bash
npm run nala local -g=@{same-tag}
```

If it passes → done. Report the fix to the user.
If it fails with a **different error** → go back to Step 3 with the new error.
If it fails with the **same error** → re-examine the fix, try a different approach.
After 3 failed fix attempts → stop and ask the user for guidance.

## Available Page Objects

These are already registered in `nala/libs/mas-test.js` — import them, don't recreate:

| Import | Page Object | What it covers |
|--------|-------------|----------------|
| `studio` | StudioPage | Navigation, search, cards, clone, save, discard, waitForCardsLoaded |
| `editor` | EditorPage | Fragment fields, RTE, color pickers, links, mnemonics, OSI |
| `ost` | OSTPage | Offer Selector Tool panel |
| `placeholders` | PlaceholdersPage | Placeholder table CRUD and search |
| `translations` | TranslationsPage | Translation project list |
| `translationEditor` | TranslationEditorPage | Translation project editor |
| `versions` | VersionsPage | Version history, compare, restore |
| `webUtil` | WebUtil | CSS verification, attribute verification, scrolling |
| `slice` | CCDSlicePage | CCD Slice card selectors + CSS |
| `suggested` | CCDSuggestedPage | CCD Suggested card selectors + CSS |
| `fries` | COMFriesPage | Commerce Fries card selectors + CSS |
| `trybuywidget` | AHTryBuyWidgetPage | Adobe Home Try-Buy Widget |
| `promotedplans` | AHPromotedPlansPage | Adobe Home Promoted Plans |
| `plans` | ACOMPlansPage | ACOM Plans card |
| `fullPricingExpress` | EXPRESSFullPricingPage | Express Full Pricing card |

## Utility Functions

From `nala/utils/commerce.js`:
- `PRICE_PATTERN` — Country-specific price regex (US, AU, CA, EG, FR)
- `constructTestUrl(baseURL, path, browserParams)` — Build test URLs
- `setupMasConsoleListener(errors)` — Capture console errors
- `setupMasRequestLogger(errors)` — Log failed network requests

From `nala/utils/fragment-tracker.js`:
- `getTitle()` — Returns `MAS.Nala.Automation.{runId}.{testName}`
- `setCurrentTestName(name)` — Set test name for title generation

## Linting

After modifying any test file, run the linter:
```bash
npx eslint {modified-file-path}
```
