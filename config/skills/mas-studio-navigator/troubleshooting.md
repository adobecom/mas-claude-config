# MAS Studio Navigator - Troubleshooting

Decision trees and solutions for common issues when navigating MAS Studio UI.

## Element Not Found

```
Element not found when trying to interact
│
├─ Is the page loaded?
│  ├─ NO → Wait for page load
│  │       → mcp__playwright__browser_wait_for({ text: 'MAS Studio' })
│  │
│  └─ YES → Take snapshot to verify current state
│           → mcp__playwright__browser_snapshot()
│
├─ Is the element in the DOM?
│  ├─ NO → Element may be conditionally rendered
│  │       - Check if parent container exists
│  │       - Check if data is loaded
│  │       - Wait for specific text that appears with the element
│  │
│  └─ YES → Element exists but selector is wrong
│           - Check selector syntax (CSS vs a11y)
│           - Try alternative selector from selectors.md
│           - Use snapshot to find correct ref/uid
│
├─ Is element behind a dialog/overlay?
│  ├─ YES → Close dialog first
│  │       → Look for sp-dialog-wrapper[open]
│  │       → Click Cancel or close button
│  │
│  └─ NO → Check if element is scrolled out of view
│          → Try scrolling or use evaluate to scroll into view
│
└─ Is element in Shadow DOM?
   ├─ YES → MAS Studio uses light DOM, this is unexpected
   │       → Check if this is a Spectrum Web Component internal
   │       → May need to pierce shadow: selector >>> inner
   │
   └─ NO → Continue with standard selectors
```

## Authentication Issues

```
Studio shows login page or auth error
│
├─ Using Playwright MCP?
│  ├─ YES → Need full auth flow
│  │       1. Check if login form visible
│  │       2. Fill email from IMS_EMAIL env var
│  │       3. Click Continue
│  │       4. Fill password from IMS_PASS env var
│  │       5. Click Sign In
│  │       6. Wait for studio to load
│  │
│  └─ NO (DevTools) → Session may have expired
│                    → User needs to re-authenticate in Chrome
│                    → Cannot auto-login with DevTools MCP
│
├─ Login form not appearing?
│  │
│  ├─ Check network for redirects
│  │  → mcp__chrome-devtools__list_network_requests()
│  │
│  └─ Check console for auth errors
│     → mcp__chrome-devtools__list_console_messages({ types: ['error'] })
│
├─ Login succeeds but studio doesn't load?
│  │
│  ├─ Check for JavaScript errors
│  │  → mcp__playwright__browser_console_messages({ onlyErrors: true })
│  │
│  └─ Check if token is stored
│     → mcp__playwright__browser_evaluate({
│         function: '() => sessionStorage.masAccessToken'
│       })
│
└─ "Not authorized" error after login?
   │
   ├─ User may not have MAS Studio access
   │  → Verify account has correct permissions
   │
   └─ Token may be expired
      → Clear sessionStorage and re-login
      → mcp__playwright__browser_evaluate({
          function: '() => sessionStorage.clear()'
        })
```

## Save Operation Fails

```
Fragment save fails or no response
│
├─ Is there a validation error?
│  ├─ YES → Check form fields for error indicators
│  │       → Look for sp-textfield[invalid]
│  │       → Look for sp-field-label with error styling
│  │       → Fix the invalid field value
│  │
│  └─ NO → Check network request
│
├─ Check network for save request
│  → mcp__chrome-devtools__list_network_requests({
│      resourceTypes: ['fetch']
│    })
│  │
│  ├─ Request not sent?
│  │  → Fragment may not have changes
│  │  → Check hasChanges flag:
│  │    mcp__chrome-devtools__evaluate_script({
│  │      function: '() => document.querySelector("mas-fragment-editor")?.fragmentStore?.value?.hasChanges'
│  │    })
│  │
│  ├─ Request returned 401?
│  │  → Auth token expired, re-login
│  │
│  ├─ Request returned 409 (conflict)?
│  │  → Fragment was modified by another user
│  │  → Reload and re-apply changes
│  │
│  └─ Request returned 500?
│     → Server error, check AEM logs
│     → May need to retry
│
├─ Check console for errors
│  → mcp__chrome-devtools__list_console_messages({ types: ['error'] })
│
└─ Toast shows error message?
   → Read toast content for specific error
   → Look for mas-toast >> sp-toast[variant="negative"]
```

## Fragment Not Loading

```
Fragment card shows error or doesn't render
│
├─ Is the aem-fragment element present?
│  → Check for: aem-fragment[fragment="<path>"]
│  │
│  ├─ YES → Check fragment status attribute
│  │       → data-status="404" → Fragment not found in AEM
│  │       → data-status="error" → Fetch failed
│  │
│  └─ NO → Fragment path may be incorrect
│          → Check URL hash for correct path parameter
│
├─ Check fragment cache
│  → mcp__chrome-devtools__evaluate_script({
│      function: '() => {
│        const AemFragment = customElements.get("aem-fragment");
│        const cache = AemFragment?.cache;
│        return cache ? Array.from(cache.keys()) : [];
│      }'
│    })
│
├─ Check network for fragment fetch
│  → Look for requests to /adobe/sites/fragments
│  │
│  ├─ Request not sent?
│  │  → Fragment may be cached
│  │  → Try clearing cache and refreshing
│  │
│  ├─ Request returned 404?
│  │  → Fragment doesn't exist at that path
│  │  → Verify path in AEM
│  │
│  └─ Request returned 403?
│     → Permission denied
│     → Check user has access to that content path
│
└─ Fragment loads but card doesn't render?
   → Check for merch-card custom element
   → Verify variant attribute is valid
   → Check console for card rendering errors
```

