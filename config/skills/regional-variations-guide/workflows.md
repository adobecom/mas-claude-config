# Variation Workflows

Step-by-step guides for common variation operations.

---

## Workflow 1: Create a Regional Variation

### Prerequisites
- Fragment must be a parent (not a variation)
- Target locale must not already have a variation

### Steps

1. **Open the variations dialog**
   ```javascript
   // In editor toolbar or context menu
   openVariationDialog() {
     this.showVariationDialog = true;
   }
   ```

2. **Dialog loads existing variations**
   ```javascript
   // mas-variation-dialog.js
   async loadExistingVariations() {
     const variations = this.fragment.listLocaleVariations();
     this.existingLocales = variations.map(v => extractLocaleFromPath(v.path));
   }
   ```

3. **User selects target locale**
   ```javascript
   // Uses mas-locale-picker in region mode
   handleLocaleSelect(event) {
     this.targetLocale = event.detail.locale; // e.g., 'fr_FR'
   }
   ```

4. **Submit triggers creation**
   ```javascript
   async handleSubmit() {
     const variation = await this.repository.createVariation(
       this.fragment,
       this.targetLocale
     );
     this.dispatchEvent(new CustomEvent('fragment-copied', {
       detail: { variation }
     }));
   }
   ```

5. **Repository creates variation**
   ```javascript
   // mas-repository.js
   async createVariation(parentFragment, targetLocale) {
     // Create empty fragment in locale folder
     const variation = await this.aem.createEmptyVariation(
       parentFragment,
       targetLocale
     );

     // Update parent's variations field
     await this.aem.updateParentVariations(parentFragment, variation.path);

     return variation;
   }
   ```

### Result
- New fragment at `/content/dam/mas/{surface}/{targetLocale}/{name}`
- Parent's `variations` field updated with new path
- Variation inherits all field values from parent

---

## Workflow 2: Detect if Fragment is a Variation

### Using EditorContextStore

```javascript
// Step 1: Load fragment context
await this.editorContextStore.loadFragmentContext(fragmentId, fragmentPath);

// Step 2: Check variation status
const isVariation = this.editorContextStore.isVariation(fragmentId);

// Step 3: If variation, get parent data
if (isVariation) {
  const parent = await this.editorContextStore.getLocaleDefaultFragmentAsync();
  this.localeDefaultFragment = new Fragment(parent);
}
```

### Manual Detection (Path-Based)

```javascript
function isVariationByPath(fragmentPath, surface) {
  const match = fragmentPath.match(/\/content\/dam\/mas\/([^/]+)\/([^/]+)\//);
  if (!match) return false;

  const locale = match[2];
  return !isDefaultLocale(locale, surface);
}
```

### Detection in Editor Component

```javascript
// merch-card-editor.js
get effectiveIsVariation() {
  // Must be variation AND have parent loaded
  return this.isVariation && this.localeDefaultFragment !== null;
}
```

---

## Workflow 3: Load Parent Fragment Data

### Automatic Loading (via EditorContextStore)

```javascript
// Called during fragment load
async loadFragmentContext(fragmentId, fragmentPath) {
  // 1. Call fragment-client API
  const result = await previewFragmentForEditor(fragmentId, options);

  // 2. Extract parent ID
  this.defaultLocaleId = result.fragmentsIds?.['default-locale-id'];

  // 3. If different, fetch parent
  if (this.defaultLocaleId && this.defaultLocaleId !== fragmentId) {
    this.parentFetchPromise = this.fetchParent(this.defaultLocaleId);
  }
}

async fetchParent(parentId) {
  const parent = await this.aem.sites.cf.fragments.getById(parentId);
  this.localeDefaultFragment = parent;
  return parent;
}
```

### Waiting for Parent

```javascript
// Ensure parent is loaded before accessing
async ensureParentLoaded() {
  if (this.editorContextStore.parentFetchPromise) {
    await this.editorContextStore.parentFetchPromise;
  }
  return this.editorContextStore.localeDefaultFragment;
}
```

### Accessing Parent Data

```javascript
// Get parent fragment wrapper
const parent = await this.editorContextStore.getLocaleDefaultFragmentAsync();
this.localeDefaultFragment = new Fragment(parent);

// Access parent field values
const parentTitle = this.localeDefaultFragment.getFieldValue('title');
```

