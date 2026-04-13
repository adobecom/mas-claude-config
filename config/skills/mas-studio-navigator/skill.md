---
name: MAS Studio Navigator
description: Navigate and interact with MAS Studio UI using Playwright and Chrome DevTools MCPs. Handles page navigation, fragment operations (select, open, edit, save, discard), form field editing, dialogs, network inspection, console debugging, and performance analysis. Use when navigating studio, editing fragments, debugging UI issues, or automating workflows. Activates on "navigate studio", "open studio", "click", "fill field", "open fragment", "edit fragment", "save fragment", "debug studio", "inspect console", "check network".
tags: [studio, playwright, chrome-devtools, ui, navigation, automation, debugging, fragments, editor]
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - mcp__playwright__browser_navigate
  - mcp__playwright__browser_click
  - mcp__playwright__browser_type
  - mcp__playwright__browser_snapshot
  - mcp__playwright__browser_wait_for
  - mcp__playwright__browser_hover
  - mcp__playwright__browser_fill_form
  - mcp__playwright__browser_evaluate
  - mcp__playwright__browser_take_screenshot
  - mcp__playwright__browser_console_messages
  - mcp__playwright__browser_select_option
  - mcp__playwright__browser_press_key
  - mcp__playwright__browser_close
  - mcp__playwright__browser_tabs
  - mcp__playwright__browser_network_requests
  - mcp__chrome-devtools__navigate_page
  - mcp__chrome-devtools__take_snapshot
  - mcp__chrome-devtools__take_screenshot
  - mcp__chrome-devtools__click
  - mcp__chrome-devtools__fill
  - mcp__chrome-devtools__hover
  - mcp__chrome-devtools__press_key
  - mcp__chrome-devtools__wait_for
  - mcp__chrome-devtools__evaluate_script
  - mcp__chrome-devtools__list_console_messages
  - mcp__chrome-devtools__get_console_message
  - mcp__chrome-devtools__list_network_requests
  - mcp__chrome-devtools__get_network_request
  - mcp__chrome-devtools__performance_start_trace
  - mcp__chrome-devtools__performance_stop_trace
  - mcp__chrome-devtools__performance_analyze_insight
  - mcp__chrome-devtools__list_pages
  - mcp__chrome-devtools__select_page
---

# MAS Studio Navigator

## Purpose

Navigate and interact with MAS Studio UI using browser automation MCPs. This skill provides:
- UI navigation workflows for both Playwright and Chrome DevTools MCPs
- Comprehensive selector references for all MAS Studio components
- Fragment operations (create, edit, save, discard, clone, delete)
- Debugging capabilities (console, network, performance)
- IMS authentication support

## When to Activate

### Automatic Triggers
- User mentions "navigate", "go to", "open" with studio context
- User wants to "click", "fill", "type" in studio UI
- User mentions "open fragment", "edit card", "save changes"
- User asks to "debug", "inspect", "check console/network"
- User provides MAS Studio URL for interaction

### Explicit Activation
- "navigate to studio"
- "open fragment editor"
- "click the save button"
- "fill the title field"
- "debug studio UI"
- "check console errors"
- "inspect network requests"

## MCP Selection Decision Logic

Choose the appropriate MCP based on the scenario:

| Scenario | Recommended MCP | Reason |
|----------|-----------------|--------|
| Launch new browser session | **Playwright** | Fresh isolated context |
| Connect to existing Chrome | **DevTools** | Preserves user session/auth |
| Multi-step form automation | **Playwright** | Reliable sequential actions |
| Inspect network requests | **DevTools** | Built-in network panel |
| Debug console errors | **DevTools** | Full console access |
| Performance profiling | **DevTools** | Trace recording |
| Take accessibility snapshot | **Playwright** | Better a11y tree |
| Scripted test-like workflows | **Playwright** | Test automation patterns |
| Real-time debugging | **DevTools** | Live inspection |

### Decision Tree

```
Is user already logged into Chrome with MAS Studio open?
├── YES → Use Chrome DevTools MCP
│   └── Preserves auth, connects to existing session
└── NO → Use Playwright MCP
    └── Fresh browser, handle auth flow

Is task automation or debugging?
├── AUTOMATION (fill forms, click buttons, navigate)
│   └── Use Playwright MCP (more reliable for sequential actions)
└── DEBUGGING (inspect DOM, console, network)
    └── Use Chrome DevTools MCP (better inspection tools)

Does task require network/console inspection?
├── YES → Use Chrome DevTools MCP
└── NO → Either MCP works, prefer Playwright for automation
```

