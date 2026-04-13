# Responsive Design Guide for MAS Merch Cards

## Collection Grid System (3-Layer Architecture)

Responsive layout in MAS is NOT handled by individual cards. It's a 3-layer system:

### Layer 1: `merch-card-collection` (JS component)
- Counts visible cards, determines variant
- Assigns grid classes: `.one-merch-card`, `.two-merch-cards`, `.three-merch-cards`, `.four-merch-cards`
- Combined with variant name: e.g., `.three-merch-cards.express-ai`

### Layer 2: Base grid rules (`global.css.js`)
```
Mobile (default):  1 column
Tablet (768px+):   2 columns
Desktop (1200px+): 3-4 columns
Large (1600px+):   4 columns
```

### Layer 3: Variant CSS overrides (your `.css.js` file)
Each variant MUST define grid rules for `.one-merch-card.{name}` through `.four-merch-cards.{name}`.

### Grid Class CSS Template (REQUIRED for every variant)

```javascript
/* Mobile: 1 column */
.one-merch-card.my-variant,
.two-merch-cards.my-variant,
.three-merch-cards.my-variant,
.four-merch-cards.my-variant {
    grid-template-columns: minmax(276px, var(--consonant-merch-card-my-variant-width));
}

/* Tablet: 2 columns */
@media screen and ${TABLET_UP} {
    .two-merch-cards.my-variant,
    .three-merch-cards.my-variant,
    .four-merch-cards.my-variant {
        grid-template-columns: repeat(2, minmax(302px, var(--consonant-merch-card-my-variant-width)));
    }
}

/* Desktop: 3 columns */
@media screen and ${DESKTOP_UP} {
    :root {
        --consonant-merch-card-my-variant-width: 359px;  /* wider on desktop */
    }
    .three-merch-cards.my-variant,
    .four-merch-cards.my-variant {
        grid-template-columns: repeat(3, minmax(302px, var(--consonant-merch-card-my-variant-width)));
    }
}

/* Large desktop: 4 columns */
@media screen and ${LARGE_DESKTOP} {
    .four-merch-cards.my-variant {
        grid-template-columns: repeat(4, minmax(276px, var(--consonant-merch-card-my-variant-width)));
    }
}
```

### Two Grid Patterns

**Fixed** (simpler): `grid-template-columns: repeat(N, var(--width))`
- Cards are exact width, grid centers them
- Used by: catalog, plans

**Minmax** (flexible): `grid-template-columns: repeat(N, minmax(MIN, var(--width)))`
- Cards flex between MIN and MAX width
- Used by: segment, product, special-offers
- Recommended for new variants

### Width Custom Property Flow

```
:root { --consonant-merch-card-{variant}-width: 302px }     ← mobile
  → grid-template-columns: minmax(276px, 302px)              ← 1 column

@media (min-width: 1200px) {
  :root { --consonant-merch-card-{variant}-width: 359px }    ← desktop
  → grid-template-columns: repeat(3, minmax(302px, 359px))   ← 3 columns
}
```

### Wide/Super-Wide Card Spanning

Cards with `size="wide"` or `size="super-wide"` span multiple grid columns:

```css
/* From merch-card.css.js */
@media (min-width: 768px) {
    :host([size='wide']),
    :host([size='super-wide']) {
        grid-column: 1 / -1;  /* full width on tablet */
    }
}
@media (min-width: 1200px) {
    :host([size='wide']) {
        grid-column: span 2;  /* span 2 columns on desktop */
    }
}
```

### Test Harness Grid Setup

To test responsive grid in the harness, use the MAS grid classes directly:

```html
<!-- Container with grid class matching card count + variant name -->
<div class="three-merch-cards express-ai" style="
    display: grid;
    justify-content: center;
    justify-items: stretch;
    gap: var(--consonant-merch-spacing-m, 32px);
    padding: var(--spacing-m, 32px);
">
    <merch-card variant="express-ai">...</merch-card>
    <merch-card variant="express-ai">...</merch-card>
    <merch-card variant="express-ai">...</merch-card>
</div>
```

