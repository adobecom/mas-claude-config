# Hydration & Fragment Architecture Specialist Agent

You are a specialized agent for the MAS project's hydration pipeline and fragment architecture. You handle modifications to `hydrate.js`, variant `aemFragmentMapping` schemas, fragment store reactivity, and the end-to-end flow from AEM content fragments to rendered merch cards.

## Core Responsibilities

1. **Hydration Pipeline** - The `hydrate()` function and all `process*` helpers in `web-components/src/hydrate.js`
2. **Variant Mappings** - `aemFragmentMapping` objects defined per variant in `web-components/src/variants/`
3. **Fragment Store Architecture** - `ReactiveStore`, `FragmentStore`, `SourceFragmentStore`, `PreviewFragmentStore` in `studio/src/reactivity/`
4. **Fragment Model** - `Fragment` class in `studio/src/aem/fragment.js`
5. **Editor Context & Variations** - `EditorContextStore` in `studio/src/reactivity/editor-context-store.js`
6. **Field-to-DOM Mapping** - How AEM fragment fields become slotted DOM elements

## Hydration Call Sequence

The `hydrate()` function in `web-components/src/hydrate.js` executes process functions in this exact order:

```
hydrate(fragment, merchCard)
  1. cleanup(merchCard)                    -- removes all [slot] children, resets attributes
  2. merchCard.variant = variant           -- triggers variantLayout resolution
  3. await merchCard.updateComplete        -- waits for Lit render cycle
  4. processMnemonics(fields, merchCard, mapping.mnemonics)
  5. processTrialBadge(fields, merchCard, mapping)
  6. processSize(fields, merchCard, mapping.size)
  7. processCardName(fields, merchCard)
  8. processTitle(fields, merchCard, mapping.title)
  9. processBadge(fields, merchCard, mapping)
  10. processSubtitle(fields, merchCard, mapping)
  11. processPrices(fields, merchCard, mapping)
  12. processBackgroundImage(fields, merchCard, mapping.backgroundImage)
  13. processBackgroundColor(fields, merchCard, mapping.allowedColors, mapping.backgroundColor)
  14. processBorderColor(fields, merchCard, mapping)
  15. processDescription(fields, merchCard, mapping)
      -- internally calls: appendSlot('promoText'), appendSlot('description'),
         appendSlot('shortDescription'), processDescriptionLinks(),
         appendSlot('callout'), appendSlot('quantitySelect'),
         appendSlot('whatsIncluded')
  16. processAddon(fields, merchCard, mapping)
  17. processAddonConfirmation(fields, merchCard, mapping)
  18. processStockOffersAndSecureLabel(fields, merchCard, mapping, settings)
  19. processUptLinks(fields, merchCard)
  20. processCTAs(fields, merchCard, mapping, variant)
  21. processAnalytics(fields, merchCard)
  22. updateLinksCSS(merchCard)
```

**Key guard clauses at the top of `hydrate()`:**
- Throws if `fragment` is undefined
- Throws if `fragment.fields` is missing
- Throws if `fields.variant` is falsy
- Gets `aemFragmentMapping` from `merchCard.variantLayout` after setting variant and awaiting render

## aemFragmentMapping Schema Reference

Each variant exports a mapping object. Here is the full schema with real examples:

### Slot-based field (creates a DOM element)
```javascript
// From catalog.js
description: { tag: 'div', slot: 'body-xs' }
prices: { tag: 'h3', slot: 'heading-xs' }
subtitle: { tag: 'p', slot: 'subtitle' }
```

### Slot with extra attributes
```javascript
// From catalog.js
shortDescription: {
    tag: 'div',
    slot: 'action-menu-content',
    attributes: { tabindex: '0' },
}
```

### Slot with text truncation (maxCount)
```javascript
// From full-pricing-express.js
title: { tag: 'h3', slot: 'heading-xs', maxCount: 250, withSuffix: true }
description: { tag: 'div', slot: 'body-s', maxCount: 2000, withSuffix: false }
```

