---
name: maslibs-parameter-guide
version: 1.0.0
description: Comprehensive guide for using the maslibs URL parameter to test MAS web component changes locally and from feature branches. Use when testing local MAS changes, debugging components, or validating feature branches.
activationPhrases:
  - "maslibs parameter"
  - "test mas locally"
  - "local mas components"
  - "test mas branch"
  - "maslibs=local"
  - "how to test mas changes"
  - "mas web components testing"
  - "test web-components locally"
  - "debug mas component"
location: project
---

# maslibs Parameter Guide

## Overview
The `maslibs` URL parameter controls which version of MAS (Merch at Scale) web components to load on a page.

**CRITICAL**: Use `maslibs` for MAS components, NOT `milolibs`
- `?maslibs=...` → MAS web components (from mas repo at `/web-components`)
- `?milolibs=...` → Other Milo features (from milo repo only)

This replaces the previous pattern where Milo was the canonical source for MAS. After migration (MWPW-183304), the MAS repo is now the primary source.

---

## Syntax

### Basic Format
```
?maslibs=<value>
```

### Valid Values

**1. Local Development**
```
?maslibs=local
```
- Loads from: `http://localhost:3030/studio/libs/fragment-client.js`
- Requires: Port 3030 running (MAS dev server)
- Use for: Testing local changes to MAS components

**2. Feature Branch (short format)**
```
?maslibs=BRANCH-NAME
```
- Example: `?maslibs=MWPW-12345`
- Loads from: `https://MWPW-12345--mas--adobecom.aem.live/studio/libs/fragment-client.js`
- Use for: Testing PR changes before merge

**3. Full Branch Format**
```
?maslibs=BRANCH--REPO--OWNER
```
- Example: `?maslibs=main--mas--adobecom`
- Loads from: `https://BRANCH--REPO--OWNER.aem.live/studio/libs/fragment-client.js`
- Use for: Custom branch deployments

**4. Production (default)**
```
(no parameter)
```
- Loads from: `https://mas.adobe.com/studio/libs/fragment-client.js`
- Use for: Production environment

---

## Implementation Details

### How maslibs Works

**Location**: `__MAS_DIR__/web-components/src/aem-fragment.js` (lines 442-465)

The `getFragmentClientUrl()` method in the AEM Fragment component handles URL parameter parsing:

```javascript
getFragmentClientUrl() {
    const urlParams = new URLSearchParams(window.location.search);
    const masLibs = urlParams.get('maslibs');

    // Production (no parameter or empty)
    if (!masLibs || masLibs.trim() === '') {
        return 'https://mas.adobe.com/studio/libs/fragment-client.js';
    }

    const sanitizedMasLibs = masLibs.trim().toLowerCase();

    // Local development
    if (sanitizedMasLibs === 'local') {
        return 'http://localhost:3030/studio/libs/fragment-client.js';
    }

    // Detect .page vs .live domain
    const { hostname } = window.location;
    const extension = hostname.endsWith('.page') ? 'page' : 'live';

    // Full branch format (contains --)
    if (sanitizedMasLibs.includes('--')) {
        return `https://${sanitizedMasLibs}.aem.${extension}/studio/libs/fragment-client.js`;
    }

    // Short branch format (assumes mas repo, adobecom owner)
    return `https://${sanitizedMasLibs}--mas--adobecom.aem.${extension}/studio/libs/fragment-client.js`;
}
```

**Key Logic**:
1. Reads `maslibs` parameter from URL query string
2. Matches against known values (local, branch names, full format)
3. Constructs the correct fragment-client.js URL
4. Automatically detects .page vs .live domain suffix

---

## Common Use Cases

### 1. Testing Local MAS Changes

**Scenario**: You modified a variant in `/web-components/src/variants/`

**Steps**:
1. Ensure port 3030 is running:
   ```bash
   cd __MAS_DIR__/web-components
   npm run dev
   ```

2. Verify port is active:
   ```bash
   lsof -i :3030
   ```

3. Add `?maslibs=local` to any Adobe page URL

4. Example URLs:
   ```
   https://www.adobe.com/creativecloud/plans.html?maslibs=local
   https://adobe.com/products/photoshop/pricing.html?maslibs=local
   https://www.adobe.com/creativecloud/collections/adobe-creative-cloud.html?maslibs=local
   ```

5. Verify in browser:
   - Open DevTools → Network tab
   - Reload page
   - Look for `fragment-client.js` loading from `localhost:3030`
   - Should see your changes reflected immediately

**Expected Result**: Page loads your local MAS components instead of production

---

### 2. Testing Feature Branch Before Merge

**Scenario**: PR #450 with branch `MWPW-12345` adds new variant

**Steps**:
1. Push branch to GitHub (make sure it's in mas repo, not milo)
2. Wait for AEM deployment (2-3 minutes):
   - Branch gets deployed to `https://MWPW-12345--mas--adobecom.aem.live`
   - Verify deployment status in Adobe's deployment system

