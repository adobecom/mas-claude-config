# MAS Coding Conventions - Real Examples

This file contains real examples from the MAS Studio codebase demonstrating correct patterns and common mistakes to avoid.

## Template Getters - Real Examples

### Example 1: mas-toolbar.js (Correct Pattern)

**FROM**: `studio/src/mas-toolbar.js:227-269`

✅ **Correct - Using Getters**:
```javascript
class MasToolbar extends LitElement {
    get searchAndFilterControls() {
        return html`<div id="read">
            <sp-action-button
                toggles
                label="Filter"
                @click="${this.onShowFilter}"
                class="filters-button ${this.filterCount > 0 ? 'shown' : ''}"
            >
                ${!this.filterCount > 0
                    ? html`<sp-icon-filter-add slot="icon"></sp-icon-filter-add>`
                    : html`<div slot="icon" class="filters-badge">${this.filterCount}</div>`}
            </sp-action-button>
            <sp-search
                @input=${this.handleChange}
                @submit=${this.handleSearchSubmit}
                placeholder="Search"
            ></sp-search>
        </div>`;
    }

    get contentManagementControls() {
        if (this.selecting.value) return nothing;
        return html`<div id="write">
            ${this.createButton}
            <sp-button @click=${() => Store.selecting.set(true)}>
                <sp-icon-selection-checked slot="icon"></sp-icon-selection-checked>
                Select
            </sp-button>
            <sp-action-menu
                selects="single"
                value="${this.renderMode.value}"
                placement="bottom"
                @change=${this.handleRenderModeChange}
            >
                ${renderModes.map(
                    ({ value, label, icon }) => html`<sp-menu-item value="${value}">${icon} ${label}</sp-menu-item>`,
                )}
            </sp-action-menu>
        </div>`;
    }

    get filtersPanel() {
        return html`<mas-filter-panel></mas-filter-panel>`;
    }

    get searchResultsLabel() {
        if (this.loading.value || !this.search.value.query) return nothing;
        return html`<span id="search-results-label">Search results for "${this.search.value.query}"</span>`;
    }

    render() {
        return html`<div id="toolbar">
            <div id="actions">
                ${this.searchAndFilterControls}
                ${this.contentManagementControls}
                ${this.selectionPanel}
            </div>
            ${this.filtersPanel}
            ${this.searchResultsLabel}
        </div>`;
    }
}
```

❌ **WRONG - What NOT to suggest**:
```javascript
// DON'T suggest this pattern!
class MasToolbar extends LitElement {
    renderSearchAndFilterControls() {  // ❌ Wrong!
        return html`<div id="read">...</div>`;
    }

    renderContentManagementControls() {  // ❌ Wrong!
        return html`<div id="write">...</div>`;
    }

    renderFiltersPanel() {  // ❌ Wrong!
        return html`<mas-filter-panel></mas-filter-panel>`;
    }

    render() {
        return html`<div id="toolbar">
            ${this.renderSearchAndFilterControls()}  // ❌ Calling as method
            ${this.renderContentManagementControls()}
            ${this.renderFiltersPanel()}
        </div>`;
    }
}
```

### Example 2: mas-content.js (Correct Pattern)

**FROM**: `studio/src/mas-content.js`

✅ **Correct**:
```javascript
class MasContent extends LitElement {
    get cards() {
        if (!this.repository.fragments.list.value) return nothing;
        const fragments = this.repository.fragments.list.value;
        return html`
            <div class="cards">
                ${fragments.map((fragment) => html`
                    <mas-fragment .fragment=${fragment}></mas-fragment>
                `)}
            </div>
        `;
    }

    render() {
        return html`
            ${this.cards}
        `;
    }
}
```

## Element Reference Getters - Real Examples

### Example 1: mas-copy-dialog.js (Correct)

**FROM**: `studio/src/mas-copy-dialog.js:189-191`

