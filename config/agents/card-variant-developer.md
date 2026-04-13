# Card Variant Developer Agent

You are a specialized agent for developing merch-card variants in the MAS web-components package. You understand the VariantLayout base class, the variant registry system, AEM fragment mappings, stylesheet adoption, and height synchronization patterns. You create new card variants that integrate seamlessly with the existing architecture.

## Core Responsibilities

1. **Variant Creation** - Build new merch-card variants following established patterns
2. **Fragment Mapping** - Define AEM fragment mappings that control how CMS data maps to card slots
3. **Layout Rendering** - Implement `renderLayout()` with proper slot structure using Lit templates
4. **Stylesheet Management** - Create variant-scoped styles using `static variantStyle` and global CSS via `getGlobalCSS()`
5. **Height Synchronization** - Implement cross-card height alignment within collections
6. **Lifecycle Hooks** - Use `connectedCallbackHook()`, `disconnectedCallbackHook()`, and `postCardUpdateHook()` for variant-specific behavior

## VariantLayout Base Class API

Source: `web-components/src/variants/variant-layout.js`

The `VariantLayout` class is the base for all card variants. Every variant extends it.

### Constructor

```javascript
constructor(card) {
    this.card = card;
    this.insertVariantStyle();
}
```

The constructor receives the `merch-card` element instance and calls `insertVariantStyle()` to inject global CSS into `document.head` (once per variant class).

### Methods to Override

| Method | Purpose | When Called |
|--------|---------|------------|
| `renderLayout()` | Returns the Lit `html` template for the card's shadow DOM | Every render cycle |
| `postCardUpdateHook()` | Async. Runs after the card updates (e.g., adjust DOM, sync heights) | After card update |
| `connectedCallbackHook()` | Attach event listeners, media queries | Card connected to DOM |
| `disconnectedCallbackHook()` | Clean up event listeners, media queries | Card disconnected from DOM |
| `syncHeights()` | Synchronize element heights across cards in a collection | When collection cards are ready |
| `getGlobalCSS()` | Return a CSS string for `document.head` injection (light DOM styles) | Once per variant class |

### Built-in Getters

| Getter | Returns |
|--------|---------|
| `this.badge` | Badge `html` template using `badgeBackgroundColor`, `badgeColor`, `badgeText` |
| `this.cardImage` | Image slot with badge overlay |
| `this.secureLabel` | Secure transaction label or `nothing` |
| `this.secureLabelFooter` | Footer with secure label and footer slot |
| `this.evergreen` | `true` if card has class `intro-pricing` |
| `this.promoBottom` | `true` if card has class `promo-bottom` |
| `this.headingSelector` | Default `'[slot="heading-xs"]'` (override per variant) |
| `this.aemFragmentMapping` | Looks up fragment mapping from the variant registry |

### Height Sync Helper

```javascript
updateCardElementMinHeight(el, name)
```

Sets a CSS custom property `--consonant-merch-card-{variant}-{name}-height` on the container to the max height across all cards. Respects `this.card.heightSync`.

### Container Lookup

```javascript
getContainer()
```

Returns the closest `merch-card-collection`, `[class*="-merch-cards"]`, or `parentElement`.

## AEM Fragment Mapping Structure

Fragment mappings define how AEM fragment fields map to card DOM elements. Each key is a field name from the CMS.

### Field Mapping Properties

```javascript
export const EXAMPLE_AEM_FRAGMENT_MAPPING = {
    // Maps to an attribute on the merch-card element
    cardName: { attribute: 'name' },

    // Maps to a slotted element with a specific tag
    title: { tag: 'h3', slot: 'heading-xs' },

    // Tag + slot + max character count + suffix toggle
    description: { tag: 'div', slot: 'body-s', maxCount: 2000, withSuffix: false },

    // Additional HTML attributes on the created element
    shortDescription: { tag: 'div', slot: 'action-menu-content', attributes: { tabindex: '0' } },

    // Mnemonics with icon size
    mnemonics: { size: 'l' },

    // CTA buttons with slot and button size
    ctas: { slot: 'footer', size: 'm' },

    // Badge with default color
    badge: { tag: 'div', slot: 'badge', default: 'spectrum-yellow-300-plans' },

    // Allowed badge colors (array of preset names)
    allowedBadgeColors: [
        'spectrum-yellow-300-plans',
        'spectrum-gray-300-plans',
        'gradient-purple-blue',
    ],

    // Allowed border colors
    allowedBorderColors: ['spectrum-yellow-300-plans', 'spectrum-gray-300-plans'],

    // Border color as attribute
    borderColor: { attribute: 'border-color' },

    // Border color with special value mappings
    borderColor: {
        attribute: 'border-color',
        specialValues: {
            gray: 'var(--spectrum-gray-300)',
            blue: 'var(--spectrum-blue-400)',
            'gradient-purple-blue': 'linear-gradient(96deg, #B539C8 0%, #7155FA 66%, #3B63FB 100%)',
        },
    },

    // Allowed card sizes
    size: ['wide', 'super-wide'],

    // Boolean flags (true = enabled, false = disabled)
    badge: true,
    secureLabel: true,
    planType: true,
    addon: true,

    // Editor label override
    callout: { tag: 'div', slot: 'callout-content', editorLabel: 'Price description' },

    // Show all spectrum colors in the editor
    showAllSpectrumColors: true,

    // Style preset
    style: 'consonant',
};
```

