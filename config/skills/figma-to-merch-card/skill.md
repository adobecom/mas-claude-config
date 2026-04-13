---
name: figma-to-merch-card
description: Convert Figma designs into MAS merch card variants using the official Figma MCP + visual AI reasoning. Orchestrates a generate-test-fix loop with parallel agents for pixel-accurate output. Use when creating new card variants from Figma, converting Figma designs to merch cards, or implementing pricing card templates.
---

# Figma to Merch Card

Convert any Figma card design into a fully functional MAS merch card variant — JS class, responsive CSS, AEM fragment mapping, and variant registration — using AI visual reasoning and an autonomous generate-test-fix loop.

## Triggers
- "figma to card", "convert figma", "new variant from figma"
- "implement this card design", "create card from figma"
- User provides a Figma URL containing a card/pricing component
- "figma to merch card", "pricing card from figma"

## Prerequisites
- Figma MCP must be connected (run `/mcp` if tools are unavailable)
- Playwright MCP for visual validation
- context7 MCP for Spectrum 2 token lookup
- Local dev server for rendering validation (`npm run dev` in web-components/)

## Phase 0: Setup

### Parse the Figma URL
Extract `fileKey` and `nodeId` from the URL:
- `https://figma.com/design/:fileKey/:fileName?node-id=:nodeId`
- Convert `-` to `:` in nodeId (e.g., `239-238252` → `239:238252`)

### Ask Surface Mode
Before any work, ask which token system to use:
- **Spectrum 2** (default): For CCD, Express, and most surfaces. Use Spectrum 2 CSS custom properties.
- **Consonant/ACOM**: For adobe.com only. Map to existing `--consonant-merch-*` tokens.

### Ask Variant Name
Get the variant name from the user (kebab-case, e.g., `simplified-pricing`).

## Phase 1: Design Extraction (parallel agents)

Launch TWO agents in parallel:

### Agent A: Design Extractor
**Tools**: Figma MCP (`get_design_context`, `get_screenshot`, `get_metadata`)

1. Call `get_metadata` on the provided nodeId to understand the component tree
2. Identify the individual card components (look for card/pricing instances)
3. Call `get_design_context` on each distinct card variant (with `disableCodeConnect: true`)
4. Call `get_screenshot` on each card for visual reference
5. If multiple breakpoint frames exist (desktop/tablet/mobile), screenshot each

**Output**: Write to a temp file containing:
- Screenshots of each card at each breakpoint
- Structured data: all typography values, colors, spacing, border radius, layout
- Designer annotations (from `data-development-annotations` attributes)
- Identified content regions and their visual roles

### Agent B: Token Resolver
**Tools**: context7 MCP, file reads

1. Read `web-components/src/global.css.js` for MAS token definitions
2. Use context7 to look up current Spectrum 2 CSS custom property names
3. Read the `token-mapping.md` reference file in this skill directory

**Output**: Write to a temp file containing:
- Spectrum 2 token → CSS property mapping for this session
- Consonant fallback table (if ACOM mode)
- Available MAS slot vocabulary with typography tokens

## Phase 2: Code Generation

After both agents complete, generate the variant:

### Slot Mapping
For each content region identified in the design:
1. **Visual role** → MAS slot name (e.g., large bold text at top → `heading-xs` or `heading-s`)
2. **Typography** → token resolution (exact Figma value → closest Spectrum 2 or consonant token)
3. **Colors** → token resolution
4. **Spacing** → token resolution

Every card is different. Do NOT assume fixed patterns for:
- Badge style (corner solid, full-width gradient, top bar, or none)
- CTA style (standard M, XL pill, black, accent, or custom)
- Layout (single column, wide, with/without image background)
- Font sizes (may not match any existing MAS token exactly)

### Structural Pattern Selection
Based on the visual analysis, choose the right patterns from `variant-patterns.md`:
- Simple flexbox → catalog pattern
- Responsive slot repositioning → plans pattern (adjustSlotPlacement)
- Background image/gradient → special-offer pattern
- Badge width sync → segment pattern

### Generate Files
Create these files using patterns from `variant-patterns.md`:

1. **`web-components/src/variants/{name}.js`**
   - Import VariantLayout, html, css, nothing from lit
   - Import CSS from `./{name}.css.js`
   - Export `{NAME}_AEM_FRAGMENT_MAPPING` constant
   - Export class extending VariantLayout
   - `getGlobalCSS()` returning imported CSS
   - `renderLayout()` with the right slot arrangement
   - Lifecycle hooks if responsive repositioning needed
   - `static variantStyle` with shadow DOM styles

2. **`web-components/src/variants/{name}.css.js`**
   - Import breakpoint constants from `../media.js`
   - Export CSS string with:
     - Root-level custom properties: `:root { --consonant-merch-card-{name}-width: Xpx }`
     - Base card styles: `merch-card[variant="{name}"]` selectors (light DOM)
     - **REQUIRED: Collection grid rules** for `.one-merch-card.{name}` through `.four-merch-cards.{name}`:
       - Mobile: 1 column using `minmax(276px, var(--width))`
       - Tablet (768px+): 2 columns using `repeat(2, minmax(302px, var(--width)))`
       - Desktop (1200px+): 3 columns, update width custom property
       - Large (1600px+): 4 columns
     - Token overrides where Figma values differ from MAS defaults
   - See `responsive-guide.md` → "Collection Grid System" for the complete template

3. **Update `web-components/src/variants/variants.js`**
   - Add import for the new variant class and fragment mapping
   - Add `registerVariant('{name}', ClassName, FRAGMENT_MAPPING, ClassName.variantStyle)`

