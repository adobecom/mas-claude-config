# MAS Studio UI Selectors Reference

Comprehensive selector reference for MAS Studio UI components. All components use light DOM (no Shadow DOM), making selectors work naturally.

## Component Hierarchy Overview

```
mas-studio (root)
├── mas-top-nav                    # Top navigation bar
│   ├── #brand                     # Logo/home link
│   ├── mas-nav-folder-picker      # Surface selector
│   ├── mas-nav-locale-picker      # Locale selector
│   └── .profile                   # User profile menu
├── mas-side-nav                   # Left sidebar
│   └── mas-side-nav-item          # Navigation items
├── mas-content                    # Main content area
│   ├── mas-toolbar                # Toolbar with actions
│   ├── mas-fragment               # Fragment cards/rows
│   └── merch-card                 # Card previews
├── mas-fragment-editor            # Fragment editor
│   ├── editor-panel               # Editor form
│   ├── variant-picker             # Variant selector
│   └── rte-field                  # Rich text editors
├── mas-toast                      # Toast notifications
└── sp-dialog-wrapper              # Modal dialogs
```

---

## Navigation Selectors (~15)

### Top Navigation

| Element | Selector | Notes |
|---------|----------|-------|
| Top nav container | `mas-top-nav` | Root nav element |
| Brand/logo | `#brand` | Adobe logo + title link |
| Brand logo SVG | `#logo` | SVG icon |
| Brand text | `#mas-studio` | "Merch At Scale Studio" |
| Surface picker | `mas-nav-folder-picker sp-action-menu` | Folder dropdown |
| Locale picker | `mas-nav-locale-picker sp-action-menu` | Locale dropdown |
| Help button | `.icon-button[title="Help"]` | Help icon |
| Notifications | `.icon-button[title="Notifications"]` | Bell icon |
| Profile button | `.profile-button` | User avatar button |
| Profile dropdown | `.profile-body` | Dropdown container |
| Profile dropdown open | `.profile-body.show` | When visible |
| User name | `.account-info h2` | Display name |
| User email | `.account-info p` | Email address |
| Manage account | `.account-info a` | Account link |
| Sign out | `.signout-link` | Logout link |

### Side Navigation

| Element | Selector | Notes |
|---------|----------|-------|
| Side nav container | `mas-side-nav` | Root sidebar |
| Nav items container | `.nav-items` | Items wrapper |
| Home | `mas-side-nav-item[label="Home"]` | Welcome page |
| Fragments | `mas-side-nav-item[label="Fragments"]` | Content list |
| Collections | `mas-side-nav-item[label="Collections"]` | Disabled |
| Promotions | `mas-side-nav-item[label="Promotions"]` | Disabled |
| Offers | `mas-side-nav-item[label="Offers"]` | Disabled |
| Placeholders | `mas-side-nav-item[label="Placeholders"]` | Placeholders page |
| Localization | `mas-side-nav-item[label="Localization"]` | Disabled |
| Support | `mas-side-nav-item[label="Support"]` | External link |

---

## Side Nav Actions - Edit Mode (~10)

When editing a fragment, side nav shows action buttons:

| Element | Selector | Notes |
|---------|----------|-------|
| Save | `mas-side-nav-item[label="Save"]` | Save changes |
| Create Variation | `mas-side-nav-item[label="Create Variation"]` | New variation |
| Duplicate | `mas-side-nav-item[label="Duplicate"]` | Clone fragment |
| Publish | `mas-side-nav-item[label="Publish"]` | Publish to live |
| Unpublish | `mas-side-nav-item[label="Unpublish"]` | Remove from live |
| Copy Code | `mas-side-nav-item[label="Copy Code"]` | Copy embed code |
| History | `mas-side-nav-item[label="History"]` | Version history |
| Unlock | `mas-side-nav-item[label="Unlock"]` | Unlock fragment |
| Delete | `mas-side-nav-item[label="Delete"]` | Delete fragment |

**Alternative Selectors** (from page objects):

| Element | Selector |
|---------|----------|
| Save button | `mas-side-nav mas-side-nav-item[label="Save"]` |
| Clone button | `mas-side-nav mas-side-nav-item[label="Duplicate"]` |
| Delete button | `mas-side-nav mas-side-nav-item[label="Delete"]` |

