# Lit and Spectrum Patterns Reference

Quick reference for common patterns in MAS Studio components.

## Lit Patterns

### Property Declarations

```javascript
static properties = {
    // String property
    name: { type: String },

    // Number property
    count: { type: Number },

    // Boolean property (use ? prefix in templates)
    active: { type: Boolean },

    // Object property
    data: { type: Object },

    // Array property
    items: { type: Array },

    // State property (internal, not reflected to attribute)
    internalState: { type: Object, state: true },

    // Property with custom attribute name
    userId: { type: String, attribute: 'user-id' },

    // Non-reactive property
    config: { type: Object, attribute: false }
};
```

### Template Syntax

```javascript
render() {
    return html`
        <!-- String interpolation -->
        <div>${this.message}</div>

        <!-- Property binding (use . prefix) -->
        <custom-element .data=${this.data}></custom-element>

        <!-- Boolean attribute (use ? prefix) -->
        <button ?disabled=${this.isDisabled}>Click</button>

        <!-- Event listener (use @ prefix) -->
        <button @click=${this.handleClick}>Click</button>

        <!-- Conditional rendering -->
        ${this.showContent ? html`
            <div>Content</div>
        ` : html`
            <div>No content</div>
        `}

        <!-- List rendering -->
        ${this.items.map(item => html`
            <div>${item.name}</div>
        `)}

        <!-- Class binding -->
        <div class="base ${this.active ? 'active' : ''}">Content</div>

        <!-- Style binding -->
        <div style="color: ${this.color}">Content</div>
    `;
}
```

### Lifecycle Methods

```javascript
constructor() {
    super();
    // Initialize properties
}

connectedCallback() {
    super.connectedCallback();
    // Called when element is added to DOM
    // Good for adding event listeners
}

disconnectedCallback() {
    super.disconnectedCallback();
    // Called when element is removed from DOM
    // Good for cleanup
}

updated(changedProperties) {
    super.updated(changedProperties);
    // Called after render when properties change
    // changedProperties is a Map of old values
    if (changedProperties.has('userId')) {
        // userId changed
    }
}

firstUpdated(changedProperties) {
    super.firstUpdated(changedProperties);
    // Called only once after first render
    // Good for accessing rendered elements
}
```

### Event Patterns

```javascript
// Dispatch custom event
dispatchEvent(new CustomEvent('my-event', {
    bubbles: true,      // Event bubbles up DOM tree
    composed: true,     // Event crosses shadow DOM boundary
    detail: {           // Custom data
        value: 'data'
    }
}));

// Listen to events
this.addEventListener('my-event', this.handleEvent);

// Arrow function for proper 'this' binding
handleEvent = (event) => {
    const { value } = event.detail;
}

// Remove listener in disconnectedCallback
this.removeEventListener('my-event', this.handleEvent);
```

## Spectrum Web Components

### Button

```javascript
import '@spectrum-web-components/button/sp-button.js';

html`
    <sp-button>Default</sp-button>
    <sp-button variant="primary">Primary</sp-button>
    <sp-button variant="secondary">Secondary</sp-button>
    <sp-button variant="negative">Delete</sp-button>
    <sp-button ?disabled=${this.disabled}>Disabled</sp-button>
    <sp-button size="s">Small</sp-button>
    <sp-button size="m">Medium</sp-button>
    <sp-button size="l">Large</sp-button>
    <sp-button @click=${this.handleClick}>Click</sp-button>
`
```

### Text Field

```javascript
import '@spectrum-web-components/textfield/sp-textfield.js';

html`
    <sp-textfield
        label="Name"
        placeholder="Enter name"
        .value=${this.name}
        @input=${this.handleInput}
    ></sp-textfield>

    <sp-textfield
        label="Email"
        type="email"
        required
        ?invalid=${this.hasError}
    ></sp-textfield>

    <sp-textfield
        label="Password"
        type="password"
        @change=${this.handleChange}
    ></sp-textfield>
`
```

### Dialog

```javascript
import '@spectrum-web-components/dialog/sp-dialog.js';

html`
    <sp-dialog ?open=${this.dialogOpen} @close=${this.handleClose}>
        <h2 slot="heading">Dialog Title</h2>

        <!-- Content -->
        <div>Dialog content</div>

        <!-- Buttons -->
        <sp-button slot="button" variant="secondary" @click=${this.handleCancel}>
            Cancel
        </sp-button>
        <sp-button slot="button" variant="primary" @click=${this.handleConfirm}>
            Confirm
        </sp-button>
    </sp-dialog>
`
```

### Checkbox

```javascript
import '@spectrum-web-components/checkbox/sp-checkbox.js';

html`
    <sp-checkbox
        ?checked=${this.isChecked}
        @change=${this.handleCheck}
    >
        Accept terms
    </sp-checkbox>

    <sp-checkbox ?disabled=${true}>Disabled</sp-checkbox>
    <sp-checkbox ?indeterminate=${this.partial}>Partial</sp-checkbox>
`
```

### Picker (Select)

```javascript
import '@spectrum-web-components/picker/sp-picker.js';
import '@spectrum-web-components/menu/sp-menu-item.js';

html`
    <sp-picker
        label="Choose option"
        .value=${this.selectedValue}
        @change=${this.handleChange}
    >
        <sp-menu-item value="option1">Option 1</sp-menu-item>
        <sp-menu-item value="option2">Option 2</sp-menu-item>
        <sp-menu-item value="option3">Option 3</sp-menu-item>
    </sp-picker>
