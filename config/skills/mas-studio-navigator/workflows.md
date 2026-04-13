# MAS Studio Navigator - Workflows

Step-by-step workflow patterns for navigating and interacting with MAS Studio using Playwright and Chrome DevTools MCPs.

## IMS Authentication

### Playwright MCP - Full Auth Flow

For fresh browser sessions requiring login:

```
1. Navigate to studio URL
   → mcp__playwright__browser_navigate({ url: 'http://localhost:3000/studio.html' })

2. Wait for IMS login page
   → mcp__playwright__browser_wait_for({ text: 'Sign in' })

3. Take snapshot to verify login form
   → mcp__playwright__browser_snapshot()

4. Fill email field (from .env IMS_EMAIL)
   → mcp__playwright__browser_type({
       element: 'Email input',
       ref: 'input[name="username"]',
       text: '<email>'
     })

5. Click Continue button
   → mcp__playwright__browser_click({
       element: 'Continue button',
       ref: 'button[data-id="EmailPage-ContinueButton"]'
     })

6. Wait for password page
   → mcp__playwright__browser_wait_for({ text: 'Enter your password' })

7. Fill password field (from .env IMS_PASS)
   → mcp__playwright__browser_type({
       element: 'Password input',
       ref: 'input[name="password"]',
       text: '<password>'
     })

8. Click Sign In button
   → mcp__playwright__browser_click({
       element: 'Sign In button',
       ref: 'button[data-id="PasswordPage-ContinueButton"]'
     })

9. Wait for studio to load
   → mcp__playwright__browser_wait_for({ text: 'MAS Studio' })
```

### Chrome DevTools MCP - Existing Session

When connecting to an already-authenticated Chrome session:

```
1. List available pages
   → mcp__chrome-devtools__list_pages()

2. Select the MAS Studio page (or navigate if needed)
   → mcp__chrome-devtools__select_page({ pageIdx: 0 })
   OR
   → mcp__chrome-devtools__navigate_page({ url: 'http://localhost:3000/studio.html' })

3. Take snapshot to verify auth state
   → mcp__chrome-devtools__take_snapshot()

4. If login required, user must authenticate manually in Chrome
```

## Page Navigation

### Sandbox Testing - Clear "Created By" Filter

**IMPORTANT**: When navigating to the sandbox environment, remember to remove the "created by" filter. This filter is automatically applied based on the current session user and will hide fragments created by other users or automation.

**Playwright:**
```
1. After navigating to sandbox, clear the "Created by" filter
   → mcp__playwright__browser_snapshot()  # Check for filter chips

2. If "Created by" filter exists, click to remove it
   → mcp__playwright__browser_click({
       element: 'Remove Created by filter',
       ref: 'sp-tag[value*="author"] sp-clear-button'
     })

3. Or click "Clear all" to remove all filters
   → mcp__playwright__browser_click({
       element: 'Clear all filters',
       ref: 'sp-action-button:has-text("Clear")'
     })
```

**DevTools:**
```
1. Take snapshot to see filter state
   → mcp__chrome-devtools__take_snapshot()

2. Click to remove "Created by" filter chip
   → mcp__chrome-devtools__click({ uid: '<filter-remove-uid>' })
```

### Navigate to Content Page

**Playwright:**
```
1. Navigate to content with path
   → mcp__playwright__browser_navigate({
       url: 'http://localhost:3000/studio.html#page=content&path=nala'
     })

2. Wait for content to load
   → mcp__playwright__browser_wait_for({ text: 'nala' })

3. Take snapshot
   → mcp__playwright__browser_snapshot()
```

**DevTools:**
```
1. Navigate page
   → mcp__chrome-devtools__navigate_page({
       url: 'http://localhost:3000/studio.html#page=content&path=nala'
     })

2. Wait for content
   → mcp__chrome-devtools__wait_for({ text: 'nala' })

3. Take snapshot
   → mcp__chrome-devtools__take_snapshot()
```

