---
paths:
  - studio/src/fields/**/*.js
  - studio/src/rte/**/*.js
  - "**/editor*.js"
  - "**/*-field.js"
---

# Field Components

## Overview

Form field components for MAS Studio editors. All use Lit elements with `mas-` prefix and integrate with Spectrum Web Components.

## Available Field Types

| Component | Purpose |
|-----------|---------|
| `mas-multifield` | Array of fields with drag-to-reorder |
| `mas-addon-field` | Dropdown for addon placeholders |
| `mas-included-field` | Icon URL + text compound field |
| `mas-mnemonic-field` | Icon + alt text + link compound |
| `mas-plan-type-field` | Toggle with show/hide checkbox |
| `mas-secure-text-field` | Toggle with visibility checkbox |
| `mas-user-picker` | Multi-select user dropdown |

## Creating New Fields

### Basic Structure

```javascript
import { html, css, LitElement } from 'lit';
import { EVENT_CHANGE, EVENT_INPUT } from '../constants.js';

class MasMyField extends LitElement {
    static get properties() {
        return {
            value: { type: String, attribute: false },
            disabled: { type: Boolean },
        };
    }

    static styles = css`
        :host {
            display: block;
        }
        sp-textfield {
            width: 100%;
        }
    `;

    get value() {
        return this._value;
    }

    set value(val) {
        this._value = val;
        this.requestUpdate();
    }

    handleInput(e) {
        this._value = e.target.value;
        this.dispatchEvent(new CustomEvent(EVENT_INPUT, {
            bubbles: true,
            composed: true,
        }));
    }

    handleChange(e) {
        this._value = e.target.value;
        this.dispatchEvent(new CustomEvent(EVENT_CHANGE, {
            bubbles: true,
            composed: true,
        }));
    }

    render() {
        return html`
            <sp-textfield
                .value="${this.value || ''}"
                @input="${this.handleInput}"
                @change="${this.handleChange}"
                ?disabled="${this.disabled}">
            </sp-textfield>
        `;
    }
}

customElements.define('mas-my-field', MasMyField);
```

### Event Constants

Always use shared constants:

```javascript
import { EVENT_CHANGE, EVENT_INPUT } from '../constants.js';

// EVENT_CHANGE - Value committed (blur, enter key, selection)
// EVENT_INPUT - Value changing (typing, dragging)
```

## Compound Fields

Fields with multiple inputs returning object values:

```javascript
class MasCompoundField extends LitElement {
    static get properties() {
        return {
            value: { type: Object, attribute: false },
        };
    }

    get value() {
        return {
            icon: this.iconValue,
            text: this.textValue,
            link: this.linkValue,
        };
    }

    set value(val) {
        this.iconValue = val?.icon || '';
        this.textValue = val?.text || '';
        this.linkValue = val?.link || '';
        this.requestUpdate();
    }

    handleFieldChange() {
        this.dispatchEvent(new CustomEvent(EVENT_CHANGE, {
            bubbles: true,
            composed: true,
            detail: this,  // Include component reference
        }));
    }
}
```

## Multifield Pattern

Container for array values with drag-to-reorder:

```html
<!-- Usage -->
<mas-multifield
    .value="${this.mnemonics}"
    @change="${this.handleMnemonicsChange}"
    button-label="Add Mnemonic">
    <template>
        <mas-mnemonic-field class="field"></mas-mnemonic-field>
    </template>
</mas-multifield>
```

### Multifield Implementation Notes

- Uses `<template>` to clone fields for each array item
- `.field` class selector finds component inside template
- Attributes from value object applied to cloned field
- Drag-to-reorder with visual feedback
- Add/remove buttons included

## Toggle Field Pattern

Fields with enable/disable and show/hide:

