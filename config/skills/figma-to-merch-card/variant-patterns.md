# MAS Merch Card Variant — Code Patterns

Structural templates distilled from existing variants. Use these as reference when generating new variants. Do NOT copy blindly — adapt to each card's specific design.

## JS Class Template

```javascript
import { VariantLayout } from './variant-layout';
import { html, css, nothing } from 'lit';
import { CSS } from './{name}.css.js';
// Import Media only if responsive slot repositioning is needed:
// import Media from '../media.js';

// AEM Fragment Mapping — defines how AEM fields map to card slots
export const {NAME}_AEM_FRAGMENT_MAPPING = {
    // REQUIRED: always include cardName
    cardName: { attribute: 'name' },

    // Text content fields — tag + slot
    title: { tag: 'h3', slot: 'heading-xs' },
    // prices: { tag: 'p', slot: 'heading-m' },
    // description: { tag: 'div', slot: 'body-xs' },
    // subtitle: { tag: 'p', slot: 'subtitle' },
    // promoText: { tag: 'p', slot: 'promo-text' },

    // Mnemonics (product icons) — size: 's' | 'm' | 'l'
    // mnemonics: { size: 'l' },

    // Boolean features — set to true to enable
    // addon: true,
    // secureLabel: true,
    // planType: true,
    // badgeIcon: true,

    // Badge — with default color
    // badge: { tag: 'div', slot: 'badge', default: 'spectrum-yellow-300-plans' },

    // Allowed colors for Studio editor
    // allowedBadgeColors: ['spectrum-yellow-300-plans', 'spectrum-gray-300-plans'],
    // allowedBorderColors: ['spectrum-yellow-300-plans'],

    // Border color attribute
    // borderColor: { attribute: 'border-color' },

    // Size options for wide cards
    // size: ['wide', 'super-wide'],

    // Complex slots
    // callout: { tag: 'div', slot: 'callout-content' },
    // quantitySelect: { tag: 'div', slot: 'quantity-select' },
    // whatsIncluded: { tag: 'div', slot: 'whats-included' },

    // CTA config — always in footer
    ctas: { slot: 'footer', size: 'm' },

    // Style identifier
    style: 'consonant',
};

export class MyVariant extends VariantLayout {
    constructor(card) {
        super(card);
        // Bind responsive handler if needed:
        // this.adaptForMedia = this.adaptForMedia.bind(this);
    }

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
                <slot name="heading-m"></slot>
                <slot name="body-xxs"></slot>
            </div>
            ${this.secureLabelFooter}
            <slot></slot>
        `;
    }

    static variantStyle = css`
        :host([variant='my-variant']) {
            min-height: 200px;
        }
    `;
}
```

## CSS Template

```javascript
import { DESKTOP_UP, LARGE_DESKTOP, TABLET_UP, TABLET_DOWN } from '../media.js';

export const CSS = `
/* Card width custom property */
:root {
    --consonant-merch-card-my-variant-width: 302px;
}

/* Base styles (mobile-first) */
merch-card[variant="my-variant"] {
    width: var(--consonant-merch-card-my-variant-width);
}

merch-card[variant="my-variant"] .body {
    padding: var(--consonant-merch-spacing-s);
    gap: var(--consonant-merch-spacing-xxs);
}

/* Footer */
merch-card[variant="my-variant"] footer {
    padding: var(--consonant-merch-spacing-xs);
}

/* Tablet */
@media screen and ${TABLET_UP} {
    merch-card[variant="my-variant"] {
        /* tablet overrides */
    }
}

/* Desktop */
@media screen and ${DESKTOP_UP} {
    merch-card[variant="my-variant"] {
        /* desktop overrides */
    }
}

/* Collection container — grid for different card counts */
.one-merch-card.my-variant {
    grid-template-columns: minmax(302px, var(--consonant-merch-card-my-variant-width));
}

@media screen and ${TABLET_UP} {
    .two-merch-cards.my-variant,
    .three-merch-cards.my-variant,
    .four-merch-cards.my-variant {
        grid-template-columns: repeat(2, minmax(302px, var(--consonant-merch-card-my-variant-width)));
    }
}

@media screen and ${DESKTOP_UP} {
    .three-merch-cards.my-variant,
    .four-merch-cards.my-variant {
        grid-template-columns: repeat(3, minmax(302px, var(--consonant-merch-card-my-variant-width)));
    }
}

@media screen and ${LARGE_DESKTOP} {
    .four-merch-cards.my-variant {
        grid-template-columns: repeat(4, minmax(302px, var(--consonant-merch-card-my-variant-width)));
    }
}
`;
```

## Registration Pattern

In `web-components/src/variants/variants.js`:

```javascript
import { MyVariant, MY_VARIANT_AEM_FRAGMENT_MAPPING } from './my-variant.js';

