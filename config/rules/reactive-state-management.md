---
paths:
  - studio/src/reactivity/**/*.js
  - "**/store*.js"
  - "**/*-store.js"
  - "**/Store.js"
---

# Reactive State Management

## Core Architecture

### ReactiveStore Class

The foundation for all reactive state in MAS Studio:

```javascript
import { ReactiveStore } from './reactivity/reactive-store.js';

// Basic store with optional validator
const counterStore = new ReactiveStore(0);
const validatedStore = new ReactiveStore([], validateArray);

// Set with value or updater function
store.set(newValue);
store.set(prev => prev + 1);

// Subscribe for changes (called immediately with current value)
store.subscribe((value, oldValue) => {
    console.log('Changed from', oldValue, 'to', value);
});
```

### StoreController (Lit Integration)

Automatically manages subscription lifecycle with Lit components:

```javascript
import StoreController from './reactivity/store-controller.js';

class MyComponent extends LitElement {
    counter = new StoreController(this, counterStore);

    render() {
        return html`Count: ${this.counter.value}`;
    }
}
```

**Key benefits:**
- Subscribes on `hostConnected()`, unsubscribes on `hostDisconnected()`
- Automatically calls `requestUpdate()` on store changes
- Access current value via `controller.value`

### ReactiveController (Multiple Stores)

Monitor multiple stores at once:

```javascript
import ReactiveController from './reactivity/reactive-controller.js';

class MyComponent extends LitElement {
    reactivity = new ReactiveController(this, [store1, store2, store3]);

    // Component re-renders when ANY monitored store changes
}
```

## Fragment Store Pairs

### Source + Preview Pattern

Fragments always use paired stores:

```javascript
import generateFragmentStore from './reactivity/source-fragment-store.js';

const sourceStore = generateFragmentStore(fragment);
const previewStore = sourceStore.previewStore;

// Edit source (what users modify)
sourceStore.updateField('title', 'New Title');

// Preview automatically resolves placeholders
const resolved = previewStore.value;
```

| Store Type | Purpose | Updates DOM |
|-----------|---------|-------------|
| `SourceFragmentStore` | Editable fields | No |
| `PreviewFragmentStore` | Resolved with placeholders | Yes (`refreshAemFragment()`) |

### FragmentStore Methods

```javascript
// Update a field value
fragmentStore.updateField('fieldName', newValue);

// Update internal (not user-visible) field
fragmentStore.updateFieldInternal('fieldName', newValue);

// Refresh from external fragment data
fragmentStore.refreshFrom(newFragmentData);

// Discard all changes since last save
fragmentStore.discardChanges();

// Check if collection
if (fragmentStore.isCollection) { }
```

## Common Mistakes

### ❌ Manual Subscribe/Unsubscribe in Components

```javascript
// BAD: Memory leak risk
connectedCallback() {
    this.unsubscribe = store.subscribe(handler);
}
disconnectedCallback() {
    this.unsubscribe?.(); // Easy to forget
}

// GOOD: Use controllers
myStore = new StoreController(this, store);
```

### ❌ Mutating Store Value Directly

```javascript
// BAD: No notification triggered
store.value.push(item);

// GOOD: Use set() with immutable update
store.set(prev => [...prev, item]);
```

### ❌ Setting Same Primitive Value

```javascript
// BAD: For primitives, equal values are ignored
store.set(5);
store.set(5); // No notification!

// If you need to force notification:
store.notify(store.value);
```

### ❌ Creating Stores in Render

```javascript
// BAD: New store every render
render() {
    const store = new ReactiveStore(0); // Don't do this
}

// GOOD: Create in constructor or as class field
constructor() {
    this.store = new ReactiveStore(0);
}
```

## Store Validators

Ensure data consistency:

```javascript
// Validator normalizes incoming data
const pageValidator = (value) => ({
    index: value?.index ?? 1,
    size: value?.size ?? 12,
});

const pageStore = new ReactiveStore({ index: 1, size: 12 }, pageValidator);

// Or register later
store.registerValidator(newValidator);
```

## Store Metadata

Store additional info without triggering updates:

```javascript
store.setMeta('loading', true);
store.setMeta('error', errorObject);

if (store.hasMeta('loading')) {
    const isLoading = store.getMeta('loading');
}

store.removeMeta('loading');
```

## Object vs Primitive Reactivity

| Type | Behavior |
|------|----------|
| Primitive | Only notifies if value actually changed |
| Object | Always notifies (assumes mutation possible) |

```javascript
// Primitive: skips if equal
numberStore.set(5);
numberStore.set(5); // No notification

// Object: always notifies
objectStore.set({ a: 1 });
objectStore.set({ a: 1 }); // Still notifies
```

## Related Skills

- `preview-fragment-debugger` - Debug preview store issues
- `fragment-operation-debugger` - Debug fragment CRUD
- `field-inheritance-analyzer` - Understand field inheritance