```javascript
class MasToggleField extends LitElement {
    static get properties() {
        return {
            value: { type: String, attribute: false },
        };
    }

    // Value states:
    // '' (empty) - enabled and showing
    // 'false' - enabled but hidden
    // null - disabled entirely

    get isEnabled() {
        return this.value !== null;
    }

    get isVisible() {
        return this.value !== 'false';
    }

    handleToggle(e) {
        this.value = e.target.checked ? '' : null;
        this.dispatch();
    }

    handleVisibility(e) {
        this.value = e.target.checked ? '' : 'false';
        this.dispatch();
    }

    render() {
        return html`
            <sp-switch
                ?checked="${this.isEnabled}"
                @change="${this.handleToggle}">
                Enable
            </sp-switch>
            ${this.isEnabled ? html`
                <sp-checkbox
                    ?checked="${this.isVisible}"
                    @change="${this.handleVisibility}">
                    Show
                </sp-checkbox>
            ` : nothing}
        `;
    }
}
```

## RTE Integration

Rich Text Editor using ProseMirror:

```javascript
import { MasRteField } from '../rte/rte-field.js';

// RTE field in editor template
html`
    <mas-rte-field
        label="Description"
        .value="${fragment.getFieldValue('description')}"
        @change="${(e) => this.updateField('description', e.target.value)}">
    </mas-rte-field>
`
```

### RTE Formatting Marks

- Bold, italic, underline
- Headings (H1-H6)
- Promo text styling
- Links (checkout, web, phone)
- Mnemonics/icons insertion

## Field State Attribute

Track inherited/overridden state for variations:

```javascript
// In template
<mas-text-field
    data-field-state="${fieldState}">
</mas-text-field>

// Field states:
// 'inherited' - Using parent value
// 'overridden' - Has local override
// '' - No inheritance context
```

## Store Integration

Fields using reactive stores:

```javascript
import ReactiveController from '../reactivity/reactive-controller.js';

class MasStoreField extends LitElement {
    reactivity = new ReactiveController(this, [optionsStore]);

    render() {
        const options = optionsStore.get();
        return html`
            <sp-picker @change="${this.handleChange}">
                ${options.map(opt =>
                    html`<sp-menu-item value="${opt.id}">${opt.label}</sp-menu-item>`
                )}
            </sp-picker>
        `;
    }
}
```

## Validation Patterns

```javascript
class MasValidatedField extends LitElement {
    static get properties() {
        return {
            value: { type: String },
            invalid: { type: Boolean, reflect: true },
            errorMessage: { type: String },
        };
    }

    validate() {
        if (!this.value) {
            this.invalid = true;
            this.errorMessage = 'Required';
            return false;
        }
        this.invalid = false;
        this.errorMessage = '';
        return true;
    }

    render() {
        return html`
            <sp-textfield
                .value="${this.value}"
                ?invalid="${this.invalid}"
                @change="${this.handleChange}">
                <sp-help-text slot="negative-help-text">
                    ${this.errorMessage}
                </sp-help-text>
            </sp-textfield>
        `;
    }
}
```

## Common Anti-Patterns

### ❌ Forgetting Composed Events

```javascript
// BAD: Won't cross shadow DOM
this.dispatchEvent(new CustomEvent('change', { bubbles: true }));

// GOOD: Crosses shadow boundaries
this.dispatchEvent(new CustomEvent('change', {
    bubbles: true,
    composed: true,
}));
```

### ❌ Direct DOM Manipulation

```javascript
// BAD: Bypasses Lit reactivity
this.shadowRoot.querySelector('input').value = newValue;

// GOOD: Use properties
this.value = newValue;
```

### ❌ Missing Event Cleanup

```javascript
// BAD: Memory leak
connectedCallback() {
    document.addEventListener('click', this.handler);
}

// GOOD: Clean up
disconnectedCallback() {
    document.removeEventListener('click', this.handler);
}
```

## Related Skills

- `editor-field-tester` - Test all field types
- `editor-rte-debugger` - Debug RTE fields
- `form-field-generator` - Generate fields from schema