4. **Build**: Run `npm run build` in `web-components/`

## Phase 3: Visual Validation (autonomous loop)

### Render the Variant
1. Create or use `test-harness.html` — loads the built MAS bundle and renders the new variant
2. Use Playwright MCP to navigate to the test page
3. Take a screenshot of the rendered card

### Compare Against Figma
1. Place the Figma screenshot and rendered screenshot side by side (Claude sees both)
2. Identify specific differences:
   - Spacing: padding/margin/gap off by more than 2px
   - Typography: font size, weight, or line height wrong
   - Colors: hex values don't match
   - Layout: alignment, flex direction, or width incorrect
   - Border: radius or color wrong
   - Badge/CTA: structural difference

### Auto-Fix Loop
For each identified difference:
1. Determine which CSS property needs adjustment
2. Edit the variant's `.css.js` file
3. Rebuild (`npm run build`)
4. Re-screenshot and re-compare

**Convergence criteria**:
- All spacing within 2px of Figma
- All colors match exactly
- Typography matches (size, weight, line-height)
- Layout structure matches
- Max 5 iterations — if not converged, present remaining differences to user

## Slot Vocabulary Reference

| Slot Name | Typical Content | Typography Token |
|-----------|----------------|-----------------|
| `icons` | Product mnemonic icons | — |
| `heading-xs` | Card title (18px) | heading-xs: 18px/22.5px |
| `heading-s` | Education title (20px) | heading-s: 20px/25px |
| `heading-m` | **Prices** (via `inline-price` component) | heading-m: 24px/30px |
| `heading-l` | Hero price (28px) | heading-l: 28px/36.4px |
| `subtitle` | Secondary heading | heading-xxxs: 14px/18px |
| `body-xxs` | Legal text (12px) | body-xxs: 12px/18px |
| `body-xs` | Description (14px) | body-xs: 14px/21px |
| `body-s` | Larger body (16px) | body-s: 16px/24px |
| `promo-text` | Promotional line | body-xs |
| `callout-content` | Tooltip/callout block | — |
| `quantity-select` | Quantity selector | — |
| `addon` | Add-on checkbox | — |
| `badge` | Badge content | detail-m: 12px/15px bold |
| `footer` | CTA buttons | cta: 15px |
| `whats-included` | Feature list | body-xs |
| `bg-image` | Background image | — |
| `per-unit-label` | Per-unit pricing label | — |

## CRITICAL: Price Structure (inline-price component)

Prices in Figma appear as styled text (e.g., "US$9.99/month" with different sizes per part). In MAS, prices are **NOT hardcoded text** — they use `<span is="inline-price">` which resolves pricing dynamically from WCS.

**Each price part is an individually-styleable span:**

| Figma Price Element | CSS Selector | Example |
|--------------------|-------------|---------|
| Currency "US$" | `.price-currency-symbol` | 22px bold |
| Amount "9" | `.price-integer` | 22px bold |
| Decimal "." | `.price-decimals-delimiter` | 22px bold |
| Cents "99" | `.price-decimals` | 22px bold |
| Period "/mo" | `.price-recurrence` | 12px bold |
| Unit "per license" | `.price-unit-type` | 12px regular |
| Tax "incl. VAT" | `.price-tax-inclusivity` | 12px subdued |

**How to match Figma price designs:**
1. In Figma, identify the different font sizes/weights for each price element
2. In the variant CSS, target individual price spans to match:
   ```css
   merch-card[variant="my-variant"] .price { font-size: 22px; font-weight: 700; }
   merch-card[variant="my-variant"] .price-recurrence { font-size: 12px; }
   ```
3. Never generate hardcoded price text — use `<span is="inline-price" data-wcs-osi="...">`
4. Use `data-template` to control price format: `price`, `strikethrough`, `legal`, `discount`
5. Use `data-display-*` attributes to show/hide parts: `data-display-recurrence`, `data-display-per-unit`

See `variant-patterns.md` → "CRITICAL: Price DOM Structure" for full DOM reference and all templates.

## Fragment Mapping Field Types

```javascript
// Text content → slot
title: { tag: 'h3', slot: 'heading-xs' },
prices: { tag: 'p', slot: 'heading-m' },
description: { tag: 'div', slot: 'body-xs' },

// Simple attribute
cardName: { attribute: 'name' },
borderColor: { attribute: 'border-color' },

// Boolean features
addon: true,
secureLabel: true,
planType: true,
badgeIcon: true,

// Mnemonics
mnemonics: { size: 'l' },  // or 's', 'm'

// Badge with defaults
badge: { tag: 'div', slot: 'badge', default: 'spectrum-yellow-300-plans' },

// Allowed colors
allowedBadgeColors: ['spectrum-yellow-300-plans', 'spectrum-gray-300-plans'],
allowedBorderColors: ['spectrum-yellow-300-plans'],

// Size options
size: ['wide', 'super-wide'],

// CTA config
ctas: { slot: 'footer', size: 'm' },

// Style
style: 'consonant',
```

## Build and Test Commands

```bash
# Build web components (includes tests)
cd web-components && npm run build

# Test locally
# Open a page with ?maslibs=local parameter

# Lint modified files
npx eslint web-components/src/variants/{name}.js web-components/src/variants/{name}.css.js
```

## Reference Files
- `variant-patterns.md` — Structural code templates for JS/CSS generation
- `responsive-guide.md` — Breakpoint system and responsive patterns
- `token-mapping.md` — Figma Spectrum 2 → CSS custom property mapping
- `test-harness.html` — HTML page for Playwright visual validation
