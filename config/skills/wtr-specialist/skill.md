---
name: wtr-specialist
description: Write and debug Web Test Runner (WTR) unit tests for MAS Studio components. Use when writing unit tests, debugging test failures, or setting up component test fixtures. Activates on "unit test", "wtr", "web test runner", "component test", "test fixture", "mock store", "@open-wc/testing".
---

# Web Test Runner (WTR) Specialist

## Purpose
Create and debug unit tests for MAS Studio components using Web Test Runner with @open-wc/testing. Provides patterns for testing Lit components, reactive stores, and complex component interactions.

## When to Activate
### Automatic Triggers
- Creating new component that needs unit tests
- Debugging failing WTR tests
- Setting up component test fixtures
- Testing reactive store behavior

### Explicit Activation
- "write unit tests for this component"
- "debug wtr test failure"
- "create test fixture"
- "test store subscriptions"
- "mock aem client"

## Critical Files
- `studio/test/*.test.html` - Test entry points
- `studio/test/*.test.js` - Test implementations
- `studio/web-test-runner.config.mjs` - WTR configuration
- `studio/package.json` - Test scripts and dependencies

## Test Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WTR TEST STRUCTURE                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   studio/test/                                                       │
│   ├── component.test.html        # HTML entry (imports test.js)     │
│   ├── component.test.js          # Test implementation              │
│   ├── fixtures/                                                      │
│   │   ├── fragment-fixtures.js   # Fragment test data               │
│   │   ├── store-fixtures.js      # Store mock data                  │
│   │   └── aem-mock.js            # AEM client mock                  │
│   └── helpers/                                                       │
│       ├── test-utils.js          # Common utilities                 │
│       └── async-helpers.js       # Async testing helpers            │
│                                                                      │
│   Run: npm run test:unit                                            │
│   Watch: npm run test:unit:watch                                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Basic Test Structure

### HTML Entry Point
```html
<!-- studio/test/my-component.test.html -->
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>My Component Tests</title>
</head>
<body>
    <script type="module" src="./my-component.test.js"></script>
</body>
</html>
```

### Test Implementation
```javascript
// studio/test/my-component.test.js
import { expect, fixture, html, oneEvent } from '@open-wc/testing';
import { stub, spy } from 'sinon';

// Import component under test
import '../src/my-component.js';

describe('MyComponent', () => {
    let element;

    beforeEach(async () => {
        element = await fixture(html`
            <my-component></my-component>
        `);
    });

    afterEach(() => {
        // Cleanup
    });

    it('renders correctly', () => {
        expect(element).to.exist;
        expect(element).shadowDom.to.equal(`
            <div class="container">
                <slot></slot>
            </div>
        `);
    });

    it('updates on property change', async () => {
        element.title = 'New Title';
        await element.updateComplete;

        expect(element.shadowRoot.querySelector('h1').textContent)
            .to.equal('New Title');
    });
});
```

## Component Testing Patterns

### 1. Testing Lit Components

```javascript
import { expect, fixture, html, elementUpdated } from '@open-wc/testing';
import '../src/mas-toolbar.js';

describe('MasToolbar', () => {
    let toolbar;

    beforeEach(async () => {
        toolbar = await fixture(html`
            <mas-toolbar></mas-toolbar>
        `);
    });

    it('has default properties', () => {
        expect(toolbar.editing).to.be.false;
        expect(toolbar.saving).to.be.false;
    });

    it('shows save button when editing', async () => {
        toolbar.editing = true;
        await toolbar.updateComplete;

        const saveButton = toolbar.shadowRoot.querySelector('#save-btn');
        expect(saveButton).to.exist;
        expect(saveButton.disabled).to.be.false;
    });

    it('disables save button while saving', async () => {
        toolbar.editing = true;
        toolbar.saving = true;
        await toolbar.updateComplete;

        const saveButton = toolbar.shadowRoot.querySelector('#save-btn');
        expect(saveButton.disabled).to.be.true;
    });

    it('dispatches save event on button click', async () => {
        toolbar.editing = true;
        await toolbar.updateComplete;

        const saveButton = toolbar.shadowRoot.querySelector('#save-btn');
        const savePromise = oneEvent(toolbar, 'save');

        saveButton.click();

        const event = await savePromise;
        expect(event).to.exist;
        expect(event.type).to.equal('save');
    });
});
```

### 2. Testing with Slots

```javascript
import { expect, fixture, html } from '@open-wc/testing';
import '../src/mas-card.js';

describe('MasCard with slots', () => {
    it('renders slotted content', async () => {
        const element = await fixture(html`
            <mas-card>
                <span slot="title">Card Title</span>
                <p slot="body">Card body content</p>
            </mas-card>
        `);

        const titleSlot = element.shadowRoot.querySelector('slot[name="title"]');
        const assignedNodes = titleSlot.assignedNodes();

        expect(assignedNodes).to.have.length(1);
        expect(assignedNodes[0].textContent).to.equal('Card Title');
    });

    it('handles empty slots gracefully', async () => {
        const element = await fixture(html`
            <mas-card></mas-card>
        `);

        const titleSlot = element.shadowRoot.querySelector('slot[name="title"]');
        expect(titleSlot.assignedNodes()).to.have.length(0);
    });
});
```

