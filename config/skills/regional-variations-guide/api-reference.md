# API Reference

Complete reference for variation-related methods and constants.

---

## Fragment Class Methods

**File**: `studio/src/aem/fragment.js`

### Field State Methods

#### `getFieldState(fieldName, parentFragment, isVariation)`

Returns the inheritance state of a field.

```javascript
/**
 * @param {string} fieldName - The field name to check
 * @param {Fragment} parentFragment - The parent fragment (null if not a variation)
 * @param {boolean} isVariation - Whether current fragment is a variation
 * @returns {'no-parent' | 'inherited' | 'same-as-parent' | 'overridden'}
 */
getFieldState(fieldName, parentFragment, isVariation) {
  // Returns one of four states
}
```

**Example:**
```javascript
const state = fragment.getFieldState('title', parentFragment, true);
// 'overridden' - field has different value than parent
```

#### `isFieldOverridden(fieldName, parentFragment, isVariation)`

Convenience method to check if field is overridden.

```javascript
/**
 * @returns {boolean}
 */
isFieldOverridden(fieldName, parentFragment, isVariation) {
  return this.getFieldState(fieldName, parentFragment, isVariation) === 'overridden';
}
```

### Effective Value Methods

#### `getEffectiveFieldValue(fieldName, parentFragment, isVariation, index)`

Returns the resolved value (own or inherited).

```javascript
/**
 * @param {string} fieldName - The field name
 * @param {Fragment} parentFragment - Parent fragment for inheritance
 * @param {boolean} isVariation - Whether this is a variation
 * @param {number} index - Array index for multi-value fields (default: 0)
 * @returns {string | null} The effective value
 */
getEffectiveFieldValue(fieldName, parentFragment, isVariation, index = 0)
```

**Example:**
```javascript
// Variation has empty title, inherits from parent
const title = fragment.getEffectiveFieldValue('title', parent, true);
// Returns parent's title value
```

#### `getEffectiveFieldValues(fieldName, parentFragment, isVariation)`

Returns all effective values for multi-value fields.

```javascript
/**
 * @returns {string[]} Array of effective values
 */
getEffectiveFieldValues(fieldName, parentFragment, isVariation)
```

### Reset Methods

#### `resetFieldToParent(fieldName)`

Clears field values to enable inheritance.

```javascript
/**
 * @param {string} fieldName - The field to reset
 * @returns {boolean} Success status
 */
resetFieldToParent(fieldName) {
  const field = this.fields.find(f => f.name === fieldName);
  if (!field) return false;
  field.values = [];
  return true;
}
```

### Variation Discovery Methods

#### `listLocaleVariations()`

Returns all locale variations of this fragment.

```javascript
/**
 * @returns {Array<{id: string, path: string}>} Variation references
 */
listLocaleVariations()
```

**Example:**
```javascript
const variations = fragment.listLocaleVariations();
// [
//   { id: 'abc123', path: '/content/dam/mas/acom/fr_FR/my-card' },
//   { id: 'def456', path: '/content/dam/mas/acom/de_DE/my-card' }
// ]
```

---

## AEM API Methods

**File**: `studio/src/aem/aem.js`

### Creation Methods

#### `createEmptyVariation(parentFragment, targetLocale)`

Creates a new variation with no field values (pure inheritance).

```javascript
/**
 * @param {Fragment} parentFragment - The parent fragment
 * @param {string} targetLocale - Target locale code (e.g., 'fr_FR')
 * @returns {Promise<Fragment>} The created variation
 * @throws {Error} If variation already exists
 */
async createEmptyVariation(parentFragment, targetLocale)
```

**Implementation details** (lines 756-813):
- Builds target path from parent path with new locale
- Ensures target folder exists
- Creates fragment with empty fields
- Copies tags from parent
- Polls for creation confirmation

#### `updateParentVariations(parentFragment, variationPath)`

Adds a variation path to parent's variations field.

```javascript
/**
 * @param {Fragment} parentFragment - The parent fragment
 * @param {string} variationPath - Path of new variation
 * @returns {Promise<void>}
 */
async updateParentVariations(parentFragment, variationPath)
```

