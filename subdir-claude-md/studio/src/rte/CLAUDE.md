# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

The RTE (Rich Text Editor) module provides ProseMirror-based rich text editing components for MAS Studio. It handles content editing for merch cards, including text formatting, links, inline prices, mnemonics, and icons.

## Core Components

### `rte-field.js`
The main rich text editor component built on ProseMirror. Provides:
- **Text formatting**: Bold, italic, underline, strikethrough, superscript
- **Custom styling marks**: Heading sizes (XXXS-M), text sizes (S, L), promo text, renewal text, mnemonic text
- **Custom nodes**: Links, inline prices (WCS integration), info icons, mnemonics
- **List support**: Bullet lists with ProseMirror list commands
- **Keyboard shortcuts**: Standard formatting shortcuts (Cmd+B, Cmd+I, Cmd+K, etc.)

Key patterns:
- Uses `LinkNodeView` and `MnemonicNodeView` for custom node rendering
- Implements light DOM rendering (`createRenderRoot() { return this; }`)
- Tracks content length with character counter
- Dispatches 'change' events on content updates
- Integrates with Offer Selector Tool (OST) for WCS offers

### `osi-field.js`
Simplified field component for selecting offer selector IDs (WCS offers):
- Provides button to open Offer Selector Tool
- Shows selected offer ID
- Visual indicator when no offer is selected (red alert icon)

### `ost.js`
Integration layer for the Offer Selector Tool (external WCS tool):
- Opens modal dialog with offer selector interface
- Converts between Studio and OST data formats
- Handles placeholder selection events (`EVENT_OST_SELECT`, `EVENT_OST_OFFER_SELECT`)
- Maps offer options to data attributes (e.g., `displayOldPrice` → `data-display-old-price`)

### Editor Components
- **`rte-link-editor.js`**: Modal for creating/editing links (web or phone) with variants (accent, primary, secondary, etc.)
- **`rte-icon-editor.js`**: Modal for inserting info icons with tooltips
- **`rte-mnemonic-editor.js`**: Modal for inserting inline mnemonic images with text and placement options

## ProseMirror Schema Architecture

### Custom Nodes
- **`inlinePrice`**: Inline price display from WCS offers
- **`link`**: Link node with checkout/phone/web support
- **`icon`**: Info icon with tooltip
- **`mnemonic`**: Inline mnemonic icon with optional tooltip text and placement

### Custom Marks
- **Styling marks**: `heading-xxxs`, `heading-xxs`, `heading-xs`, `heading-s`, `heading-m`, `text-s`, `text-l`, `promo-text`, `promo-duration-text`, `mnemonic-text`, `renewal-text`
- **Standard marks**: `strong`, `em`, `strikethrough`, `underline`, `superscript`

### Schema Configuration
The editor schema is built dynamically based on component attributes:
- `inline`: Changes doc content to `inline*` (no block structure)
- `list`: Adds list nodes to schema
- `link`/`uptLink`: Adds link node support
- `icon`: Adds icon node support
- `mnemonic`: Adds mnemonic node support
- `marks`: Filters which styling marks are available

## Event System

### Events Dispatched
- **`change`**: Fired when editor content changes (bubbles, composed)
- **`save`**: Fired by editor modals when saving changes (from link/icon/mnemonic editors)
- **`close`**: Fired when editor modals are closed

### Events Consumed
- **`EVENT_OST_SELECT`**: Receives placeholder selection from Offer Selector Tool
- **`EVENT_OST_OFFER_SELECT`**: Receives offer selection from Offer Selector Tool (osi-field only)
- **`keydown`**: Handles ESC key to close editor modals

## Key Development Patterns

### Transaction Handling
All ProseMirror state changes go through the `#handleTransaction` method:
1. Apply transaction to current state
2. Update selection state (detect link selection)
3. Update editor view
4. Serialize content and dispatch 'change' event
5. Update character length counter

### Node Selection
Custom nodes (links, mnemonics) are selected using `NodeSelection.create()`:
- Single click: Text cursor placement
- Double click: Node selection (opens editor for mnemonics)
- Selected nodes get `ProseMirror-selectednode` class

### Modal Editor Pattern
All editors (link, icon, mnemonic) follow the same pattern:
1. Component has `open` and `dialog` boolean properties
2. Editor opens via `show{Editor}Editor = true` + `await updateComplete`
3. Populate editor with data via `Object.assign()`
4. User saves or cancels
5. Save handler dispatches 'save' event with form data
6. Parent component handles save event and updates ProseMirror state

### WCS Integration
The Offer Selector Tool integration:
1. User clicks OST button or double-clicks existing offer
2. `openOfferSelectorTool()` opens modal with WCS API
3. User selects offer from catalog
4. OST dispatches custom event with offer attributes
5. Editor creates/updates inline price or checkout link node

## Testing Notes

- Editor uses light DOM rendering, no shadow DOM for content
- ProseMirror state is ephemeral - serialize to HTML to persist
- Use `editorView.dom.innerText` for text length calculations
- Unicode normalization (NFC) is handled at Fragment level, not here
