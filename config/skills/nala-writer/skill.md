---
name: nala-writer
description: "Write, create, and modify NALA E2E tests. Handles new test suite creation, test case addition, page object updates, and spec modifications. Use when writing new tests, adding test cases, creating test suites for new features, or modifying existing tests. Activates on: 'write nala test', 'create test for', 'add test case', 'new nala test', 'scaffold test', 'modify nala test', 'update test'."
---

# NALA Test Writer

You are an expert at writing and modifying MAS NALA E2E tests.

## CRITICAL RULES

1. **ALWAYS follow the two-file pattern** — spec file (data) + test file (code), never mix them
2. **ALWAYS reuse existing page objects** from `mas-test.js` — never create duplicates
3. **ALWAYS use `npm run nala` to verify** — run the test after creating it
4. **ALWAYS ask the user for fragment IDs** — never guess or make up UUIDs
5. **Read existing similar tests** as templates before writing new ones

## NALA Anti-Patterns (NEVER DO)

### 1. Do NOT filter or split the features array in test files

Each spec feature entry must map 1:1 to exactly one test block. Never use `.filter()`, `.find()`, or conditional logic on the `features` array to decide which tests to run or how to run them.

**BAD:**
```js
const enabledFeatures = features.filter((f) => !f.data.trialCta);
const disabledFeature = features.find((f) => f.data.trialCta);
// Then different describe blocks for each group
```

**GOOD:** Each feature in the spec array gets its own self-contained test. If different features genuinely need different test flows, create **separate spec+test file pairs**.

### 2. Do NOT use route interception to simulate feature states

E2E tests must reflect real user experiences. Never use `page.route()` to override API responses or modify backend data in flight to simulate a condition. If you need to test "feature X disabled", use a real fragment that naturally has the feature disabled.

**BAD:**
```js
await page.route('**/mas/io/fragment**', async (route) => {
    const response = await route.fetch();
    const json = await response.json();
    json.settings.someFlag = false;
    await route.fulfill({ response, json });
});
```

**GOOD:** Ask the user for a fragment ID that naturally has the desired state, then write a straightforward test against that real data.

### 3. Use dedicated locale fragments — prefer fr_FR over en_GB

Use fragments created specifically for nala testing, in the `fr_FR` locale (not `en_GB`). This avoids collision with fragments used by other tests and prevents accidental regressions between test suites.

## Phase 1: Understand What to Build

### If context is available (e.g., "write tests for the feature we just built"):

```bash
# Check what was recently changed
git diff --name-only HEAD~5

# Identify the component/feature area
git diff --name-only HEAD~5 | grep -E 'studio/src|web-components/src'
```

### If user specifies the target:
- Read the component source code to understand its fields, slots, and CSS properties
- Check if a page object already exists in `mas-test.js`

## Phase 2: Detect Test Category

**Category A — Card variant test** if:
- The feature is a new merch-card variant (acom, ahome, ccd, commerce, express)
- Changes are in `web-components/src/variants/` or `studio/src/` for card rendering
- The test will validate CSS, edit fields, or save card data

**Category B — Studio feature test** if:
- The feature is a Studio UI capability (search, filter, settings, translations, versions, etc.)
- Changes are in `studio/src/` for non-card functionality
- The test validates UI interactions, navigation, or dialogs

**Category C — Docs test** if:
- The feature affects consumer-facing rendering (not Studio)
- Changes are in `web-components/` for rendering behavior
- The test validates events (mas:ready, mas:failed) and DOM output

## Phase 3: Get Fragment ID

**For Category A tests:** Fragment ID is REQUIRED. Ask the user:
> "I need a test fragment ID to create the spec file. This should be an existing fragment in the nala sandbox. What fragment ID should I use?"

**For Category B tests:** Fragment ID is optional. Ask only if the test involves a specific fragment.

**For Category C tests:** Fragment ID is not needed.

**NEVER generate a UUID or use a placeholder.** Wait for the user to provide it.

## Phase 4: Generate Files

### Category A: Card Variant Tests

**Directory structure to create:**
```
nala/studio/{surface}/{variant}/
├── {variant}.page.js
├── specs/
│   ├── {variant}_css.spec.js
│   ├── {variant}_edit_and_discard.spec.js    (if editable)
│   └── {variant}_save.spec.js                (if supports clone/save)
└── tests/
    ├── {variant}_css.test.js
    ├── {variant}_edit_and_discard.test.js     (if editable)
    └── {variant}_save.test.js                 (if supports clone/save)
```

Create these directories first:
```bash
mkdir -p nala/studio/{surface}/{variant}/specs
mkdir -p nala/studio/{surface}/{variant}/tests
```