The variant CSS grid rules (`.three-merch-cards.express-ai`) handle responsive column changes automatically. No additional harness CSS needed.

## Breakpoint Constants

From `web-components/src/media.js`:

| Name | Query | Figma Frame Width |
|------|-------|-------------------|
| `SPECTRUM_MOBILE_LANDSCAPE` | `max-width: 700px` | — |
| `MOBILE_LANDSCAPE` | `max-width: 767px` | 375px |
| `TABLET_UP` | `min-width: 768px` | 768px |
| `TABLET_DOWN` | `max-width: 1199px` | — |
| `DESKTOP_UP` | `min-width: 1200px` | 1440px |
| `LARGE_DESKTOP` | `min-width: 1600px` | 1920px |

### Media Object (JS)

```javascript
import Media from '../media.js';

Media.isMobile        // matches MOBILE_LANDSCAPE
Media.isDesktop       // matches DESKTOP_UP and not LARGE_DESKTOP
Media.isDesktopOrUp   // matches DESKTOP_UP
Media.matchMobile     // MediaQueryList for MOBILE_LANDSCAPE
Media.matchDesktop    // MediaQueryList for DESKTOP_UP and not LARGE_DESKTOP
Media.matchDesktopOrUp // MediaQueryList for DESKTOP_UP
Media.matchLargeDesktop // MediaQueryList for LARGE_DESKTOP
```

## CSS Template Strings

Import breakpoints in CSS files:

```javascript
import { DESKTOP_UP, LARGE_DESKTOP, TABLET_UP, TABLET_DOWN } from '../media.js';

export const CSS = `
/* Base (mobile-first) styles */
merch-card[variant="my-variant"] {
    width: var(--consonant-merch-card-my-variant-width);
}

/* Tablet and up */
@media screen and ${TABLET_UP} {
    merch-card[variant="my-variant"] {
        /* tablet overrides */
    }
}

/* Desktop and up */
@media screen and ${DESKTOP_UP} {
    merch-card[variant="my-variant"] {
        /* desktop overrides */
    }
}

/* Large desktop */
@media screen and ${LARGE_DESKTOP} {
    merch-card[variant="my-variant"] {
        /* large desktop overrides */
    }
}
`;
```

## Decision: CSS-Only vs JS Slot Repositioning

### Use CSS-Only When:
- Slot order stays the same across all breakpoints
- Only dimensions, spacing, font-sizes, or visibility change
- Cards just get narrower/wider without structural changes

**CSS-Only Pattern**:
```css
/* Mobile: stack vertically, full width */
merch-card[variant="my-variant"] {
    width: 100%;
}

/* Desktop: fixed width */
@media screen and ${DESKTOP_UP} {
    merch-card[variant="my-variant"] {
        width: var(--consonant-merch-card-my-variant-width);
    }
}
```

### Use JS Slot Repositioning When:
- Elements physically move between `.body` and `footer` at different breakpoints
- Wide/super-wide cards show different slot arrangements than standard cards
- Content needs to be repositioned based on screen size AND card size attribute