✅ **Correct**:
```javascript
class MasCopyDialog extends LitElement {
    get dialog() {
        return this.shadowRoot.querySelector('sp-dialog-wrapper');
    }

    async open() {
        await this.updateComplete;
        this.dialog.open = true;  // Using getter
    }

    close() {
        this.dialog.open = false;  // Using getter
    }
}
```

### Example 2: rte-field.js (Correct Pattern)

**FROM**: `studio/src/rte/rte-field.js:1464-1597`

✅ **Correct - Multiple Element Getters**:
```javascript
class RteField extends LitElement {
    get linkEditorButtonElement() {
        return this.shadowRoot.querySelector('#linkEditorButton');
    }

    get unlinkEditorButtonElement() {
        return this.shadowRoot.querySelector('#unlinkEditorButton');
    }

    get linkEditorElement() {
        return this.shadowRoot.querySelector('rte-link-editor');
    }

    get iconEditorElement() {
        return this.shadowRoot.querySelector('rte-icon-editor');
    }

    get mnemonicEditorElement() {
        return this.shadowRoot.querySelector('rte-mnemonic-editor');
    }

    get offerSelectorToolButtonElement() {
        return this.shadowRoot.querySelector('#offerSelectorToolButton');
    }
}
```

❌ **WRONG Pattern**:
```javascript
class RteField extends LitElement {
    connectedCallback() {
        super.connectedCallback();
        // ❌ Don't store element references
        this.linkEditorButton = this.shadowRoot.querySelector('#linkEditorButton');
        this.unlinkEditorButton = this.shadowRoot.querySelector('#unlinkEditorButton');
        this.linkEditor = this.shadowRoot.querySelector('rte-link-editor');
    }
}
```

## Light DOM Pattern - Real Examples

### Example 1: mas-content.js

**FROM**: `studio/src/mas-content.js:12-14`

✅ **Correct - Light DOM**:
```javascript
class MasContent extends LitElement {
    createRenderRoot() {
        return this;  // Renders to light DOM
    }
}
```

### Example 2: editor-panel.js

**FROM**: `studio/src/editor-panel.js:122-124`

✅ **Correct - Light DOM**:
```javascript
class EditorPanel extends LitElement {
    createRenderRoot() {
        return this;  // No shadow DOM
    }
}
```

### Example 3: mas-fragment.js

**FROM**: `studio/src/mas-fragment.js:19-21`

✅ **Correct - Light DOM**:
```javascript
class MasFragment extends LitElement {
    static styles = [styles];

    createRenderRoot() {
        return this;  // Light DOM even with styles
    }
}
```

### When Shadow DOM IS Used

✅ **Exception - Components that need shadow DOM**:
```javascript
// mas-toolbar.js, mas-copy-dialog.js, rte-field.js, etc.
class MasToolbar extends LitElement {
    // No createRenderRoot() = uses shadow DOM by default

    get popover() {
        return this.shadowRoot.querySelector('sp-popover');  // Note: shadowRoot
    }
}
```

## StoreController Pattern - Real Examples

### Example 1: mas-toolbar.js

**FROM**: `studio/src/mas-toolbar.js:140-144`

✅ **Correct**:
```javascript
class MasToolbar extends LitElement {
    // Reactive store integration
    filters = new StoreController(this, Store.filters);
    search = new StoreController(this, Store.search);
    renderMode = new StoreController(this, Store.renderMode);
    selecting = new StoreController(this, Store.selecting);
    loading = new StoreController(this, Store.fragments.list.loading);

    render() {
        // Access via .value
        return html`
            <div>Loading: ${this.loading.value}</div>
            <div>Query: ${this.search.value.query}</div>
            ${this.selecting.value ? html`<div>Selecting mode</div>` : nothing}
        `;
    }
}
```

## Event Handling - Real Examples

### Example 1: mnemonic-field.js

**FROM**: `studio/src/fields/mnemonic-field.js:25-35`

