---
name: nala-page-object-generator
description: Generate Playwright page objects and selectors for NALA tests. Use when creating new tests, updating selectors, or generating test infrastructure. Activates on "generate page object", "create test selectors", "nala page object", "playwright selectors", "test automation".
---

# NALA Page Object Generator

## Purpose
Automatically generate Playwright page objects and selectors for MAS Studio NALA tests. Analyzes UI components via accessibility tree and generates stable, maintainable selectors following best practices.

**Integration:** This skill works with the `nala-writer` skill. Use `nala-writer` for full test suite generation; use this skill specifically for generating or updating page object selectors.

## When to Activate
### Automatic Triggers
- Creating new NALA test suite
- UI changes requiring selector updates
- Test failures from broken selectors

### Explicit Activation
- "generate page object for editor panel"
- "create selectors for the toolbar"
- "update page object for fragment dialog"

## MCP Tools Used
- `mcp__plugin_playwright_playwright__browser_navigate` - Navigate to Studio
- `mcp__plugin_playwright_playwright__browser_snapshot` - Get accessibility tree
- `mcp__plugin_playwright_playwright__browser_evaluate` - Inspect DOM

## Critical Files
- `nala/studio/` - Existing test structure
- `nala/utils/` - Shared utilities

## Page Object Structure

```
nala/studio/[feature]/
├── [feature].page.js      # Page object with selectors
├── [feature].spec.js      # Test specifications
└── tests/
    ├── [feature]_edit.test.js
    ├── [feature]_save.test.js
    └── [feature]_discard.test.js
```

## Core Workflow

### 1. Capture Accessibility Snapshot
Navigate to Studio and capture UI state:

```javascript
// Use Playwright MCP
await mcp__plugin_playwright_playwright__browser_navigate({ url: 'http://localhost:3000/studio' });
const snapshot = await mcp__plugin_playwright_playwright__browser_snapshot();
```

### 2. Analyze Element Structure
Parse snapshot for interactive elements:

```
Accessibility Tree Analysis:
├── toolbar (role: toolbar)
│   ├── button "Create" (role: button)
│   ├── searchbox "Search fragments" (role: searchbox)
│   ├── button "Filters" (role: button)
│   └── combobox "Locale" (role: combobox)
├── main (role: main)
│   ├── grid "Fragments" (role: grid)
│   │   └── gridcell (role: gridcell) × 24
│   └── region "Editor Panel" (role: region)
│       ├── textbox "Title" (role: textbox)
│       ├── textbox "Description" (role: textbox)
│       └── button "Save" (role: button)
```

### 3. Generate Page Object

```javascript
// nala/studio/editor/editor.page.js
export default class EditorPage {
    constructor(page) {
        this.page = page;
    }

    // Toolbar selectors
    get toolbar() {
        return this.page.getByRole('toolbar');
    }

    get createButton() {
        return this.page.getByRole('button', { name: 'Create' });
    }

    get searchInput() {
        return this.page.getByRole('searchbox', { name: 'Search fragments' });
    }

    get filterButton() {
        return this.page.getByRole('button', { name: 'Filters' });
    }

    get localeSelect() {
        return this.page.getByRole('combobox', { name: 'Locale' });
    }

    // Editor panel selectors
    get editorPanel() {
        return this.page.getByRole('region', { name: 'Editor Panel' });
    }

    get titleField() {
        return this.editorPanel.getByRole('textbox', { name: 'Title' });
    }

    get descriptionField() {
        return this.editorPanel.getByRole('textbox', { name: 'Description' });
    }

    get saveButton() {
        return this.editorPanel.getByRole('button', { name: 'Save' });
    }

    get discardButton() {
        return this.editorPanel.getByRole('button', { name: 'Discard' });
    }

    // Fragment grid
    get fragmentGrid() {
        return this.page.getByRole('grid', { name: 'Fragments' });
    }

    getFragmentCard(name) {
        return this.fragmentGrid.locator('merch-card').filter({ hasText: name });
    }

    // Actions
    async search(query) {
        await this.searchInput.fill(query);
        await this.page.keyboard.press('Enter');
    }

    async selectLocale(locale) {
        await this.localeSelect.click();
        await this.page.getByRole('option', { name: locale }).click();
    }

    async openFragment(name) {
        await this.getFragmentCard(name).click();
    }

    async editTitle(newTitle) {
        await this.titleField.clear();
        await this.titleField.fill(newTitle);
    }

    async save() {
        await this.saveButton.click();
        await this.page.waitForSelector('[data-toast="saved"]');
    }

    async discard() {
        await this.discardButton.click();
    }
}
```

### 4. Generate Test Spec