**JS Repositioning Pattern** (from Plans variant):
```javascript
import Media from '../media.js';

export class MyVariant extends VariantLayout {
    constructor(card) {
        super(card);
        this.adaptForMedia = this.adaptForMedia.bind(this);
    }

    // Move slots based on screen size + card size
    adjustSlotPlacement(name, sizes, shouldBeInFooter) {
        const shadowRoot = this.card.shadowRoot;
        const footer = shadowRoot.querySelector('footer');
        const size = this.card.getAttribute('size');
        if (!size) return;

        const slotInFooter = shadowRoot.querySelector(`footer slot[name="${name}"]`);
        const slotInBody = shadowRoot.querySelector(`.body slot[name="${name}"]`);
        const body = shadowRoot.querySelector('.body');

        if (!size.includes('wide')) {
            footer?.classList.remove('wide-footer');
            if (slotInFooter) slotInFooter.remove();
        }
        if (!sizes.includes(size)) return;

        footer?.classList.toggle('wide-footer', Media.isDesktopOrUp);
        if (!shouldBeInFooter && slotInFooter) {
            if (slotInBody) slotInFooter.remove();
            else {
                const bodyPlaceholder = body.querySelector(`[data-placeholder-for="${name}"]`);
                if (bodyPlaceholder) bodyPlaceholder.replaceWith(slotInFooter);
                else body.appendChild(slotInFooter);
            }
            return;
        }
        if (shouldBeInFooter && slotInBody) {
            const bodyPlaceholder = document.createElement('div');
            bodyPlaceholder.setAttribute('data-placeholder-for', name);
            bodyPlaceholder.classList.add('slot-placeholder');
            if (!slotInFooter) {
                footer.prepend(slotInBody.cloneNode(true));
            }
            slotInBody.replaceWith(bodyPlaceholder);
        }
    }

    adaptForMedia() {
        this.adjustSlotPlacement('addon', ['super-wide'], Media.isDesktopOrUp);
        this.adjustSlotPlacement('callout-content', ['super-wide'], Media.isDesktopOrUp);
    }

    connectedCallbackHook() {
        Media.matchMobile.addEventListener('change', this.adaptForMedia);
        Media.matchDesktopOrUp.addEventListener('change', this.adaptForMedia);
    }

    disconnectedCallbackHook() {
        Media.matchMobile.removeEventListener('change', this.adaptForMedia);
        Media.matchDesktopOrUp.removeEventListener('change', this.adaptForMedia);
    }

    async postCardUpdateHook() {
        this.adaptForMedia();
    }
}
```

## Height Sync Pattern

For cards in collections that need synchronized heights:

```javascript
updateCardElementMinHeight(el, name) {
    if (!el || this.card.heightSync === false) return;
    const propName = `--consonant-merch-card-${this.card.variant}-${name}-height`;
    const height = Math.max(0, parseInt(window.getComputedStyle(el).height) || 0);
    const container = this.getContainer();
    const maxHeight = parseInt(container.style.getPropertyValue(propName)) || 0;
    if (height > maxHeight) {
        container.style.setProperty(propName, `${height}px`);
    }
}
```

## Collection Container CSS

Cards in collections use CSS grid:

```css
/* Collection container for the variant */
.collection-container.my-variant {
    display: grid;
    gap: var(--consonant-merch-spacing-s);
    grid-template-columns: repeat(auto-fill, minmax(var(--consonant-merch-card-my-variant-width), 1fr));
}

@media screen and ${DESKTOP_UP} {
    .collection-container.my-variant {
        grid-template-columns: repeat(3, minmax(0, var(--consonant-merch-card-my-variant-width)));
    }
}
```

## Card Width Custom Property Convention

Every variant defines its width as a CSS custom property:
```css
:root {
    --consonant-merch-card-{variant-name}-width: {value}px;
}
```

Examples from existing variants:
- Plans: `--merch-card-plans-min-width: 244px`
- Catalog: `--consonant-merch-card-catalog-width: 302px`
- Product: `--consonant-merch-card-product-width: 300px`

## Dark Mode Pattern

```css
.dark merch-card[variant="my-variant"],
merch-card[variant="my-variant"].dark {
    --consonant-merch-card-background-color: var(--spectrum-gray-100);
    color: var(--spectrum-gray-800);
}
```

## Figma Frame → Breakpoint Mapping

When Figma provides frames at non-standard widths, map them:

| Figma Frame | Target Breakpoint | CSS Query |
|------------|-------------------|-----------|
| 320-375px | Mobile | Default (no media query) or `max-width: 767px` |
| 768px | Tablet | `${TABLET_UP}` |
| 1024px | Tablet (large) | Between TABLET_UP and DESKTOP_UP |
| 1200-1440px | Desktop | `${DESKTOP_UP}` |
| 1600-1920px | Large desktop | `${LARGE_DESKTOP}` |
