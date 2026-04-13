# Token Mapping: Figma Spectrum 2 → CSS

Maps Figma design token names to CSS custom properties for use in MAS merch card variants.

## How to Use

1. Extract token values from Figma `get_design_context` output
2. Look up the Figma token name in the tables below
3. Use the corresponding CSS property in your variant CSS
4. If in **consonant mode** (ACOM), use the MAS fallback instead

**Important**: Use `context7` MCP to verify current Spectrum 2 token names at generation time. Token names may evolve between Spectrum versions.

## Spacing Tokens

| Figma Token Path | Value | Spectrum 2 CSS | MAS Consonant Fallback |
|-----------------|-------|---------------|----------------------|
| `--spacing/spacing-50` | 2px | `--spectrum-spacing-50` | *(no token — use literal)* |
| `--spacing/spacing-75` | 4px | `--spectrum-spacing-75` | `--consonant-merch-spacing-xxxs` |
| `--spacing/sx-spacing-80` | 6px | *(custom — use literal)* | *(no token — use literal)* |
| `--spacing/spacing-100` | 8px | `--spectrum-spacing-100` | `--consonant-merch-spacing-xxs` |
| `--spacing/spacing-200` | 12px | `--spectrum-spacing-200` | *(no token — use literal)* |
| `--spacing/spacing-300` | 16px | `--spectrum-spacing-300` | `--consonant-merch-spacing-xs` |
| `--spacing/spacing-400` | 24px | `--spectrum-spacing-400` | `--consonant-merch-spacing-s` |
| *(hardcoded)* | 32px | `--spectrum-spacing-500` | `--consonant-merch-spacing-m` |

## Typography — Font Size Tokens

| Figma Token Path | Value | Spectrum 2 CSS | MAS Consonant Fallback | MAS Slot |
|-----------------|-------|---------------|----------------------|----------|
| `title/title-xs` | 18px | `--spectrum-font-size-300` | `--consonant-merch-card-heading-xs-font-size` | heading-xs |
| `title/title-s` | 20px | `--spectrum-font-size-400` | `--consonant-merch-card-heading-s-font-size` | heading-s |
| `title/title-m` | 22px | `--spectrum-font-size-500` | *(no exact match — between heading-s and heading-m)* | heading-m (closest) |
| `title/title-l` | 24px | `--spectrum-font-size-600` | `--consonant-merch-card-heading-m-font-size` | heading-m |
| `body/s` | 14px | `--spectrum-font-size-100` | `--consonant-merch-card-body-xs-font-size` | body-xs |
| `body/xs` | 12px | `--spectrum-font-size-75` | `--consonant-merch-card-body-xxs-font-size` | body-xxs |
| `body/m` | 16px | `--spectrum-font-size-200` | `--consonant-merch-card-body-s-font-size` | body-s |
| `body/l` | 18px | `--spectrum-font-size-300` | `--consonant-merch-card-body-m-font-size` | body-m |
| `label/label-s` | 12px | `--spectrum-font-size-75` | `--consonant-merch-card-detail-m-font-size` | badge/detail |

## Typography — Line Height Tokens

| Figma Token Path | Value | Spectrum 2 CSS | MAS Consonant Value | Delta |
|-----------------|-------|---------------|--------------------| ------|
| `line-height/title/title-xs` | 24px | Spectrum: 1.3 ratio | `22.5px` | **+1.5px** |
| `line-height/title/title-m` | 28px | Spectrum: 1.3 ratio | *(no 22px heading)* | — |
| `line-height/title/title-l` | 30px | Spectrum: 1.3 ratio | `30px` | Exact |
| Body line heights | 1.3x | Spectrum: 1.3 ratio | MAS uses fixed px | **Systematic mismatch** |

**Note on line heights**: Figma/Spectrum 2 uses a `1.3` multiplier universally. MAS consonant tokens use specific pixel values that don't match this ratio. When generating CSS:
- **Spectrum 2 mode**: use `line-height: 1.3` or the Spectrum token
- **Consonant mode**: use the MAS pixel value from global.css.js

## Color Tokens

