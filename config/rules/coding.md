# Coding Rules

## Problem-Solving Priority (STRICT order)

1. **DELETE code** (Best)
2. **MODIFY existing code** (Good)
3. **ADD new code** (Last resort) — justify why 1 and 2 don't work

## Stop Triggers

Before ANY code change:
- Have you READ the files you're modifying?
- Can you explain the root cause in ONE sentence?
- Is this the SMALLEST possible fix?
- If change exceeds 30 lines: justify or break into smaller changes

## Shared Utility Check

Before modifying these files, STOP:
- `hydrate.js` → Can a getter in the component solve this?
- `merch-card.js` → Can conditional rendering solve this?
- Any `/src/*.js` root file → Is this truly shared, not component-specific?

## Component-Level Solutions First

1. Can a getter/method in the component solve it? → Do that
2. Can conditional rendering solve it? → Do that
3. Can CSS solve it? → Do that
4. Only if none work → modify shared utilities

## Code Quality

Full coding principles with examples: `.specify/memory/constitution.md`

Key tables from the constitution apply here:
- Getters over querySelector (queried 2+ times → getter)
- Trust your helpers (don't duplicate callee's null checks)
- Data over code (same pattern 2+ times → array + iteration)
- 4+ intermediate variables → extract to helper

## Lit Best Practices

- Use `nothing` for conditional removal, not `''`
- Use `repeat()` for keyed lists
- Immutable updates (spread operators for new refs)
- Use `@property()` + templates, not manual DOM updates
- Use `static styles`, not inline styles
- Lifecycle: `willUpdate` → `render` (pure) → `firstUpdated` (once) → `updated` (each)
