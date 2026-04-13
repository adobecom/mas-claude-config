/**
 * BAD PATTERN: Over-engineered verbose code
 *
 * This file shows examples of code that is unnecessarily complex.
 * These patterns should be avoided.
 */

// ============================================================
// BAD: Helper function for single use
// ============================================================

// DON'T create utilities for one-time operations
function formatBadgeText(text) {
    return text?.trim() || '';
}

function validateBadgeContent(content) {
    if (!content) return false;
    if (typeof content !== 'string') return false;
    if (content.trim().length === 0) return false;
    return true;
}

class BadComponent {
    processBadge(badge) {
        const text = formatBadgeText(badge);
        if (!validateBadgeContent(text)) {
            return null;
        }
        return text;
    }
}

// GOOD: Inline the simple logic
class GoodComponent {
    processBadge(badge) {
        const text = badge?.trim();
        return text || null;
    }
}

// ============================================================
// BAD: Over-parameterized function
// ============================================================

// DON'T add parameters "just in case"
function fetchFragment(
    id,
    options = {},
    transform = (x) => x,
    cacheKey = null,
    retryCount = 3,
    retryDelay = 1000,
    onProgress = () => {},
    signal = null
) {
    // In practice, only 'id' is ever used
}

// GOOD: Build for current needs
function fetchFragment(id) {
    return fetch(`/api/fragments/${id}`).then((r) => r.json());
}

// ============================================================
// BAD: Defensive handling for impossible cases
// ============================================================

// DON'T add guards for scenarios that can't happen
function processFields(fragment) {
    if (!fragment) {
        throw new Error('Fragment is required');
    }
    if (!fragment.fields) {
        throw new Error('Fragment must have fields');
    }
    if (!Array.isArray(fragment.fields)) {
        throw new Error('Fields must be an array');
    }
    if (fragment.fields.length === 0) {
        console.warn('Fragment has no fields');
        return {};
    }
    // Schema and caller already guarantee all of these
}

// GOOD: Trust internal contracts
function processFields(fragment) {
    return fragment.fields.reduce((acc, field) => {
        acc[field.name] = field.value;
        return acc;
    }, {});
}

// ============================================================
// BAD: Configuration object for static values
// ============================================================

// DON'T make things configurable when they never change
const config = {
    apiBase: '/api',
    timeout: 5000,
    maxRetries: 3,
    defaultLocale: 'en-US',
};

function fetchData() {
    return fetch(config.apiBase, { timeout: config.timeout });
}

// GOOD: Use constants
const API_BASE = '/api';
const TIMEOUT_MS = 5000;

function fetchData() {
    return fetch(API_BASE, { timeout: TIMEOUT_MS });
}

// ============================================================
// BAD: Abstract factory for single implementation
// ============================================================

// DON'T create abstractions without multiple concrete uses
class CardFactory {
    static create(type) {
        switch (type) {
            case 'catalog':
                return new CatalogCard();
            default:
                throw new Error(`Unknown card type: ${type}`);
        }
    }
}

const card = CardFactory.create('catalog');

// GOOD: Direct instantiation
const card = new CatalogCard();

/**
 * REMEMBER:
 * - Create abstraction only when you have 3+ concrete uses
 * - Inline is usually better than a helper function
 * - Trust internal code, validate at boundaries only
 * - Constants > configuration for fixed values
 * - If 3 lines of similar code work, don't abstract
 */
