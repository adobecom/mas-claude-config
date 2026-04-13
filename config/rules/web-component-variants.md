---
paths:
  - web-components/src/variants/**/*.js
  - "**/variant-layout.js"
  - "**/variants.js"
  - web-components/src/**/*.js
---

# Web Component Variants

## Architecture Overview

Merch card variants extend `VariantLayout` base class and register via `registerVariant()`:

```
VariantLayout (base)
    ├── Catalog
    ├── Plans
    ├── Product
    ├── Segment
    ├── SpecialOffer
    ├── Mini
    └── ... (36+ variants)
```

## Creating a New Variant

### 1. Create Variant Class

```javascript
// variants/my-variant.js
import { VariantLayout } from './variant-layout.js';
import { html, css } from 'lit';
import { CSS } from './my-variant.css.js';

export const MY_VARIANT_AEM_FRAGMENT_MAPPING = {
    cardName: { attribute: 'name' },
    badge: true,
    ctas: { slot: 'footer', size: 'm' },
    description: { tag: 'div', slot: 'body-xs' },
    mnemonics: { size: 'l' },
    prices: { tag: 'h3', slot: 'heading-xs' },
    title: { tag: 'h3', slot: 'heading-xs' },
    size: ['wide', 'super-wide'],
};

export class MyVariant extends VariantLayout {
    constructor(card) {
        super(card);
    }

    renderLayout() {
        return html`
            <div class="body">
                <slot name="icons"></slot>
                ${this.badge}
                <slot name="heading-xs"></slot>
                <slot name="body-xs"></slot>
            </div>
            ${this.secureLabelFooter}
        `;
    }

    getGlobalCSS() {
        return CSS;
    }

    static variantStyle = css`
        :host([variant='my-variant']) {
            min-height: 300px;
            width: var(--consonant-merch-card-my-variant-width);
        }
    `;
}
```

### 2. Create CSS File

```javascript
// variants/my-variant.css.js
export const CSS = `
    merch-card[variant="my-variant"] .body {
        padding: var(--consonant-merch-spacing-s);
    }

    merch-card[variant="my-variant"] [slot="heading-xs"] {
        font-size: var(--consonant-merch-card-heading-xs-font-size);
    }
`;
```

### 3. Register Variant

```javascript
// variants/variants.js
import { MyVariant, MY_VARIANT_AEM_FRAGMENT_MAPPING } from './my-variant.js';

registerVariant(
    'my-variant',           // Variant name
    MyVariant,              // Class
    MY_VARIANT_AEM_FRAGMENT_MAPPING,  // AEM field mapping
    MyVariant.variantStyle, // Static CSS
    MyVariant.collectionOptions, // Optional collection options
);
```

## AEM Fragment Mapping

Define how AEM fields map to card slots:

```javascript
const MAPPING = {
    // Simple boolean (standard handling)
    badge: true,

    // Attribute mapping
    cardName: { attribute: 'name' },

    // Slot with tag wrapper
    title: { tag: 'h3', slot: 'heading-xs' },
    description: { tag: 'div', slot: 'body-xs' },

    // Slot with extra attributes
    shortDescription: {
        tag: 'div',
        slot: 'action-menu-content',
        attributes: { tabindex: '0' },
    },

    // CTAs with button size
    ctas: { slot: 'footer', size: 'm' },

    // Mnemonics with icon size
    mnemonics: { size: 'l' },

    // Allowed size classes
    size: ['wide', 'super-wide'],
};
```

## VariantLayout Base Class

### Inherited Properties

| Property | Description |
|----------|-------------|
| `this.card` | The merch-card element |
| `this.badge` | Rendered badge HTML |
| `this.cardImage` | Image with badge |
| `this.secureLabel` | Secure transaction label |
| `this.secureLabelFooter` | Footer with secure label |
| `this.evergreen` | Has `intro-pricing` class |
| `this.promoBottom` | Has `promo-bottom` class |

### Lifecycle Hooks

```javascript
class MyVariant extends VariantLayout {
    connectedCallbackHook() {
        // Called when card connects to DOM
        this.card.addEventListener('mouseenter', this.handler);
    }

    disconnectedCallbackHook() {
        // Called when card disconnects - MUST clean up
        this.card.removeEventListener('mouseenter', this.handler);
    }

    async postCardUpdateHook() {
        // Called after card updates
        await this.adjustTitleWidth();
    }

    syncHeights() {
        // Called when all cards in collection ready
        this.updateCardElementMinHeight(element, 'section-name');
    }
}
```