---

## Content Area Selectors (~20)

### Toolbar

| Element | Selector | Notes |
|---------|----------|-------|
| Toolbar | `mas-toolbar` | Actions bar |
| Search input | `#actions sp-search input` | Fragment search |
| Search icon | `#actions sp-search sp-icon-search` | Search button |
| Filter button | `sp-action-button[label="Filter"]` | Open filters |
| Render view | `sp-icon-view-grid-fluid` | Grid view toggle |
| Table view | `sp-icon-table` | Table view toggle |
| Create button | `sp-button:has-text("Create")` | New fragment |
| Copy button | `sp-button:has-text("Copy")` | Copy fragment |

### Quick Actions (Home Page)

| Element | Selector | Notes |
|---------|----------|-------|
| Quick actions container | `.quick-actions` | Home page cards |
| Go to Content card | `.quick-action-card[heading="Go to Content"]` | Navigate action |
| Recently updated | `.recently-updated` | Recent items |

### Fragment List

| Element | Selector | Notes |
|---------|----------|-------|
| Content container | `#content-container` | Main area |
| Fragment by ID | `.mas-fragment[data-id="${id}"]` | Render mode |
| Fragment wrapper | `mas-fragment` | Generic wrapper |
| Fragment render | `mas-fragment-render` | Card view |
| Fragment table | `mas-fragment-table` | Table row |
| Table row by ID | `sp-table-row[value="${id}"]` | Row element |
| Fragment status | `mas-fragment-status` | Status badge |
| Selection overlay | `.overlay` | Click overlay |
| AEM fragment | `aem-fragment[fragment="${id}"]` | Data element |
| Merch card | `merch-card` | Card component |

### Table View Specific

| Element | Selector | Notes |
|---------|----------|-------|
| Table | `sp-table` | Table container |
| Table row | `sp-table-row` | Row element |
| Name cell | `sp-table-cell.name` | Fragment name |
| Title cell | `sp-table-cell.title` | Title field |
| Status cell | `sp-table-cell.status` | Status column |
| Preview icon | `sp-table-cell.preview sp-icon-preview` | Preview button |

---

## Editor Panel Selectors (~35)

### Editor Container

| Element | Selector | Notes |
|---------|----------|-------|
| Editor container | `mas-fragment-editor` | Root element |
| Editor content | `#fragment-editor #editor-content` | Main panel |
| Alt selector | `mas-fragment-editor > #fragment-editor #editor-content` | More specific |
| Form column | `#form-column` | Left column |
| Preview column | `#preview-column` | Right column |
| Editor panel | `editor-panel` | Form container |
| Preview header | `.preview-header` | Preview title |
| Preview content | `.preview-content` | Preview area |
| Loading spinner | `sp-progress-circle` | Loading indicator |

### Variant & Style Pickers

| Element | Selector | Notes |
|---------|----------|-------|
| Variant picker | `#card-variant` | Variant dropdown |
| Variant picker alt | `variant-picker` | Component |
| Style picker | `#card-style` | Style dropdown |
| Size picker | `#card-size` | Size dropdown |

### Text Fields

| Element | Selector | Notes |
|---------|----------|-------|
| Author path | `#author-path` | AEM path |
| Title RTE | `rte-field#card-title div[contenteditable="true"]` | Rich text |
| Subtitle input | `#card-subtitle input` | Plain text |
| Badge input | `#card-badge input` | Badge text |
| Promo text | `#promo-text input` | Promotional text |
| Background image | `#background-image input` | Image URL |

### RTE Fields (Rich Text)

| Element | Selector | Notes |
|---------|----------|-------|
| Description RTE | `sp-field-group#description div[contenteditable="true"]` | Rich text |
| Short description | `rte-field#shortDescription div[contenteditable="true"]` | Rich text |
| Callout RTE | `sp-field-group#callout div[contenteditable="true"]` | Rich text |
| Callout field group | `sp-field-group#callout` | Container |
| Callout icon button | `sp-field-group#callout .icon-button` | Icon picker |

### Color Pickers