3. Add `?maslibs=MWPW-12345` to test page

4. Example:
   ```
   https://www.adobe.com/creativecloud/plans.html?maslibs=MWPW-12345
   ```

5. Verify your changes loaded:
   - New variant should render correctly
   - New fields should be available in editor
   - Prices and CTAs should work

**Expected Result**: Page loads components from your feature branch

---

### 3. Combining with milolibs (Testing Both)

**Scenario**: Testing MAS changes alongside Milo feature changes

**URL**:
```
?milolibs=local&maslibs=local
```

**Example URLs**:
```
https://www.adobe.com/creativecloud/plans.html?milolibs=local&maslibs=local
https://adobe.com/products/express/pricing.html?milolibs=MWPW-99999&maslibs=MWPW-12345
```

**Expected Result**:
- Milo features load from Milo's local development server (different port)
- MAS components load from localhost:3030
- Both work together on the same page

**Parameter Syntax**:
```
✓ Correct: ?milolibs=local&maslibs=local  (use &)
✗ Wrong:   ?milolibs=local?maslibs=local  (don't use ?)
✗ Wrong:   milolibs=local maslibs=local   (separate with &)
```

---

### 4. Testing Multiple Branches

**Scenario**: You have a PR in both mas and milo repos

**URL**:
```
?milolibs=BRANCH1--milo--adobecom&maslibs=BRANCH2--mas--adobecom
```

**Example**:
```
https://www.adobe.com/creativecloud/plans.html?milolibs=MWPW-99999--milo--adobecom&maslibs=MWPW-12345--mas--adobecom
```

---

## NALA Test Integration

### Environment Variables

**MILO_LIBS**: Despite the legacy name, can contain either milolibs OR maslibs parameter

**MAS_LIBS**: Can also be used for maslibs-specific parameter (clearer naming)

### Example Test Commands

**Test with local MAS:**
```bash
LOCAL_TEST_LIVE_URL="http://localhost:3000" MILO_LIBS="?maslibs=local" npx playwright test nala/studio/merch-card/...
```

**Test with feature branch:**
```bash
LOCAL_TEST_LIVE_URL="https://MWPW-12345--mas--adobecom.aem.live" MILO_LIBS="?maslibs=MWPW-12345" npx playwright test nala/studio/...
```

**Test with both local milo and mas:**
```bash
LOCAL_TEST_LIVE_URL="http://localhost:3000" MILO_LIBS="?milolibs=local&maslibs=local" npx playwright test nala/studio/...
```

### Test Helper Functions

**Location**: `__MAS_DIR__/nala/utils/commerce.js` (lines 189-195)

```javascript
const MILO_LIBS = process.env.MILO_LIBS || '';
const MAS_LIBS = process.env.MAS_LIBS || '';

function constructTestUrl(baseURL, path, browserParams = '') {
    let fullUrl = `${baseURL}${path}`;
    fullUrl = addUrlQueryParams(fullUrl, browserParams);
    fullUrl = addUrlQueryParams(fullUrl, MILO_LIBS);  // Adds milolibs parameter
    fullUrl = addUrlQueryParams(fullUrl, MAS_LIBS);   // Adds maslibs parameter
    return fullUrl;
}
```

**Key Files**:
- `__MAS_DIR__/nala/utils/nala.run.js` - Test runner configuration
- `__MAS_DIR__/nala/utils/commerce.js` - URL construction helpers
- `__MAS_DIR__/nala/libs/mas-test.js` - MAS-specific test utilities

