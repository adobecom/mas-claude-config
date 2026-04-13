# Field Inheritance Patterns

Detailed documentation of how field values are inherited between parent fragments and variations.

---

## Field States

Every field in a variation exists in one of four states:

### 1. `no-parent`

**Meaning**: The fragment is not a variation, or parent data is unavailable.

```javascript
// Condition
if (!isVariation || !parentFragment) {
  return 'no-parent';
}
```

**UI Behavior**: No inheritance indicator shown.

### 2. `inherited`

**Meaning**: The field is empty in the variation and inherits from parent.

```javascript
// Condition
const ownIsEmpty = isEffectivelyEmpty(ownValues);
const parentIsEmpty = isEffectivelyEmpty(parentValues);

if (ownIsEmpty && parentIsEmpty) return 'inherited';  // Both empty
if (ownIsEmpty) return 'inherited';  // Own empty, uses parent
```

**UI Behavior**: No indicator. Field shows parent value in preview.

### 3. `same-as-parent`

**Meaning**: The field has an explicit value that matches the parent exactly.

```javascript
// Condition
const areEqual = compareFieldValues(ownValues, parentValues);
if (areEqual) return 'same-as-parent';
```

**UI Behavior**: No indicator. Technically overridden but matches parent.

### 4. `overridden`

**Meaning**: The field has an explicit value different from parent.

```javascript
// Condition - after all other checks
return 'overridden';
```

**UI Behavior**: Shows "Overridden. Click to restore." link.

---

## State Detection Logic

### Complete Implementation

**File**: `studio/src/aem/fragment.js:184-223`

```javascript
getFieldState(fieldName, parentFragment, isVariation) {
  // Rule 1: Not a variation
  if (!isVariation || !parentFragment) {
    return 'no-parent';
  }

  const ownField = this.getField(fieldName);
  const parentField = parentFragment.getField(fieldName);

  const ownValues = ownField?.values || [];
  const parentValues = parentField?.values || [];

  // Helper: Check if values are effectively empty
  const isEffectivelyEmpty = (values) =>
    values.length === 0 ||
    values.every((v) => v === '' || v === null || v === undefined);

  const ownIsEmpty = isEffectivelyEmpty(ownValues);
  const parentIsEmpty = isEffectivelyEmpty(parentValues);

  // Rule 2: Both empty = inherited (nothing to compare)
  if (ownIsEmpty && parentIsEmpty) {
    return 'inherited';
  }

  // Rule 3: Own empty = inherits parent value
  if (ownIsEmpty) {
    return 'inherited';
  }

  // Rule 4: Compare values with normalization
  const normalizeForComparison = (v) => {
    if (v === null || v === undefined) return '';
    if (typeof v === 'string') {
      return v
        .normalize('NFC')           // Unicode normalization
        .trim()                     // Whitespace
        .replace(/\s+role="[^"]*"/g, '')      // ARIA role
        .replace(/\s+aria-level="[^"]*"/g, ''); // ARIA level
    }
    return String(v);
  };

  const areEqual =
    ownValues.length === parentValues.length &&
    ownValues.every((v, i) =>
      normalizeForComparison(v) === normalizeForComparison(parentValues[i])
    );

  return areEqual ? 'same-as-parent' : 'overridden';
}
```

### Decision Tree

```
                    ┌─────────────────┐
                    │  isVariation?   │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │ NO           │              │ YES
              ▼              │              ▼
        ┌──────────┐         │    ┌─────────────────┐
        │ no-parent│         │    │ parentFragment? │
        └──────────┘         │    └────────┬────────┘
                             │             │
                             │    ┌────────┼────────┐
                             │    │ NO     │        │ YES
                             │    ▼        │        ▼
                             │ ┌──────────┐│ ┌──────────────┐
                             │ │ no-parent││ │ownValues     │
                             │ └──────────┘│ │empty?        │
                             │             │ └──────┬───────┘
                             │             │        │
                             │             │ ┌──────┼──────┐
                             │             │ │ YES  │      │ NO
                             │             │ ▼      │      ▼
                             │      ┌───────────┐  │ ┌────────────┐
                             │      │ inherited │  │ │ values     │
                             │      └───────────┘  │ │ match?     │
                             │                     │ └─────┬──────┘
                             │                     │       │
                             │                     │ ┌─────┼─────┐
                             │                     │ │ YES │     │ NO
                             │                     │ ▼     │     ▼
                             │             ┌──────────────┐│ ┌──────────┐
                             │             │same-as-parent││ │overridden│
                             │             └──────────────┘│ └──────────┘
```

---

## Value Normalization

Before comparing field values, normalization handles common differences:

