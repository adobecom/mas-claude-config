# MAS Component Examples

Complete working examples of MAS Studio components.

## Example 1: Chat Message Component

Based on `mas-chat-message.js`:

```javascript
import { LitElement, html } from 'lit';

export class MasChatMessage extends LitElement {
    static properties = {
        message: { type: Object },
        showSuggestions: { type: Boolean }
    };

    constructor() {
        super();
        this.message = null;
        this.showSuggestions = false;
    }

    createRenderRoot() {
        return this;
    }

    get isUser() {
        return this.message?.role === 'user';
    }

    get isAssistant() {
        return this.message?.role === 'assistant';
    }

    get isError() {
        return this.message?.role === 'error';
    }

    formatTimestamp(timestamp) {
        return new Date(timestamp).toLocaleTimeString();
    }

    render() {
        if (!this.message) return html``;

        return html`
            <div class="chat-message ${this.message.role}">
                <div class="message-header">
                    <span class="message-role">
                        ${this.isUser ? 'You' : 'AI'}
                    </span>
                    <span class="message-time">
                        ${this.formatTimestamp(this.message.timestamp)}
                    </span>
                </div>
                <div class="message-content">
                    ${this.message.content}
                </div>
                ${this.message.cardConfig ? html`
                    <mas-chat-preview .cardConfig=${this.message.cardConfig}>
                    </mas-chat-preview>
                ` : ''}
                ${this.message.showSuggestions && this.showSuggestions ? html`
                    <mas-prompt-suggestions></mas-prompt-suggestions>
                ` : ''}
            </div>
        `;
    }
}

customElements.define('mas-chat-message', MasChatMessage);
```

## Example 2: Input Component with Validation

```javascript
import { LitElement, html } from 'lit';

export class MasTextInput extends LitElement {
    static properties = {
        label: { type: String },
        value: { type: String },
        placeholder: { type: String },
        disabled: { type: Boolean },
        required: { type: Boolean },
        errorMessage: { type: String, state: true }
    };

    constructor() {
        super();
        this.label = '';
        this.value = '';
        this.placeholder = '';
        this.disabled = false;
        this.required = false;
        this.errorMessage = '';
    }

    createRenderRoot() {
        return this;
    }

    validate() {
        if (this.required && !this.value.trim()) {
            this.errorMessage = 'This field is required';
            return false;
        }
        this.errorMessage = '';
        return true;
    }

    handleInput(e) {
        this.value = e.target.value;
        this.validate();
        this.dispatchEvent(new CustomEvent('value-changed', {
            bubbles: true,
            detail: { value: this.value, valid: !this.errorMessage }
        }));
    }

    handleBlur() {
        this.validate();
    }

    render() {
        return html`
            <div class="text-input-wrapper">
                <sp-textfield
                    label=${this.label}
                    .value=${this.value}
                    placeholder=${this.placeholder}
                    ?disabled=${this.disabled}
                    ?required=${this.required}
                    @input=${this.handleInput}
                    @blur=${this.handleBlur}
                ></sp-textfield>
                ${this.errorMessage ? html`
                    <div class="error-message">${this.errorMessage}</div>
                ` : ''}
            </div>
        `;
    }
}

customElements.define('mas-text-input', MasTextInput);
```

## Example 3: List Component with Selection

```javascript
import { LitElement, html } from 'lit';

export class MasCardList extends LitElement {
    static properties = {
        cards: { type: Array },
        selectedIds: { type: Array },
        selectable: { type: Boolean },
        loading: { type: Boolean, state: true }
    };

    constructor() {
        super();
        this.cards = [];
        this.selectedIds = [];
        this.selectable = false;
        this.loading = false;
    }

    createRenderRoot() {
        return this;
    }

    isSelected(cardId) {
        return this.selectedIds.includes(cardId);
    }

    handleCardClick(card) {
        if (!this.selectable) {
            this.dispatchEvent(new CustomEvent('card-click', {
                bubbles: true,
                detail: { card }
            }));
            return;
        }

        const newSelectedIds = this.isSelected(card.id)
            ? this.selectedIds.filter(id => id !== card.id)
            : [...this.selectedIds, card.id];

        this.selectedIds = newSelectedIds;
        this.dispatchEvent(new CustomEvent('selection-changed', {
            bubbles: true,
            detail: { selectedIds: this.selectedIds }
        }));
    }

    render() {
        if (this.loading) {
            return html`
                <div class="loading-state">
                    <sp-progress-circle indeterminate></sp-progress-circle>
                    <p>Loading cards...</p>
                </div>
            `;
        }

        if (this.cards.length === 0) {
            return html`
                <div class="empty-state">
                    <p>No cards found</p>
                </div>
            `;
        }

        return html`
            <div class="card-list">
                ${this.cards.map(card => html`
                    <div
                        class="card-item ${this.isSelected(card.id) ? 'selected' : ''}"
                        @click=${() => this.handleCardClick(card)}
                    >
                        <h4>${card.title}</h4>
                        <p>${card.description || ''}</p>
                        ${this.selectable ? html`
                            <sp-checkbox
                                ?checked=${this.isSelected(card.id)}
                                @click=${(e) => e.stopPropagation()}
                                @change=${() => this.handleCardClick(card)}
                            ></sp-checkbox>
                        ` : ''}
                    </div>
                `)}
            </div>
        `;
    }
}

customElements.define('mas-card-list', MasCardList);
```