---

## Local Development Setup

### Prerequisites

**Port 3030**: MAS build server must be running

### Check if Running

```bash
lsof -i :3030
```

If shows process, port is active. If empty, port is available.

### Start MAS Dev Server

```bash
cd __MAS_DIR__/web-components
npm install  # if first time
npm run dev
```

Or use the project's npm script:
```bash
cd __MAS_DIR__
npm run dev:web-components
```

### Verify Server is Running

1. Check port:
   ```bash
   lsof -i :3030
   ```

2. Test connectivity:
   ```bash
   curl http://localhost:3030/studio/libs/fragment-client.js | head -20
   ```

3. Should see JavaScript code (minified or readable depending on build mode)

---

## Troubleshooting

### Issue: maslibs=local not working

**Symptoms**:
- Browser console shows 404 error for fragment-client.js
- Components not loading
- "Cannot GET /studio/libs/fragment-client.js"

**Solution**:
1. Is port 3030 running?
   ```bash
   lsof -i :3030
   ```
   If not: `cd /web-components && npm run dev`

2. Is URL parameter spelled correctly?
   - ✓ Correct: `?maslibs=local`
   - ✗ Wrong: `?maslib=local` (typo)
   - ✗ Wrong: `?maslibs=LOCAL` (case)

3. Check browser console:
   - Open DevTools (F12)
   - Go to Network tab
   - Reload page
   - Look for fragment-client.js
   - Click it and check response

4. Check MAS dev server logs:
   - Look for errors in terminal where `npm run dev` is running
   - Check if on correct port (3030)
   - Check if watching for file changes

---

### Issue: Branch parameter not loading

**Symptoms**:
- Gets 404 or "deployment not found"
- Components don't load from branch

**Solution**:
1. Has branch been deployed to AEM?
   - Check: `https://BRANCH--mas--adobecom.aem.live` in browser
   - Should load without errors
   - If 404, deployment in progress (wait 2-3 minutes)

2. Is branch name correct?
   - Parameter is case-sensitive
   - Use exact branch name: `?maslibs=MWPW-12345` (not `mwpw-12345`)
   - Don't include `--mas--adobecom` in parameter (auto-added)

3. Check domain suffix:
   - `.aem.live` for staging
   - `.aem.page` for preview
   - Browser usually auto-detects based on current domain

4. Wait for AEM deployment:
   - First push takes 3-5 minutes
   - Subsequent updates take 1-2 minutes
   - Check deployment status in GitHub Actions

---

### Issue: Both milolibs and maslibs not working together

**Symptoms**:
- Only one parameter works
- Both show 404 errors
- Milo OR MAS loads, but not both

**Solution**:
1. Check parameter syntax:
   - ✓ Correct: `?milolibs=local&maslibs=local` (use &)
   - ✗ Wrong: `?milolibs=local?maslibs=local` (use ? only once)
   - ✗ Wrong: `milolibs=local maslibs=local` (no space)

2. Check both ports running:
   ```bash
   lsof -i :3000   # Milo proxy
   lsof -i :3030   # MAS server
   ```
   Both should show running process

3. Check browser console for errors:
   - One 404 might be blocking the other
   - Fix the first issue, then check second

4. Test individually first:
   - Test just `?maslibs=local`
   - Test just `?milolibs=local`
   - Then combine with `&`

---

### Issue: Fragment client loading but components don't render

**Symptoms**:
- Network shows fragment-client.js loaded (200)
- But merch-card doesn't render
- Console shows JavaScript errors

**Solution**:
1. Check for JavaScript errors:
   - Open DevTools → Console
   - Look for red error messages
   - Check if related to component initialization

2. Check local build is complete:
   ```bash
   cd /web-components
   npm run build
   ```

3. Verify correct fragment client URL:
   - In DevTools → Network
   - Find fragment-client.js request
   - Click it
   - Check "Request URL" matches expected URL
   - Check response is valid JavaScript

4. Check AEM fragment exists:
   - Fragment-client.js depends on AEM having fragment data
   - Without fragment model, component may fail silently
   - Verify fragment path in browser console

