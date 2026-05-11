# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This directory contains reusable form field components for MAS Studio editors. All components are Lit elements that follow the `mas-` or `merch-` prefix convention and integrate with Spectrum Web Components.

## Field Components

### Core Fields
- **addon-field.js** - Dropdown field for selecting addon placeholders with toggle to enable/disable
- **included-field.js** - Compound field for "what's included" items (icon URL + text)
- **mnemonic-field.js** - Compound field for mnemonic icons (icon URL + alt text + link)
- **plan-type-field.js** - Toggle field with checkbox to show/hide plan type text
- **secure-text-field.js** - Toggle field with checkbox to show/hide secure transaction label
- **user-picker.js** - Multi-select dropdown for picking users with search functionality
- **multifield.js** - Container component for managing arrays of fields with drag-to-reorder and add/remove

### Field Architecture Patterns

#### Event Handling
- Fields dispatch `EVENT_CHANGE` (from `../constants.js`) when values are committed
- Fields dispatch `EVENT_INPUT` (from `../constants.js`) for real-time value changes
- Events bubble with `bubbles: true, composed: true` to pass through shadow DOM
- Events include `detail: this` to provide reference to the field component

#### Value Access
- All fields implement a `value` getter/setter
- Simple fields return strings or primitives
- Compound fields (included-field, mnemonic-field) return objects with multiple properties
- Multifield returns an array of values

#### Toggle Fields Pattern
- `plan-type-field.js` and `secure-text-field.js` follow a common pattern:
  - Switch toggle to enable/disable the field
  - Checkbox to control visibility (true = show, false/'false' = hide)
  - Store empty string when showing, 'false' when hiding, empty when disabled

#### Reactive State Integration
- Fields using stores (like addon-field) use `ReactiveController` from `../reactivity/reactive-controller.js`
- Store references are passed as properties and managed by the controller
- Loading states are handled via store's `loading` property

### Multifield Component

The multifield component deserves special attention as it wraps other field components:

**Usage Pattern:**
```html
<mas-multifield .value="${arrayValue}" @change="${handler}">
  <template>
    <mas-mnemonic-field class="field"></mas-mnemonic-field>
  </template>
</mas-multifield>
```

**Key Features:**
- Clones template content for each array item
- Drag-to-reorder functionality with visual feedback
- Add/remove buttons for managing items
- Automatically syncs field attributes with array values
- Uses `.field` class selector to find the component inside the template

## Integration with Editors

Fields are primarily used in:
- `../editors/merch-card-editor.js` - Card content editing
- `../editors/merch-card-collection-editor.js` - Collection editing
- `../aem/mas-filter-panel.js` - Filtering UI

## Development Guidelines

### Creating New Fields
1. Extend `LitElement` from 'lit'
2. Import and dispatch `EVENT_CHANGE` and `EVENT_INPUT` from `../constants.js`
3. Implement `value` getter/setter for data access
4. Use Spectrum Web Components for UI (sp-textfield, sp-checkbox, sp-switch, etc.)
5. Register with `customElements.define('mas-{name}', ClassName)`

### Working with Compound Fields
- Compound fields (included-field, mnemonic-field) manage multiple related inputs
- They aggregate individual inputs into a single value object
- Changes to any child input trigger parent field events

### Styling Approach
- Use static `styles` property with `css` tagged template from 'lit'
- Fields typically use `width: 100%` for sp-textfield components
- Follow Spectrum design tokens for consistency