#### Page Object Template

```javascript
// nala/studio/{surface}/{variant}/{variant}.page.js
export default class {VariantClassName}Page {
    constructor(page) {
        this.page = page;

        // Element selectors — use slot attributes (most stable)
        this.title = page.locator('h3[slot="heading-xxs"]');
        this.price = page.locator('p[slot="price"] span[is="inline-price"]');
        this.description = page.locator('div[slot="body-xxs"]');
        this.cta = page.locator('[slot="cta"] a');

        // CSS properties for visual validation
        this.cssProp = {
            card: {
                'background-color': 'rgb(255, 255, 255)',
                'border-radius': '16px',
                'border-top-color': 'rgb(218, 218, 218)',
            },
            title: {
                color: 'rgb(19, 19, 19)',
                'font-size': '18px',
            },
            price: {
                color: 'rgb(19, 19, 19)',
            },
            cta: {
                'background-color': 'rgb(20, 115, 230)',
                color: 'rgb(255, 255, 255)',
            },
        };
    }
}
```

**To populate CSS values:** Open MAS Studio in headed mode, inspect the card in DevTools, and copy computed CSS values. Or run a quick CSS test that will fail — the error shows actual values.

#### CSS Spec Template

```javascript
// nala/studio/{surface}/{variant}/specs/{variant}_css.spec.js
export default {
    FeatureName: 'M@S Studio {Surface} {Variant}',
    features: [
        {
            tcid: '0',
            name: '@studio-{variant}-css',
            path: '/studio.html',
            data: {
                cardid: '{FRAGMENT_ID}',
            },
            browserParams: '#page=content&path=nala&query=',
            tags: '@mas-studio @{surface} @{surface}-{variant} @{surface}-{variant}-css @{surface}-css',
        },
    ],
};
```

#### CSS Test Template

```javascript
// nala/studio/{surface}/{variant}/tests/{variant}_css.test.js
import { test, expect, studio, {pageObj}, webUtil, miloLibs, setTestPage } from '../../../../libs/mas-test.js';
import {Variant}Spec from '../specs/{variant}_css.spec.js';

const { features } = {Variant}Spec;
const { path, browserParams, data: { cardid } } = features[0];

test.describe('M@S Studio {Surface} {Variant} card test suite', () => {
    test(`${features[0].name},${features[0].tags}`, async ({ page, baseURL }) => {
        const testPage = `${baseURL}${path}${miloLibs}${browserParams}${cardid}`;
        const card = await studio.getCard(cardid);
        setTestPage(testPage);

        await test.step('step-1: Go to MAS Studio test page', async () => {
            await page.goto(testPage);
            await page.waitForLoadState('domcontentloaded');
        });

        await test.step('step-2: Validate card is visible', async () => {
            await studio.waitForCardsLoaded();
            await expect(card).toBeVisible();
        });

        await test.step('step-3: Validate CSS properties', async () => {
            const results = await Promise.allSettled([
                test.step('Card CSS', async () => {
                    expect(await webUtil.verifyCSS(card, {pageObj}.cssProp.card)).toBeTruthy();
                }),
                test.step('Title CSS', async () => {
                    expect(await webUtil.verifyCSS({pageObj}.title, {pageObj}.cssProp.title)).toBeTruthy();
                }),
                test.step('Price CSS', async () => {
                    expect(await webUtil.verifyCSS({pageObj}.price, {pageObj}.cssProp.price)).toBeTruthy();
                }),
                test.step('CTA CSS', async () => {
                    expect(await webUtil.verifyCSS({pageObj}.cta, {pageObj}.cssProp.cta)).toBeTruthy();
                }),
            ]);

            const failures = results
                .filter((r) => r.status === 'rejected')
                .map((r) => `Failed: ${r.reason}`);

            if (failures.length > 0) {
                throw new Error(`CSS validation failures:\n${failures.join('\n')}`);
            }
        });
    });
});
```

#### Edit and Discard Spec Template

```javascript
// nala/studio/{surface}/{variant}/specs/{variant}_edit_and_discard.spec.js
export default {
    FeatureName: 'M@S Studio {Surface} {Variant}',
    features: [
        {
            tcid: '0',
            name: '@studio-{variant}-edit-and-discard',
            path: '/studio.html',
            data: {
                cardid: '{FRAGMENT_ID}',
                editedTitle: 'Edited Test Title',
            },
            browserParams: '#page=content&path=nala&query=',
            tags: '@mas-studio @{surface} @{surface}-{variant} @{surface}-{variant}-edit @{surface}-edit',
        },
    ],
};
```