**Implementation details** (lines 821-858):
- Gets parent with ETag for optimistic locking
- Finds or creates `variations` field
- Appends new path
- Saves with ETag
- Polls for confirmation

### Deletion Methods

#### `clearVariationsField(fragment)`

Clears the variations field (used before deletion).

```javascript
/**
 * @param {Fragment} fragment - Fragment to clear
 * @returns {Promise<Fragment>} Updated fragment
 */
async clearVariationsField(fragment)
```

#### `removeFromParentVariations(parentFragment, variationPath)`

Removes a specific variation from parent's variations field.

```javascript
/**
 * @param {Fragment} parentFragment - The parent fragment
 * @param {string} variationPath - Path to remove
 * @returns {Promise<void>}
 */
async removeFromParentVariations(parentFragment, variationPath)
```

### Search Methods

#### `findVariationsByName(fragment)`

Searches for variations by fragment name (fallback method).

```javascript
/**
 * @param {Fragment} fragment - Fragment to find variations for
 * @returns {Promise<Array<{id: string, path: string}>>}
 */
async findVariationsByName(fragment)
```

---

## Store Methods

### EditorContextStore

**File**: `studio/src/reactivity/editor-context-store.js`

#### `loadFragmentContext(fragmentId, fragmentPath)`

Loads variation context including parent detection.

```javascript
/**
 * @param {string} fragmentId - Current fragment ID
 * @param {string} fragmentPath - Current fragment path
 * @returns {Promise<void>}
 */
async loadFragmentContext(fragmentId, fragmentPath)
```

**Sets these properties:**
- `defaultLocaleId` - Parent fragment ID (if variation)
- `isVariationByPath` - Path-based detection result
- `localeDefaultFragment` - Cached parent data
- `parentFetchPromise` - Promise for async parent loading

#### `isVariation(fragmentId)`

Checks if fragment is a variation.

```javascript
/**
 * @param {string} fragmentId - Fragment to check
 * @returns {boolean}
 */
isVariation(fragmentId)
```

#### `getLocaleDefaultFragmentAsync()`

Returns parent fragment data (async).

```javascript
/**
 * @returns {Promise<Fragment | null>}
 */
async getLocaleDefaultFragmentAsync()
```

### SourceFragmentStore

**File**: `studio/src/reactivity/source-fragment-store.js`

#### `updateField(fieldName, value)`

Updates a field value.

```javascript
/**
 * @param {string} fieldName - Field to update
 * @param {string} value - New value
 */
updateField(fieldName, value)
```

#### `resetFieldToParent(fieldName, parentValues)`

Resets field to inherit from parent.

```javascript
/**
 * @param {string} fieldName - Field to reset
 * @param {string[]} parentValues - Parent values for preview
 * @returns {boolean} Success status
 */
resetFieldToParent(fieldName, parentValues = [])
```

### PreviewFragmentStore

**File**: `studio/src/reactivity/preview-fragment-store.js`

#### `updateFieldWithParentValue(fieldName, parentValues)`

Updates preview with inherited parent values.

```javascript
/**
 * @param {string} fieldName - Field to update
 * @param {string[]} parentValues - Values to merge
 */
updateFieldWithParentValue(fieldName, parentValues)
```

---

## Repository Methods

**File**: `studio/src/mas-repository.js`

#### `createVariation(parentFragment, targetLocale)`

High-level variation creation with validation.

```javascript
/**
 * @param {Fragment} parentFragment - Parent fragment
 * @param {string} targetLocale - Target locale (e.g., 'fr_FR')
 * @returns {Promise<Fragment>} Created variation
 * @throws {Error} If creating from variation or duplicate exists
 */
async createVariation(parentFragment, targetLocale)
```

#### `deleteFragmentWithVariations(fragment)`

Deletes fragment and all its variations.

```javascript
/**
 * @param {Fragment} fragment - Fragment to delete
 * @returns {Promise<{success: string[], failed: string[]}>}
 */
async deleteFragmentWithVariations(fragment)
```

#### `getExistingVariationLocales(fragment)`

Returns locales that already have variations.

```javascript
/**
 * @param {Fragment} fragment - Fragment to check
 * @returns {Promise<string[]>} Array of locale codes
 */
async getExistingVariationLocales(fragment)
```