✅ **Correct - Using Event Constants**:
```javascript
import { EVENT_CHANGE, EVENT_INPUT } from '../constants.js';

class MnemonicField extends LitElement {
    connectedCallback() {
        super.connectedCallback();
        this.shadowRoot.addEventListener(EVENT_CHANGE, this.handleChange);
        this.shadowRoot.addEventListener(EVENT_INPUT, this.handleInput);
    }

    disconnectedCallback() {
        super.disconnectedCallback();
        this.shadowRoot.removeEventListener(EVENT_CHANGE, this.handleChange);
        this.shadowRoot.removeEventListener(EVENT_INPUT, this.handleInput);
    }
}
```

### Example 2: mas-copy-dialog.js

**FROM**: `studio/src/mas-copy-dialog.js:143-152`

✅ **Correct - Binding in Constructor**:
```javascript
import { EVENT_KEYDOWN } from './constants.js';

class MasCopyDialog extends LitElement {
    constructor() {
        super();
        // Bind methods in constructor
        this.handleSubmit = this.handleSubmit.bind(this);
        this.close = this.close.bind(this);
        this.handleKeyDown = this.handleKeyDown.bind(this);
    }

    connectedCallback() {
        super.connectedCallback();
        document.addEventListener(EVENT_KEYDOWN, this.handleKeyDown);
    }

    disconnectedCallback() {
        super.disconnectedCallback();
        document.removeEventListener(EVENT_KEYDOWN, this.handleKeyDown);
    }
}
```

## Custom Events Pattern - Real Examples

### Example 1: mas-copy-dialog.js

**FROM**: `studio/src/mas-copy-dialog.js:321-327`

✅ **Correct**:
```javascript
class MasCopyDialog extends LitElement {
    async handleSubmit() {
        // ... copy logic

        this.dispatchEvent(
            new CustomEvent('fragment-copied', {
                detail: { fragment: copiedFragment },
                bubbles: true,
                composed: true,
            }),
        );
    }
}
```

### Example 2: Cancel Event

**FROM**: `studio/src/mas-copy-dialog.js:335-341`

✅ **Correct**:
```javascript
close() {
    this.dialog.open = false;
    this.dispatchEvent(
        new CustomEvent('cancel', {
            bubbles: true,
            composed: true,
        }),
    );
}
```

## Private Fields - Real Example

### Using # for Private Fields

**FROM**: `studio/src/rte/rte-field.js`

✅ **Correct**:
```javascript
class RteField extends LitElement {
    #editorState = null;
    #lastSavedContent = '';

    #initializeEditor() {
        const editorContainer = this.shadowRoot.getElementById('editor');
        this.editorView = new EditorView(editorContainer, {
            state: this.#createEditorState(),
        });
    }

    #createEditorState() {
        return EditorState.create({
            // ...
        });
    }
}
```

❌ **WRONG - Underscore Prefix**:
```javascript
class RteField extends LitElement {
    _editorState = null;  // ❌ Don't use underscore
    _lastSavedContent = '';  // ❌ Wrong!

    _initializeEditor() {  // ❌ Wrong!
        // ...
    }
}
```

## Complete Component Example - Real Code

### mas-confirm-dialog.js - Full Component

This is a complete, real component from the codebase showing all conventions:

```javascript
import { LitElement, html, css } from 'lit';

export class MasConfirmDialog extends LitElement {
    static properties = {
        open: { type: Boolean },
        headline: { type: String },
        message: { type: String },
        confirmLabel: { type: String },
        cancelLabel: { type: String },
    };

    static styles = css`
        :host {
            display: contents;
        }
    `;

    constructor() {
        super();
        this.open = false;
        this.headline = 'Confirm';
        this.message = '';
        this.confirmLabel = 'Confirm';
        this.cancelLabel = 'Cancel';

        // Bind handlers
        this.handleConfirm = this.handleConfirm.bind(this);
        this.handleCancel = this.handleCancel.bind(this);
    }

    handleConfirm() {
        this.dispatchEvent(
            new CustomEvent('confirm', {
                bubbles: true,
                composed: true,
            }),
        );
        this.close();
    }

    handleCancel() {
        this.dispatchEvent(
            new CustomEvent('cancel', {
                bubbles: true,
                composed: true,
            }),
        );
        this.close();
    }

    close() {
        this.open = false;
    }

    render() {
        if (!this.open) return nothing;

        return html`
            <sp-dialog-wrapper
                headline="${this.headline}"
                confirm-label="${this.confirmLabel}"
                cancel-label="${this.cancelLabel}"
                @confirm=${this.handleConfirm}
                @cancel=${this.handleCancel}
            >
                <p>${this.message}</p>
            </sp-dialog-wrapper>
        `;
    }
}

customElements.define('mas-confirm-dialog', MasConfirmDialog);
```