#### Edit and Discard Test Template

```javascript
// nala/studio/{surface}/{variant}/tests/{variant}_edit_and_discard.test.js
import { test, expect, studio, editor, {pageObj}, webUtil, miloLibs, setTestPage } from '../../../../libs/mas-test.js';
import {Variant}Spec from '../specs/{variant}_edit_and_discard.spec.js';

const { features } = {Variant}Spec;
const { path, browserParams, data: { cardid } } = features[0];

test.describe('M@S Studio {Surface} {Variant} edit and discard test suite', () => {
    test(`${features[0].name},${features[0].tags}`, async ({ page, baseURL }) => {
        const testPage = `${baseURL}${path}${miloLibs}${browserParams}${cardid}`;
        const card = await studio.getCard(cardid);
        setTestPage(testPage);

        await test.step('step-1: Navigate and open editor', async () => {
            await page.goto(testPage);
            await page.waitForLoadState('domcontentloaded');
            await studio.waitForCardsLoaded();
            await card.dblclick();
        });

        await test.step('step-2: Edit title field', async () => {
            await editor.title.click();
            await page.keyboard.press('Meta+A');
            await page.keyboard.press('Backspace');
            await editor.title.fill(features[0].data.editedTitle);
        });

        await test.step('step-3: Validate change in preview', async () => {
            await expect({pageObj}.title).toContainText(features[0].data.editedTitle);
        });

        await test.step('step-4: Discard changes', async () => {
            await studio.discardEditorChanges(editor);
        });

        await test.step('step-5: Verify change was reverted', async () => {
            await expect({pageObj}.title).not.toContainText(features[0].data.editedTitle);
        });
    });
});
```

#### Save Spec Template

```javascript
// nala/studio/{surface}/{variant}/specs/{variant}_save.spec.js
export default {
    FeatureName: 'M@S Studio {Surface} {Variant}',
    features: [
        {
            tcid: '0',
            name: '@studio-{variant}-save',
            path: '/studio.html',
            data: {
                cardid: '{FRAGMENT_ID}',
                editedTitle: 'Saved Test Title',
            },
            browserParams: '#page=content&path=nala&query=',
            tags: '@mas-studio @{surface} @{surface}-{variant} @{surface}-{variant}-save @{surface}-save',
        },
    ],
};
```

#### Save Test Template

```javascript
// nala/studio/{surface}/{variant}/tests/{variant}_save.test.js
import { test, expect, studio, editor, {pageObj}, webUtil, miloLibs, setTestPage, setClonedCardID } from '../../../../libs/mas-test.js';
import {Variant}Spec from '../specs/{variant}_save.spec.js';

const { features } = {Variant}Spec;
const { path, browserParams, data: { cardid } } = features[0];

test.describe('M@S Studio {Surface} {Variant} save test suite', () => {
    test(`${features[0].name},${features[0].tags}`, async ({ page, baseURL }) => {
        const testPage = `${baseURL}${path}${miloLibs}${browserParams}${cardid}`;
        setTestPage(testPage);

        await test.step('step-1: Navigate to test page', async () => {
            await page.goto(testPage);
            await page.waitForLoadState('domcontentloaded');
            await studio.waitForCardsLoaded();
        });

        await test.step('step-2: Clone card', async () => {
            const clonedCardId = await studio.cloneCard(cardid);
            setClonedCardID(clonedCardId);
        });

        await test.step('step-3: Edit cloned card', async () => {
            await editor.title.click();
            await page.keyboard.press('Meta+A');
            await page.keyboard.press('Backspace');
            await editor.title.fill(features[0].data.editedTitle);
        });

        await test.step('step-4: Save card', async () => {
            await studio.saveCard();
        });

        await test.step('step-5: Validate saved changes', async () => {
            const results = await Promise.allSettled([
                test.step('Title saved', async () => {
                    await expect({pageObj}.title).toContainText(features[0].data.editedTitle);
                }),
            ]);

            const failures = results
                .filter((r) => r.status === 'rejected')
                .map((r) => `Failed: ${r.reason}`);

            if (failures.length > 0) {
                throw new Error(`Save validation failures:\n${failures.join('\n')}`);
            }
        });
    });
});
```

### Category B: Studio Feature Tests

**Decide between B1 and B2:**
- **B1 (own directory):** If the feature has 3+ test cases, needs its own page object, or is a large isolated feature (translations, regional-variations, placeholders, versions)
- **B2 (studio.test.js):** If the feature is a small test for core Studio behavior (search, locale change, surface change)

#### B1: Feature with own directory