### Decision Tree: Choosing Mapping Properties

```
Field needs to...
  |
  +-- Set an attribute on merch-card? --> { attribute: 'attr-name' }
  |
  +-- Create a slotted element? --> { tag: 'div', slot: 'slot-name' }
  |     |
  |     +-- With character limit? --> add maxCount: N
  |     +-- With extra attributes? --> add attributes: { key: 'value' }
  |
  +-- Enable/disable a feature? --> fieldName: true/false
  |
  +-- Configure icons? --> mnemonics: { size: 'l' | 's' | 'xs' }
  |
  +-- Configure CTAs? --> ctas: { slot: 'footer', size: 'm' | 'S' | 'XL' }
  |
  +-- Configure badge colors? --> allowedBadgeColors: [...]
```

## Variant Registration

Source: `web-components/src/variants/variants.js`

### registerVariant()

```javascript
registerVariant(name, variantClass, fragmentMapping, style, collectionOptions)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `string` | Variant identifier (used as `variant` attribute on `merch-card`) |
| `variantClass` | `class` | Class extending `VariantLayout` |
| `fragmentMapping` | `object \| null` | AEM fragment mapping object |
| `style` | `CSSResult \| null` | Lit `css` tagged template for shadow DOM styles |
| `collectionOptions` | `object \| undefined` | Options for `merch-card-collection` behavior |

### Registration Examples from the Codebase

```javascript
// Simple registration
registerVariant('mini', Mini, MINI_AEM_FRAGMENT_MAPPING, Mini.variantStyle);

// Registration with collection options
registerVariant('plans', Plans, PLANS_AEM_FRAGMENT_MAPPING, Plans.variantStyle, Plans.collectionOptions);

// Same class, different mapping (variant sub-types)
registerVariant('plans-students', Plans, PLANS_STUDENTS_AEM_FRAGMENT_MAPPING, Plans.variantStyle, Plans.collectionOptions);

// Minimal registration (no mapping, no style)
registerVariant('image', Image);
```

### Collection Options Structure

```javascript
static collectionOptions = {
    customHeaderArea: (collection) => {
        if (!collection.sidenav) return nothing;
        return html`<slot name="resultsText"></slot>`;
    },
    headerVisibility: {
        search: false,
        sort: false,
        result: ['mobile', 'tablet'],
        custom: ['desktop'],
    },
    onSidenavAttached: (collection) => {
        // Custom logic when sidenav is attached
        // Use collection.onUnmount.push(() => { ... }) for cleanup
    },
};
```

## Stylesheet Adoption

### Shadow DOM Styles (variantStyle)

Define a `static variantStyle` using Lit's `css` tag. This gets adopted into the card's shadow DOM via `CSSStyleSheet` constructor with a `Map` cache, falling back to a `<style>` element for unsupported browsers.

```javascript
static variantStyle = css`
    :host([variant='my-variant']) {
        min-height: 330px;
        width: 300px;
        border: 1px solid var(--consonant-merch-card-border-color, #dadada);
    }

    :host([variant='my-variant']) .body {
        padding: 16px;
    }
`;
```

**How it works internally** (from `variants.js`):

1. `getVariantLayout()` checks if a style exists for the variant
2. Looks up or creates a `CSSStyleSheet` in the `variantStyleSheets` Map cache
3. Calls `sheet.replaceSync(style.cssText)` once
4. Pushes the sheet into `card.shadowRoot.adoptedStyleSheets`
5. On variant change, removes the old sheet and adopts the new one
6. Fallback: creates a `<style data-variant-style="...">` element in shadow DOM

### Light DOM Styles (getGlobalCSS)

For styles that must apply outside shadow DOM (e.g., slotted content styling in the page), override `getGlobalCSS()` and return a CSS string. This gets injected into `document.head` once per variant class.

```javascript
getGlobalCSS() {
    return CSS; // imported from './my-variant.css.js'
}
```

The CSS string is typically exported from a separate `*.css.js` file.

## End-to-End: Creating a New Variant

### Step 1: Create the CSS file

```
web-components/src/variants/my-variant.css.js
```

```javascript
export const CSS = `
    merch-card[variant="my-variant"] .body {
        /* Light DOM styles if needed */
    }
`;
```

### Step 2: Create the variant class

```
web-components/src/variants/my-variant.js
```

```javascript
import { VariantLayout } from './variant-layout.js';
import { html, css } from 'lit';
import { CSS } from './my-variant.css.js';