### Search for Fragment

**Playwright:**
```
1. Navigate to content page (if not already there)

2. Find and click search input
   → mcp__playwright__browser_click({
       element: 'Search input',
       ref: '#actions sp-search input'
     })

3. Type fragment ID
   → mcp__playwright__browser_type({
       element: 'Search input',
       ref: '#actions sp-search input',
       text: 'fragment-id-here'
     })

4. Wait for results
   → mcp__playwright__browser_wait_for({ text: 'fragment-id-here' })
```

**DevTools:**
```
1. Click search input
   → mcp__chrome-devtools__click({ uid: '<search-input-uid>' })

2. Fill search term
   → mcp__chrome-devtools__fill({
       uid: '<search-input-uid>',
       value: 'fragment-id-here'
     })

3. Wait for results
   → mcp__chrome-devtools__wait_for({ text: 'fragment-id-here' })
```

## Fragment Operations

### Select Fragment (Single Click)

**Playwright:**
```
1. Take snapshot to find fragment
   → mcp__playwright__browser_snapshot()

2. Click fragment card
   → mcp__playwright__browser_click({
       element: 'Fragment card',
       ref: '.mas-fragment[data-id="<fragment-id>"]'
     })

3. Verify selection (overlay appears)
   → mcp__playwright__browser_snapshot()
```

**DevTools:**
```
1. Take snapshot
   → mcp__chrome-devtools__take_snapshot()

2. Click fragment by uid
   → mcp__chrome-devtools__click({ uid: '<fragment-uid>' })
```

### Open Fragment Editor (Double Click)

**Playwright:**
```
1. Double-click fragment card
   → mcp__playwright__browser_click({
       element: 'Fragment card',
       ref: '.mas-fragment[data-id="<fragment-id>"]',
       doubleClick: true
     })

2. Wait for editor panel
   → mcp__playwright__browser_wait_for({ text: 'card-title' })

3. Take snapshot to see editor fields
   → mcp__playwright__browser_snapshot()
```

**DevTools:**
```
1. Double-click fragment
   → mcp__chrome-devtools__click({
       uid: '<fragment-uid>',
       dblClick: true
     })

2. Wait for editor
   → mcp__chrome-devtools__wait_for({ text: 'card-title' })

3. Take snapshot
   → mcp__chrome-devtools__take_snapshot()
```

### Save Fragment

**Playwright:**
```
1. Click Save button in side nav
   → mcp__playwright__browser_click({
       element: 'Save button',
       ref: 'mas-side-nav-item[label="Save"]'
     })

2. Wait for success toast
   → mcp__playwright__browser_wait_for({ text: 'Fragment saved' })

3. Check console for errors (optional)
   → mcp__playwright__browser_console_messages({ onlyErrors: true })
```

**DevTools:**
```
1. Click Save
   → mcp__chrome-devtools__click({ uid: '<save-button-uid>' })

2. Wait for toast
   → mcp__chrome-devtools__wait_for({ text: 'Fragment saved' })

3. Check console
   → mcp__chrome-devtools__list_console_messages({ types: ['error'] })
```

### Discard Changes

**Playwright:**
```
1. Click Discard button
   → mcp__playwright__browser_click({
       element: 'Discard button',
       ref: 'mas-side-nav-item[label="Discard"]'
     })

2. Wait for confirmation dialog
   → mcp__playwright__browser_wait_for({ text: 'Discard changes' })

3. Click confirm Discard button
   → mcp__playwright__browser_click({
       element: 'Confirm Discard',
       ref: 'sp-dialog sp-button:has-text("Discard")'
     })

4. Wait for editor to close or reset
   → mcp__playwright__browser_snapshot()
```

### Duplicate Fragment