### 3. Testing Async Operations

```javascript
import { expect, fixture, html, waitUntil } from '@open-wc/testing';
import { stub } from 'sinon';
import '../src/mas-fragment-editor.js';

describe('MasFragmentEditor async', () => {
    let element;
    let fetchStub;

    beforeEach(async () => {
        // Mock fetch
        fetchStub = stub(window, 'fetch').resolves(
            new Response(JSON.stringify({
                id: 'test-123',
                fields: [{ name: 'title', value: 'Test' }]
            }))
        );

        element = await fixture(html`
            <mas-fragment-editor fragment-id="test-123">
            </mas-fragment-editor>
        `);
    });

    afterEach(() => {
        fetchStub.restore();
    });

    it('loads fragment on connect', async () => {
        await waitUntil(
            () => element.fragment !== null,
            'Fragment should be loaded',
            { timeout: 2000 }
        );

        expect(element.fragment.id).to.equal('test-123');
        expect(fetchStub.calledOnce).to.be.true;
    });

    it('shows loading state', async () => {
        // Create new element to catch loading state
        const newElement = document.createElement('mas-fragment-editor');
        newElement.setAttribute('fragment-id', 'test-456');

        document.body.appendChild(newElement);

        expect(newElement.loading).to.be.true;

        await waitUntil(() => !newElement.loading);
        expect(newElement.loading).to.be.false;

        document.body.removeChild(newElement);
    });
});
```

## Store Testing Patterns

### 4. Testing Reactive Stores

```javascript
import { expect } from '@open-wc/testing';
import { ReactiveStore } from '../src/reactivity/reactive-store.js';

describe('ReactiveStore', () => {
    let store;

    beforeEach(() => {
        store = new ReactiveStore({ count: 0 });
    });

    it('initializes with default value', () => {
        expect(store.get()).to.deep.equal({ count: 0 });
    });

    it('updates value with set', () => {
        store.set({ count: 5 });
        expect(store.get().count).to.equal(5);
    });

    it('notifies subscribers on change', () => {
        let notified = false;
        let newValue;

        store.subscribe(value => {
            notified = true;
            newValue = value;
        });

        store.set({ count: 10 });

        expect(notified).to.be.true;
        expect(newValue.count).to.equal(10);
    });

    it('allows unsubscription', () => {
        let callCount = 0;

        const unsubscribe = store.subscribe(() => {
            callCount++;
        });

        store.set({ count: 1 });
        expect(callCount).to.equal(1);

        unsubscribe();

        store.set({ count: 2 });
        expect(callCount).to.equal(1); // No additional call
    });
});
```

### 5. Testing Store Integration

```javascript
import { expect, fixture, html, waitUntil } from '@open-wc/testing';
import { Store } from '../src/store.js';
import '../src/mas-filter-panel.js';

describe('MasFilterPanel with Store', () => {
    let element;
    let originalFilters;

    beforeEach(async () => {
        // Save original store state
        originalFilters = Store.filters.get();

        // Reset store
        Store.filters.set({ locale: 'en_US', tags: [] });

        element = await fixture(html`
            <mas-filter-panel></mas-filter-panel>
        `);
    });

    afterEach(() => {
        // Restore store state
        Store.filters.set(originalFilters);
    });

    it('reflects store state', () => {
        const localeSelect = element.shadowRoot.querySelector('#locale');
        expect(localeSelect.value).to.equal('en_US');
    });

    it('updates store on user interaction', async () => {
        const localeSelect = element.shadowRoot.querySelector('#locale');

        // Simulate selection
        localeSelect.value = 'ja';
        localeSelect.dispatchEvent(new Event('change'));

        await element.updateComplete;

        expect(Store.filters.get().locale).to.equal('ja');
    });

    it('reacts to external store changes', async () => {
        Store.filters.set({ locale: 'fr_FR', tags: [] });

        await waitUntil(() =>
            element.shadowRoot.querySelector('#locale').value === 'fr_FR'
        );

        expect(element.locale).to.equal('fr_FR');
    });
});
```

## Mock Patterns

### 6. AEM Client Mock

```javascript
// studio/test/mocks/aem-mock.js
export class MockAemClient {
    constructor(responses = {}) {
        this.responses = responses;
        this.calls = [];
    }

    async fetchFragment(id) {
        this.calls.push({ method: 'fetchFragment', args: [id] });
        return this.responses[id] || null;
    }

    async saveFragment(id, data) {
        this.calls.push({ method: 'saveFragment', args: [id, data] });
        return { success: true, etag: '"new-etag"' };
    }

    async searchFragments(query) {
        this.calls.push({ method: 'searchFragments', args: [query] });
        return this.responses.search || [];
    }

    getCallsTo(method) {
        return this.calls.filter(c => c.method === method);
    }

    reset() {
        this.calls = [];
    }
}

// Usage in test
import { MockAemClient } from './mocks/aem-mock.js';

describe('Component with AEM', () => {
    let mockAem;

    beforeEach(() => {
        mockAem = new MockAemClient({
            'test-123': {
                id: 'test-123',
                title: 'Test Fragment',
                fields: []
            }
        });

        // Inject mock
        window.__aemClient = mockAem;
    });

    it('fetches fragment via AEM client', async () => {
        const element = await fixture(html`
            <my-element fragment-id="test-123"></my-element>
        `);

        await element.updateComplete;

        expect(mockAem.getCallsTo('fetchFragment')).to.have.length(1);
    });
});
```