| Element | Selector | Notes |
|---------|----------|-------|
| Badge color | `sp-picker#badgeColor` | Badge bg color |
| Badge border | `sp-picker#badgeBorderColor` | Badge border |
| Border color | `sp-picker#border-color` | Card border |
| Background color | `sp-picker#backgroundColor` | Card background |

### Multi-field Components

| Element | Selector | Notes |
|---------|----------|-------|
| Prices field | `sp-field-group#prices` | Price container |
| CTAs field | `sp-field-group#ctas` | CTA buttons |
| CTA link | `sp-field-group#ctas a` | Individual CTA |
| CTA secondary | `sp-field-group#ctas a.secondary` | Secondary style |

### OSI (Offer Selector)

| Element | Selector | Notes |
|---------|----------|-------|
| OSI field | `osi-field#osi` | OSI component |
| OSI button | `#offerSelectorToolButtonOSI` | Open OST |
| OST button (RTE) | `#offerSelectorToolButton` | In RTE toolbar |

### Tags & Metadata

| Element | Selector | Notes |
|---------|----------|-------|
| Tags field | `aem-tag-picker-field[label="Tags"]` | Tag picker |

### Quantity Selector

| Element | Selector | Notes |
|---------|----------|-------|
| Show quantity | `#quantitySelect sp-checkbox input` | Toggle |
| Quantity title | `sp-field-group#quantitySelectorTitle #title-quantity input` | Label |
| Quantity start | `sp-field-group#quantitySelectorStart #start-quantity input` | Min value |
| Quantity step | `sp-field-group#quantitySelectorStep #step-quantity input` | Increment |

### What's Included

| Element | Selector | Notes |
|---------|----------|-------|
| Label | `#whatsIncludedLabel input` | Section label |
| Add icon | `#whatsIncluded sp-icon-add` | Add button |
| Icon URL | `#whatsIncluded #icon input` | Icon field |
| Icon label | `#whatsIncluded #text input` | Text field |
| Remove button | `#whatsIncluded sp-icon-close` | Delete item |

### Add-on Field

| Element | Selector | Notes |
|---------|----------|-------|
| Show add-on | `#addon-field #input` | Toggle |

---

## Mnemonic Modal Selectors (~15)

| Element | Selector | Notes |
|---------|----------|-------|
| Mnemonic field | `mas-mnemonic-field` | Field component |
| Edit button | `mas-mnemonic-field sp-action-button` | Open modal |
| Modal open | `mas-mnemonic-modal[open]` | Open state |
| Modal dialog | `mas-mnemonic-modal[open] sp-dialog` | Dialog container |
| Product tab | `mas-mnemonic-modal[open] sp-tab[value="product-icon"]` | Product picker |
| URL tab | `mas-mnemonic-modal[open] sp-tab[value="url"]` | URL input |
| Icon URL input | `mas-mnemonic-modal[open] #url-icon >> input` | Icon URL |
| Alt text input | `mas-mnemonic-modal[open] #url-alt >> input` | Alt text |
| Link input | `mas-mnemonic-modal[open] #url-link >> input` | Link URL |
| Product search | `mas-mnemonic-modal sp-search input` | Search field |
| Product list | `mas-mnemonic-modal .product-list` | Results |
| Icon item | `mas-mnemonic-modal[open] .icon-item:has-text("${name}")` | Product icon |
| Save button | `mas-mnemonic-modal[open] sp-button[variant="accent"]` | Save |
| Cancel button | `mas-mnemonic-modal[open] sp-button[variant="secondary"]` | Cancel |

---

## RTE Toolbar Selectors (~10)

| Element | Selector | Notes |
|---------|----------|-------|
| Link editor button | `#linkEditorButton` | Edit link |
| Add icon button | `#addIconButton` | Insert icon |
| OST button | `#offerSelectorToolButton` | Insert price |

### Link Editor Panel

| Element | Selector | Notes |
|---------|----------|-------|
| Checkout params | `#checkoutParameters input` | URL params |
| Link text | `#linkText input` | Display text |
| Analytics ID | `sp-picker#analyticsId` | Analytics |
| Phone tab | `#linkTypeNav sp-tab[value="phone"]` | Phone link |
| Phone number | `#phoneNumber input` | Phone input |
| Save link | `#saveButton` | Save changes |
| Link variant | `#linkVariant` | Button style |

