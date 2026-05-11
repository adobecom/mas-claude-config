# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development
- `npm run build` - Build the application using esbuild (bundles swc.js, prosemirror.js, spectrum.js)
- `npm run proxy` - Start proxy server pointing to production AEM (port 8080)
- `npm run proxy:qa` - Start proxy server pointing to QA environment
- `npm run proxy:https` - Start HTTPS proxy with SSL certificates

### Testing
- `npm run test` - Run tests with Web Test Runner in watch mode with coverage
- `npm run test:ci` - Run tests in CI mode (no watch)
- Run a single test: `npm run test -- --grep "test name"`

### Repo-root commands (run from the mas/ repo root)
- `npm run lint` - Run ESLint with auto-fix across all workspaces
- `npm run format` - Format code with Prettier
- `npm run studio` - Start studio with proxy and AEM
- `npm run nala` - Run Nala test automation

## Architecture

### Core Components
- **MAS Studio** is a web-based content management tool for Adobe Experience Manager (AEM)
- Built with **Lit** web components following the `mas-` prefix convention
- Uses **Spectrum Web Components** for Adobe's design system
- Integrates **ProseMirror** for rich text editing capabilities

### State Management
- Custom reactive state system built on:
  - `ReactiveStore` class (`src/reactivity/reactive-store.js`) - Provides reactive state with validation
  - `StoreController` (`src/reactivity/store-controller.js`) - Integrates stores with Lit components
  - Global `Store` object (`src/store.js`) manages application-wide state
- Store validators ensure data consistency (e.g., `filtersValidator`, `pageValidator`, `sortValidator`)
- Stores support subscription pattern for reactive updates across components
- `FragmentStore` wraps `Fragment` instances to make them reactive within the Lit component lifecycle

### Content Model
- **Fragments**: Core content units represented by `Fragment` class (`src/aem/fragment.js`)
  - Track changes with `hasChanges` flag and `initialValue` for rollback
  - Provide field access via `getField()`, `getFieldValue()`, `updateField()`
  - Handle Unicode normalization (NFC) for special characters
- **Cards**: Product/offer cards edited via `merch-card-editor.js` with variant-specific fields
- **Collections**: Groups of cards edited via `merch-card-collection-editor.js`
- **Placeholders**: Content replacement system extending `Fragment` class

### Key Directories
- `src/aem/` - AEM integration and API communication (see `src/aem/CLAUDE.md` for details)
- `src/bulk-publish/` - Bulk-publish editor: list view, item picker, locales picker, status dialogs, success banner. Per-row validation (`validate()`) marks items as valid/error/already-published; project-level rules in `mas-bulk-publish-editor.js` gate the publish action.
- `src/editors/` - Fragment editors (merch-card-editor.js, merch-card-collection-editor.js, variant-picker.js)
- `src/fields/` - Form field components for editors
- `src/filters/` - Data filtering and search components
- `src/rte/` - Rich Text Editor components using ProseMirror (rte-field.js, osi-field.js)
- `src/reactivity/` - Custom reactive state management system

### Development Patterns
- Components use `createRenderRoot() { return this; }` for light DOM rendering (no shadow DOM)
- Side panel editor pattern via `editor-panel.js` for content editing
- Fragment-based architecture for modular content
- Router (`src/router.js`) syncs URL hash with store state for bookmarkable URLs
- Proxy server required for CORS handling during development (AEM on port 8080, WTR on port 2023)
- Authentication via IMS tokens stored in `sessionStorage.masAccessToken`

### Modal Dialog Patterns

Two patterns coexist:

**1. `sp-dialog-wrapper` (preferred for confirm/cancel modals).** See `src/bulk-publish/mas-bulk-publish-confirm-dialog.js` and `src/mas-add-items-dialog.js`. The mas-swc-dialog skill documents the right tokens and slots. Use this whenever a stock confirm/cancel/info flow works.

**2. Custom dialog container with dark backdrop (use only when `sp-dialog-wrapper` doesn't fit).** Examples: dialogs that need exact positioning relative to a triggering element, or that pre-date the Spectrum dialog adoption. Boilerplate:
```css
:host {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    z-index: 999;
    display: block;
}

.dialog-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(0, 0, 0, 0.5);
    z-index: 999;
    display: flex;
    align-items: center;
    justify-content: center;
}

.dialog-container {
    background: var(--spectrum-white);
    border-radius: 20px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
    padding: 24px;
    min-width: 400px;
    z-index: 1000;
    position: relative;
}

.dialog-header {
    font-size: 18px;
    font-weight: 600;
    margin-bottom: 24px;
    padding-bottom: 16px;
    border-bottom: 1px solid var(--spectrum-gray-200);
}

.dialog-footer {
    display: flex;
    justify-content: flex-end;
    gap: 12px;
    margin-top: 24px;
}
```
HTML structure:
```html
<div class="dialog-backdrop" @click=${this.handleBackdropClick}>
    <div class="dialog-container" @click=${(e) => e.stopPropagation()}>
        <!-- content -->
    </div>
</div>
```
- Use `.dialog-backdrop` with `rgba(0, 0, 0, 0.5)` for dark semi-transparent overlay
- Click backdrop to close dialog (with `handleBackdropClick` method)
- Use `e.stopPropagation()` on container to prevent backdrop click when clicking dialog
- Use `sp-button` for Cancel/Confirm actions in the footer