## Example 4: Modal Dialog with Actions

```javascript
import { LitElement, html } from 'lit';

export class MasConfirmDialog extends LitElement {
    static properties = {
        open: { type: Boolean },
        title: { type: String },
        message: { type: String },
        confirmLabel: { type: String },
        cancelLabel: { type: String },
        variant: { type: String }
    };

    constructor() {
        super();
        this.open = false;
        this.title = 'Confirm';
        this.message = '';
        this.confirmLabel = 'Confirm';
        this.cancelLabel = 'Cancel';
        this.variant = 'primary';
    }

    createRenderRoot() {
        return this;
    }

    handleCancel() {
        this.open = false;
        this.dispatchEvent(new CustomEvent('cancel', { bubbles: true }));
    }

    handleConfirm() {
        this.open = false;
        this.dispatchEvent(new CustomEvent('confirm', { bubbles: true }));
    }

    render() {
        return html`
            <sp-dialog ?open=${this.open} @close=${this.handleCancel}>
                <h2 slot="heading">${this.title}</h2>
                <div class="dialog-content">
                    ${this.message}
                </div>
                <sp-button
                    slot="button"
                    variant="secondary"
                    @click=${this.handleCancel}
                >
                    ${this.cancelLabel}
                </sp-button>
                <sp-button
                    slot="button"
                    variant=${this.variant}
                    @click=${this.handleConfirm}
                >
                    ${this.confirmLabel}
                </sp-button>
            </sp-dialog>
        `;
    }
}

customElements.define('mas-confirm-dialog', MasConfirmDialog);
```

## Example 5: Form Component with Multiple Fields

```javascript
import { LitElement, html } from 'lit';
import './mas-text-input.js';

export class MasCardForm extends LitElement {
    static properties = {
        formData: { type: Object },
        disabled: { type: Boolean },
        errors: { type: Object, state: true }
    };

    constructor() {
        super();
        this.formData = {
            title: '',
            description: '',
            variant: 'default'
        };
        this.disabled = false;
        this.errors = {};
    }

    createRenderRoot() {
        return this;
    }

    handleFieldChange(fieldName, event) {
        this.formData = {
            ...this.formData,
            [fieldName]: event.detail.value
        };

        if (!event.detail.valid) {
            this.errors = {
                ...this.errors,
                [fieldName]: 'Invalid value'
            };
        } else {
            const newErrors = { ...this.errors };
            delete newErrors[fieldName];
            this.errors = newErrors;
        }

        this.dispatchEvent(new CustomEvent('form-changed', {
            bubbles: true,
            detail: {
                formData: this.formData,
                valid: Object.keys(this.errors).length === 0
            }
        }));
    }

    handleSubmit(e) {
        e.preventDefault();

        const isValid = Object.keys(this.errors).length === 0;
        if (!isValid) return;

        this.dispatchEvent(new CustomEvent('form-submit', {
            bubbles: true,
            detail: { formData: this.formData }
        }));
    }

    render() {
        return html`
            <form class="card-form" @submit=${this.handleSubmit}>
                <mas-text-input
                    label="Title"
                    .value=${this.formData.title}
                    ?disabled=${this.disabled}
                    required
                    @value-changed=${(e) => this.handleFieldChange('title', e)}
                ></mas-text-input>

                <mas-text-input
                    label="Description"
                    .value=${this.formData.description}
                    ?disabled=${this.disabled}
                    @value-changed=${(e) => this.handleFieldChange('description', e)}
                ></mas-text-input>

                <sp-picker
                    label="Variant"
                    .value=${this.formData.variant}
                    ?disabled=${this.disabled}
                    @change=${(e) => this.handleFieldChange('variant', {
                        detail: { value: e.target.value, valid: true }
                    })}
                >
                    <sp-menu-item value="default">Default</sp-menu-item>
                    <sp-menu-item value="special">Special</sp-menu-item>
                    <sp-menu-item value="premium">Premium</sp-menu-item>
                </sp-picker>

                <div class="form-actions">
                    <sp-button type="submit" variant="primary" ?disabled=${this.disabled}>
                        Save
                    </sp-button>
                </div>
            </form>
        `;
    }
}

customElements.define('mas-card-form', MasCardForm);
```

