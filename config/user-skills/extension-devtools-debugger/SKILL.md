---
description: Debug MAS Studio Chrome Extension using Chrome DevTools MCP. Inspect merch-card detection, overlay behavior, network requests to MAS IO API, console errors, and content script interactions. Use when debugging extension issues, testing card detection, inspecting fragment requests, analyzing UI problems, or when user mentions "debug extension", "inspect card", "check badge", "extension not working".
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - mcp__chrome-devtools__take_snapshot
  - mcp__chrome-devtools__take_screenshot
  - mcp__chrome-devtools__click
  - mcp__chrome-devtools__navigate_page
  - mcp__chrome-devtools__list_pages
  - mcp__chrome-devtools__select_page
  - mcp__chrome-devtools__evaluate_script
  - mcp__chrome-devtools__wait_for
  - mcp__chrome-devtools__list_console_messages
  - mcp__chrome-devtools__get_console_message
  - mcp__chrome-devtools__list_network_requests
  - mcp__chrome-devtools__get_network_request
  - mcp__chrome-devtools__hover
---

# MAS Studio Extension DevTools Debugger

## Purpose

Debug the MAS Studio Chrome Extension using Chrome DevTools MCP. This skill enables real-time inspection of:
- Merch card detection on web pages
- Badge/overlay behavior and positioning
- Network requests to MAS IO API
- Console errors from content scripts
- Extension storage and authentication state

## Prerequisites

### Chrome Remote Debugging

Chrome must be running with remote debugging enabled for MCP to connect:

```bash
# Close all Chrome instances first, then:
open -a "Google Chrome" --args --remote-debugging-port=9222
```

**Verification**: After launching, check http://localhost:9222/json to verify debugging is active.

### Extension Loaded

Ensure the extension is loaded:
1. Navigate to `chrome://extensions/`
2. Enable "Developer mode"
3. Click "Load unpacked" and select `mas-studio-extension` directory
4. Note the extension ID for service worker debugging

### Test Pages

Pages with merch cards for testing:
- https://www.adobe.com/creativecloud/plans.html
- https://www.adobe.com/products/photoshop.html
- Any page using mas.js with `<merch-card>` elements

## Extension-Specific Selectors

### Content Script Elements
| Selector | Purpose |
|----------|---------|
| `.mas-ext-badge` | Extension badge on detected cards |
| `.mas-ext-badge-icon` | Pencil emoji icon |
| `.mas-ext-badge-variant` | Variant label text |
| `.mas-ext-panel` | Expandable info panel |
| `.mas-ext-panel-content` | Panel content area |

### Target Elements
| Selector | Purpose |
|----------|---------|
| `merch-card` | Target card elements |
| `aem-fragment` | Fragment element with ID |
| `merch-card[variant]` | Card with variant attribute |

### Global Objects
| Object | Purpose |
|--------|---------|
| `window.MASCardDetector` | Card detection singleton |
| `window.MASCardOverlay` | Overlay/panel singleton |
| `window.MASStudioLinker` | Deep link generator |

## Core Workflows

### Workflow 1: Check Extension State

Verify the extension is loaded and functioning:

```javascript
// Check all extension components
await mcp__chrome-devtools__evaluate_script({
  function: `() => ({
    detectorActive: !!window.MASCardDetector,
    detectorCards: window.MASCardDetector?.detectedCards?.size || 0,
    observerActive: !!window.MASCardDetector?.observer,
    overlayActive: !!window.MASCardOverlay,
    badgeCount: document.querySelectorAll('.mas-ext-badge').length,
    linkerActive: !!window.MASStudioLinker
  })`
})
```

**Expected Output**:
```json
{
  "detectorActive": true,
  "detectorCards": 5,
  "observerActive": true,
  "overlayActive": true,
  "badgeCount": 5,
  "linkerActive": true
}
```

### Workflow 2: Debug Card Detection

When cards aren't being detected:

```javascript
// Step 1: Check if merch-cards exist on page
await mcp__chrome-devtools__evaluate_script({
  function: `() => {
    const cards = document.querySelectorAll('merch-card');
    return {
      totalCards: cards.length,
      cardsWithFragments: Array.from(cards).filter(c =>
        c.querySelector('aem-fragment')?.getAttribute('fragment')
      ).length,
      fragments: Array.from(cards).map(c => ({
        variant: c.getAttribute('variant'),
        fragmentId: c.querySelector('aem-fragment')?.getAttribute('fragment'),
        size: c.getAttribute('size')
      }))
    };
  }`
})

// Step 2: Check detector state
await mcp__chrome-devtools__evaluate_script({
  function: `() => ({
    detectedCards: Array.from(window.MASCardDetector?.detectedCards?.entries() || []),
    observerConnected: !!window.MASCardDetector?.observer
  })`
})

// Step 3: Manually trigger detection
await mcp__chrome-devtools__evaluate_script({
  function: `() => {
    window.MASCardDetector?.detectExistingCards();
    return window.MASCardDetector?.detectedCards?.size;
  }`
})
```