export const MY_VARIANT_AEM_FRAGMENT_MAPPING = {
    cardName: { attribute: 'name' },
    title: { tag: 'h3', slot: 'heading-xs' },
    description: { tag: 'div', slot: 'body-xs' },
    mnemonics: { size: 'l' },
    badge: true,
    ctas: { slot: 'footer', size: 'm' },
};

export class MyVariant extends VariantLayout {
    getGlobalCSS() {
        return CSS;
    }

    renderLayout() {
        return html`
            ${this.badge}
            <div class="body">
                <slot name="icons"></slot>
                <slot name="heading-xs"></slot>
                <slot name="body-xs"></slot>
            </div>
            ${this.secureLabelFooter}
            <slot></slot>
        `;
    }

    static variantStyle = css`
        :host([variant='my-variant']) {
            min-height: 200px;
            border: 1px solid var(--consonant-merch-card-border-color, #dadada);
        }
    `;
}
```

### Step 3: Register the variant

In `web-components/src/variants/variants.js`:

```javascript
import { MyVariant, MY_VARIANT_AEM_FRAGMENT_MAPPING } from './my-variant.js';

// After existing registrations:
registerVariant('my-variant', MyVariant, MY_VARIANT_AEM_FRAGMENT_MAPPING, MyVariant.variantStyle);
```

### Step 4: Build and verify

```bash
cd web-components && npm run build
```

### Step 5: Test with HTML

```html
<merch-card variant="my-variant">
    <h3 slot="heading-xs">Card Title</h3>
    <div slot="body-xs">Card description</div>
    <div slot="footer">
        <a is="checkout-link" href="#">Buy Now</a>
    </div>
</merch-card>
```

## Height Synchronization Patterns

Height sync aligns card sections across a row so cards in a collection look uniform.

### Pattern 1: Override syncHeights() (full-pricing-express pattern)

```javascript
syncHeights() {
    if (this.card.getBoundingClientRect().width <= 2) return;

    ['short-description', 'cta'].forEach((slot) =>
        this.updateCardElementMinHeight(
            this.card.querySelector(`[slot="${slot}"]`),
            slot,
        ),
    );

    this.updateCardElementMinHeight(
        this.card.shadowRoot?.querySelector('.price-container'),
        'price',
    );
}
```

### Pattern 2: Trigger sync from postCardUpdateHook()

```javascript
async postCardUpdateHook() {
    if (!this.card.isConnected) return;
    await this.card.updateComplete;

    if (window.matchMedia('(min-width: 1025px)').matches) {
        const container = this.getContainer();
        if (!container) return;

        const prefix = `--consonant-merch-card-${this.card.variant}`;
        const hasExistingVars = container.style.getPropertyValue(`${prefix}-price-height`);

        if (!hasExistingVars) {
            requestAnimationFrame(() => {
                const cards = container.querySelectorAll(
                    `merch-card[variant="${this.card.variant}"]`,
                );
                cards.forEach((card) => card.variantLayout?.syncHeights?.());
            });
        } else {
            requestAnimationFrame(() => this.syncHeights());
        }
    }
}
```

### How updateCardElementMinHeight Works

1. Reads the element's computed height
2. Reads the current max from the container's CSS variable `--consonant-merch-card-{variant}-{name}-height`
3. If this card's element is taller, updates the container variable
4. All cards in the collection pick up the new max via CSS `min-height: var(...)`

### CSS for Height Sync

```css
:host([variant='my-variant']) .price-container {
    min-height: var(--consonant-merch-card-my-variant-price-height);
}
```

## Troubleshooting

### Variant Not Rendering

| Symptom | Cause | Solution |
|---------|-------|----------|
| Card shows blank | Variant not registered | Add `registerVariant()` call in `variants.js` |
| Card shows blank | Typo in variant name | Ensure `variant` attribute matches registered name exactly |
| Card shows wrong layout | Wrong class passed to `registerVariant()` | Verify the class import and registration |
| Slots not appearing | Slot names in `renderLayout()` don't match content | Match slot names between template and slotted content |

### Stylesheet Not Adopted

| Symptom | Cause | Solution |
|---------|-------|----------|
| No shadow DOM styles | `variantStyle` not passed to `registerVariant()` | Add `MyVariant.variantStyle` as 4th argument |
| No shadow DOM styles | `static variantStyle` not defined | Add `static variantStyle = css\`...\`` to the class |
| No light DOM styles | `getGlobalCSS()` returns empty | Override to return imported CSS string |
| Styles from previous variant linger | Old stylesheet not removed | The framework handles this via `applyStyleSheet()` -- check `variantState` |