## Example 6: Component with Store Integration

```javascript
import { LitElement, html } from 'lit';
import StoreController from './reactivity/store-controller.js';
import Store from './store.js';

export class MasCurrentPath extends LitElement {
    constructor() {
        super();
        // Subscribe to search store
        new StoreController(this, Store.search);
        // Subscribe to filters store
        new StoreController(this, Store.filters);
    }

    createRenderRoot() {
        return this;
    }

    get currentPath() {
        return Store.search.value.path || '/';
    }

    get currentLocale() {
        return Store.filters.value.locale || 'en_US';
    }

    handlePathChange(e) {
        Store.search.set({
            ...Store.search.value,
            path: e.target.value
        });
    }

    render() {
        return html`
            <div class="path-display">
                <span class="label">Current Path:</span>
                <sp-textfield
                    .value=${this.currentPath}
                    @change=${this.handlePathChange}
                ></sp-textfield>
                <span class="locale-badge">${this.currentLocale}</span>
            </div>
        `;
    }
}

customElements.define('mas-current-path', MasCurrentPath);
```

## Example 7: Async Data Loading Component

```javascript
import { LitElement, html } from 'lit';
import { showToast } from './utils.js';

export class MasFragmentLoader extends LitElement {
    static properties = {
        fragmentId: { type: String },
        fragment: { type: Object, state: true },
        loading: { type: Boolean, state: true },
        error: { type: String, state: true }
    };

    constructor() {
        super();
        this.fragmentId = null;
        this.fragment = null;
        this.loading = false;
        this.error = null;
    }

    createRenderRoot() {
        return this;
    }

    updated(changedProperties) {
        if (changedProperties.has('fragmentId') && this.fragmentId) {
            this.loadFragment();
        }
    }

    async loadFragment() {
        this.loading = true;
        this.error = null;

        try {
            const repository = document.querySelector('mas-repository');
            if (!repository) {
                throw new Error('Repository not found');
            }

            this.fragment = await repository.aem.sites.cf.fragments.getById(
                this.fragmentId
            );

            this.dispatchEvent(new CustomEvent('fragment-loaded', {
                bubbles: true,
                detail: { fragment: this.fragment }
            }));
        } catch (error) {
            console.error('Failed to load fragment:', error);
            this.error = error.message;
            showToast(`Failed to load fragment: ${error.message}`, 'negative');
        } finally {
            this.loading = false;
        }
    }

    renderLoading() {
        return html`
            <div class="loading-container">
                <sp-progress-circle indeterminate></sp-progress-circle>
                <p>Loading fragment...</p>
            </div>
        `;
    }

    renderError() {
        return html`
            <div class="error-container">
                <sp-icon-alert></sp-icon-alert>
                <p>${this.error}</p>
                <sp-button @click=${this.loadFragment}>Retry</sp-button>
            </div>
        `;
    }

    renderFragment() {
        return html`
            <div class="fragment-display">
                <h3>${this.fragment.title}</h3>
                <p>${this.fragment.path}</p>
                <pre>${JSON.stringify(this.fragment, null, 2)}</pre>
            </div>
        `;
    }

    render() {
        if (this.loading) return this.renderLoading();
        if (this.error) return this.renderError();
        if (this.fragment) return this.renderFragment();
        return html`<div>No fragment loaded</div>`;
    }
}

customElements.define('mas-fragment-loader', MasFragmentLoader);
```

These examples demonstrate common patterns used in MAS Studio components, including state management, event handling, store integration, and async operations.