// Add to existing registerVariant calls:
registerVariant(
    'my-variant',
    MyVariant,
    MY_VARIANT_AEM_FRAGMENT_MAPPING,
    MyVariant.variantStyle,
    // Optional: collection options
);
```

## Pattern: Simple Flexbox (Catalog)

Reference: `web-components/src/variants/catalog.js`

The simplest variant pattern — vertical flex column, no responsive JS:
- `renderLayout()` returns slots in a `.body` div + footer
- No lifecycle hooks needed
- CSS handles all responsiveness
- Supports action menu via separate slot

```javascript
renderLayout() {
    return html`
        ${this.cardImage}
        <div class="body">
            <slot name="icons"></slot>
            <slot name="heading-xs"></slot>
            <slot name="heading-m"></slot>
            <slot name="body-xxs"></slot>
            <slot name="promo-text"></slot>
            <slot name="body-xs"></slot>
        </div>
        ${this.secureLabelFooter}
    `;
}
```

## Pattern: Responsive Slot Repositioning (Plans)

Reference: `web-components/src/variants/plans.js`

For cards where slots move between `.body` and `footer` depending on screen size + card `size` attribute:

Key methods:
- `connectedCallbackHook()` — add Media listeners
- `disconnectedCallbackHook()` — remove Media listeners
- `adaptForMedia()` — call `adjustSlotPlacement` for each moving slot
- `adjustSlotPlacement(name, sizes, shouldBeInFooter)` — moves slot between containers
- `postCardUpdateHook()` — async operations after DOM update

Also handles:
- Legal text cloning (price → legal template)
- Addon plan type sync
- Education list spacing with IntersectionObserver

## Pattern: Background Image / Gradient (Special Offers)

Reference: `web-components/src/variants/special-offer.js`

For cards with background image or gradient treatment:

```javascript
get cardImage() {
    return html`<div class="image">
        <slot name="bg-image"></slot>
        ${this.badge}
    </div>`;
}

get evergreen() {
    return this.card.classList.contains('intro-pricing');
}

renderLayout() {
    return html`
        ${this.cardImage}
        <div class="body">
            <slot name="detail-m"></slot>
            <slot name="heading-xs"></slot>
            <slot name="heading-m"></slot>
            <slot name="body-xs"></slot>
            <slot name="promo-text"></slot>
        </div>
        ${this.secureLabelFooter}
    `;
}
```

CSS for gradient/image:
```css
merch-card[variant="special-offers"] .image {
    position: relative;
    overflow: hidden;
    border-radius: 8px 8px 0 0;
}
```

## Pattern: Badge Width Sync (Segment)

Reference: `web-components/src/variants/segment.js`

For cards where heading max-width adjusts based on badge width:

```javascript
async postCardUpdateHook() {
    const badge = this.card.shadowRoot?.getElementById('badge');
    const heading = this.card.querySelector('[slot="heading-xs"]');
    if (badge && heading) {
        const badgeWidth = badge.getBoundingClientRect().width;
        const cardWidth = this.card.getBoundingClientRect().width;
        heading.style.maxWidth = `${cardWidth - badgeWidth - 16}px`;
    }
}
```

## Pattern: Full-Width Top Badge/Tag (NEW — for gradient bars)

For designs where the badge is a full-width bar at the top of the card (not a corner badge):

```javascript
get topTag() {
    if (!this.card.badgeText) return nothing;
    return html`
        <div class="top-tag"
            style="background: ${this.card.badgeBackgroundColor || 'linear-gradient(96deg, #d73220 0%, #d92361 33%, #7155fa 100%)'}">
            <span style="color: ${this.card.badgeColor || '#fff'}">
                ${this.card.badgeText}
            </span>
        </div>
    `;
}

renderLayout() {
    return html`
        ${this.topTag}
        <div class="body">
            <!-- slots -->
        </div>
        ${this.secureLabelFooter}
    `;
}
```

CSS for top tag:
```css
:host([variant='my-variant']) .top-tag {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 4px 9px;
    font-size: 12px;
    font-weight: 700;
    line-height: 14px;
    border-radius: 8px 8px 0 0;
}
```

## Pattern: XL Pill CTA Buttons (NEW — for Express/Firefly cards)

For designs using large pill-shaped CTAs instead of standard M buttons:

```css
/* Override CTA styling in variant CSS */
merch-card[variant="my-variant"] footer a {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    padding: 12px 24px;
    border-radius: 24px;
    font-size: 18px;
    font-weight: 700;
    text-decoration: none;
}

/* Accent (purple) button */
merch-card[variant="my-variant"] footer a.con-button.blue {
    background-color: #5258e4;
    color: #fff;
    border: none;
}

/* Primary (black) button */
merch-card[variant="my-variant"] footer a.con-button {
    background-color: rgba(0, 0, 0, 0.9);
    color: #fff;
    border: none;
}

/* Outline button */
merch-card[variant="my-variant"] footer a.con-button.outline {
    background: transparent;
    color: #292929;
    border: 2px solid #292929;
}
```

## Collection Options (Optional)

For variants that need custom collection behavior:

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
};
```

## CRITICAL: Price DOM Structure (inline-price component)