```javascript
// nala/studio/editor/editor.spec.js
module.exports = {
    name: 'Editor Panel',
    features: [
        {
            name: '@editor-edit-title',
            path: '/studio',
            tags: '@mas-studio @editor @smoke',
            data: {
                fragmentName: 'Test Fragment',
                newTitle: 'Updated Title',
            },
        },
        {
            name: '@editor-save-changes',
            path: '/studio',
            tags: '@mas-studio @editor @regression',
            data: {
                fragmentName: 'Test Fragment',
            },
        },
    ],
};
```

### 5. Generate Test File

```javascript
// nala/studio/editor/tests/editor_edit.test.js
import { test, expect } from '@playwright/test';
import EditorPage from '../editor.page.js';
import spec from '../editor.spec.js';

const { features } = spec;

test.describe('Editor Panel Tests', () => {
    let editorPage;

    test.beforeEach(async ({ page }) => {
        editorPage = new EditorPage(page);
        await page.goto('/studio');
    });

    features.forEach((feature) => {
        test(`${feature.name} ${feature.tags}`, async ({ page }) => {
            // Open fragment
            await editorPage.openFragment(feature.data.fragmentName);

            // Edit title
            if (feature.data.newTitle) {
                await editorPage.editTitle(feature.data.newTitle);
                await expect(editorPage.titleField).toHaveValue(feature.data.newTitle);
            }

            // Save if required
            if (feature.name.includes('save')) {
                await editorPage.save();
                await expect(page.locator('[data-toast="saved"]')).toBeVisible();
            }
        });
    });
});
```

## Selector Strategies

### Priority Order
1. **Slot attributes** - Most stable (e.g. `[slot="heading-xxs"]`)
2. **Data attributes** - Explicit, reliable (e.g. `[data-testid="checkout-link"]`)
3. **Component tag + attribute** - Scoped and descriptive (e.g. `merch-card[variant="ccd-slice"]`)
4. **CSS classes** - Avoid, fragile

### Selector Examples

```javascript
// Best - Slot attribute
page.locator('[slot="heading-xxs"]')

// Good - Data attribute
page.locator('[data-testid="checkout-link"]')

// Acceptable - Component tag + attribute
page.locator('merch-card[variant="ccd-slice"]')

// Avoid - Fragile CSS
page.locator('div.toolbar > button:nth-child(2)')
```

### Scoped Selectors

```javascript
// Scope to parent element
const editorPanel = page.getByRole('region', { name: 'Editor Panel' });
const saveButton = editorPanel.getByRole('button', { name: 'Save' });

// Better than global selector
const saveButton = page.locator('#editor sp-button[variant="accent"]');
```

## MAS Studio Common Selectors

### Toolbar
```javascript
toolbar: page.getByRole('toolbar')
createButton: page.getByRole('button', { name: 'Create' })
searchInput: page.getByPlaceholder('Search fragments')
filterButton: page.getByRole('button', { name: 'Filters' })
```

### Editor Panel
```javascript
editorPanel: page.locator('editor-panel')
titleField: page.getByRole('textbox', { name: 'Title' })
variantSelect: page.getByRole('combobox', { name: 'Variant' })
saveButton: page.getByRole('button', { name: 'Save' })
```

### Fragment Cards
```javascript
fragmentGrid: page.locator('mas-content')
fragmentCard: page.locator('merch-card')
cardByName: (name) => page.locator('merch-card').filter({ hasText: name })
```

### Dialogs
```javascript
dialog: page.getByRole('dialog')
dialogTitle: page.getByRole('heading', { level: 2 })
confirmButton: page.getByRole('dialog').getByRole('button', { name: 'Confirm' })
```

## Best Practices

### DO
- Use role-based selectors primarily
- Scope selectors to parent elements
- Create reusable action methods
- Add waitFor conditions in actions
- Use meaningful method names

### DON'T
- Use index-based selectors
- Hardcode IDs that may change
- Create overly specific CSS selectors
- Skip waiting for state changes

## Existing Page Objects

Before generating a new page object, check if one already exists:

| Variable | Class | Coverage |
|---|---|---|
| `studio` | `StudioPage` | Navigation, search, cards, clone, save, discard |
| `editor` | `EditorPage` | Fragment fields, RTE, color pickers, links, mnemonics |
| `ost` | `OSTPage` | Offer Selector Tool panel |
| `placeholders` | `PlaceholdersPage` | Placeholder table CRUD |
| `translations` | `TranslationsPage` | Translation project list |
| `translationEditor` | `TranslationEditorPage` | Translation project editor |
| `versions` | `VersionsPage` | Version history, compare, restore |
| `webUtil` | `WebUtil` | CSS verification, attributes, scrolling |

**Card-specific page objects:** `slice`, `suggested`, `fries`, `trybuywidget`, `promotedplans`, `plans`, `fullPricingExpress`

## Success Criteria
- [ ] Accessibility snapshot captured
- [ ] All interactive elements identified
- [ ] Page object class generated
- [ ] Selectors prioritize stability
- [ ] Action methods included
- [ ] Test spec generated
- [ ] Basic test file created
