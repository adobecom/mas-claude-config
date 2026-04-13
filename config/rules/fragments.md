# Fragment & Variation Rules

## Fragment Field Fallbacks

NEVER use variant-specific values in fallback logic:

```javascript
// BAD
if (!fieldsObject.variant) fieldsObject.variant = 'catalog';

// GOOD - generic handling
fieldsObject[field.name] = field.multiple ? [] : '';
// or pull from configuration
const defaults = getDefaultFieldValues();
fieldsObject[field.name] = defaults[field.name] ?? '';
```

## Variation Architecture (from npeltier - PR #432)

- Do NOT duplicate variation logic from mas/io
- Base `isVariation()` on data from `previewFragmentForEditor`, not custom logic
- Use `default-locale-id` from editor context store to determine parent
- Use `localeDefaultFragment` instead of `parentFragment`
- Return FULL context object from PreviewFragmentStore

## Variation Rules

- One variation per locale per fragment — no exceptions
- Do NOT allow creation if one already exists
- No "unique name" generation — fail with clear error message
