# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

The `src/placeholders` directory contains components for managing AEM content placeholders in MAS Studio. Placeholders are key-value pairs (with optional rich text) that can be localized and published to AEM.

## Architecture

### Component Structure

- **`mas-placeholders.js`** - Main container component
  - Manages list of placeholders with filtering, sorting, and search
  - Handles bulk operations (selection, deletion)
  - Uses `FragmentStore` for reactive placeholder data
  - Subscribes to `Events.fragmentDeleted` for cleanup after deletion

- **`mas-placeholders-item.js`** - Individual placeholder row component
  - Inline editing for key and value fields
  - Supports both plain text and rich text (RTE) values
  - Action menu for publish/delete operations
  - Light DOM rendering (`createRenderRoot() { return this; }`)

- **`mas-placeholders-creation-modal.js`** - Modal for creating new placeholders
  - Form with key, locale, value, and rich text toggle
  - Normalizes keys using `normalizeKey()` utility
  - Calls `repository.createPlaceholder()`

### Data Model

Placeholders extend the `Fragment` class (`src/aem/placeholder.js`):
- **`key`** - Unique identifier (normalized)
- **`value`** - Plain text value (if `isRichText` is false)
- **`richTextValue`** - HTML content (if `isRichText` is true)
- **`isRichText`** - Boolean flag indicating value type
- **`locale`** - Placeholder locale
- **`status`** - Draft or Published
- **`updatedBy`** / **`updatedAt`** - Modification metadata

### Reactive State Management

- Uses `FragmentStore` to wrap `Placeholder` instances
- `ReactiveController` connects stores to Lit component lifecycle
- Store changes trigger component re-renders via `notify()`
- Main stores:
  - `Store.placeholders.list.data` - Array of `FragmentStore` instances
  - `Store.placeholders.selection` - Array of selected placeholder keys
  - `Store.placeholders.search` - Search term for filtering
  - `Store.sort` - Sort configuration (sortBy, sortDirection)

### Key Patterns

1. **Fragment-based editing**: Placeholders are AEM Content Fragments with fields for key/value
2. **Inline editing mode**: Toggle between view and edit states per row
3. **Rich Text Editor (RTE)**: Dynamic field type switching based on `isRichText` flag
4. **Selection panel**: Bulk operations on multiple selected placeholders
5. **Pending state**: Disables checkboxes during async operations to prevent race conditions

### Repository Operations

All AEM interactions go through `MasRepository`:
- `createPlaceholder(placeholder)` - Create new placeholder
- `saveFragment(placeholderStore)` - Save changes to existing placeholder
- `publishFragment(placeholder)` - Publish to AEM
- `deleteFragment(placeholder)` - Delete single placeholder
- `bulkDeleteFragments(fragments)` - Delete multiple placeholders
- `removeFromIndexFragment(fragments)` - Remove from placeholder index before deletion

### Important Implementation Details

- **Unicode normalization**: Placeholder keys/values use NFC normalization
- **Selection refresh**: After filtering/sorting, selection checkboxes must be refreshed via `refresh()` method
- **RTE initialization**: Rich text fields require manual initialization with `rteField.innerHTML` on edit mode
- **Light DOM**: Components render without shadow DOM for easier CSS styling
- **Event subscription**: Components must unsubscribe from events in `disconnectedCallback()`
