# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

The reactivity system provides a custom reactive state management solution integrated with Lit components. This is MAS Studio's core state management layer that powers reactive updates throughout the application.

## Core Architecture

### ReactiveStore (`reactive-store.js`)
The foundation class for reactive state management:
- Holds state in `value` property with optional validation via `validator` function
- Implements publish-subscribe pattern with `subscribe()`, `unsubscribe()`, `notify()`
- `set()` method accepts either a new value or an update function: `store.set(newValue)` or `store.set(prev => prev + 1)`
- Supports metadata storage via `setMeta()`, `getMeta()`, `hasMeta()`, `removeMeta()`
- Primitive values only trigger updates if the value actually changes
- Object values are always considered changed and trigger notifications

### Lit Integration

**StoreController** (`store-controller.js`)
- Connects a single `ReactiveStore` to a Lit component
- Automatically subscribes on `hostConnected()` and unsubscribes on `hostDisconnected()`
- Stores the current value in `controller.value` property
- Calls `host.requestUpdate()` when store changes

**ReactiveController** (`reactive-controller.js`)
- Monitors multiple `ReactiveStore` instances simultaneously
- Requests Lit component update when any monitored store changes
- Supports optional callback function that executes after each update
- Use `updateStores(stores)` to change which stores are monitored dynamically

### Fragment Stores

The system provides specialized store classes for managing Fragment objects:

**FragmentStore** (`fragment-store.js`)
- Extends `ReactiveStore` to work with `Fragment` instances
- Provides convenience methods: `updateField()`, `updateFieldInternal()`, `refreshFrom()`, `discardChanges()`
- Automatically refreshes corresponding `<aem-fragment>` elements in the DOM via `refreshAemFragment()`
- Exposes `loading` state for async operations
- `isCollection` getter checks if fragment is a collection type

**PreviewFragmentStore** (`preview-fragment-store.js`)
- Shows resolved/preview version of fragment with placeholders replaced
- Calls `previewStudioFragment()` to resolve placeholders using current context (locale, surface, dictionary)
- Uses `replaceFrom()` instead of `set()` to maintain object reference stability
- Automatically resolves when fields change or when placeholder dictionary updates
- Skips resolution for collection fragments or when no preview placeholders are available

**SourceFragmentStore** (`source-fragment-store.js`)
- Contains the editable/source version of a fragment
- Always paired with a `PreviewFragmentStore` via `generateFragmentStore()`
- Propagates all field updates to its paired preview store
- Source is what editors modify; preview shows the resolved result
- Does not refresh `<aem-fragment>` cache (only preview store does)

**generateFragmentStore()** function creates linked source/preview store pairs:
```javascript
const sourceStore = generateFragmentStore(fragment);
// sourceStore.previewStore contains the paired preview store
```

### MasEvent (`mas-event.js`)
Simple event emitter for application events:
- `subscribe(fn)` - Register event listener
- `unsubscribe(fn)` - Remove event listener
- `emit(options)` - Trigger event with optional data

## Usage Patterns

### Basic Store with Lit Component
```javascript
import { ReactiveStore } from './reactive-store.js';
import StoreController from './store-controller.js';

const counterStore = new ReactiveStore(0);

class MyComponent extends LitElement {
  counter = new StoreController(this, counterStore);

  render() {
    return html`Count: ${this.counter.value}`;
  }
}
```

### Monitoring Multiple Stores
```javascript
import ReactiveController from './reactive-controller.js';

class MyComponent extends LitElement {
  reactivity = new ReactiveController(this, [store1, store2, store3]);

  // Component re-renders when any store changes
}
```

### Fragment Editing Pattern
```javascript
import generateFragmentStore from './source-fragment-store.js';

const fragmentStore = generateFragmentStore(fragment);

// Edit the source
fragmentStore.updateField('title', 'New Title');

// Preview store automatically reflects the change with resolved placeholders
const previewValue = fragmentStore.previewStore.value;
```

## Important Notes

- **Object Reference Stability**: `PreviewFragmentStore` maintains object reference with `replaceFrom()` to avoid breaking Lit component references
- **Notification Chain**: `SourceFragmentStore` → `PreviewFragmentStore` → DOM refresh happens automatically
- **Validation**: Store validators run on every `set()` call to ensure data consistency
- **Subscription Lifecycle**: Controllers automatically manage subscribe/unsubscribe based on Lit component lifecycle
- **Performance**: Primitive value stores skip updates if value hasn't changed; use `notify()` to force an update