### Link Variants

| Element | Selector |
|---------|----------|
| Accent | `sp-button[variant="accent"]` |
| Primary | `sp-button[variant="primary"]:not([treatment="outline"])` |
| Primary outline | `sp-button[variant="primary"][treatment="outline"]` |
| Secondary | `sp-button[variant="secondary"]:not([treatment="outline"])` |
| Secondary outline | `sp-button[variant="secondary"][treatment="outline"]` |
| Primary link | `sp-link:has-text("Primary link")` |
| Secondary link | `sp-link[variant="secondary"]` |

---

## Dialog Selectors (~15)

### Generic Dialogs

| Element | Selector | Notes |
|---------|----------|-------|
| Open dialog | `sp-dialog-wrapper[open]` | Any open dialog |
| Confirm dialog | `sp-dialog[variant="confirmation"]` | Confirmation type |
| Global confirm | `#global-confirm-dialog` | App-wide dialog |

### Dialog Actions

| Element | Selector | Notes |
|---------|----------|-------|
| Cancel button | `sp-button:has-text("Cancel")` | Cancel action |
| Delete button | `sp-button:has-text("Delete")` | Delete action |
| Discard button | `sp-button:has-text("Discard")` | Discard changes |
| Clone button | `sp-button:has-text("Clone")` | Clone action |
| Dialog input | `sp-dialog[variant="confirmation"] sp-textfield input` | Title input |

### Specific Dialogs

| Element | Selector | Notes |
|---------|----------|-------|
| Create dialog | `mas-create-dialog` | New fragment |
| Copy dialog | `mas-copy-dialog` | Copy fragment |
| Variation dialog | `mas-create-variation-dialog` | New variation |

### Dialog States

| Element | Selector | Notes |
|---------|----------|-------|
| Dialog with progress | `sp-dialog[variant="confirmation"] sp-button sp-progress-circle` | Loading |
| Discard confirm | `sp-dialog[variant="confirmation"] sp-button:has-text("Discard")` | In dialog |

---

## Toast Selectors (~5)

| Element | Selector | Notes |
|---------|----------|-------|
| Toast container | `mas-toast` | All toasts |
| Success toast | `mas-toast >> sp-toast[variant="positive"]` | Success message |
| Error toast | `mas-toast >> sp-toast[variant="negative"]` | Error message |
| Info toast | `mas-toast >> sp-toast[variant="info"]` | Progress/info |
| Any toast | `mas-toast >> sp-toast` | Generic |
| Non-info toast | `mas-toast >> sp-toast:not([variant="info"])` | Final result |

---

## Card Variant Selectors (~15)

### CCD Cards

| Element | Selector |
|---------|----------|
| CCD Suggested | `merch-card[variant="ccd-suggested"]` |
| CCD Slice | `merch-card[variant="ccd-slice"]` |
| CCD Slice Wide | `merch-card[variant="ccd-slice"][size="wide"]` |

### Adobe Home Cards

| Element | Selector |
|---------|----------|
| Try Buy Widget | `merch-card[variant="ah-try-buy-widget"]` |
| Try Buy Single | `merch-card[variant="ah-try-buy-widget"][size="single"]` |
| Try Buy Double | `merch-card[variant="ah-try-buy-widget"][size="double"]` |
| Try Buy Triple | `merch-card[variant="ah-try-buy-widget"][size="triple"]` |
| Promoted Plans | `merch-card[variant="ah-promoted-plans"]` |
| Promoted Gradient | `merch-card[variant="ah-promoted-plans"][gradient-border="true"]` |

### ACOM Cards

| Element | Selector |
|---------|----------|
| Plans | `merch-card[variant="plans"]` |
| Full Pricing Express | `merch-card[variant="full-pricing-express"]` |
| Catalog | `merch-card[variant="catalog"]` |
| Product | `merch-card[variant="product"]` |
| Segment | `merch-card[variant="segment"]` |
| Special Offers | `merch-card[variant="special-offers"]` |

### Commerce Cards