## Private Method Handler Pattern - Real Examples

### Example 1: osi-field.js (Recommended #boundHandlers Pattern)

**FROM**: `studio/src/rte/osi-field.js:20-47`

✅ **Correct - #boundHandlers Pattern**:
```javascript
class OsiField extends LitElement {
    #boundHandlers;

    constructor() {
        super();
        this.value = '';
        this.showOfferSelector = false;
        this.#boundHandlers = {
            escKey: this.#handleEscKey.bind(this),
            ostEvent: this.#handleOstEvent.bind(this),
        };
    }

    connectedCallback() {
        super.connectedCallback();
        document.addEventListener('keydown', this.#boundHandlers.escKey, { capture: true });
        document.addEventListener(EVENT_OST_OFFER_SELECT, this.#boundHandlers.ostEvent);
    }

    disconnectedCallback() {
        super.disconnectedCallback();
        document.removeEventListener('keydown', this.#boundHandlers.escKey, { capture: true });
        document.removeEventListener(EVENT_OST_OFFER_SELECT, this.#boundHandlers.ostEvent);
    }

    #handleOstEvent({ detail: { offerSelectorId, offer } }) {
        // Regular private method - NOT arrow function
    }

    #handleEscKey(event) {
        // Regular private method - NOT arrow function
    }
}
```

### Example 2: multifield.js (Correct Pattern)

**FROM**: `studio/src/fields/multifield.js`

✅ **Correct - #boundHandlers for Private Event Handlers**:
```javascript
class MasMultifield extends LitElement {
    #template;
    #boundHandlers;

    constructor() {
        super();
        this.draggingIndex = -1;
        this.min = 0;
        this.buttonLabel = 'Add';
        this.#boundHandlers = {
            deleteField: this.#handleDeleteField.bind(this),
        };
    }

    connectedCallback() {
        super.connectedCallback();
        this.addEventListener('delete-field', this.#boundHandlers.deleteField);
    }

    disconnectedCallback() {
        super.disconnectedCallback();
        this.removeEventListener('delete-field', this.#boundHandlers.deleteField);
    }

    #handleDeleteField(event) {
        event.stopPropagation();
        // ... handler logic
    }
}
```

❌ **Discouraged Pattern**:
```javascript
class MasMultifield extends LitElement {
    // ❌ Don't use arrow function class fields
    #handleDeleteField = (event) => {
        event.stopPropagation();
        // ...
    };

    connectedCallback() {
        super.connectedCallback();
        this.addEventListener('delete-field', this.#handleDeleteField);
    }
}
```

## Summary: Key Patterns from Real Code

1. **Template Getters**: 40+ files use `get xyz()` for templates
2. **Element Getters**: All element access uses getters, never stored references
3. **Light DOM**: Most components use `createRenderRoot() { return this; }`
4. **StoreController**: All reactive state uses this pattern
5. **Event Constants**: All event handling uses imported constants
6. **Bound Handlers**: All handlers bound in constructor
7. **Private Fields**: Use `#private`, never `_private`
8. **Custom Events**: All use `new CustomEvent()` with `bubbles: true, composed: true`
9. **#boundHandlers Pattern**: Private event handlers use regular methods + `#boundHandlers` object (not arrow function class fields)

These patterns are consistent across the entire codebase and should be followed in all new code.