## Editor Panel Issues

```
Editor panel doesn't open or is empty
│
├─ Did double-click register?
│  → Take snapshot to verify fragment is selected
│  → Check for .overlay class on fragment (selection indicator)
│  │
│  ├─ Fragment not selected?
│  │  → Single click to select first
│  │  → Then double-click to open editor
│  │
│  └─ Fragment selected but editor not open?
│     → Check for mas-fragment-editor element
│     → Check editor-expanded state in store
│
├─ Editor opens but fields are empty?
│  │
│  ├─ Fragment data not loaded
│  │  → Check fragmentStore.value in editor
│  │  → mcp__chrome-devtools__evaluate_script({
│  │      function: '() => document.querySelector("mas-fragment-editor")?.fragmentStore?.value'
│  │    })
│  │
│  └─ Fields not rendering for variant
│     → Check variant-picker has correct value
│     → Some variants have different field sets
│
├─ Editor stuck in loading state?
│  → Check for loading spinner
│  → Check network for pending requests
│  → May need to close and reopen
│
└─ Editor fields are read-only?
   → Check if fragment is published-only
   → Check user permissions
   → Verify not in preview mode
```

## Dialog/Modal Issues

```
Dialog doesn't appear or won't close
│
├─ Dialog should appear but doesn't?
│  │
│  ├─ Button click may not have registered
│  │  → Take snapshot to verify button exists
│  │  → Check if button is disabled
│  │  → Try waiting briefly and clicking again
│  │
│  └─ Dialog may be opening off-screen
│     → Check for sp-dialog-wrapper[open] anywhere in DOM
│     → May need to scroll or resize viewport
│
├─ Dialog appears but can't interact?
│  │
│  ├─ Dialog may be behind overlay
│  │  → Check z-index issues
│  │
│  └─ Wrong dialog opened
│     → Close current dialog first
│     → Look for sp-button:has-text("Cancel")
│
├─ Dialog won't close?
│  │
│  ├─ Required fields not filled
│  │  → Check for validation errors in dialog
│  │  → Fill required fields before confirming
│  │
│  └─ Close button not clickable
│     → Check if dialog is processing (loading state)
│     → Wait for operation to complete
│
└─ Multiple dialogs stacked?
   → Close dialogs one at a time from top
   → Press Escape key as alternative
   → mcp__playwright__browser_press_key({ key: 'Escape' })
```

## Toast/Notification Issues

```
Toast doesn't appear after operation
│
├─ Operation actually completed?
│  → Check network for request completion
│  → Verify data changed in page
│  │
│  ├─ Operation succeeded silently
│  │  → Toast may have auto-dismissed
│  │  → Check console for success logs
│  │
│  └─ Operation failed silently
│     → Check console for error messages
│     → Check network response for error
│
├─ Toast appears but disappears too fast?
│  → Toasts auto-dismiss after ~3 seconds
│  → Need to check immediately after action
│  → Consider checking console messages instead
│
└─ Wrong toast variant?
   → Success: sp-toast[variant="positive"]
   → Error: sp-toast[variant="negative"]
   → Info: sp-toast[variant="info"]
   → Check toast content for actual message
```

## Performance Issues

```
Studio is slow or unresponsive
│
├─ Start performance trace
│  → mcp__chrome-devtools__performance_start_trace({
│      reload: true,
│      autoStop: true
│    })
│
├─ Check for memory issues
│  → mcp__chrome-devtools__evaluate_script({
│      function: '() => performance.memory'
│    })
│
├─ Check fragment cache size
│  → Large cache may cause slowness
│  → mcp__chrome-devtools__evaluate_script({
│      function: '() => customElements.get("aem-fragment")?.cache?.size'
│    })
│
├─ Check for excessive re-renders
│  → Look for Lit component update cycles
│  → Monitor console for render warnings
│
└─ Network bottleneck?
   → Check pending network requests
   → mcp__chrome-devtools__list_network_requests()
   → Look for slow or failed requests
```

## Common Error Messages

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "Fragment not found" | Fragment deleted or path wrong | Verify fragment exists in AEM |
| "Not authorized" | Missing permissions or expired token | Re-authenticate |
| "Conflict detected" | Fragment modified by another user | Reload and merge changes |
| "Validation failed" | Required field empty or invalid | Check form field validation |
| "Network error" | Connection issue or CORS | Check proxy is running (port 8080) |
| "Save failed" | Server rejected update | Check AEM logs, verify data |
| "Token expired" | IMS session timed out | Clear session and re-login |

## Quick Diagnostic Commands

### Check Application State
```javascript
mcp__chrome-devtools__evaluate_script({
  function: `() => {
    const studio = document.querySelector('mas-studio');
    const store = studio?.store;
    return {
      page: store?.page?.value,
      path: store?.path?.value,
      locale: store?.locale?.value,
      selectedId: store?.selectedFragmentId?.value,
      editorExpanded: store?.editorExpanded?.value,
      hasChanges: document.querySelector('mas-fragment-editor')?.fragmentStore?.value?.hasChanges
    };
  }`
})
```

### Check Fragment Cache
```javascript
mcp__chrome-devtools__evaluate_script({
  function: `() => {
    const AemFragment = customElements.get('aem-fragment');
    const cache = AemFragment?.cache;
    return {
      size: cache?.size || 0,
      keys: cache ? Array.from(cache.keys()).slice(0, 10) : []
    };
  }`
})
```

### Force Page Refresh
```javascript
mcp__playwright__browser_evaluate({
  function: '() => location.reload()'
})
```

### Clear Session and Re-auth
```javascript
mcp__playwright__browser_evaluate({
  function: '() => { sessionStorage.clear(); location.reload(); }'
})
```