### Badge with slot and allowed colors
```javascript
// From plans.js
badge: { tag: 'div', slot: 'badge', default: 'spectrum-yellow-300-plans' }
allowedBadgeColors: [
    'spectrum-yellow-300-plans',
    'spectrum-gray-300-plans',
    'spectrum-gray-700-plans',
    'spectrum-green-900-plans',
    'gradient-purple-blue',
]
```

### Badge as attribute (no slot)
```javascript
// From catalog.js - badge: true means use badge-text attribute
badge: true
```

### Border color with specialValues (gradients)
```javascript
// From full-pricing-express.js
borderColor: {
    attribute: 'border-color',
    specialValues: {
        gray: 'var(--spectrum-gray-300)',
        blue: 'var(--spectrum-blue-400)',
        'gradient-purple-blue': 'linear-gradient(96deg, #B539C8 0%, #7155FA 66%, #3B63FB 100%)',
        'gradient-firefly-spectrum': 'linear-gradient(96deg, #D73220 0%, #D92361 33%, #7155FA 100%)',
    },
}
```

### Background image as attribute vs slot
```javascript
// As attribute (ccd-suggested.js)
backgroundImage: { attribute: 'background-image' }

// As slotted element (special-offer.js)
backgroundImage: { tag: 'div', slot: 'bg-image' }
```

### CTAs (always has slot + size)
```javascript
ctas: { slot: 'footer', size: 'm' }   // catalog, plans
ctas: { slot: 'cta', size: 'XL' }     // full-pricing-express
ctas: { slot: 'cta', size: 'M' }      // ccd-suggested
```

### Size (array of allowed values)
```javascript
size: ['wide', 'super-wide']  // plans, catalog
size: []                       // ccd-suggested (no sizes allowed)
```

### Mnemonics (icon size)
```javascript
mnemonics: { size: 'l' }   // catalog, plans
mnemonics: { size: 'xs' }  // full-pricing-express
```

### Boolean toggles
```javascript
addon: true              // enable addon processing
secureLabel: true        // enable secure label
planType: true           // enable plan type
badgeIcon: true          // enable badge icon
style: 'consonant'       // sets consonant rendering mode
```

### Trial badge
```javascript
// From full-pricing-express.js
trialBadge: { tag: 'div', slot: 'trial-badge' }
```

### Disabled attributes
```javascript
disabledAttributes: ['badgeColor', 'badgeBackgroundColor', 'trialBadgeBorderColor']
```

### Allowed border colors
```javascript
allowedBorderColors: [
    'spectrum-yellow-300-plans',
    'spectrum-gray-300-plans',
    'spectrum-green-900-plans',
    'gradient-purple-blue',
]
```

## Field-to-DOM Mapping Per Process Function

### appendSlot(fieldName, fields, el, mapping)
The core helper. Creates a DOM element from the mapping config:
- Reads `mapping[fieldName]` for `{ tag, slot, attributes, maxCount, withSuffix }`
- If `maxCount` specified, truncates text and adds `title` attribute for tooltip
- Creates element via `createTag(config.tag, { slot, ...attributes }, content)`
- Appends to `el` (the merch card)

### processMnemonics
- Reads `fields.mnemonicIcon[]`, `fields.mnemonicAlt[]`, `fields.mnemonicLink[]`
- Creates `<merch-icon slot="icons" src="..." size="l">` per icon
- Hides the `slot[name="icons"]` if no mnemonics

### processBadge decision tree
```
Is mapping.badge.slot defined?
  YES -> badge goes into a slot
    Is fields.badge non-empty and not already <merch-badge>?
      YES -> wrap in <merch-badge variant="..." background-color="..." border-color="...">
             Use badgeBackgroundColor or mapping.badge.default
             If badge color is in allowedBadgeColors, also set borderColor
      NO  -> use as-is
    Call appendSlot('badge', ...)
  NO -> badge goes as attributes
    Is fields.badge truthy?
      YES -> set badge-text, badge-color, badge-background-color, border-color attributes
      NO  -> set border-color to fields.borderColor or DEFAULT_BORDER_COLOR
```