### Workflow 3: Debug Badge/Overlay Issues

When badges don't appear or panels don't open:

```javascript
// Step 1: Check badge elements in DOM
await mcp__chrome-devtools__take_snapshot()

// Step 2: Inspect badge state
await mcp__chrome-devtools__evaluate_script({
  function: `() => {
    const badges = document.querySelectorAll('.mas-ext-badge');
    return Array.from(badges).map(badge => ({
      fragmentId: badge.dataset.fragmentId,
      variant: badge.querySelector('.mas-ext-badge-variant')?.textContent,
      position: badge.getBoundingClientRect(),
      visible: badge.offsetParent !== null
    }));
  }`
})

// Step 3: Check panel cache
await mcp__chrome-devtools__evaluate_script({
  function: `() => ({
    badgeCount: window.MASCardOverlay?.badges?.size || 0,
    panelCount: document.querySelectorAll('.mas-ext-panel').length,
    fragmentCacheSize: window.MASCardOverlay?.fragmentDataCache?.size || 0,
    cachedFragments: Array.from(window.MASCardOverlay?.fragmentDataCache?.keys() || [])
  })`
})

// Step 4: Force position update
await mcp__chrome-devtools__evaluate_script({
  function: `() => {
    window.MASCardOverlay?.updatePositions();
    return 'Positions updated';
  }`
})
```

### Workflow 4: Analyze Network Requests

Debug API calls to MAS IO:

```javascript
// Step 1: List all network requests
const requests = await mcp__chrome-devtools__list_network_requests({
  resourceTypes: ['fetch', 'xhr']
})

// Step 2: Filter for MAS API requests
await mcp__chrome-devtools__evaluate_script({
  function: `(requests) => {
    return requests.filter(r =>
      r.url.includes('mas.adobe.com/io') ||
      r.url.includes('ims-na1.adobelogin.com')
    );
  }`,
  args: [requests]
})

// Step 3: Get detailed request info
await mcp__chrome-devtools__get_network_request({
  reqid: 'request-id-from-list'
})
```

**Key Endpoints to Monitor**:
| Endpoint | Purpose |
|----------|---------|
| `mas.adobe.com/io/fragment` | Fragment data fetch |
| `ims-na1.adobelogin.com/ims/profile/v1` | User profile |
| `ims-na1.adobelogin.com/ims/authorize/v2` | OAuth flow |

### Workflow 5: Debug Console Errors

Find and analyze extension errors:

```javascript
// Step 1: List console messages
const messages = await mcp__chrome-devtools__list_console_messages({
  types: ['error', 'warn'],
  pageSize: 50
})

// Step 2: Filter extension-related errors
await mcp__chrome-devtools__evaluate_script({
  function: `(messages) => {
    return messages.filter(m =>
      m.text?.includes('[MAS Extension]') ||
      m.text?.includes('MASCardDetector') ||
      m.text?.includes('MASCardOverlay') ||
      m.text?.includes('mas-studio-ext')
    );
  }`,
  args: [messages]
})

// Step 3: Get detailed error info
await mcp__chrome-devtools__get_console_message({
  msgid: 'message-id-from-list'
})
```

**Common Error Patterns**:
| Error | Cause | Fix |
|-------|-------|-----|
| `MASCardDetector is not defined` | Content script not loaded | Reload extension |
| `Cannot read property 'fragment'` | Missing aem-fragment child | Check card structure |
| `401 Unauthorized` | Expired token | Re-authenticate |
| `CORS error` | Cross-origin blocked | Check service worker |

### Workflow 6: Debug Authentication

Check auth state and tokens:

```javascript
// Step 1: Check authentication via message
await mcp__chrome-devtools__evaluate_script({
  function: `() => {
    return new Promise(resolve => {
      chrome.runtime.sendMessage({ type: 'CHECK_AUTH' }, response => {
        resolve(response);
      });
    });
  }`
})

// Step 2: Check storage directly (if available)
await mcp__chrome-devtools__evaluate_script({
  function: `() => {
    return new Promise(resolve => {
      chrome.storage.local.get([
        'masAccessToken',
        'masTokenExpiry',
        'masUserProfile'
      ], result => {
        resolve({
          hasToken: !!result.masAccessToken,
          tokenExpiry: result.masTokenExpiry,
          isExpired: result.masTokenExpiry ? Date.now() > result.masTokenExpiry : true,
          userName: result.masUserProfile?.name
        });
      });
    });
  }`
})
```

### Workflow 7: Interactive Testing

Click and interact with extension UI:

```javascript
// Step 1: Take snapshot to get element UIDs
await mcp__chrome-devtools__take_snapshot()

// Step 2: Click on a badge to open panel
await mcp__chrome-devtools__click({
  uid: 'badge-element-uid'
})

// Step 3: Wait for panel to open
await mcp__chrome-devtools__wait_for({
  text: 'Fragment ID',
  timeout: 5000
})

// Step 4: Take screenshot of result
await mcp__chrome-devtools__take_screenshot({
  filename: 'extension-panel-open.png'
})
```