### Helper Methods

```javascript
// Get container (collection or parent)
const container = this.getContainer();

// Update min-height CSS property for alignment
this.updateCardElementMinHeight(element, 'heading');

// Adjust title width for badge overlap
await this.adjustTitleWidth();
```

## CSS Organization

### Global CSS (getGlobalCSS)

Injected once per variant into document head:

```javascript
getGlobalCSS() {
    return CSS;  // From .css.js file
}

// In .css.js
export const CSS = `
    merch-card[variant="catalog"] { ... }
`;
```

### Variant Style (static variantStyle)

Applied per-card via adoptedStyleSheets:

```javascript
static variantStyle = css`
    :host([variant='catalog']) {
        min-height: 330px;
    }
`;
```

## Slot Patterns

### Standard Slots

```html
<slot name="icons"></slot>      <!-- Mnemonic icons -->
<slot name="heading-xs"></slot> <!-- Title/price -->
<slot name="body-xs"></slot>    <!-- Description -->
<slot name="footer"></slot>     <!-- CTAs -->
<slot name="promo-text"></slot> <!-- Promotional text -->
```

### Conditional Slots

```javascript
renderLayout() {
    return html`
        ${!this.promoBottom
            ? html`<slot name="promo-text"></slot>`
            : ''}
        <slot name="body-xs"></slot>
        ${this.promoBottom
            ? html`<slot name="promo-text"></slot>`
            : ''}
    `;
}
```

## Action Menu Pattern

For variants with expandable menus:

```javascript
get actionMenu() {
    return this.card.shadowRoot.querySelector('.action-menu');
}

toggleActionMenu = (e) => {
    if (e.type !== 'click' && e.code !== 'Space') return;
    e.preventDefault();
    this.setMenuVisibility(!this.isMenuOpen());
};

connectedCallbackHook() {
    this.card.addEventListener('keydown', this.handleKeyDown);
}

disconnectedCallbackHook() {
    this.card.removeEventListener('keydown', this.handleKeyDown);
}
```

## Mobile/Responsive Patterns

```javascript
import { isMobileOrTablet } from '../utils.js';

renderLayout() {
    return html`
        <div class="action-menu ${
            isMobileOrTablet() ? 'always-visible' : 'invisible'
        }">
            ...
        </div>
    `;
}
```

## Height Synchronization

Align elements across cards in a collection:

```javascript
syncHeights() {
    const heading = this.card.shadowRoot.querySelector('[slot="heading-xs"]');
    this.updateCardElementMinHeight(heading, 'heading');

    const body = this.card.shadowRoot.querySelector('[slot="body-xs"]');
    this.updateCardElementMinHeight(body, 'body');
}
```

## Common Anti-Patterns

### ❌ Missing Event Cleanup

```javascript
// BAD: Memory leak
connectedCallbackHook() {
    this.card.addEventListener('click', this.handler);
}
// No disconnectedCallbackHook!

// GOOD: Clean up listeners
disconnectedCallbackHook() {
    this.card.removeEventListener('click', this.handler);
}
```

### ❌ Direct querySelector Without Caching

```javascript
// BAD: Repeated queries
renderLayout() {
    const menu = this.card.shadowRoot.querySelector('.menu');
    // ...
}

// GOOD: Use getter for caching
get actionMenu() {
    return this.card.shadowRoot.querySelector('.action-menu');
}
```

### ❌ Modifying hydrate.js for Variant Logic

```javascript
// BAD: Adding variant-specific code to shared utility
// In hydrate.js
if (variant === 'catalog') { ... }

// GOOD: Handle in variant class
class Catalog extends VariantLayout {
    renderLayout() {
        // Variant-specific rendering
    }
}
```

## Build Requirements

After changing variant files:

```bash
cd web-components
npm run build  # Runs tests AND compiles
```

## Related Skills

- `card-variant-registry` - Variant schemas and slots
- `lit-component-scaffolder` - Generate new components
- `figma-to-code` - Convert Figma designs to variants
