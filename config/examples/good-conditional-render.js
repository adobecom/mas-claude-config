/**
 * GOOD PATTERN: Component-level solutions
 *
 * When fixing component-specific issues, solve them IN the component
 * using getters and conditional rendering. Do NOT modify shared utilities.
 */

// ============================================================
// BAD: Modifying shared utility for component-specific behavior
// ============================================================

// In hydrate.js (shared utility) - DON'T DO THIS
function processBadge(fields, merchCard) {
    // BAD: Adding component-specific logic to shared utility
    const badgeContent = fields.badge?.trim();
    if (!badgeContent) {
        fields.badge = null;
    }
    // This affects ALL card variants, not just the one with the issue
}

// ============================================================
// GOOD: Solve in the component file
// ============================================================

// In simplified-pricing-express.js (component file)
class SimplifiedPricingExpress extends VariantLayout {
    // Getter to detect badge presence
    get badge() {
        return this.card.querySelector('[slot="badge"]');
    }

    // Conditional rendering based on getter
    renderLayout() {
        return html`
            <div class="card-content">
                ${this.badge
                    ? html`<div class="badge-wrapper"><slot name="badge"></slot></div>`
                    : html`<slot name="badge" hidden></slot>`}
                <slot name="heading"></slot>
                <slot name="price"></slot>
            </div>
        `;
    }
}

// ============================================================
// DECISION TREE: Where to solve the issue
// ============================================================

/**
 * 1. Can a getter in the component solve it?
 *    YES → Add getter and use it
 *    NO  → Continue to step 2
 *
 * 2. Can conditional rendering in the component solve it?
 *    YES → Use ternary in html template
 *    NO  → Continue to step 3
 *
 * 3. Can CSS in the component solve it?
 *    YES → Add styles to component's CSS
 *    NO  → Continue to step 4
 *
 * 4. Is this truly shared behavior needed by ALL consumers?
 *    YES → NOW consider shared utility changes
 *    NO  → Go back to steps 1-3, you missed something
 */

// ============================================================
// WHY component-level solutions are better
// ============================================================

/**
 * - Shared utilities affect ALL consumers (wide blast radius)
 * - Component changes only affect that component (narrow blast radius)
 * - Easier to test component-level changes
 * - Easier to revert if something goes wrong
 * - Other team members' components aren't affected
 */