| Element | Selector |
|---------|----------|
| Fries | `merch-card[variant="fries"]` |
| TWP | `merch-card[variant="twp"]` |

### Card Content Slots

| Element | Selector | Notes |
|---------|----------|-------|
| Heading | `h3[slot="heading-xxxs"]` | Title slot |
| Body | `div[slot="body-xxs"]` | Description slot |
| Price | `span[data-template="price"] .price` | Price display |
| CTA container | `div[slot="cta"]` | Button area |
| CTA button | `div[slot="cta"] button` | Action button |
| Free trial | `div[slot="cta"] button[data-analytics-id="free-trial"]` | Trial CTA |

---

## Price Template Selectors (~5)

| Element | Selector | Notes |
|---------|----------|-------|
| Regular price | `span[is="inline-price"][data-template="price"]` | Standard |
| Strikethrough | `span[is="inline-price"][data-template="strikethrough"]` | Original |
| Promo strikethrough | `span[is="inline-price"][data-template="price"] > .price-strikethrough` | Discounted |
| Phone link | `a[href^="tel:"]` | Phone CTA |

---

## IMS Login Selectors (~8)

| Element | Selector | Notes |
|---------|----------|-------|
| Login form | `form[data-id="LoginForm"]` | Form container |
| Email input | `input[name="username"]` | Email field |
| Password input | `input[name="password"]` | Password field |
| Continue button | `button[data-id="EmailPage-ContinueButton"]` | After email |
| Sign in button | `button[data-id="PasswordPage-ContinueButton"]` | Submit login |

---

## Breadcrumb Selectors (~3)

| Element | Selector | Notes |
|---------|----------|-------|
| Breadcrumbs | `#breadcrumbs` | Container |
| Breadcrumb nav | `sp-breadcrumbs` | Navigation |
| Back to table | `sp-breadcrumb-item:has-text("Fragments table")` | Return link |
| Editor crumb | `sp-breadcrumb-item:has-text("Editor")` | Current |

---

## Usage Examples

### Find Fragment and Open Editor

```javascript
// Playwright
const fragment = await page.locator('.mas-fragment[data-id="abc-123"]');
await fragment.dblclick();
await page.locator('mas-fragment-editor').waitFor({ state: 'visible' });

// DevTools
await mcp__chrome-devtools__click({ uid: '.mas-fragment[data-id="abc-123"]', dblClick: true });
await mcp__chrome-devtools__wait_for({ text: 'variant' });
```

### Edit Title Field

```javascript
// Playwright
await mcp__playwright__browser_click({
  element: 'Title field',
  ref: 'rte-field#card-title div[contenteditable="true"]'
});
await mcp__playwright__browser_type({
  element: 'Title field',
  ref: 'rte-field#card-title div[contenteditable="true"]',
  text: 'New Title'
});

// DevTools
await mcp__chrome-devtools__fill({
  uid: 'rte-field#card-title div[contenteditable="true"]',
  value: 'New Title'
});
```

### Save Fragment

```javascript
// Playwright
await mcp__playwright__browser_click({
  element: 'Save button',
  ref: 'mas-side-nav-item[label="Save"]'
});
await mcp__playwright__browser_wait_for({ text: 'saved' });

// DevTools
await mcp__chrome-devtools__click({ uid: 'mas-side-nav-item[label="Save"]' });
await mcp__chrome-devtools__wait_for({ text: 'saved' });
```

### Check Toast Message

```javascript
// Playwright
const successToast = await page.locator('mas-toast >> sp-toast[variant="positive"]');
await expect(successToast).toBeVisible();

// DevTools - check via snapshot
await mcp__chrome-devtools__take_snapshot();
// Look for toast in snapshot output
```

---

## Notes

1. **Light DOM**: All MAS Studio components render in light DOM, so standard CSS selectors work
2. **Spectrum Components**: Use `sp-*` prefix for Adobe Spectrum Web Components
3. **Dynamic IDs**: Fragment IDs are UUIDs - use template literals `${id}`
4. **State Attributes**: Check `[disabled]`, `[open]`, `[selected]` for element states
5. **Playwright vs DevTools**: Both use same selectors, but DevTools uses `uid` parameter