### NFC Unicode Normalization

Different Unicode representations of the same character:

```javascript
// Example: é can be represented as:
// - U+00E9 (precomposed)
// - U+0065 + U+0301 (decomposed)

'café'.normalize('NFC') === 'café'.normalize('NFC') // true
```

### Whitespace Trimming

Removes leading/trailing whitespace:

```javascript
'  hello  '.trim() === 'hello' // true
```

### ARIA Attribute Removal

RTE content may include ARIA attributes that shouldn't affect comparison:

```javascript
const clean = html
  .replace(/\s+role="[^"]*"/g, '')
  .replace(/\s+aria-level="[^"]*"/g, '');

// Before: <h2 role="heading" aria-level="2">Title</h2>
// After:  <h2>Title</h2>
```

---

## Effective Value Resolution

When displaying a field, use `getEffectiveFieldValue()` to get the resolved value:

### Implementation

```javascript
// studio/src/aem/fragment.js:162-170
getEffectiveFieldValue(fieldName, parentFragment, isVariation, index = 0) {
  const ownValue = this.getFieldValue(fieldName, index);

  // Has own value - use it
  if (ownValue) return ownValue;

  // Not a variation or no parent - return own (even if empty)
  if (!isVariation || !parentFragment) return ownValue;

  // Inherit from parent
  return parentFragment.getFieldValue(fieldName, index);
}
```

### For Multiple Values

```javascript
// studio/src/aem/fragment.js:172-182
getEffectiveFieldValues(fieldName, parentFragment, isVariation) {
  const ownField = this.getField(fieldName);

  if (ownField && ownField.values && ownField.values.length > 0) {
    return ownField.values;
  }

  if (!parentFragment || !isVariation) {
    return ownField?.values || [];
  }

  const parentField = parentFragment.getField(fieldName);
  return parentField?.values || [];
}
```

---

## Store Propagation Chain

Changes flow through the store chain:

```
┌─────────────────────────────────────────────────────────────────┐
│                     STORE PROPAGATION                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  User Edit                                                       │
│      │                                                           │
│      ▼                                                           │
│  ┌────────────────────┐                                         │
│  │ SourceFragmentStore│  Holds pending edits                    │
│  │                    │  - updateField(name, value)              │
│  │                    │  - resetFieldToParent(name, parentVal)   │
│  └─────────┬──────────┘                                         │
│            │                                                     │
│            │ notify()                                            │
│            ▼                                                     │
│  ┌────────────────────┐                                         │
│  │ PreviewFragmentStore│ Resolves for preview                   │
│  │                    │ - Merges inherited fields                │
│  │                    │ - Calls transformation pipeline          │
│  │                    │ - Updates live preview                   │
│  └─────────┬──────────┘                                         │
│            │                                                     │
│            │ save()                                              │
│            ▼                                                     │
│  ┌────────────────────┐                                         │
│  │ AEM Fragment       │  Persists to AEM                        │
│  │                    │  - sites.cf.fragments.save()             │
│  └────────────────────┘                                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### SourceFragmentStore

**File**: `studio/src/reactivity/source-fragment-store.js`

```javascript
// Update a field
updateField(fieldName, value) {
  this.value.setFieldValue(fieldName, value);
  this.dirty = true;
  this.notify();
}

// Reset field to parent value
resetFieldToParent(fieldName, parentValues = []) {
  const success = this.value.resetFieldToParent(fieldName);
  if (success) {
    this.notify();
    // Update preview with parent values
    this.previewStore.updateFieldWithParentValue(fieldName, parentValues);
  }
  return success;
}
```

### PreviewFragmentStore

**File**: `studio/src/reactivity/preview-fragment-store.js`

```javascript
// Merge inherited field into preview
updateFieldWithParentValue(fieldName, parentValues) {
  const field = this.value.getField(fieldName);

  if (field) {
    field.values = parentValues;
  } else if (parentValues.length > 0) {
    // Add inherited field to preview
    this.value.fields.push({
      name: fieldName,
      values: parentValues,
      multiple: parentValues.length > 1
    });
  }

  this.resolveFragment();
}
```

---

## Reset to Parent Mechanism

When user clicks "Click to restore", the field is reset to inherit from parent:

### Flow

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────────┐
│ User clicks  │     │ Fragment.reset   │     │ Stores update    │
│ "restore"    │────►│ FieldToParent()  │────►│ with parent val  │
└──────────────┘     └──────────────────┘     └──────────────────┘
```

### Implementation