---

## Workflow 4: Override a Field Value

### In Editor Component

```javascript
// User types in field
handleFieldChange(fieldName, newValue) {
  // 1. Update source store
  this.fragmentStore.updateField(fieldName, newValue);

  // 2. Store propagates to preview
  // (automatic via notify())

  // 3. Field state becomes 'overridden'
  const state = this.getFieldState(fieldName);
  // state === 'overridden' if different from parent
}
```

### Store Update Flow

```javascript
// source-fragment-store.js
updateField(fieldName, value) {
  // Update fragment field
  const field = this.value.getField(fieldName);
  if (field) {
    field.values = [value];
  } else {
    this.value.fields.push({
      name: fieldName,
      values: [value]
    });
  }

  // Mark dirty and notify
  this.dirty = true;
  this.notify();
}
```

### Preview Update

```javascript
// preview-fragment-store.js (called via subscription)
handleSourceUpdate() {
  // Copy source values to preview
  this.syncFromSource();

  // Resolve placeholders and transformations
  this.resolveFragment();
}
```

---

## Workflow 5: Reset Field to Parent Value

### User Trigger

```javascript
// User clicks "Overridden. Click to restore."
renderFieldStatusIndicator(fieldName) {
  return html`
    <a @click=${() => this.resetFieldToParent(fieldName)}>
      Overridden. Click to restore.
    </a>
  `;
}
```

### Reset Implementation

```javascript
// merch-card-editor.js
async resetFieldToParent(fieldName) {
  // 1. Get parent values
  const parentField = this.localeDefaultFragment?.getField(fieldName);
  const parentValues = parentField?.values || [];

  // 2. Reset in source store
  const success = this.fragmentStore.resetFieldToParent(fieldName, parentValues);

  if (success) {
    // 3. Show confirmation
    showToast('Field restored to parent value', 'positive');

    // 4. Handle special field types
    if (this.isRTEField(fieldName)) {
      await this.updateRTEContent(fieldName, parentValues[0] || '');
    }
  }

  return success;
}
```

### Store Reset

```javascript
// source-fragment-store.js
resetFieldToParent(fieldName, parentValues = []) {
  // Clear own values (makes field inherited)
  const success = this.value.resetFieldToParent(fieldName);

  if (success) {
    this.notify();

    // Update preview with parent values for display
    this.previewStore.updateFieldWithParentValue(fieldName, parentValues);
  }

  return success;
}
```

### Fragment Reset

```javascript
// fragment.js
resetFieldToParent(fieldName) {
  const field = this.fields.find(f => f.name === fieldName);
  if (!field) return false;

  // Clear values - field now inherits
  field.values = [];
  return true;
}
```

---

## Workflow 6: Delete a Variation

### Delete Only Variation

```javascript
async deleteVariation(variationFragment) {
  // 1. Get parent
  const parentPath = await this.getParentPath(variationFragment);
  const parent = await this.aem.sites.cf.fragments.getByPath(parentPath);

  // 2. Remove from parent's variations field
  await this.aem.removeFromParentVariations(parent, variationFragment.path);

  // 3. Delete variation fragment
  await this.aem.sites.cf.fragments.delete(variationFragment.id);
}
```

### Delete Parent with All Variations

```javascript
// mas-repository.js
async deleteFragmentWithVariations(fragment) {
  // 1. Get all variations
  const variations = fragment.listLocaleVariations();

  // 2. Clear parent's variations field
  await this.aem.clearVariationsField(fragment);

  // 3. Delete each variation
  const results = { success: [], failed: [] };
  for (const variation of variations) {
    try {
      await this.aem.sites.cf.fragments.delete(variation.id);
      results.success.push(variation.path);
    } catch (error) {
      // Try force delete
      try {
        await this.aem.forceDelete(variation.path);
        results.success.push(variation.path);
      } catch {
        results.failed.push(variation.path);
      }
    }
  }

  // 4. Delete parent
  await this.aem.sites.cf.fragments.delete(fragment.id);

  return results;
}
```

---

## Workflow 7: List All Variations for a Fragment

### Using Fragment Method