## Core Workflows

See `workflows.md` for detailed step-by-step workflows covering:
- IMS Authentication
- Page Navigation
- Fragment Operations (CRUD)
- Form Field Editing
- Dialog Handling
- Debugging Scenarios

## Selector Reference

See `selectors.md` for comprehensive UI selectors organized by:
- Navigation (top nav, side nav)
- Content Area (fragments, toolbar)
- Editor Panel (fields, pickers)
- Dialogs and Toasts
- Card Variants
- IMS Login

## Troubleshooting

See `troubleshooting.md` for decision trees covering:
- Element not found issues
- Authentication failures
- Network request errors
- Save/publish failures

## Quick Reference

### Playwright MCP - Common Operations

```javascript
// Navigate to studio
await mcp__playwright__browser_navigate({
  url: 'http://localhost:3000/studio.html#page=content&path=nala'
});

// Take snapshot (better than screenshot for understanding state)
await mcp__playwright__browser_snapshot();

// Click element
await mcp__playwright__browser_click({
  element: 'Fragment card',
  ref: '.mas-fragment[data-id="abc-123"]'
});

// Double-click to open editor
await mcp__playwright__browser_click({
  element: 'Fragment card',
  ref: '.mas-fragment[data-id="abc-123"]',
  doubleClick: true
});

// Fill text field
await mcp__playwright__browser_type({
  element: 'Title field',
  ref: 'rte-field#card-title div[contenteditable="true"]',
  text: 'New Title'
});

// Wait for element
await mcp__playwright__browser_wait_for({
  text: 'Fragment saved successfully'
});

// Check console errors
await mcp__playwright__browser_console_messages({
  onlyErrors: true
});
```

### Chrome DevTools MCP - Common Operations

```javascript
// Navigate (if user has Chrome open)
await mcp__chrome-devtools__navigate_page({
  url: 'http://localhost:3000/studio.html#page=content&path=nala'
});

// Take snapshot (shows uid for elements)
await mcp__chrome-devtools__take_snapshot();

// Click element by uid
await mcp__chrome-devtools__click({
  uid: 'mas-side-nav-item[label="Save"]'
});

// Fill field
await mcp__chrome-devtools__fill({
  uid: '#card-subtitle',
  value: 'New Subtitle'
});

// Check console messages
await mcp__chrome-devtools__list_console_messages({
  types: ['error', 'warn']
});

// Check network requests
await mcp__chrome-devtools__list_network_requests({
  resourceTypes: ['fetch', 'xhr']
});

// Evaluate JavaScript in page
await mcp__chrome-devtools__evaluate_script({
  function: `() => {
    const AemFragment = customElements.get('aem-fragment');
    return AemFragment?.cache?.size || 0;
  }`
});

// Performance trace
await mcp__chrome-devtools__performance_start_trace({
  reload: true,
  autoStop: true
});
```

## Integration with Other Skills

Works with:
- **nala-runner**: Uses same selectors for test automation
- **studio-fragment-debugger**: Deep fragment debugging
- **mas-mcp-tester**: Validate MCP operations
- **mas-aem-integration**: Fragment CRUD operations

## Best Practices

### DO:
- Always take a snapshot before complex interactions
- Use `wait_for` before clicking on dynamic elements
- Check console errors after failed operations
- Verify toast messages for operation success/failure
- Use descriptive element names in click operations

### DON'T:
- Assume page state without snapshot
- Click without verifying element exists
- Ignore error toasts
- Skip authentication check for protected pages
- Use hard-coded timeouts (use wait_for instead)

## MAS Studio URL Patterns

```
# Home page
http://localhost:3000/studio.html#page=welcome

# Content/Fragments list
http://localhost:3000/studio.html#page=content&path=nala

# Fragment search
http://localhost:3000/studio.html#page=content&path=nala&query=<fragment-id>

# Fragment editor
http://localhost:3000/studio.html#page=content&path=nala&query=<fragment-id>
# Then double-click card to open editor

# Placeholders
http://localhost:3000/studio.html#page=placeholders

# With milolibs
http://localhost:3000/studio.html?milolibs=local#page=content&path=nala
```

## Authentication

MAS Studio requires IMS authentication. See `workflows.md` for auth flow details.

**Credentials Source**: `.env` file
- `IMS_EMAIL`: Adobe test account email
- `IMS_PASS`: Adobe test account password

**Playwright**: Handle full auth flow (navigate, fill, submit)
**DevTools**: Connect to already-authenticated Chrome session
