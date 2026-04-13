---
paths:
  - "**/events.js"
  - "**/mas-event.js"
  - studio/src/**/*.js
---

# Event-Driven Communication

## MasEvent Class

Lightweight event emitter for application-wide events:

```javascript
import MasEvent from './reactivity/mas-event.js';

const myEvent = new MasEvent();

// Subscribe (returns nothing, must manually unsubscribe)
myEvent.subscribe((data) => {
    console.log('Event received:', data);
});

// Emit to all subscribers
myEvent.emit({ type: 'action', payload: data });

// Unsubscribe
myEvent.unsubscribe(handlerFn);
```

## Global Event Bus

Central application events defined in `studio/src/events.js`:

```javascript
import Events from './events.js';

// Available events:
Events.toast        // Show notification toasts
Events.fragmentAdded     // Fragment created
Events.fragmentDeleted   // Fragment deleted
Events.filtersReset     // Filter panel reset

// Usage
Events.toast.emit({ variant: 'positive', message: 'Saved!' });
Events.fragmentAdded.emit({ fragment });
```

### Toast Events

```javascript
// Show success toast
Events.toast.emit({
    variant: 'positive',
    message: 'Fragment saved successfully',
});

// Show error toast
Events.toast.emit({
    variant: 'negative',
    message: 'Failed to save fragment',
});

// Variants: 'positive', 'negative', 'info', 'warning'
```

## Custom Events in Web Components

### Dispatch Pattern

```javascript
class MyComponent extends LitElement {
    handleAction() {
        this.dispatchEvent(new CustomEvent('action-complete', {
            bubbles: true,
            composed: true,  // Cross shadow DOM
            detail: { result: 'success' },
        }));
    }
}
```

### Component Constants

Use shared event constants from `studio/src/constants.js`:

```javascript
import { EVENT_CHANGE, EVENT_INPUT } from '../constants.js';

// Dispatch standard events
this.dispatchEvent(new CustomEvent(EVENT_CHANGE, {
    bubbles: true,
    composed: true,
    detail: this,
}));
```

| Constant | Use Case |
|----------|----------|
| `EVENT_CHANGE` | Value committed (blur, enter, selection) |
| `EVENT_INPUT` | Value changing (typing, dragging) |

## Events vs Stores: When to Use Which

| Scenario | Use |
|----------|-----|
| Persistent state (user selections, data) | ReactiveStore |
| Transient notification (toast, error) | MasEvent |
| Component communication (parent-child) | CustomEvent |
| Global state sync (filters, context) | ReactiveStore |
| One-shot action (fragment added) | MasEvent |

## Memory Leak Prevention

### ❌ Forgetting to Unsubscribe

```javascript
// BAD: Memory leak
connectedCallback() {
    Events.fragmentAdded.subscribe(this.handler);
}
// No cleanup!

// GOOD: Clean up on disconnect
connectedCallback() {
    super.connectedCallback();
    this.boundHandler = this.handleFragment.bind(this);
    Events.fragmentAdded.subscribe(this.boundHandler);
}

disconnectedCallback() {
    super.disconnectedCallback();
    Events.fragmentAdded.unsubscribe(this.boundHandler);
}
```

### Store Events with Controllers

When using both stores and events in a component:

```javascript
class MyComponent extends LitElement {
    store = new StoreController(this, fragmentStore);
    boundHandler = this.handleEvent.bind(this);

    connectedCallback() {
        super.connectedCallback();
        Events.fragmentAdded.subscribe(this.boundHandler);
    }

    disconnectedCallback() {
        super.disconnectedCallback();
        Events.fragmentAdded.unsubscribe(this.boundHandler);
    }
}
```

## Async Event Handling

MasEvent is synchronous. For async handlers:

```javascript
// Handler executes synchronously
myEvent.subscribe(async (data) => {
    await processAsync(data);  // May complete after emit returns
});

// If you need to wait:
const results = await Promise.all(
    handlers.map(h => h(data))
);
```

## Component Event Flow

### Bubbling Events Through Shadow DOM

```javascript
// From deeply nested component
this.dispatchEvent(new CustomEvent('field-change', {
    bubbles: true,    // Bubbles up DOM tree
    composed: true,   // Crosses shadow boundaries
    detail: { field: 'title', value: 'New Value' },
}));

// Parent catches it
<child-component @field-change="${this.handleFieldChange}">
```

### Stopping Propagation

```javascript
handleClick(e) {
    e.stopPropagation();  // Don't bubble further
    // Handle locally
}

handleChange(e) {
    e.stopImmediatePropagation();  // Stop all handlers
}
```

## Field Component Events

All form fields dispatch standardized events:

```javascript
// Field implementation
class MasTextField extends LitElement {
    handleInput(e) {
        this.dispatchEvent(new CustomEvent(EVENT_INPUT, {
            bubbles: true,
            composed: true,
        }));
    }

    handleChange(e) {
        this.dispatchEvent(new CustomEvent(EVENT_CHANGE, {
            bubbles: true,
            composed: true,
        }));
    }
}

// Parent usage
<mas-text-field
    @input="${this.handleInput}"
    @change="${this.handleChange}">
</mas-text-field>
```

## Related Skills

- `merch-card-editor-debugger` - Debug editor event flow
- `preview-fragment-debugger` - Debug store/event interactions