`
```

### Progress Circle

```javascript
import '@spectrum-web-components/progress-circle/sp-progress-circle.js';

html`
    <!-- Indeterminate (spinning) -->
    <sp-progress-circle indeterminate></sp-progress-circle>

    <!-- With progress value -->
    <sp-progress-circle progress="50"></sp-progress-circle>

    <!-- Different sizes -->
    <sp-progress-circle size="s" indeterminate></sp-progress-circle>
    <sp-progress-circle size="m" indeterminate></sp-progress-circle>
    <sp-progress-circle size="l" indeterminate></sp-progress-circle>
`
```

### Toast

```javascript
import '@spectrum-web-components/toast/sp-toast.js';

html`
    <sp-toast ?open=${this.toastOpen} variant="positive">
        Success message
    </sp-toast>

    <sp-toast ?open=${this.toastOpen} variant="negative">
        Error message
    </sp-toast>

    <sp-toast ?open=${this.toastOpen} variant="info">
        Info message
    </sp-toast>
`

// Or use utility function
import { showToast } from './utils.js';
showToast('Message', 'positive');
```

### Action Button

```javascript
import '@spectrum-web-components/action-button/sp-action-button.js';

html`
    <sp-action-button @click=${this.handleAction}>
        Action
    </sp-action-button>

    <sp-action-button ?selected=${this.isSelected}>
        Toggle
    </sp-action-button>

    <sp-action-button ?quiet=${true}>
        Quiet
    </sp-action-button>
`
```

### Icons

```javascript
import '@spectrum-web-components/icons-workflow/icons/sp-icon-*.js';

html`
    <sp-icon-magic-wand></sp-icon-magic-wand>
    <sp-icon-alert></sp-icon-alert>
    <sp-icon-checkmark-circle></sp-icon-checkmark-circle>
    <sp-icon-close></sp-icon-close>
    <sp-icon-edit></sp-icon-edit>
    <sp-icon-delete></sp-icon-delete>

    <!-- With size -->
    <sp-icon-magic-wand size="s"></sp-icon-magic-wand>
    <sp-icon-magic-wand size="m"></sp-icon-magic-wand>
    <sp-icon-magic-wand size="l"></sp-icon-magic-wand>
    <sp-icon-magic-wand size="xl"></sp-icon-magic-wand>
`
```

## Store Integration Patterns

### Subscribe to Store

```javascript
import StoreController from './reactivity/store-controller.js';
import Store from './store.js';

constructor() {
    super();
    // Component re-renders when store value changes
    new StoreController(this, Store.search);
    new StoreController(this, Store.filters);
}

// Access store values
render() {
    const path = Store.search.value.path;
    const locale = Store.filters.value.locale;

    return html`<div>${path} - ${locale}</div>`;
}
```

### Update Store

```javascript
// Set new value
Store.search.set({
    ...Store.search.value,
    path: '/new/path'
});

// Or update specific property
Store.filters.set({
    ...Store.filters.value,
    locale: 'fr_FR'
});
```

## FragmentStore Patterns

### Create Fragment Store

```javascript
import { FragmentStore } from './reactivity/fragment-store.js';

// Create store from fragment
const fragmentStore = new FragmentStore(fragment);

// Access properties
const title = fragmentStore.title;
const hasChanges = fragmentStore.hasChanges;

// Get field value
const description = fragmentStore.getFieldValue('description');

// Update field
fragmentStore.updateField('description', 'New value');

// Save changes
await fragmentStore.save();

// Rollback changes
fragmentStore.rollback();
```

## Common Component Recipes

### Loading State Pattern

```javascript
static properties = {
    loading: { type: Boolean, state: true }
};

async loadData() {
    this.loading = true;
    try {
        const data = await fetchData();
        this.data = data;
    } catch (error) {
        console.error(error);
    } finally {
        this.loading = false;
    }
}

render() {
    if (this.loading) {
        return html`<sp-progress-circle indeterminate></sp-progress-circle>`;
    }
    return html`<div>${this.data}</div>`;
}
```

### Error State Pattern

```javascript
static properties = {
    error: { type: String, state: true }
};

async doOperation() {
    this.error = null;
    try {
        await operation();
    } catch (error) {
        this.error = error.message;
    }
}

render() {
    if (this.error) {
        return html`
            <div class="error">
                <sp-icon-alert></sp-icon-alert>
                ${this.error}
            </div>
        `;
    }
    // Normal render
}
```

### Form Validation Pattern

```javascript
validateForm() {
    const errors = {};

    if (!this.formData.title) {
        errors.title = 'Title is required';
    }

    if (this.formData.email && !this.isValidEmail(this.formData.email)) {
        errors.email = 'Invalid email';
    }

    this.errors = errors;
    return Object.keys(errors).length === 0;
}

handleSubmit(e) {
    e.preventDefault();
    if (!this.validateForm()) return;

    // Submit form
}
```

### Debounced Input Pattern

```javascript
constructor() {
    super();
    this.debounceTimer = null;
}

handleInput(e) {
    const value = e.target.value;

    // Clear previous timer
    clearTimeout(this.debounceTimer);

    // Set new timer
    this.debounceTimer = setTimeout(() => {
        this.processInput(value);
    }, 300);
}

disconnectedCallback() {
    super.disconnectedCallback();
    clearTimeout(this.debounceTimer);
}
```

These patterns cover the most common use cases in MAS Studio components.