---

## Constants and Patterns

### Path Pattern

**File**: `studio/src/aem/fragment.js`

```javascript
const PATH_TOKENS = /\/content\/dam\/mas\/(?<surface>[^/]+)\/(?<parsedLocale>[^/]+)\/(?<fragmentPath>.+)/;
```

**Groups:**
- `surface` - e.g., `acom`, `cc`
- `parsedLocale` - e.g., `en_US`, `fr_FR`
- `fragmentPath` - e.g., `cards/my-card`

### Default Locale Detection

**File**: `studio/src/locales.js`

```javascript
/**
 * Check if locale is default for surface
 * @param {string} locale - e.g., 'en_US'
 * @param {string} surface - e.g., 'acom'
 * @returns {boolean}
 */
function isDefaultLocale(locale, surface)

/**
 * Get default locale for surface
 * @param {string} surface - e.g., 'acom'
 * @returns {string} Default locale code
 */
function getDefaultLocale(surface)
```

### Locale Data Structure

```javascript
// locales.js
const locales = [
  { lang: 'en', country: 'US', default: ALL_SURFACES },
  { lang: 'en', country: 'GB', region: ACOM_SURFACES },
  { lang: 'fr', country: 'FR', default: ACOM_SURFACES },
  { lang: 'fr', country: 'CA', region: ACOM_SURFACES },
  // ... 74 countries total
];
```

**Properties:**
- `lang` - ISO 639-1 language code
- `country` - ISO 3166-1 country code
- `default` - Surfaces where this is the default locale
- `region` - Surfaces where this is a regional variation

### Surface Constants

```javascript
const ALL_SURFACES = ['acom', 'cc', 'dc', 'bacom'];
const ACOM_SURFACES = ['acom'];
const CC_SURFACES = ['cc'];
```

---

## Type Definitions

### FieldState

```typescript
type FieldState = 'no-parent' | 'inherited' | 'same-as-parent' | 'overridden';
```

### VariationReference

```typescript
interface VariationReference {
  id: string;       // Fragment ID
  path: string;     // Full AEM path
}
```

### LocaleConfig

```typescript
interface LocaleConfig {
  lang: string;     // 'en', 'fr', 'de', etc.
  country: string;  // 'US', 'FR', 'DE', etc.
  default?: string[];  // Surfaces where this is default
  region?: string[];   // Surfaces where this is regional
}
```

---

## Error Codes

### AEM API Errors

| Code | Description | Resolution |
|------|-------------|------------|
| 404 | Fragment not found | Fragment may have been deleted |
| 409 | Conflict (ETag mismatch) | Retry with fresh ETag |
| 412 | Precondition failed | Fragment was modified, refetch |
| 500 | Server error | Retry or check AEM logs |

### Validation Errors

| Error | Cause | Resolution |
|-------|-------|------------|
| "Cannot create from variation" | Tried to create variation from variation | Open parent fragment first |
| "Variation already exists" | Duplicate locale | Choose different locale |
| "Invalid locale" | Locale not supported for surface | Check locale configuration |

---

## Events

### Fragment Events

```javascript
// Variation created
'fragment-copied': CustomEvent<{ variation: Fragment }>

// Fragment deleted
'fragment-deleted': CustomEvent<{ fragmentId: string }>

// Field reset to parent
'field-reset': CustomEvent<{ fieldName: string }>
```

### Store Events

```javascript
// Fragment data changed
'fragment-changed': CustomEvent<{ fragment: Fragment }>

// Preview updated
'preview-updated': CustomEvent<{ preview: ResolvedFragment }>
```

---

## Polling Configuration

AEM operations are eventually consistent. The system polls for confirmation:

```javascript
const POLL_CONFIG = {
  maxAttempts: 10,      // Maximum poll attempts
  intervalMs: 250,      // Interval between polls
  timeoutMs: 2500       // Total timeout (maxAttempts * intervalMs)
};
```

**Polling triggers:**
- After `createEmptyVariation()` - waits for fragment to appear
- After `updateParentVariations()` - waits for field update
- After `clearVariationsField()` - waits for field clear
- After any `save()` operation - waits for ETag change