Prices in merch cards are NOT plain text. They are rendered by `<span is="inline-price">` — a web component that resolves pricing from Adobe's Web Commerce Services (WCS) via an offer selector ID.

### Price HTML (what goes in the card slot)

```html
<!-- In the heading-m slot, prices are NOT hardcoded. They use inline-price: -->
<p slot="heading-m">
    <span is="inline-price"
        data-wcs-osi="abc123def456"
        data-template="price"
        data-display-recurrence="true"
        data-display-per-unit="false"
        data-display-tax="false">
    </span>
</p>
```

### Rendered DOM (what inline-price generates)

Each price part is a **separate span** that can be individually styled:

```html
<span is="inline-price" data-template="price" data-wcs-osi="..." class="placeholder-resolved">
    <span class="price">
        <span class="price-currency-symbol">US$</span>
        <span class="price-currency-space disabled"></span>
        <span class="price-integer">9</span>
        <span class="price-decimals-delimiter">.</span>
        <span class="price-decimals">99</span>
        <span class="price-recurrence">/mo</span>
        <span class="price-unit-type disabled"></span>
        <span class="price-tax-inclusivity disabled"></span>
    </span>
</span>
```

### Figma → CSS Mapping for Price Parts

Figma designs show prices with different styling per element. Map them to CSS selectors:

| Figma Element | CSS Selector | Typical Figma Style |
|--------------|--------------|---------------------|
| Currency symbol "US$" | `.price-currency-symbol` | Same size as integer, or smaller |
| Price integer "9" | `.price-integer` | Large, bold (e.g., 22px/700) |
| Decimal delimiter "." | `.price-decimals-delimiter` | Same as integer |
| Decimal digits "99" | `.price-decimals` | Same as integer, or smaller |
| Recurrence "/mo" | `.price-recurrence` | Smaller (e.g., 12px/700) |
| Per-unit "per license" | `.price-unit-type` | Small, regular weight |
| Tax label "incl. VAT" | `.price-tax-inclusivity` | Small, subdued color |

**Example: Styling price parts in variant CSS**

```css
/* Style the full price at 22px bold */
merch-card[variant="my-variant"] .price {
    font-size: 22px;
    font-weight: 700;
    line-height: 28px;
    color: #222;
}

/* Override recurrence "/mo" to be smaller */
merch-card[variant="my-variant"] .price-recurrence {
    font-size: 12px;
    font-weight: 700;
}

/* Hide disabled parts */
merch-card[variant="my-variant"] .price .disabled {
    display: none;
}
```

### Price Templates

Different `data-template` values produce different DOM wrappers:

| Template | Container Class | Use Case |
|----------|----------------|----------|
| `price` | `.price` or `.price .price-alternative` | Regular price display |
| `strikethrough` | `.price .price-strikethrough` | Original price (crossed out) |
| `optical` | `.price .price-optical` | Monthly equivalent of annual |
| `annual` | `.price .price-annual` | Annual price |
| `legal` | `.price .price-legal` | Legal text (tax, plan type) |
| `discount` | `.discount` | Percentage discount badge |
| `promo-strikethrough` | `.price .price-promo-strikethrough` | Discounted price only |

### Promo/Strikethrough Price Pattern

When a promotion exists, two prices render side-by-side:

```html
<!-- Old price (struck through) -->
<span is="inline-price" data-template="strikethrough" data-wcs-osi="...">
    <span class="price price-strikethrough">
        <sr-only class="strikethrough-aria-label">Regularly at </sr-only>
        <span class="price-currency-symbol">US$</span>
        <span class="price-integer">7</span>
        <span class="price-decimals-delimiter">.</span>
        <span class="price-decimals">99</span>
        <span class="price-recurrence disabled"></span>
    </span>
</span>
<!-- New price -->
<span is="inline-price" data-template="price" data-wcs-osi="...">
    <span class="price price-alternative">
        <sr-only class="alt-aria-label">Alternatively at </sr-only>
        <span class="price-currency-symbol">US$</span>
        <span class="price-integer">4</span>
        <span class="price-decimals-delimiter">.</span>
        <span class="price-decimals">99</span>
        <span class="price-recurrence">/mo</span>
    </span>
</span>
```

**CSS for strikethrough:**
```css
merch-card[variant="my-variant"] .price-strikethrough {
    text-decoration: line-through;
    color: #707070;
    font-size: 16px;
}
```

### Key Rules for the Skill

1. **Never hardcode price text** — always use `<span is="inline-price" data-wcs-osi="...">`. Price values come from WCS.
2. **Style price parts via CSS** — match Figma's per-element typography to CSS selectors on `.price-currency-symbol`, `.price-integer`, `.price-recurrence`, etc.
3. **data-template controls structure** — choose the right template for the design's price pattern.
4. **data-display-* controls visibility** — `data-display-recurrence="true"` shows "/mo", `data-display-per-unit="true"` shows "per license".
5. **`.disabled` class hides empty parts** — don't write CSS to hide parts that are already handled.
6. **Legal text is a separate price** — rendered with `data-template="legal"` showing tax, plan type, per-unit info.