### 7. Fragment Fixtures

```javascript
// studio/test/fixtures/fragment-fixtures.js
export const FRAGMENT_FIXTURES = {
    catalog: {
        id: 'catalog-001',
        path: '/content/dam/mas/commerce/en_US/catalog-001',
        etag: '"abc123"',
        variant: 'catalog',
        locale: 'en_US',
        fields: [
            { name: 'variant', value: 'catalog' },
            { name: 'title', value: 'Test Catalog Card' },
            { name: 'body', value: '<p>Body content</p>' },
            { name: 'osi', value: 'CEE1EC6E57B34A26B5CC0D4E3214E2F9' },
            { name: 'ctas', values: ['buy-now', 'learn-more'] }
        ]
    },

    slice: {
        id: 'slice-001',
        path: '/content/dam/mas/ccd/en_US/slice-001',
        variant: 'ccd-slice',
        fields: [
            { name: 'variant', value: 'ccd-slice' },
            { name: 'title', value: 'Slice Card' },
            { name: 'badge', value: 'NEW' }
        ]
    },

    variation: {
        id: 'variation-ja-001',
        path: '/content/dam/mas/commerce/ja/variation-ja-001',
        locale: 'ja',
        parentFragmentId: 'catalog-001',
        fields: [
            { name: 'title', value: 'テストカタログカード' },
            { name: 'body', value: '<p>日本語コンテンツ</p>' }
        ]
    }
};

export function createFragment(type, overrides = {}) {
    const base = FRAGMENT_FIXTURES[type];
    return {
        ...base,
        ...overrides,
        fields: overrides.fields || base.fields
    };
}
```

## Event Testing

### 8. Testing Custom Events

```javascript
import { expect, fixture, html, oneEvent } from '@open-wc/testing';
import '../src/mas-field.js';

describe('MasField events', () => {
    it('dispatches field-change on input', async () => {
        const element = await fixture(html`
            <mas-field name="title" value="initial"></mas-field>
        `);

        const input = element.shadowRoot.querySelector('input');

        setTimeout(() => {
            input.value = 'updated';
            input.dispatchEvent(new Event('input'));
        });

        const event = await oneEvent(element, 'field-change');

        expect(event.detail.name).to.equal('title');
        expect(event.detail.value).to.equal('updated');
        expect(event.detail.previousValue).to.equal('initial');
    });

    it('cancellable events prevent default', async () => {
        const element = await fixture(html`
            <mas-field name="protected"></mas-field>
        `);

        element.addEventListener('field-change', (e) => {
            e.preventDefault();
        });

        const input = element.shadowRoot.querySelector('input');
        input.value = 'new value';
        input.dispatchEvent(new Event('input'));

        await element.updateComplete;

        // Value should not change because event was prevented
        expect(element.value).to.not.equal('new value');
    });
});
```

## WTR Configuration

### web-test-runner.config.mjs
```javascript
import { esbuildPlugin } from '@web/dev-server-esbuild';
import { playwrightLauncher } from '@web/test-runner-playwright';

export default {
    files: 'test/**/*.test.js',
    nodeResolve: true,
    browsers: [
        playwrightLauncher({ product: 'chromium' })
    ],
    plugins: [
        esbuildPlugin({ ts: false })
    ],
    testFramework: {
        config: {
            timeout: 5000
        }
    },
    coverageConfig: {
        include: ['src/**/*.js'],
        exclude: ['src/swc.js'],
        threshold: {
            statements: 80,
            branches: 75,
            functions: 80,
            lines: 80
        }
    }
};
```

## Running Tests

```bash
# Run all unit tests
npm run test:unit

# Run with watch mode
npm run test:unit:watch

# Run specific test file
npx wtr test/my-component.test.js

# Run with coverage
npx wtr --coverage

# Debug mode (opens browser)
npx wtr --manual
```

## Debugging Tips

### Debug in Browser
```javascript
// Add debugger statement
it('debug this test', async () => {
    const element = await fixture(html`<my-component></my-component>`);
    debugger; // Execution stops here in devtools
    expect(element).to.exist;
});
```

### Verbose Output
```javascript
it('shows debug info', async () => {
    const element = await fixture(html`<my-component></my-component>`);

    console.log('Element:', element);
    console.log('Shadow DOM:', element.shadowRoot.innerHTML);
    console.log('Properties:', element.toJSON?.());
});
```

## Success Criteria
- [ ] Test file created with proper structure
- [ ] Component fixture renders correctly
- [ ] Properties and attributes tested
- [ ] Events and interactions tested
- [ ] Store integration tested
- [ ] Async operations properly awaited
- [ ] Mocks cleaned up after tests
- [ ] Coverage meets threshold