**Playwright:**
```
1. Open fragment editor (double-click)

2. Click Duplicate button
   → mcp__playwright__browser_click({
       element: 'Duplicate button',
       ref: 'mas-side-nav-item[label="Duplicate"]'
     })

3. Wait for clone dialog
   → mcp__playwright__browser_wait_for({ text: 'Clone' })

4. Fill new title (optional)
   → mcp__playwright__browser_type({
       element: 'Clone title input',
       ref: 'sp-dialog sp-textfield input',
       text: 'New Fragment Title'
     })

5. Click Clone button
   → mcp__playwright__browser_click({
       element: 'Clone confirm',
       ref: 'sp-button:has-text("Clone")'
     })

6. Wait for success
   → mcp__playwright__browser_wait_for({ text: 'cloned successfully' })
```

### Delete Fragment

**Playwright:**
```
1. Open fragment editor

2. Click Delete button
   → mcp__playwright__browser_click({
       element: 'Delete button',
       ref: 'mas-side-nav-item[label="Delete"]'
     })

3. Wait for confirmation dialog
   → mcp__playwright__browser_wait_for({ text: 'Delete fragment' })

4. Click confirm Delete
   → mcp__playwright__browser_click({
       element: 'Confirm Delete',
       ref: 'sp-button:has-text("Delete")'
     })

5. Wait for deletion
   → mcp__playwright__browser_wait_for({ text: 'deleted' })
```

## Form Field Editing

### Edit Text Field (Simple Input)

**Playwright:**
```
1. Clear existing text and type new value
   → mcp__playwright__browser_type({
       element: 'Subtitle field',
       ref: '#card-subtitle input',
       text: 'New Subtitle'
     })
```

**DevTools:**
```
1. Fill field
   → mcp__chrome-devtools__fill({
       uid: '<subtitle-input-uid>',
       value: 'New Subtitle'
     })
```

### Edit RTE Field (Rich Text)

**Playwright:**
```
1. Click RTE container to focus
   → mcp__playwright__browser_click({
       element: 'Title RTE',
       ref: 'rte-field#card-title div[contenteditable="true"]'
     })

2. Select all text
   → mcp__playwright__browser_press_key({ key: 'Control+a' })

3. Type new content
   → mcp__playwright__browser_type({
       element: 'Title RTE',
       ref: 'rte-field#card-title div[contenteditable="true"]',
       text: 'New Title Text'
     })
```

### Select Dropdown Option (Picker)

**Playwright:**
```
1. Click picker to open
   → mcp__playwright__browser_click({
       element: 'Variant picker',
       ref: '#card-variant'
     })

2. Wait for menu
   → mcp__playwright__browser_wait_for({ text: 'ccd-suggested' })

3. Click option
   → mcp__playwright__browser_click({
       element: 'Variant option',
       ref: 'sp-menu-item[value="ccd-suggested"]'
     })
```

**DevTools:**
```
1. Click picker
   → mcp__chrome-devtools__click({ uid: '<variant-picker-uid>' })

2. Click option
   → mcp__chrome-devtools__click({ uid: '<option-uid>' })
```

### Edit Mnemonic (Icon)

**Playwright:**
```
1. Click mnemonic edit button
   → mcp__playwright__browser_click({
       element: 'Mnemonic edit button',
       ref: 'mas-mnemonic-field sp-action-button'
     })

2. Wait for modal
   → mcp__playwright__browser_wait_for({ text: 'Select product' })

3. Search for product
   → mcp__playwright__browser_type({
       element: 'Product search',
       ref: 'mas-mnemonic-modal sp-search input',
       text: 'Photoshop'
     })

4. Click product in list
   → mcp__playwright__browser_click({
       element: 'Product item',
       ref: 'mas-mnemonic-modal .product-item:has-text("Photoshop")'
     })

5. Click Save/Apply
   → mcp__playwright__browser_click({
       element: 'Save mnemonic',
       ref: 'mas-mnemonic-modal sp-button[variant="accent"]'
     })
```