Same directory structure as Category A but without CSS-specific patterns. Use UI interaction assertions instead.

#### B2: Feature added to studio.test.js

**Step 1:** Add feature entry to `nala/studio/studio.spec.js`:
```javascript
{
    tcid: '{NEXT_TCID}',
    name: '@studio-{feature-name}',
    path: '/studio.html',
    data: {
        // feature-specific test data
    },
    browserParams: '#page=content&path=nala',
    tags: '@mas-studio @{feature-tag}',
},
```

Find the next tcid by reading the existing spec file and incrementing the last one.

**Step 2:** Add test implementation to `nala/studio/studio.test.js`:
```javascript
// @studio-{feature-name} - {description}
test(`${features[N].name},${features[N].tags}`, async ({ page, baseURL }) => {
    const testPage = `${baseURL}${features[N].path}${miloLibs}${features[N].browserParams}`;
    setTestPage(testPage);

    await test.step('step-1: Go to MAS Studio test page', async () => {
        await page.goto(testPage);
        await page.waitForLoadState('domcontentloaded');
    });

    await test.step('step-2: Validate feature behavior', async () => {
        // UI interactions and assertions
    });
});
```

### Category C: Docs Tests

For consumer-facing rendering tests under `nala/docs/`.

```javascript
// Uses @playwright/test directly, NOT mas-test.js
import { test, expect } from '@playwright/test';
```

No auth required. Uses `mas-docs-chromium` project. Event-based assertions (mas:ready, mas:failed, aem:error).

## Phase 5: Register Page Object

If you created a new page object, add it to `nala/libs/mas-test.js`:

1. Add import at the top:
```javascript
import {VariantClassName}Page from '../studio/{surface}/{variant}/{variant}.page.js';
```

2. Add to the `masTest` fixture:
```javascript
{pageObj}: async ({ page }, use) => {
    const obj = new {VariantClassName}Page(page);
    await use(obj);
},
```

3. Export the fixture name.

## Phase 6: Verify

Run the newly created test:
```bash
npm run nala local -g=@studio-{variant}-css
```

If it fails, read the error, fix the issue, and re-run. Common first-run issues:
- Wrong import path (count the `../` levels)
- CSS values don't match (update page object cssProp with actual values)
- Fragment ID doesn't exist (ask user for correct ID)

## Selector Priority

When creating selectors for page objects:

1. **Slot attributes** (most stable): `page.locator('[slot="heading-xxs"]')`
2. **Data attributes**: `page.locator('[data-testid="checkout-link"]')`
3. **Component tag + attribute**: `page.locator('merch-card[variant="ccd-slice"]')`
4. **CSS classes** (avoid, fragile): `page.locator('.my-class')`

## Tag Naming Convention

- **Card tests:** name = `@studio-{variant}-{type}`, tags = `@mas-studio @{surface} @{surface}-{variant} @{surface}-{variant}-{type}`
- **Feature tests:** name = `@studio-{feature-name}`, tags = `@mas-studio @{feature-tag}`
- **Docs tests:** name = `@MAS-DOCS-{feature}`, tags = `@mas-docs`

## Available Imports from mas-test.js

```javascript
import {
    test, expect,
    studio, editor, ost,
    slice, suggested, fries,
    trybuywidget, promotedplans, plans,
    fullPricingExpress,
    placeholders, translations, translationEditor, versions,
    webUtil,
    miloLibs, masIOUrl,
    setClonedCardID, getClonedCardID, setTestPage,
} from '../../../../libs/mas-test.js';  // adjust depth for your location
```

## Fragment Tracker / Run ID System

Save tests that clone fragments use a run ID system for cleanup:
- `createRunId()` generates `nala-run-{timestamp}-{random}` at suite start
- `getTitle()` returns `MAS.Nala.Automation.{runId}.{testName}` — used as fragment title when cloning
- `setClonedCardID(id)` / `getClonedCardID()` — tracks cloned fragment for assertions
- Global teardown searches for fragments matching run ID and deletes them
- Cleanup checks locale paths: `en_US`, `fr_FR`, `en_CA`, `en_GB`, `en_AU`

## Commerce Utilities (nala/utils/commerce.js)

- `PRICE_PATTERN` — Country-specific price regex (US, AU, CA, EG, FR)
- `constructTestUrl(baseURL, path, browserParams)` — Build test URLs
- `setupMasConsoleListener(errors)` — Capture console errors
- `setupMasRequestLogger(errors)` — Log failed network requests
- `createWorkerPageSetup(config)` — Worker-scoped page setup for docs tests

## Linting

After creating or modifying any test file, run:
```bash
npx eslint {file-path}
```