```javascript
// studio/src/editors/merch-card-editor.js
async resetFieldToParent(fieldName) {
  // 1. Get parent values
  const parentValues = this.localeDefaultFragment?.getField(fieldName)?.values || [];

  // 2. Reset in source store (clears own value)
  const success = this.fragmentStore.resetFieldToParent(fieldName, parentValues);

  if (success) {
    showToast('Field restored to parent value', 'positive');

    // 3. Special handling for RTE fields
    if (this.isRTEField(fieldName)) {
      this.updateRTEContent(fieldName, parentValues[0]);
    }
  }

  return success;
}
```

### Fragment Reset Method

```javascript
// studio/src/aem/fragment.js
resetFieldToParent(fieldName) {
  const field = this.fields.find(f => f.name === fieldName);
  if (!field) return false;

  // Clear values - makes field "inherited"
  field.values = [];
  return true;
}
```

---

## Tags Field Special Handling

Tags use custom comparison logic since they're stored differently:

```javascript
// studio/src/editors/merch-card-editor.js:93-104
getTagsFieldState() {
  if (!this.effectiveIsVariation) return 'no-parent';

  // Get own tags (pending or existing)
  const ownTags = (this.fragment.newTags || this.fragment.tags.map(t => t.id))
    .slice()
    .sort()
    .join(',');

  // Get parent tags
  const parentTags = this.localeDefaultFragment?.tags
    .map(t => t.id)
    .sort()
    .join(',') || '';

  if (!ownTags && !parentTags) return 'inherited';
  if (!ownTags) return 'inherited';
  return ownTags === parentTags ? 'same-as-parent' : 'overridden';
}
```

---

## UI Integration

### Field Status Indicator

```javascript
// studio/src/editors/merch-card-editor.js
renderFieldStatusIndicator(fieldName) {
  // Only show for variations
  if (!this.effectiveIsVariation) return nothing;

  // Only show for overridden fields
  const state = this.getFieldState(fieldName);
  if (state !== 'overridden') return nothing;

  return html`
    <div class="field-status-indicator">
      <a @click=${(e) => {
        e.preventDefault();
        this.resetFieldToParent(fieldName);
      }}>
        <sp-icon-unlink></sp-icon-unlink>
        Overridden. Click to restore.
      </a>
    </div>
  `;
}
```

### CSS Styling

```css
.field-status-indicator {
  font-size: 12px;
  color: var(--spectrum-orange-600);
  margin-top: 4px;
}

.field-status-indicator a {
  cursor: pointer;
  text-decoration: none;
  display: flex;
  align-items: center;
  gap: 4px;
}

.field-status-indicator a:hover {
  text-decoration: underline;
}
```

---

## Common Patterns

### Pattern: Check Field Before Operation

```javascript
// Only perform operation if field is overridden
const state = this.getFieldState(fieldName);
if (state === 'overridden') {
  // Perform reset or highlight operation
}
```

### Pattern: Get Displayed Value

```javascript
// Always use effective value for display
const displayValue = this.fragment.getEffectiveFieldValue(
  fieldName,
  this.localeDefaultFragment,
  this.effectiveIsVariation
);
```

### Pattern: Conditional Inheritance UI

```javascript
renderField(fieldName) {
  const value = this.getEffectiveFieldValue(fieldName);
  const state = this.getFieldState(fieldName);

  return html`
    <div class="field ${state}">
      <label>${fieldName}</label>
      <input .value=${value} @change=${(e) => this.handleChange(fieldName, e)}>
      ${this.renderFieldStatusIndicator(fieldName)}
    </div>
  `;
}
```

---

## Debugging Tips

### Log Field States

```javascript
// Debug all field states
this.fragment.fields.forEach(field => {
  const state = this.fragment.getFieldState(
    field.name,
    this.localeDefaultFragment,
    this.effectiveIsVariation
  );
  console.log(`${field.name}: ${state}`, {
    own: field.values,
    parent: this.localeDefaultFragment?.getField(field.name)?.values
  });
});
```

### Check Normalization Issues

```javascript
// Compare raw vs normalized
const own = this.fragment.getFieldValue(fieldName);
const parent = this.localeDefaultFragment?.getFieldValue(fieldName);

console.log('Raw own:', JSON.stringify(own));
console.log('Raw parent:', JSON.stringify(parent));
console.log('Normalized own:', own?.normalize('NFC').trim());
console.log('Normalized parent:', parent?.normalize('NFC').trim());
```

### Verify Store Chain

```javascript
// Check values at each store level
console.log('Source store:', this.fragmentStore.value.getField(fieldName));
console.log('Preview store:', this.previewStore.value.getField(fieldName));
console.log('Parent fragment:', this.localeDefaultFragment?.getField(fieldName));
```
