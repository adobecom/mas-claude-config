# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

The `/src/aem/` directory contains the AEM (Adobe Experience Manager) integration layer for MAS Studio. It provides the core API client and data models for interacting with AEM's Content Fragment APIs.

## Core Components

### AEM Client (`aem.js`)
- Main API client for all AEM operations
- Handles authentication via IMS tokens (stored in `sessionStorage.masAccessToken`)
- Provides CRUD operations for content fragments
- Implements polling mechanisms for async operations (create/update with configurable timeouts)
- Uses ETag-based optimistic locking for concurrent updates
- Supports search with cursor-based pagination via generator functions

### Fragment Model (`fragment.js`)
- Base class representing an AEM Content Fragment
- Tracks changes with `hasChanges` flag and `initialValue` state
- Provides field access methods: `getField()`, `getFieldValue()`, `updateField()`
- Handles Unicode normalization (NFC) for special characters
- Supports change tracking and rollback via `discardChanges()`

### Placeholder Model (`placeholder.js`)
- Extends `Fragment` for placeholder-type content fragments
- Supports both plain text and rich text values
- Provides accessors for `key`, `value`, and metadata

### Filter Panel (`mas-filter-panel.js`)
- UI component for filtering fragments by tags
- Implements AND/OR logic: OR within same tag namespace, AND across different namespaces
- Example: `filterByTags(['mas:plan_type/abm', 'mas:plan_type/m2m'])` uses OR logic
- Example: `filterByTags(['mas:plan_type/abm', 'mas:status/draft'])` uses AND logic

### Tag Picker (`aem-tag-picker-field.js`)
- Field component for selecting AEM tags
- Integrates with AEM's tag taxonomy system

### Content Tree (`content-tree.js`)
- Simple navigation component for hierarchical content structure

## Key API Methods

### Fragment Operations
- `aem.sites.cf.fragments.search()` - Generator function for paginated search
- `aem.sites.cf.fragments.getById()` - Fetch fragment by ID
- `aem.sites.cf.fragments.getByPath()` - Fetch fragment by path
- `aem.sites.cf.fragments.getWithEtag()` - Get fragment with ETag for updates
- `aem.sites.cf.fragments.save()` - Save changes (uses polling to verify)
- `aem.sites.cf.fragments.copy()` - Copy fragment using classic API
- `aem.sites.cf.fragments.create()` - Create new fragment
- `aem.sites.cf.fragments.publish()` - Publish fragment with references
- `aem.sites.cf.fragments.delete()` - Delete fragment

### Other Operations
- `aem.folders.list()` - List folders in a path
- `aem.tags.list()` - List tags from a root namespace
- `aem.getCsrfToken()` - Get CSRF token for write operations

## Important Patterns

### Polling Pattern
- After create/update operations, the code polls for updated fragments
- Uses `MAX_POLL_ATTEMPTS` (10) and `POLL_TIMEOUT` (250ms)
- Required because AEM operations are eventually consistent
- `pollUpdatedFragment()` checks ETag, modified timestamp, and field changes

### Tag Filtering Logic
Tags use hierarchical AND/OR logic:
- Tags with same root namespace: OR (match any)
- Tags with different root namespaces: AND (match all namespaces)
- Example: `['mas:plan_type/abm', 'mas:plan_type/m2m', 'mas:status/draft']` means "(abm OR m2m) AND draft"

### Fragment Change Tracking
- `fragment.initialValue` stores original state
- `fragment.hasChanges` indicates unsaved modifications
- `fragment.updateField()` automatically sets `hasChanges = true`
- `fragment.discardChanges()` reverts to `initialValue`
- `fragment.refreshFrom()` updates both current and initial state after save

## Testing

Tests are located in `/test/aem/aem.test.js` and use Web Test Runner with Chai assertions.

Run tests with:
- `npm run test` - Watch mode with coverage (from studio root)
- `npm run test:ci` - CI mode (from studio root)
- `npm run test -- --grep "test name"` - Run specific test (from studio root)

## Configuration

Local settings can be configured in `.claude/settings.local.json` for controlling MCP tool permissions.