---

## When to Use maslibs vs milolibs

### Use `?maslibs=...`
- Testing MAS web component changes (merch-card, variants, etc.)
- Testing fragment-client.js modifications
- Testing commerce service changes
- Testing price rendering changes
- Testing OSI (offer selection interface) changes
- Testing any code in `/web-components/` directory
- Testing new variants in `/web-components/src/variants/`

### Use `?milolibs=...`
- Testing Milo block changes (accordion, table, etc.)
- Testing Milo global navigation changes
- Testing Milo header/footer changes
- Testing other non-MAS Milo features
- Testing code in `__ADOBE_DIR__/milo/libs/` (excluding mas)

### Use Both
- When testing integration between MAS components and Milo features
- Example: Testing MAS card inside a Milo marquee block
- Example: Testing MAS component inside Milo accordion
- Example: Testing MAS price display with Milo commerce blocks

---

## URL Construction Examples

### Single Component Testing
```
https://www.adobe.com/creativecloud/plans.html?maslibs=local
```

### Multiple Parameters
```
https://www.adobe.com/creativecloud/plans.html?maslibs=local&utm_source=test&utm_medium=local
```

### With Milo
```
https://www.adobe.com/creativecloud/plans.html?milolibs=local&maslibs=local
```

### Feature Branch Testing
```
https://www.adobe.com/creativecloud/plans.html?maslibs=MWPW-12345
```

### Mixed Local and Branch
```
https://www.adobe.com/creativecloud/plans.html?milolibs=MWPW-99999&maslibs=local
```

### Production (no parameters)
```
https://www.adobe.com/creativecloud/plans.html
```

---

## Quick Reference Table

| Scenario | Parameter | URL Example |
|----------|-----------|-------------|
| Local MAS dev | `?maslibs=local` | `adobe.com/plans.html?maslibs=local` |
| Feature branch | `?maslibs=BRANCH` | `adobe.com/plans.html?maslibs=MWPW-123` |
| Local Milo dev | `?milolibs=local` | `adobe.com/plans.html?milolibs=local` |
| Both local | `?milolibs=local&maslibs=local` | `adobe.com/plans.html?milolibs=local&maslibs=local` |
| Production | (no params) | `adobe.com/plans.html` |
| Branch to branch | `?milolibs=BR1&maslibs=BR2` | `adobe.com/plans.html?milolibs=MWPW-99999&maslibs=MWPW-12345` |

---

## Related Documentation

- **maslibs Implementation**: `__MAS_DIR__/web-components/src/aem-fragment.js:442-465`
- **NALA Test Integration**: `__MAS_DIR__/nala/utils/commerce.js:189-195`
- **GitHub Actions**: `/.github/workflows/run-milo-nala-maslibs.yml`
- **MAS Migration**: MWPW-183304 (migration from Milo to MAS repo)
- **Variant Registry**: See [card-variant-registry skill](../card-variant-registry/skill.md)
- **Fragment Client**: `__MAS_DIR__/web-components/src/aem-fragment.js`

---

## Key Differences: Old vs New

### Before Migration (Old Pattern)
- MAS source: `__ADOBE_DIR__/milo/libs/features/mas` (outdated)
- Used: `?milolibs=...` for all component testing
- Testing pattern: Same milolibs parameter for everything

### After Migration (Current Pattern)
- MAS source: `__MAS_DIR__/web-components` (canonical)
- Use: `?maslibs=...` for MAS components
- Use: `?milolibs=...` for non-MAS Milo features
- Testing pattern: Separate parameters for MAS vs Milo

### Migration Reference
- **PR**: #464 (MWPW-183304: Final Milo M@S migration)
- **Completion Date**: December 2025
- **Impact**: MAS is now maintained in its own repository

---

## Success Checklist

✅ Port 3030 is running (verify with `lsof -i :3030`)
✅ URL parameter spelled correctly (`maslibs` not `maslib`)
✅ Using correct syntax with `&` for multiple parameters
✅ Browser console shows no 404 errors for fragment-client.js
✅ Components render correctly with local changes
✅ Feature branch deployments are available
✅ Both milolibs and maslibs work together when needed