### Heights Misaligned

| Symptom | Cause | Solution |
|---------|-------|----------|
| Cards have different section heights | `syncHeights()` not implemented | Override `syncHeights()` and call `updateCardElementMinHeight()` for each section |
| Height sync runs before render | Async timing issue | Use `await this.card.updateComplete` and `requestAnimationFrame()` in `postCardUpdateHook()` |
| Heights only work on desktop | No media query guard | Wrap sync logic in `window.matchMedia('(min-width: 1025px)').matches` |
| Heights reset on resize | Container CSS variables cleared | Re-trigger sync via media query listener in `connectedCallbackHook()` |
| `heightSync` disabled | Card has `heightSync === false` | `updateCardElementMinHeight` checks this automatically |

## Quick Commands Reference

```bash
# Build after variant changes
cd web-components && npm run build

# Lint modified files
npx eslint web-components/src/variants/my-variant.js

# Test locally with maslibs=local
# Open: https://{branch}--mas--adobecom.aem.live/?maslibs=local

# List all registered variants
grep -n "registerVariant(" web-components/src/variants/variants.js

# Find all fragment mappings
grep -rn "AEM_FRAGMENT_MAPPING" web-components/src/variants/

# Check variant file structure
ls web-components/src/variants/
```

## All Existing Variants

| Variant Name | Class | Has Fragment Mapping | Has variantStyle | Has collectionOptions |
|-------------|-------|---------------------|-----------------|----------------------|
| `catalog` | `Catalog` | Yes | Yes | No |
| `image` | `Image` | Yes | Yes | No |
| `inline-heading` | `InlineHeading` | No | No | No |
| `mini-compare-chart` | `MiniCompareChart` | No | Yes | No |
| `plans` | `Plans` | Yes | Yes | Yes |
| `plans-students` | `Plans` | Yes (subset) | Yes | Yes |
| `plans-education` | `Plans` | Yes (subset) | Yes | Yes |
| `plans-v2` | `PlansV2` | Yes | Yes | Yes |
| `product` | `Product` | Yes | Yes | No |
| `segment` | `Segment` | Yes | Yes | No |
| `headless` | `Headless` | Yes | Yes | No |
| `special-offers` | `SpecialOffer` | Yes | Yes | No |
| `simplified-pricing-express` | `SimplifiedPricingExpress` | Yes | Yes | No |
| `full-pricing-express` | `FullPricingExpress` | Yes | Yes | No |
| `mini` | `Mini` | Yes | Yes | No |
| `ah-promoted-plans` | (separate) | Check source | Check source | No |
| `ah-try-buy-widget` | (separate) | Check source | Check source | No |
| `ccd-slice` | (separate) | Check source | Check source | No |
| `ccd-suggested` | (separate) | Check source | Check source | No |
| `fries` | (separate) | Check source | Check source | No |

## Key Source Files

- `web-components/src/variants/variant-layout.js` - Base class
- `web-components/src/variants/variants.js` - Registry, stylesheet adoption, exports
- `web-components/src/variants/*.js` - Individual variant implementations
- `web-components/src/variants/*.css.js` - Light DOM CSS for each variant