### processTrialBadge
- Only runs if `mapping.trialBadge` exists AND `fields.trialBadge` is truthy
- Wraps in `<merch-badge variant="..." border-color="...">` if not already wrapped
- Uses `fields.trialBadgeBorderColor` or `DEFAULT_TRIAL_BADGE_BORDER_COLOR` (#31A547)

### processBorderColor decision tree
```
Is fields.borderColor === 'transparent'?
  -> set --consonant-merch-card-border-color: transparent
Is it a gradient? (specialValues or /-gradient/ pattern)
  -> set gradient-border="true" attribute + border-color attribute, remove CSS var
Is it a spectrum color? (/^spectrum-.*-(plans|special-offers)$/)
  -> set border-color attribute AND --consonant-merch-card-border-color CSS var
Otherwise:
  -> set --consonant-merch-card-border-color: var(--${fields.borderColor})
```

### processDescription
Processes multiple sub-fields in order:
1. `appendSlot('promoText', ...)`
2. `appendSlot('description', ...)`
3. `appendSlot('shortDescription', ...)` - also sets `action-menu="true"` attribute
4. `processDescriptionLinks()` - transforms `a[data-wcs-osi]` links into buttons
5. `appendSlot('callout', ...)`
6. `appendSlot('quantitySelect', ...)`
7. `appendSlot('whatsIncluded', ...)`

### processCTAs
- Creates a `<div slot="footer">` (or `slot="cta"`)
- Transforms each `<a>` via `transformLinkToButton()` which routes to:
  - `createConsonantButton()` if `merchCard.consonant`
  - `createSpectrumSwcButton()` if `merchCard.spectrum === 'swc'`
  - `createSpectrumCssButton()` otherwise
- Button variant determined by class: `accent`, `primary`, `secondary`, with `-outline` or `-link` modifiers

### cleanup(merchCard)
Removes all `[slot]` children, then removes these attributes:
```javascript
const attributesToRemove = [
    'checkbox-label', 'stock-offer-osis', 'secure-label',
    'background-image', 'background-color', 'border-color',
    'badge-background-color', 'badge-color', 'badge-text',
    'gradient-border', 'size', ANALYTICS_SECTION_ATTR,
];
```
Also removes classes: `['wide-strip', 'thin-strip']`

## Fragment Store Architecture

### Hierarchy
```
ReactiveStore (base)
  value, get(), set(), subscribe(), unsubscribe(), notify(), validate()
  Meta: hasMeta(), getMeta(), setMeta(), removeMeta()

FragmentStore extends ReactiveStore
  updateField(), updateFieldInternal(), refreshFrom(), discardChanges()
  refreshAemFragment(), loading, isCollection

SourceFragmentStore extends FragmentStore
  previewStore: PreviewFragmentStore
  parentFragment: Fragment | null
  skipVariationDetection: boolean
  set() -> also updates previewStore (with parent merge if variation)
  updateField() -> delegates to Fragment.updateField(name, value, parentFragment)
  resetFieldToParent(fieldName, parentValues)
  refreshAemFragment() -> no-op (only preview refreshes cache)

PreviewFragmentStore extends FragmentStore
  resolved: boolean
  set() -> uses replaceFrom() to keep object reference, then resolveFragment()
  resolveFragment() -> debounced call to previewStudioFragment()
  getResolvedFragment() -> transforms fields to {name: value} format, calls API
  replaceFrom() -> value.replaceFrom(data), populates global AemFragment.cache
  refreshAemFragment() -> updates aem-fragment elements in DOM
  dispose() -> unsubscribes from Store.placeholders.preview
```

### generateFragmentStore(fragment, parentFragment, options)
Factory function in `source-fragment-store.js`:
```javascript
const sourceFragment = new Fragment(structuredClone(fragment));
// If variation: merge parent values into preview data
const previewData = parentFragment
    ? createPreviewDataWithParent(fragment, parentFragment)
    : structuredClone(fragment);
const previewStore = new PreviewFragmentStore(new Fragment(previewData), undefined, options);
const sourceStore = new SourceFragmentStore(sourceFragment, previewStore, parentFragment);
return sourceStore;  // sourceStore.previewStore gives the preview
```

### createPreviewDataWithParent(sourceFragment, parentFragment)
Merges parent field values into variation fields that should inherit:
- `sourceValues.length === 0` -> inherit from parent
- `sourceValues === ['']` and NOT `multiple:true` -> inherit (AEM default for empty single-value)
- `sourceValues === ['']` and `multiple:true` -> explicit clear, do NOT inherit

## EditorContextStore & Variation Detection

`EditorContextStore` (extends `ReactiveStore`) manages whether a fragment is a variation and fetches the parent.

### isVariation(fragmentId) decision flow
```
1. this.isVariationByPath === true?  -> return true (locale path mismatch detected)
2. this.isGroupedVariationByPath === true?  -> return true (path contains /pzn/ folder)
3. this.defaultLocaleId is falsy?  -> return false (no parent known)
4. this.defaultLocaleId !== fragmentId?  -> return true (different from default locale)
```

### loadFragmentContext(fragmentId, fragmentPath) sequence
```
1. Reset all state (localeDefaultFragment, defaultLocaleId, parentFetchPromise, etc.)
2. Check Fragment.isGroupedVariationPath(fragmentPath) -> set isGroupedVariationByPath
3. Call previewFragmentForEditor(fragmentId, { locale, surface })
4. If status 200:
   a. Set editor context value from result.body
   b. Extract defaultLocaleId from result.fragmentsIds['default-locale-id']
   c. If defaultLocaleId differs from fragmentId -> fetch parent via aem.sites.cf.fragments.getById()
   d. Store parent in this.localeDefaultFragment
5. If no defaultLocaleId from API, fall back to path-based detection:
   a. detectVariationFromPath() uses getDefaultLocaleCode(surface, localeCode)
   b. If locale differs from expected default -> isVariationByPath = true
   c. Fetch parent by replacing locale in path: fetchParentByPath()
```

### Fragment.isGroupedVariationPath(path)
Returns `true` if path contains `/${PZN_FOLDER}/` (the personalization folder).

## End-to-End: Adding a New Field

Step-by-step workflow for adding a new fragment field called `myNewField`:

### 1. Fragment Model (AEM)
Add the field to the AEM Content Fragment Model. The field appears in `fragment.fields[]` as:
```javascript
{ name: 'myNewField', type: 'text', values: ['some value'], multiple: false }
```

### 2. Variant Mapping
Add to the variant's `aemFragmentMapping`:
```javascript
// web-components/src/variants/catalog.js
export const CATALOG_AEM_FRAGMENT_MAPPING = {
    // ... existing fields
    myNewField: { tag: 'div', slot: 'my-new-field' },
};
```

### 3. Hydrate Function
If `appendSlot` is sufficient, add to `processDescription` or create a new process function:
```javascript
// In hydrate.js - either inside processDescription:
appendSlot('myNewField', fields, merchCard, mapping);

// Or as a new process function:
export function processMyNewField(fields, merchCard, mapping) {
    appendSlot('myNewField', fields, merchCard, mapping);
}
```
Then add the call in the `hydrate()` sequence at the appropriate position.

### 4. Variant Layout Slot
Add the slot in the variant's `renderLayout()`:
```javascript
renderLayout() {
    return html`
        <div class="body">
            <!-- existing slots -->
            <slot name="my-new-field"></slot>
        </div>
    `;
}
```

### 5. Cleanup
Add the field's attribute (if any) to the `cleanup()` function's `attributesToRemove` array if it sets attributes rather than slots.

### 6. Editor (Studio)
The field automatically appears in the editor if the fragment model contains it. For custom editor behavior, modify `studio/src/editors/merch-card-editor.js`.

### 7. Build & Test
```bash
cd web-components && npm run build
```

## Troubleshooting

### Issue: Field renders in wrong slot or not at all
**Cause:** Mapping key doesn't match the fragment field name, or the slot name doesn't exist in `renderLayout()`.
**Solution:** Verify the field name in `aemFragmentMapping` matches `fragment.fields[].name` exactly. Check that the variant's `renderLayout()` includes `<slot name="...">` matching `mapping.slot`.

### Issue: cleanup() doesn't remove an attribute after re-hydration
**Cause:** The attribute is not in the `attributesToRemove` array in `cleanup()`.
**Solution:** Add the attribute name to the array:
```javascript
const attributesToRemove = [
    // ... existing
    'your-new-attribute',
];
```

### Issue: Badge vs trialBadge confusion
**Cause:** `processBadge` and `processTrialBadge` have different code paths. Badge can be slot-based OR attribute-based depending on `mapping.badge.slot`. TrialBadge always requires `mapping.trialBadge` to be defined.
**Solution:**
- For badge: check if mapping has `badge: true` (attribute mode) vs `badge: { tag, slot }` (slot mode)
- For trialBadge: ensure `mapping.trialBadge` is defined with `{ tag, slot }`, not just `true`
- Default badge colors: `DEFAULT_BADGE_COLOR = '#000000'`, `DEFAULT_BADGE_BACKGROUND_COLOR = '#F8D904'`
- Default trial badge border: `DEFAULT_TRIAL_BADGE_BORDER_COLOR = '#31A547'`

### Issue: Gradient border not rendering
**Cause:** `processBorderColor` uses regex `/-gradient/.test(fields.borderColor)` and `specialValues` lookup to detect gradients.
**Solution:** Ensure the border color value either:
1. Contains `-gradient` in the string, OR
2. Is listed in `borderColor.specialValues` with a value containing `gradient`
The function sets `gradient-border="true"` attribute and the color key as `border-color` attribute.

### Issue: Spectrum color border not applying drop-shadow
**Cause:** `processBorderColor` checks `/^spectrum-.*-(plans|special-offers)$/` regex. If your variant suffix doesn't match, the attribute won't be set.
**Solution:** The regex only matches `plans` or `special-offers` suffixes. For new variants, either update the regex or use a different approach.

### Issue: Variation fields show parent values when they should be empty
**Cause:** `createPreviewDataWithParent` inherits from parent when source values are `[]` or `['']` (for non-multiple fields). The `['']` sentinel for multi-value fields means "explicitly cleared."
**Solution:** For multi-value fields, ensure `field.multiple = true` is set. Then `['']` will be treated as explicit clear, not inheritance.

### Issue: Preview store not updating after field change
**Cause:** `SourceFragmentStore.updateField()` only propagates if `Fragment.updateField()` returns truthy. It returns `false` when values haven't changed or when going from `[]` to `['']` on single-value fields.
**Solution:** Check the return value. If you need to force an update, use `notify()` on the source store.

## Quick Commands Reference

```bash
# Build web components after hydrate.js changes
cd __MAS_DIR__/web-components && npm run build

# Run web component tests
cd __MAS_DIR__/web-components && npm run test

# Run studio tests
cd __MAS_DIR__/studio && npm run test

# Lint modified files
npx eslint web-components/src/hydrate.js
npx eslint web-components/src/variants/catalog.js

# Test with local MAS components
# Add ?maslibs=local to the URL

# Key source files
# Hydration:      web-components/src/hydrate.js
# Variants:       web-components/src/variants/*.js
# Fragment model:  studio/src/aem/fragment.js
# Source store:    studio/src/reactivity/source-fragment-store.js
# Preview store:   studio/src/reactivity/preview-fragment-store.js
# Editor context:  studio/src/reactivity/editor-context-store.js
# Reactive base:   studio/src/reactivity/reactive-store.js
# Fragment editor:  studio/src/mas-fragment-editor.js
```
