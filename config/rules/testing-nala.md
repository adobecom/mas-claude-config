---
paths:
  - nala/**/*.js
  - nala/**/*.spec.js
  - "**/*.spec.js"
  - "**/tests/**/*.js"
---

# NALA E2E Testing Patterns

## Skills

Use these skills for NALA-related work:

- For running/fixing tests → use `nala-runner` skill (`/nala local @tag`, `/nala fix @tag`)
- For creating/modifying tests → use `nala-writer` skill (`/nala write <description>`)
- For generating page objects → use `nala-page-object-generator` skill

## Key Rule

**ALWAYS use `npm run nala`, NEVER `npx playwright test` directly.**

## Prerequisites

### Required Ports

Before running NALA tests locally, ensure these ports are active:

| Port | Service | Command |
|------|---------|---------|
| 8080 | AEM Server | `aem up` |
| 3000 | Proxy | `npm run proxy` (from studio/) |

### Check Port Status

```bash
lsof -i :8080  # Check AEM
lsof -i :3000  # Check proxy
```

### Quick Start

```bash
# From milo project
aem up

# From studio/
npm run proxy

# Run tests (ALWAYS use npm run nala, NEVER npx playwright test)
npm run nala -- --grep @tag
```

### Slash Command Examples

```
/nala local @tag          # run tests locally by tag
/nala fix @tag            # run and fix failing tests
/nala write <description> # create new tests
```

## Test Structure

### Page Object Pattern

```javascript
// nala/blocks/merch-card/merch-card.page.js
export default class MerchCard {
    constructor(page) {
        this.page = page;

        // Selectors
        this.card = page.locator('merch-card');
        this.badge = this.card.locator('[slot="badge"]');
        this.heading = this.card.locator('[slot="heading-xs"]');
        this.price = this.card.locator('[slot="price"]');
        this.cta = this.card.locator('[slot="cta"] a');
    }

    async getBadgeText() {
        return this.badge.textContent();
    }

    async clickCTA() {
        await this.cta.click();
    }
}
```

### Spec File Pattern

```javascript
// nala/blocks/merch-card/merch-card.spec.js
import { test, expect } from '@playwright/test';
import MerchCard from './merch-card.page.js';

test.describe('Merch Card', () => {
    test('displays badge correctly', async ({ page }) => {
        await page.goto('/test-page');
        const merchCard = new MerchCard(page);

        await expect(merchCard.badge).toBeVisible();
        expect(await merchCard.getBadgeText()).toBe('Best Value');
    });
});
```

## Selectors Best Practices

### Prefer Stability Over Convenience

```javascript
// GOOD: Stable selectors
page.locator('[slot="badge"]')
page.locator('[data-testid="checkout-cta"]')
page.locator('merch-card[variant="catalog"]')

// BAD: Fragile selectors
page.locator('.badge-class')
page.locator('div > span:nth-child(2)')
page.locator('text=Buy now')  // Text can change
```

### Shadow DOM Access

```javascript
// Access shadow DOM content
const shadowHost = page.locator('merch-card');
const shadowContent = shadowHost.locator('>> .inner-element');
```

## Waiting Patterns

### Wait for Network Idle

```javascript
await page.goto('/test-page', { waitUntil: 'networkidle' });
```

### Wait for Element State

```javascript
// Wait for visibility
await expect(card).toBeVisible({ timeout: 5000 });

// Wait for text content
await expect(card).toContainText('Expected text');

// Wait for attribute
await expect(card).toHaveAttribute('variant', 'catalog');
```

### Avoid Arbitrary Timeouts

```javascript
// BAD: Arbitrary wait
await page.waitForTimeout(2000);

// GOOD: Wait for specific condition
await page.waitForSelector('merch-card[ready]');
await expect(card).toBeVisible();
```

## Test Tags

Use tags for selective test execution:

```javascript
test('feature test @smoke', async ({ page }) => {
    // Runs with: npm run nala -- --grep @smoke
});

test('comprehensive test @regression', async ({ page }) => {
    // Runs with: npm run nala -- --grep @regression
});
```

## Environment Configuration

### Test URLs

```javascript
// Local testing
const baseURL = 'http://localhost:8080';

// Stage testing
const baseURL = 'https://stage--mas--adobecom.aem.live';

// Use environment variable
const baseURL = process.env.TEST_URL || 'http://localhost:8080';
```

### URL Parameters

```javascript
// Test with local MAS components
await page.goto('/test-page?maslibs=local');

// Test with feature branch
await page.goto('/test-page?maslibs=feature-branch-name');

// Test with local Milo
await page.goto('/test-page?milolibs=local');
```

## Common Test Patterns

### Visual Comparison

```javascript
test('card renders correctly', async ({ page }) => {
    await page.goto('/test-page');
    await expect(page.locator('merch-card')).toHaveScreenshot('merch-card.png');
});
```

### API Mocking

```javascript
test('handles API error', async ({ page }) => {
    await page.route('**/api/fragments/*', route => {
        route.fulfill({ status: 500 });
    });

    await page.goto('/test-page');
    await expect(page.locator('.error-message')).toBeVisible();
});
```

## E2E Anti-Patterns (NEVER DO)

These were identified by **afmicka** (NALA maintainer) in PR review:

### 1. Do NOT filter/split the features array in test files
Every entry in the spec's `features` array must map 1:1 to exactly one test block. Never use `.filter()` or `.find()` on `features` to split them into groups. If different flows are needed, use separate spec+test file pairs.

### 2. Do NOT use route interception to simulate feature state
`page.route()` overriding API responses is not a real E2E experience. Instead, ask the user for a real fragment that naturally has the desired state (e.g., a fragment where the setting is disabled). Never mock backend data to force a condition.

### 3. Use dedicated fr_FR fragments, not en_GB
Tests should use fragments created specifically for nala, in `fr_FR` locale. Using `en_GB` risks collision with fragments used in other test suites.

## Related Skills

- `nala-runner` - Run, debug, and fix NALA tests (`/nala local @tag`, `/nala fix @tag`)
- `nala-writer` - Write and modify NALA tests (`/nala write <description>`)
- `nala-page-object-generator` - Generate page objects and spec scaffolding
