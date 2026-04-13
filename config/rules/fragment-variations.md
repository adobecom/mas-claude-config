---
paths:
  - io/studio/**/*.js
  - "**/variation*.js"
  - "**/fragment*.js"
  - studio/src/**/*variation*.js
  - studio/src/**/*fragment*.js
---

# Fragment & Variation Rules

## Architecture Principles

### Do NOT Duplicate Variation Logic from mas/io

The I/O Runtime layer (`io/`) already handles variation detection and context resolution. Studio code should consume this context, not recreate the logic.

### Use Editor Store for Variation Detection

Base `isVariation()` on data from `previewFragmentForEditor`, not custom logic:

```javascript
// Get parent info from editor context
const defaultLocaleId = context.fragmentIds['default-locale-id'];

// If empty, current fragment IS the locale default (parent)
const isVariation = defaultLocaleId && defaultLocaleId !== currentFragmentId;
```

### PreviewFragmentStore - Return Full Context

- Use a clone of `fragment.previewFragment` that returns the FULL context object
- Access parent info via `context.fragmentIds['default-locale-id']`
- Return whole context - future needs may require additional data

## Naming Conventions

| Term | Usage |
|------|-------|
| `localeDefaultFragment` | The parent fragment (locale default) |
| `parentFragment` | Avoid - use `localeDefaultFragment` instead |
| `previewFragmentForEditor` | Function name for editor preview |

## Variation Rules

### One Variation Per Locale Per Fragment

- Do NOT allow creation of a variation if one already exists for that locale
- No "unique name" generation - fail with clear error message
- Must have exactly one regional variation per fragment per locale

```javascript
// When creating a variation
if (existingVariationForLocale) {
    throw new Error(`Variation already exists for locale ${locale}`);
}
```

## Field Value Comparison

### Inheritance Detection Pattern

Compare `previewFragmentForEditor` store values vs current fragment field values:
- **Different values** = inherited field (using parent's value)
- **Same values** = effective (overridden) field value

```javascript
// Future pattern: chain of parents, not just one parent
const parentValue = localeDefaultFragment.fields[fieldName];
const currentValue = currentFragment.fields[fieldName];

const isInherited = parentValue === currentValue;
```

## Field Fallback Anti-Patterns

### Never Hardcode Variant-Specific Fallbacks

```javascript
// BAD: Hardcoded fallback
if (field.name === 'variant' && !field.values?.length) {
    fieldsObject.variant = 'catalog';  // Never do this
}

// GOOD: Generic handling
fieldsObject[field.name] = field.multiple
    ? (field.values ?? [])
    : (field.values?.[0] ?? '');
```

## Related Skills

- `fragment-variation-tester` - Test and validate fragment variations
- `field-inheritance-analyzer` - Deep analysis of field inheritance
- `fragment-operation-debugger` - Debug fragment CRUD operations