## Debugging Scenarios

### Scenario: Badges Not Appearing

**Symptoms**: Cards on page but no red badges visible

**Debug Steps**:
```javascript
// 1. Verify cards exist
const cards = await mcp__chrome-devtools__evaluate_script({
  function: `() => document.querySelectorAll('merch-card').length`
})

// 2. Check if detector found them
const detected = await mcp__chrome-devtools__evaluate_script({
  function: `() => window.MASCardDetector?.detectedCards?.size`
})

// 3. Check if badges exist but hidden
const badges = await mcp__chrome-devtools__evaluate_script({
  function: `() => {
    const badges = document.querySelectorAll('.mas-ext-badge');
    return Array.from(badges).map(b => ({
      display: getComputedStyle(b).display,
      visibility: getComputedStyle(b).visibility,
      opacity: getComputedStyle(b).opacity
    }));
  }`
})

// 4. Check console for errors
await mcp__chrome-devtools__list_console_messages({ types: ['error'] })
```

### Scenario: Panel Shows "Loading..." Forever

**Symptoms**: Badge click opens panel but data never loads

**Debug Steps**:
```javascript
// 1. Check network for fragment request
await mcp__chrome-devtools__list_network_requests({
  resourceTypes: ['fetch']
})

// 2. Check for auth errors
await mcp__chrome-devtools__list_console_messages({
  types: ['error']
})

// 3. Verify fragment ID is correct
await mcp__chrome-devtools__evaluate_script({
  function: `() => {
    const panel = document.querySelector('.mas-ext-panel.open');
    return panel?.dataset?.fragmentId;
  }`
})

// 4. Test manual fetch
await mcp__chrome-devtools__evaluate_script({
  function: `(fragmentId) => {
    return new Promise(resolve => {
      chrome.runtime.sendMessage({
        type: 'FETCH_FRAGMENT_DATA',
        data: { fragmentId }
      }, response => {
        resolve(response);
      });
    });
  }`,
  args: ['fragment-id-here']
})
```

### Scenario: Extension Works But Studio Link Fails

**Symptoms**: "Edit in Studio" button doesn't open correct page

**Debug Steps**:
```javascript
// 1. Check link generation
await mcp__chrome-devtools__evaluate_script({
  function: `(fragmentId, variant) => {
    return window.MASStudioLinker?.generateDeepLink(fragmentId, variant);
  }`,
  args: ['fragment-id', 'plans']
})

// 2. Verify variant-to-surface mapping
await mcp__chrome-devtools__evaluate_script({
  function: `() => window.MASStudioLinker?.variantToSurface`
})

// 3. Check for locale inference
await mcp__chrome-devtools__evaluate_script({
  function: `() => window.MASStudioLinker?.inferLocale()`
})
```

## Best Practices

### Do's
- Always take snapshot before clicking to get valid UIDs
- Check console errors first when debugging issues
- Verify network requests for API failures
- Use evaluate_script to access extension globals
- Wait for elements after navigation/clicks

### Don'ts
- Don't assume extension is loaded without checking
- Don't skip authentication verification
- Don't ignore CORS errors (they indicate service worker issues)
- Don't use hardcoded timeouts without reason

## Integration

### Works With
- `/debug-content-script` - Manual debugging guide
- `/debug-auth` - Authentication troubleshooting
- `/debug-message-flow` - Service worker communication

### Test Pages
```bash
# Navigate to test page
await mcp__chrome-devtools__navigate_page({
  type: 'url',
  url: 'https://www.adobe.com/creativecloud/plans.html'
})
```

## Quick Reference

### Essential Commands

```javascript
// Full extension health check
await mcp__chrome-devtools__evaluate_script({
  function: `() => ({
    detector: {
      active: !!window.MASCardDetector,
      cards: window.MASCardDetector?.detectedCards?.size || 0,
      observer: !!window.MASCardDetector?.observer
    },
    overlay: {
      active: !!window.MASCardOverlay,
      badges: window.MASCardOverlay?.badges?.size || 0,
      cache: window.MASCardOverlay?.fragmentDataCache?.size || 0
    },
    linker: {
      active: !!window.MASStudioLinker
    },
    dom: {
      merchCards: document.querySelectorAll('merch-card').length,
      badges: document.querySelectorAll('.mas-ext-badge').length,
      panels: document.querySelectorAll('.mas-ext-panel').length
    }
  })`
})
```

### Force Refresh Extension State

```javascript
// Re-detect all cards
await mcp__chrome-devtools__evaluate_script({
  function: `() => {
    window.MASCardDetector?.detectedCards?.clear();
    window.MASCardDetector?.detectExistingCards();
    return window.MASCardDetector?.detectedCards?.size;
  }`
})
```

### Clear Extension Cache

```javascript
// Clear fragment cache
await mcp__chrome-devtools__evaluate_script({
  function: `() => {
    window.MASCardOverlay?.fragmentDataCache?.clear();
    return 'Cache cleared';
  }`
})
```
