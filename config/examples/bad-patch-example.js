/**
 * BAD PATTERN: Symptom-patching instead of root cause fixes
 *
 * This file shows examples of "band-aid" fixes that hide
 * the real problem instead of solving it.
 */

// ============================================================
// BAD: setTimeout to "fix" timing issues
// ============================================================

// DON'T use setTimeout to paper over race conditions
class BadComponent {
    connectedCallback() {
        // BAD: setTimeout hides the real problem
        setTimeout(() => {
            this.initializeCard();
        }, 100);
    }

    handleClick() {
        // BAD: Why is 50ms needed? What's the real issue?
        setTimeout(() => {
            this.updatePreview();
        }, 50);
    }
}

// GOOD: Fix the actual timing issue
class GoodComponent {
    connectedCallback() {
        // Wait for the component to be properly connected
        this.updateComplete.then(() => {
            this.initializeCard();
        });
    }

    handleClick() {
        // If element isn't ready, ensure it's ready first
        this.requestUpdate();
        this.updateComplete.then(() => {
            this.updatePreview();
        });
    }
}

// ============================================================
// BAD: Retry loops hiding actual bugs
// ============================================================

// DON'T add retries without understanding why failures happen
async function fetchFragmentBad(id) {
    for (let i = 0; i < 3; i++) {
        try {
            return await fetch(`/api/fragments/${id}`);
        } catch (error) {
            console.warn(`Retry ${i + 1}/3`);
            await sleep(1000);
        }
    }
    throw new Error('Failed after 3 retries');
}

// GOOD: Understand and fix the root cause
// Root cause: endpoint returns 500 when cache is cold
// Fix: warm the cache on startup, or fix the backend
async function fetchFragmentGood(id) {
    return fetch(`/api/fragments/${id}`);
}

// ============================================================
// BAD: Null checks for impossible scenarios
// ============================================================

// DON'T add guards "just to be safe"
function processBadgeBad(fragment) {
    // These checks are unnecessary - caller guarantees fragment exists
    if (!fragment) return null;
    if (!fragment.fields) return null;

    const badge = fragment.fields.find((f) => f.name === 'badge');
    if (!badge) return null;
    if (!badge.value) return null;

    // Original bug: badge.value was always undefined
    // This code papers over the bug instead of fixing it
    return badge.value;
}

// GOOD: Fix the actual bug
function processBadgeGood(fragment) {
    const badge = fragment.fields.find((f) => f.name === 'badge');
    // Root cause: value is in badge.values[0], not badge.value
    return badge?.values?.[0] || null;
}

// ============================================================
// BAD: MutationObserver to detect changes
// ============================================================

// DON'T use MutationObserver when reactive state exists
class BadObserverComponent {
    connectedCallback() {
        // BAD: Observer to watch for DOM changes
        this.observer = new MutationObserver(() => {
            this.updateLayout();
        });
        this.observer.observe(this, { childList: true, subtree: true });
    }
}

// GOOD: Use reactive properties and Lit's update cycle
class GoodReactiveComponent {
    static properties = {
        items: { type: Array },
    };

    updated(changedProperties) {
        if (changedProperties.has('items')) {
            this.updateLayout();
        }
    }
}

// ============================================================
// BAD: Event.stopPropagation without understanding why
// ============================================================

// DON'T stop propagation without knowing what you're preventing
handleClick(event) {
    event.stopPropagation(); // WHY? What listener are we hiding from?
    this.doSomething();
}

// GOOD: Understand the event flow and fix properly
handleClick(event) {
    // If parent should not receive this event, document why
    // Better: fix the parent to check event.target
    this.doSomething();
}

/**
 * ROOT CAUSE ANALYSIS CHECKLIST:
 *
 * Before adding a workaround, ask:
 * 1. WHY is this happening?
 * 2. WHY does that cause this?
 * 3. WHY is that the case?
 * (Ask "why" at least 3 times)
 *
 * If you can't explain the root cause in one sentence,
 * you haven't investigated enough.
 */
