/**
 * GOOD PATTERN: Using getters instead of querySelector
 *
 * Getters encapsulate DOM queries, making code more readable,
 * testable, and reusable across methods.
 */

// ============================================================
// BAD: Direct querySelector usage scattered throughout code
// ============================================================

class BadComponent extends LitElement {
    saveFragment() {
        // BAD: querySelector repeated in multiple methods
        const repository = document.querySelector('mas-repository');
        repository.save(this.fragment);
    }

    refreshFragment() {
        // BAD: Same query duplicated
        const repository = document.querySelector('mas-repository');
        repository.refresh(this.fragment);
    }

    deleteFragment() {
        // BAD: And again...
        const repository = document.querySelector('mas-repository');
        repository.delete(this.fragment);
    }
}

// ============================================================
// GOOD: Getter encapsulates the query
// ============================================================

class GoodComponent extends LitElement {
    // Single getter - reusable, testable, readable
    get repository() {
        return document.querySelector('mas-repository');
    }

    saveFragment() {
        this.repository.save(this.fragment);
    }

    refreshFragment() {
        this.repository.refresh(this.fragment);
    }

    deleteFragment() {
        this.repository.delete(this.fragment);
    }
}

// ============================================================
// GOOD: Getter for slot element detection
// ============================================================

class MerchCardVariant extends LitElement {
    // Getter to check if badge slot has content
    get badge() {
        return this.card.querySelector('[slot="badge"]');
    }

    // Getter for price element
    get price() {
        return this.card.querySelector('[slot="price"]');
    }

    // Use getters in render logic
    renderLayout() {
        return html`
            ${this.badge ? html`<div class="badge-wrapper"><slot name="badge"></slot></div>` : nothing}
            ${this.price ? html`<div class="price-wrapper"><slot name="price"></slot></div>` : nothing}
        `;
    }
}

/**
 * WHY THIS MATTERS:
 * - Getters are reusable across multiple methods
 * - Easy to mock in tests
 * - Single source of truth for DOM queries
 * - Changes to query only need updating in one place
 */