## Debugging Workflows

### Check Console Errors

**Playwright:**
```
1. Get error messages
   → mcp__playwright__browser_console_messages({ onlyErrors: true })
```

**DevTools:**
```
1. List console messages
   → mcp__chrome-devtools__list_console_messages({
       types: ['error', 'warn']
     })

2. Get specific message details
   → mcp__chrome-devtools__get_console_message({ msgid: <id> })
```

### Inspect Network Requests

**DevTools (preferred):**
```
1. List network requests
   → mcp__chrome-devtools__list_network_requests({
       resourceTypes: ['fetch', 'xhr']
     })

2. Get request details
   → mcp__chrome-devtools__get_network_request({ reqid: <id> })
```

**Playwright:**
```
1. Get network requests
   → mcp__playwright__browser_network_requests()
```

### Evaluate JavaScript in Page

**Playwright:**
```
→ mcp__playwright__browser_evaluate({
    function: `() => {
      const AemFragment = customElements.get('aem-fragment');
      return AemFragment?.cache?.size || 0;
    }`
  })
```

**DevTools:**
```
→ mcp__chrome-devtools__evaluate_script({
    function: `() => {
      const store = document.querySelector('mas-studio')?.store;
      return {
        page: store?.page?.value,
        path: store?.path?.value,
        selectedId: store?.selectedFragmentId?.value
      };
    }`
  })
```

### Performance Profiling

**DevTools:**
```
1. Start trace with reload
   → mcp__chrome-devtools__performance_start_trace({
       reload: true,
       autoStop: true
     })

2. (After trace completes) Analyze insights
   → mcp__chrome-devtools__performance_analyze_insight({
       insightSetId: '<insight-set-id>',
       insightName: 'LCPBreakdown'
     })
```

## Multi-Tab Workflows

### Open New Tab

**Playwright:**
```
1. Open new tab
   → mcp__playwright__browser_tabs({ action: 'new' })

2. Navigate in new tab
   → mcp__playwright__browser_navigate({
       url: 'http://localhost:3000/studio.html#page=placeholders'
     })
```

**DevTools:**
```
1. Create new page
   → mcp__chrome-devtools__new_page({
       url: 'http://localhost:3000/studio.html#page=placeholders'
     })
```

### Switch Between Tabs

**Playwright:**
```
1. List tabs
   → mcp__playwright__browser_tabs({ action: 'list' })

2. Select tab by index
   → mcp__playwright__browser_tabs({ action: 'select', index: 0 })
```

**DevTools:**
```
1. List pages
   → mcp__chrome-devtools__list_pages()

2. Select page
   → mcp__chrome-devtools__select_page({ pageIdx: 0 })
```

## Screenshot and Snapshot Workflows

### Take Screenshot

**Playwright:**
```
→ mcp__playwright__browser_take_screenshot({
    filename: 'studio-state.png',
    fullPage: true
  })
```

**DevTools:**
```
→ mcp__chrome-devtools__take_screenshot({
    filePath: '/tmp/studio-state.png',
    fullPage: true
  })
```

### Take Accessibility Snapshot

**Playwright (preferred for a11y):**
```
→ mcp__playwright__browser_snapshot()
```

**DevTools:**
```
→ mcp__chrome-devtools__take_snapshot({ verbose: true })
```

## Common URL Patterns

| Page | URL |
|------|-----|
| Home/Welcome | `http://localhost:3000/studio.html#page=welcome` |
| Content (nala) | `http://localhost:3000/studio.html#page=content&path=nala` |
| Content (sandbox) | `http://localhost:3000/studio.html#page=content&path=sandbox` |
| Content with search | `http://localhost:3000/studio.html#page=content&path=nala&query=<id>` |
| Placeholders | `http://localhost:3000/studio.html#page=placeholders` |
| With milolibs | `http://localhost:3000/studio.html?milolibs=local#page=content&path=nala` |