| Figma Token Path | Hex | Spectrum 2 CSS | MAS Usage |
|-----------------|-----|---------------|-----------|
| `palette/gray/25` | `#FFFFFF` | `--spectrum-gray-25` | White text on dark bg |
| `palette/gray/50` | `#F8F8F8` | `--spectrum-gray-50` | Tab/section background |
| `palette/gray/100` | `#ECECEC` | `--spectrum-gray-100` | Subtle background |
| `palette/gray/200` | `#D5D5D5` | `--spectrum-gray-200` | Borders |
| `palette/gray/700` | `#505050` | `--spectrum-gray-700` | Subdued text |
| `palette/gray/800` | `#292929` | `--spectrum-gray-800` | Primary text, dark UI |
| `palette/gray/900` | `#1A1A1A` | `--spectrum-gray-900` | Deepest text |
| `palette/white` | `#FFFFFF` | `--spectrum-white` | Card background |
| `content/neutral/default` | `#222222` | `--spectrum-neutral-content-color-default` | Heading text |
| `content/neutral-subdued` | `#464646` | `--spectrum-neutral-subdued-content-color-default` | Body text |
| `accent/default` | `#5258E4` | `--spectrum-accent-color-default` | Accent CTA |
| `border/sx-extra-subdued` | `#D5D5D5` | `--spectrum-border-color-default` | Card border |
| `static-red/900` | `#D73220` | `--spectrum-static-red-900` | Gradient start |
| `static-magenta/900` | `#D92361` | `--spectrum-static-magenta-900` | Gradient middle |
| `static-indigo/900` | `#7155FA` | `--spectrum-static-indigo-900` | Gradient end |

### MAS Consonant Color Equivalents

| Figma Color | Consonant Token/Variable | Value |
|-------------|--------------------------|-------|
| `#222` content text | `color: var(--consonant-merch-card-body-color, #222)` | Direct use |
| `#DADADA` border | `--consonant-merch-card-border` | MAS uses #DADADA not #D5D5D5 |
| `#FFF` card bg | `--consonant-merch-card-background-color` | Direct use |

## Border Radius Tokens

| Figma Token | Value | Spectrum 2 CSS | MAS Consonant |
|-------------|-------|---------------|---------------|
| `radius/corner-radius-100` | 8px | `--spectrum-corner-radius-100` | `--consonant-merch-spacing-xxs` (8px) |

**Note**: MAS default card border radius uses `--consonant-merch-spacing-xs` (16px). Figma designs typically use 8px. Override in variant CSS.

## Font Family

| Context | Figma Font | CSS |
|---------|-----------|-----|
| Titles (Spectrum 2) | Adobe Clean Spectrum VF: Bold | `font-family: 'Adobe Clean', adobe-clean, sans-serif; font-weight: 700;` |
| Body (Standard) | Adobe Clean: Regular | `font-family: var(--merch-body-font-family);` |
| Detail/Badge | Adobe Clean: Bold | `font-family: 'Adobe Clean', adobe-clean, sans-serif; font-weight: 700;` |

**Note**: "Adobe Clean Spectrum VF" is a variable font variant. In CSS, use standard "Adobe Clean" with appropriate font-weight. The variable font is loaded by the page, not by MAS.

## MAS Typography Token Table (from global.css.js)

### Headings
| Token | Font Size | Line Height |
|-------|-----------|-------------|
| heading-xxxs | 14px | 18px |
| heading-xxs | 16px | 20px |
| heading-xs | 18px | 22.5px |
| heading-s | 20px | 25px |
| heading-m | 24px | 30px |
| heading-l | 28px | 36.4px |
| heading-xl | 32px | 40px |

### Body
| Token | Font Size | Line Height |
|-------|-----------|-------------|
| body-xxs | 12px | 18px |
| body-xs | 14px | 21px |
| body-s | 16px | 24px |
| body-m | 18px | 27px |
| body-l | 20px | 30px |
| body-xl | 22px | 33px |
| body-xxl | 24px | — |

### Detail
| Token | Font Size | Line Height | Weight |
|-------|-----------|-------------|--------|
| detail-s | 11px | 14px | 500 |
| detail-m | 12px | 15px | 700 |

### CTA
| Token | Font Size |
|-------|-----------|
| cta | 15px |

## MAS Spacing Token Table

| Token | Value |
|-------|-------|
| spacing-xxxs | 4px |
| spacing-xxs | 8px |
| spacing-xs | 16px |
| spacing-s | 24px |
| spacing-m | 32px |