```javascript
// fragment.js:243-259
listLocaleVariations() {
  const currentMatch = this.path.match(PATH_TOKENS);
  if (!currentMatch?.groups) return [];

  const { surface, parsedLocale, fragmentPath } = currentMatch.groups;

  return this.references?.filter((reference) => {
    const refMatch = reference.path.match(PATH_TOKENS);
    if (!refMatch?.groups) return false;

    return (
      surface === refMatch.groups.surface &&
      fragmentPath === refMatch.groups.fragmentPath &&
      parsedLocale !== refMatch.groups.parsedLocale
    );
  });
}
```

### Fallback: Search by Name

```javascript
// aem.js:906-960
async findVariationsByName(fragment) {
  const name = fragment.name;

  // Search for all fragments with same name
  const results = await this.sites.cf.fragments.search({
    query: name,
    path: `/content/dam/mas/${fragment.surface}`
  });

  // Filter to matching paths (same name, different locale)
  return results.filter(result => {
    const match = result.path.match(PATH_TOKENS);
    return (
      match?.groups?.fragmentPath === fragment.fragmentPath &&
      match?.groups?.parsedLocale !== fragment.locale
    );
  });
}
```

### Display in UI

```javascript
// mas-fragment-variations.js
renderVariations() {
  const variations = this.fragment.listLocaleVariations();

  return html`
    <table>
      <thead>
        <tr>
          <th>Locale</th>
          <th>Path</th>
        </tr>
      </thead>
      <tbody>
        ${variations.map(v => html`
          <tr @dblclick=${() => this.navigateToVariation(v)}>
            <td>${extractLocaleFromPath(v.path)}</td>
            <td>${v.path}</td>
          </tr>
        `)}
      </tbody>
    </table>
  `;
}
```

---

## Workflow 8: Check Existing Variation Locales

### Before Creating Variation

```javascript
// mas-variation-dialog.js
async loadExistingVariations() {
  // Get from parent's variations field
  const variationsField = this.fragment.getField('variations');
  const variationPaths = variationsField?.values || [];

  // Extract locales from paths
  this.existingLocales = variationPaths.map(path => {
    const match = path.match(/\/([a-z]{2}_[A-Z]{2})\//);
    return match ? match[1] : null;
  }).filter(Boolean);
}
```

### In Locale Picker

```javascript
// mas-locale-picker.js
get availableLocales() {
  const allLocales = getRegionLocales(this.surface, this.language);

  // Filter out existing variations
  return allLocales.filter(locale =>
    !this.existingLocales.includes(locale.code)
  );
}
```

### Visual Indicator

```javascript
renderLocaleOption(locale) {
  const exists = this.existingLocales.includes(locale.code);

  return html`
    <sp-menu-item
      value=${locale.code}
      ?disabled=${exists}
    >
      ${locale.label} ${exists ? '(exists)' : ''}
    </sp-menu-item>
  `;
}
```

---

## Error Handling Patterns

### Variation Creation Errors

```javascript
async createVariation(parentFragment, targetLocale) {
  // Validate: must be parent
  if (this.isVariation(parentFragment.id)) {
    throw new Error('Cannot create variation from a variation. Open the parent fragment first.');
  }

  // Validate: no duplicate
  const existing = await this.getExistingVariationLocales(parentFragment);
  if (existing.includes(targetLocale)) {
    throw new Error(`A variation for ${targetLocale} already exists.`);
  }

  // Validate: valid locale
  if (!isValidLocale(targetLocale, parentFragment.surface)) {
    throw new Error(`${targetLocale} is not a valid locale for this surface.`);
  }

  try {
    return await this.aem.createEmptyVariation(parentFragment, targetLocale);
  } catch (error) {
    if (error.status === 409) {
      throw new Error('Variation already exists. Please refresh and try again.');
    }
    throw error;
  }
}
```

### Parent Loading Errors

```javascript
async loadParent() {
  try {
    await this.editorContextStore.parentFetchPromise;
    return this.editorContextStore.localeDefaultFragment;
  } catch (error) {
    console.error('Failed to load parent fragment:', error);

    // Show degraded experience
    showToast('Parent fragment unavailable. Inheritance features disabled.', 'warning');

    return null;
  }
}
```
