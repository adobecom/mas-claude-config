---
paths:
  - studio/src/**/*.js
  - web-components/**/*.js
  - web-components/src/**/*.js
---

# MAS Code Conventions

## Spectrum Web Components

### Import Location

All Spectrum Web Component imports go in `/studio/src/swc.js`:

```javascript
// In swc.js (centralized registry)
import '@spectrum-web-components/button/sp-button.js';
import '@spectrum-web-components/action-button/sp-action-button.js';

// NOT in individual component files
```

**Why**: swc.js is bundled globally - imports here are available everywhere.

### Styling Spectrum Components

**Never use `::part()` selectors**. Instead use:

1. CSS custom properties (design tokens)
2. Component attributes/properties
3. Wrapper elements with styling
4. Spectrum's built-in theming (theme/scale/color attributes)

```css
/* BAD */
sp-button::part(base) { background: red; }

/* GOOD */
sp-button {
    --spectrum-button-background-color: red;
}
```

## Component Patterns

### Getter Pattern (Preferred)

Use getters for DOM element access instead of querySelector in methods:

```javascript
// GOOD: Reusable getter
get badge() {
    return this.card.querySelector('[slot="badge"]');
}

renderLayout() {
    return html`${this.badge
        ? html`<div class="badge-wrapper"><slot name="badge"></slot></div>`
        : html`<slot name="badge" hidden></slot>`}`;
}

// BAD: querySelector in render method
renderLayout() {
    const badge = this.card.querySelector('[slot="badge"]');
    // ...
}
```

### Store Subscriptions

Use reactive stores for state management:

```javascript
connectedCallback() {
    super.connectedCallback();
    this.unsubscribe = store.subscribe((state) => {
        this.state = state;
        this.requestUpdate();
    });
}

disconnectedCallback() {
    super.disconnectedCallback();
    this.unsubscribe?.();
}
```

## Dead Code Cleanup (Mandatory)

After ANY file modification, check for and remove:

- [ ] Unused functions (no callers)
- [ ] Unused variables/constants
- [ ] Unused imports
- [ ] Commented-out code blocks
- [ ] Empty event listeners
- [ ] Orphaned helper functions
- [ ] Unreachable conditional branches
- [ ] Console.logs (unless intentional)

### Verification Steps

1. Search for all function/variable references
2. Use grep to find usages across codebase
3. Check if imports are still needed
4. Remove obsolete code from your changes
5. Run linter: `npm run lint:fix`

## Component-Level Solutions First

### Decision Tree for Fixes

1. **Can a getter/method in the component solve it?** → Do that
2. **Can conditional rendering solve it?** → Do that
3. **Can CSS in the component solve it?** → Do that
4. **Only if none work** → Consider shared utilities

### Files to NEVER Modify for Component-Specific Behavior

- `hydrate.js` - shared fragment hydration
- `merch-card.js` - base card implementation
- Any `src/*.js` root file imported by multiple components

## Naming Conventions

- No variables starting with underscore
- No inline comments unless asked
- No inline styles in HTML tags

## Build Requirements

After changes to `web-components/`:
```bash
npm run build  # Runs tests AND compiles Lit components
```

## Related Skills

- `mas-coding-conventions` - Enforce coding conventions
- `component-import-checker` - Verify Spectrum imports
- `lit-component-scaffolder` - Generate new components
- `dead-code-cleanup` - Auto-detect unused code
