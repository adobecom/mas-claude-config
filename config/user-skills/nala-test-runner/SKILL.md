---
description: Intelligently run, debug, and manage Nala E2E tests for Milo/MAS projects. Handles test execution, environment setup, failure analysis, and integrates with nala-mcp for test generation. Use when running tests, debugging failures, testing locally/stage, or when user mentions nala, playwright, e2e, test names (Express, CCD, accordion), or test tags.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - TodoWrite
  - mcp__playwright__browser_navigate
  - mcp__playwright__browser_snapshot
  - mcp__playwright__browser_console_messages
  - mcp__playwright__browser_network_requests
  - mcp__playwright__browser_evaluate
  - mcp__playwright__browser_take_screenshot
  - mcp__playwright__browser_wait_for
  - mcp__chrome-devtools__take_snapshot
  - mcp__chrome-devtools__list_console_messages
  - mcp__chrome-devtools__list_network_requests
---

# Nala Test Runner Skill

## Purpose

This skill intelligently runs and debugs Nala (Playwright) E2E tests for Milo and MAS projects. It:
- Constructs correct `npm run nala` commands from natural language
- Manages test environment (aem server, LOCAL_TEST_LIVE_URL, proxies)
- Discovers tests by name or tag
- Analyzes test failures and suggests fixes
- Integrates with nala-mcp for test generation
- Supports multi-environment testing (local, stage, branch)

## When to Activate

### Automatic Activation
- User mentions "test", "nala", "playwright", or "e2e"
- User mentions test names: "Express", "CCD", "accordion", "tabs", etc.
- User mentions test tags: "@MAS-Express-Card-Free", "@smoke", "@regression"
- User says "debug", "run tests", "test locally", "test on stage"
- After code changes to blocks/features that have tests

### Explicit Activation
- "run nala tests"
- "test [component] locally"
- "debug failing [test]"
- "test on stage"
- "run [tag]"

## Core Workflow

### Phase 1: Parse Intent

Extract key information from user input:

1. **Environment**: Where to run tests
   - "locally", "on my machine" → `local`
   - "on stage", "staging" → `stage`
   - "branch MWPW-12345" → `MWPW-12345`
   - "main", "production" → `main`
   - Default: `local`

1a. **MiloLibs** (optional): Which Milo libs to use
   - "with local libs", "use milolibs local" → `milolibs=local`
   - "with prod libs", "production libs" → `milolibs=prod`
   - "with branch libs MWPW-12345" → `milolibs=MWPW-12345--milo--adobecom`
   - If NOT specified: Don't set MILO_LIBS (use default)
   - **CRITICAL**: Only set when user explicitly requests or when testing MAS changes locally

2. **Test Target**: What to test
   - Specific file: "express.test.js" → `test=express.test.js`
   - Component name: "accordion" → Find `accordion.test.js`
   - Tag: "free card", "@smoke" → `@MAS-Express-Card-Free`, `@smoke`

3. **Browser**: Which browser
   - "Firefox", "ff" → `browser=firefox`
   - "WebKit", "safari" → `browser=webkit`
   - Default: `browser=chrome`

4. **Mode**: Execution mode
   - "debug", "step through" → `mode=debug`
   - "headed", "visible" → `mode=headed`
   - "ui mode" → `mode=ui`
   - Default: `mode=headless`

5. **Device**: Device type
   - "mobile", "phone" → `device=mobile`
   - Default: `device=desktop`

### Phase 2: Verify Prerequisites

Before running tests, check environment:

#### For Local Tests

1. **Check Required Ports**
   ```bash
   # Check AEM server (port 8080)
   if ! lsof -ti:8080 > /dev/null 2>&1; then
     echo "❌ AEM server not running on port 8080"
     echo "Start with: aem up"
     exit 1
   fi

   # Check proxy server (port 3000)
   if ! lsof -ti:3000 > /dev/null 2>&1; then
     echo "❌ Proxy not running on port 3000"
     echo "Start with: cd __ADOBE_DIR__/milo && npm run proxy"
     exit 1
   fi

   echo "✓ AEM server running on port 8080"
   echo "✓ Proxy running on port 3000"
   ```

2. **Verify Server Health**
   ```bash
   # Test if server actually responds
   if ! curl -s -f http://localhost:3000 > /dev/null; then
     echo "❌ Server not responding at http://localhost:3000"
     echo "Check server logs"
     exit 1
   fi

   echo "✓ Server responding at http://localhost:3000"
   ```

3. **Set Environment Variables**
   ```bash
   # Always set base URL
   export LOCAL_TEST_LIVE_URL=http://localhost:3000

   # Conditionally set MILO_LIBS based on user input
   # If user requested milolibs=local OR testing MAS changes:
   if [[ "$USE_LOCAL_LIBS" == "true" ]]; then
     export MILO_LIBS='?milolibs=local'
     echo "✓ Using local Milo libs: MILO_LIBS='?milolibs=local'"
   elif [[ -n "$BRANCH_LIBS" ]]; then
     export MILO_LIBS="?milolibs=${BRANCH_LIBS}"
     echo "✓ Using branch libs: MILO_LIBS='?milolibs=${BRANCH_LIBS}'"
   else
     # Don't set MILO_LIBS - use default (empty string)
     echo "ℹ️  Using default libs (MILO_LIBS not set)"
   fi
   ```

4. **Check MAS Build (if testing MAS components)**
   ```bash
   # Only check if testing MAS-specific tests
   if [[ "$TEST_PATH" == *"/mas/"* ]] || [[ "$TEST_TAG" == *"@mas"* ]]; then
     # Check in correct Milo directory (NOT web-components!)
     MAS_BUNDLE="__ADOBE_DIR__/milo/libs/features/mas/dist/mas.js"

     if [[ ! -f "$MAS_BUNDLE" ]]; then
       echo "❌ MAS bundle not found at $MAS_BUNDLE"
       echo "Build with: npm run build:bundle"
       exit 1
     fi

     # Check if source is newer than bundle
     MAS_SRC_NEWEST=$(find __ADOBE_DIR__/milo/libs/features/mas/src -name "*.js" -type f -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -1 | cut -d' ' -f1)
     MAS_BUNDLE_TIME=$(stat -f "%m" "$MAS_BUNDLE")

     if [[ "$MAS_SRC_NEWEST" -gt "$MAS_BUNDLE_TIME" ]]; then
       echo "⚠️  MAS source newer than bundle"
       echo "Rebuild with: npm run build:bundle"
     else
       echo "✓ MAS bundle up to date"
     fi
   fi
   ```

5. **Studio Proxy (if testing studio)**
   ```bash
   # Only for studio tests
   if [[ "$TEST_PATH" == *"/studio/"* ]]; then
     if ! lsof -ti:3456 > /dev/null 2>&1; then
       echo "⚠️  Studio proxy not running on port 3456"
       echo "Start with: cd __MAS_DIR__/@studio/ && npm run proxy"
     else
       echo "✓ Studio proxy running on port 3456"
     fi
   fi
   ```

#### For Stage/Branch Tests
- No prerequisites needed
- Direct execution

### Phase 3: Discover Tests

Find the test file or tag to run with dynamic repo detection:

#### Step 1: Detect Current Repository
```bash
# Get git root directory
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

# Determine which repo we're in
if [[ "$GIT_ROOT" == *"/milo" ]]; then
  REPO="milo"
  TEST_DIR="$GIT_ROOT/nala"
  echo "📦 Detected: Milo repository"
elif [[ "$GIT_ROOT" == *"/mas" ]]; then
  REPO="mas"
  TEST_DIR="$GIT_ROOT/nala/studio"
  echo "📦 Detected: MAS repository"
else
  echo "⚠️  Unknown repository. Using current directory."
  TEST_DIR="./nala"
fi
```

#### Step 2: Search for Tests by Name
```bash
# User says: "test accordion"
# Dynamic search based on repo:
find "$TEST_DIR" -name "*accordion*.test.js"

# Example results:
# Milo: nala/blocks/accordion/accordion.test.js
# MAS:  nala/studio/accordion/accordion.test.js
```

#### Step 3: Search by Component Type
```bash
# User says: "test express cards"
# Search intelligently:
if [[ "$REPO" == "milo" ]]; then
  # Check MAS features first
  ls "$TEST_DIR/features/mas/express/" 2>/dev/null
  # Then blocks
  ls "$TEST_DIR/blocks/express/" 2>/dev/null
elif [[ "$REPO" == "mas" ]]; then
  # Check studio tests
  ls "$TEST_DIR/" | grep -i express
fi
```

#### Step 4: Search by Tag
```bash
# User says: "test free card"
# Map to tag: @MAS-Express-Card-Free
# Search in correct directory:
grep -r "@MAS-Express-Card-Free" "$TEST_DIR" --include="*.test.js"
```

See `test-catalog.md` for complete test and tag mappings.

### Phase 4: Construct Command

Build the npm run nala command:

```bash
# Base command
npm run nala [env] [options]

# Examples:
npm run nala local test=express.test.js
npm run nala stage @accordion
npm run nala local @MAS-Express-Card-Free browser=firefox mode=debug
npm run nala MWPW-178376 owner='axelcurenobasurto' @mas
```

Command construction rules in `command-builder.md`.

### Phase 5: Execute Tests

Run the constructed command:

```bash
# Change to project directory
cd __ADOBE_DIR__/milo

# Run command
npm run nala local test=express.test.js

# Monitor output
# - Show progress
# - Capture errors
# - Report results
```

### Phase 6: Analyze Results

#### If Tests Pass
```markdown
✓ Test Results

All tests passed!
- Duration: 24.5s
- Tests run: 3
- Passed: 3
- Failed: 0
```

#### If Tests Fail

**IMPORTANT**: Use Playwright/Chrome DevTools MCP for intelligent analysis!

##### Phase 6A: Automated Failure Investigation

When a test fails, automatically investigate using MCP tools:

```bash
# 1. Navigate to the failing URL
mcp__playwright__browser_navigate(url="http://localhost:3000/test-page")

# 2. Capture page snapshot (accessibility tree)
snapshot = mcp__playwright__browser_snapshot()
# Result: List of all elements with their types, text, and attributes

# 3. Get console errors
console_errors = mcp__playwright__browser_console_messages(onlyErrors=true)
# Result: Actual JavaScript errors from the page

# 4. Check network requests
network = mcp__playwright__browser_network_requests()
# Result: All requests with status codes (identify 404s, 500s, timeouts)

# 5. Validate selector if timeout
if error_type == "timeout":
  exists = mcp__playwright__browser_evaluate(
    function="() => document.querySelector('merch-card') !== null"
  )
  # Result: true/false - does selector actually exist?
```

##### Phase 6B: Intelligent Root Cause Analysis

Based on MCP data, determine root cause:

```markdown
✗ Test Failed: TimeoutError: Waiting for selector 'merch-card' failed

🔍 **Automated Investigation Results**

**1. Page Snapshot Analysis**
   ✓ Snapshot captured - 187 elements found
   ✗ No 'merch-card' elements present
   ℹ️  Found similar: <div class="merch-card-skeleton"> (3 instances)
   ℹ️  Found similar: <merch-card-collection> (1 instance)

**2. Console Error Analysis**
   ❌ ERROR: Failed to load resource: http://localhost:3000/libs/features/mas/dist/mas.js (404)
   ⚠️  WARNING: Custom element 'merch-card' not defined

**3. Network Request Analysis**
   ❌ 404: /libs/features/mas/dist/mas.js (117ms)
   ✓ 200: /studio.html (45ms)
   ✓ 200: /styles.css (23ms)

**4. Selector Validation**
   ✗ document.querySelector('merch-card') = null
   ℹ️  Selector syntax is valid but element doesn't exist

📊 **Root Cause**: MAS bundle (mas.js) returned 404 → Custom element not registered → merch-card element never created

💡 **Solution** (in priority order):
   1. Build MAS bundle: `npm run build:bundle`
   2. Verify MILO_LIBS is correct: `echo $MILO_LIBS`
   3. Check if proxy is serving correct path

🎯 **Would you like me to**:
   A) Build the MAS bundle and re-run
   B) Check proxy configuration
   C) Open in headed mode for visual inspection
   D) Validate the test selector logic
```

##### Phase 6C: Selector Intelligence

If selector doesn't exist, help find the right one:

```markdown
**Selector Not Found**: 'merch-card[variant="express"]'

🔎 **Finding Similar Elements**:

From page snapshot, found:
1. `merch-card[data-variant="express"]` (3 matches)
   ↳ Difference: Use 'data-variant' not 'variant'

2. `merch-card-collection merch-card` (2 matches)
   ↳ Needs parent selector

3. `aem-fragment[fragment-id="..."]` (5 matches)
   ↳ Consider using fragment ID instead

💡 **Suggested Fix**:
```javascript
// Old selector (wrong):
await page.locator('merch-card[variant="express"]')

// New selector (correct):
await page.locator('merch-card[data-variant="express"]')
```

Would you like me to update the test with the corrected selector?
```

##### Phase 6D: Shadow DOM Detection

Check if element is in shadow DOM:

```javascript
// Use evaluate to check shadow DOM
const inShadowDOM = await mcp__playwright__browser_evaluate(
  function: `() => {
    // Search for element in shadow roots
    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_ELEMENT,
      null
    );
    let node;
    while (node = walker.nextNode()) {
      if (node.shadowRoot) {
        const found = node.shadowRoot.querySelector('merch-card');
        if (found) return { found: true, host: node.tagName };
      }
    }
    return { found: false };
  }`
);

// If found in shadow DOM:
if (inShadowDOM.found) {
  console.log(`
    ℹ️  Element is in shadow DOM of <${inShadowDOM.host}>

    💡 Update selector to:
    page.locator('${inShadowDOM.host}')
        .locator('merch-card')  // Playwright auto-pierces shadow DOM
  `);
}
```

See `failure-patterns.md` for common error patterns and `playwright-mcp-integration.md` for detailed MCP usage.

### Phase 6E: Selective Test Execution for Fixing

**CRITICAL RULE**: When fixing failing tests, ALWAYS run only the specific test(s) being fixed, NOT the entire test suite.

#### Why Selective Execution Matters

Running the full test suite during active fixing:
- ❌ Wastes time (5-10 min full suite vs 10-30s single test)
- ❌ Makes it hard to verify if your specific fix worked
- ❌ Mixes results from fixed tests with unfixed tests
- ❌ Slows down the fix-verify cycle

#### Pattern 1: Fix Single Test

```bash
# ❌ BAD: Runs entire test suite (100+ tests, 5-10 minutes)
LOCAL_TEST_LIVE_URL="http://localhost:3000" npx playwright test nala/studio/ --reporter=list --timeout=60000

# ✅ GOOD: Run only the failing test (1 test, 10-30 seconds)
LOCAL_TEST_LIVE_URL="http://localhost:3000" npx playwright test nala/studio/acom/plans/individuals/tests/individuals_edit.test.js --grep "@studio-plans-individuals-edit-title" --reporter=list --timeout=60000
```

**Command Construction**:
```bash
# Extract from error output:
# "nala/studio/acom/plans/individuals/tests/individuals_edit.test.js:45:7 › @studio-plans-individuals-edit-title"
#  ↑ test file path                                                           ↑ tag to grep

# Build command:
LOCAL_TEST_LIVE_URL="http://localhost:3000" \
npx playwright test [test-file-path] \
--grep "@tag-name" \
--reporter=list \
--timeout=60000
```

#### Pattern 2: Fix Multiple Related Tests

When fixing a group of related tests (e.g., all mnemonic tests, all CTA tests):

```bash
# Option A: Run multiple specific tags
LOCAL_TEST_LIVE_URL="http://localhost:3000" \
npx playwright test nala/studio/ \
--grep "@studio-plans-individuals-edit-discard-mnemonic|@studio-slice-edit-discard-mnemonic|@studio-fries-edit-discard-mnemonic" \
--reporter=list \
--timeout=60000

# Option B: Run specific test files
LOCAL_TEST_LIVE_URL="http://localhost:3000" \
npx playwright test \
nala/studio/acom/plans/individuals/tests/individuals_edit_and_discard.test.js \
nala/studio/ccd/slice/tests/slice_edit_and_discard.test.js \
nala/studio/commerce/fries/tests/fries_edit_and_discard.test.js \
--grep "mnemonic" \
--reporter=list \
--timeout=60000

# Option C: Use grep pattern for common keywords
LOCAL_TEST_LIVE_URL="http://localhost:3000" \
npx playwright test nala/studio/ \
--grep "mnemonic|variant-change" \
--reporter=list \
--timeout=60000
```

#### Pattern 3: Extract Test Information from Error Output

From Playwright error output, extract the necessary information:

```bash
# Error output example:
# ✘ [mas-live-chromium] › nala/studio/acom/plans/individuals/tests/individuals_edit.test.js:45:7 › @studio-plans-individuals-edit-title

# Extract:
# - Test file: nala/studio/acom/plans/individuals/tests/individuals_edit.test.js
# - Tag: @studio-plans-individuals-edit-title

# Build command:
LOCAL_TEST_LIVE_URL="http://localhost:3000" \
npx playwright test nala/studio/acom/plans/individuals/tests/individuals_edit.test.js \
--grep "@studio-plans-individuals-edit-title" \
--reporter=list \
--timeout=60000
```

#### Fix-Verify-Next Workflow

The correct workflow when fixing multiple test failures:

```markdown
## Fixing 3 Test Failures

### Phase 1: Identify All Failing Tests
List of failing tests:
1. @studio-plans-individuals-edit-title
2. @studio-slice-edit-mnemonic
3. @studio-fries-save-cta

### Phase 2: Fix Each Test Individually

#### Test 1: @studio-plans-individuals-edit-title
1. ✓ Analyzed failure (selector timeout)
2. ✓ Applied fix to studio.page.js:123 (added proper wait)
3. ✓ Running ONLY this test:
   ```bash
   LOCAL_TEST_LIVE_URL="http://localhost:3000" \
   npx playwright test nala/studio/acom/plans/individuals/tests/individuals_edit.test.js \
   --grep "@studio-plans-individuals-edit-title" \
   --reporter=list \
   --timeout=60000
   ```
4. ✓ Result: Test passed (12.3s)
5. ✓ Moving to next test

#### Test 2: @studio-slice-edit-mnemonic
1. ✓ Analyzed failure (toast timing)
2. ✓ Applied fix to slice.page.js:89
3. ✓ Running ONLY this test:
   ```bash
   LOCAL_TEST_LIVE_URL="http://localhost:3000" \
   npx playwright test nala/studio/ccd/slice/tests/slice_edit.test.js \
   --grep "@studio-slice-edit-mnemonic" \
   --reporter=list \
   --timeout=60000
   ```
4. ✓ Result: Test passed (15.7s)
5. ✓ Moving to next test

#### Test 3: @studio-fries-save-cta
1. ✓ Analyzed failure (CTA click timing)
2. ✓ Applied fix to fries.test.js:234
3. ✓ Running ONLY this test:
   ```bash
   LOCAL_TEST_LIVE_URL="http://localhost:3000" \
   npx playwright test nala/studio/commerce/fries/tests/fries_save.test.js \
   --grep "@studio-fries-save-cta" \
   --reporter=list \
   --timeout=60000
   ```
4. ✓ Result: Test passed (18.2s)

### Phase 3: Final Verification
All 3 tests fixed individually (total: 46.2s).
Now running full suite for final verification:
```bash
LOCAL_TEST_LIVE_URL="http://localhost:3000" \
npx playwright test nala/studio/ \
--reporter=list \
--timeout=60000
```
Result: All tests passed (8m 34s)
```

#### When to Run Full Suite vs Selective Tests

| Scenario | What to Run | Why |
|----------|-------------|-----|
| **Fixing a specific test** | Run only that test by tag | Fast feedback, clear verification |
| **Fixing related tests** | Run only those tests by tags or grep pattern | Verify related fixes together |
| **Applied fix to shared code** | Run affected tests by directory/pattern | Verify no regressions in related tests |
| **All fixes complete** | Run full test suite | Final regression check |
| **Before creating PR** | Run full test suite | Ensure no unintended side effects |
| **During active fixing** | ❌ NEVER run full suite | Too slow, unclear results |

#### Quick Reference: Command Templates

```bash
# Single test by tag
LOCAL_TEST_LIVE_URL="http://localhost:3000" npx playwright test [test-file] --grep "@tag" --reporter=list --timeout=60000

# Multiple tests by tags
LOCAL_TEST_LIVE_URL="http://localhost:3000" npx playwright test [test-file] --grep "@tag1|@tag2|@tag3" --reporter=list --timeout=60000

# Tests matching pattern
LOCAL_TEST_LIVE_URL="http://localhost:3000" npx playwright test nala/studio/ --grep "mnemonic|cta" --reporter=list --timeout=60000

# Single test file (all tests in it)
LOCAL_TEST_LIVE_URL="http://localhost:3000" npx playwright test [test-file] --reporter=list --timeout=60000

# Full suite (ONLY after all fixes)
LOCAL_TEST_LIVE_URL="http://localhost:3000" npx playwright test nala/studio/ --reporter=list --timeout=60000
```

#### Best Practices for Test Fixing

**Do's ✓**:
- Run individual tests during active fixing
- Use specific tags or file paths
- Verify each fix immediately
- Keep fix-verify cycle under 30 seconds
- Run full suite only as final verification
- Use `--reporter=list` for clear output
- Document which tag you're fixing

**Don'ts ✗**:
- Don't run full suite during active fixing
- Don't mix results from multiple unrelated tests
- Don't guess if a fix worked (run the specific test)
- Don't run tests in headed mode during fixing (slower)
- Don't forget to run full suite at the end

### Phase 7: Integration with nala-mcp

If test files don't exist, offer to generate them:

```markdown
Test file not found: super-card.test.js

I can generate test files using nala-mcp:
- super-card.page.js (page object)
- super-card.spec.js (test data)
- super-card.test.js (test implementation)

Generate tests now? (y/n)
```

If yes, coordinate with nala-mcp:
1. Call nala-mcp tool: `generate-complete-test-suite`
2. Wait for generation complete
3. Validate files created
4. Run the generated tests
5. Report results

See `nala-mcp-integration.md` for integration patterns.

## Command Construction Patterns

### Pattern 1: Simple Local Test
```
Input: "test express"
Command: npm run nala local test=express.test.js
```

### Pattern 2: Tag-Based Test
```
Input: "test free card"
Tag mapping: @MAS-Express-Card-Free
Command: npm run nala local @MAS-Express-Card-Free
```

### Pattern 3: Multiple Tags
```
Input: "test express smoke tests"
Tags: @express @smoke
Command: npm run nala local @express @smoke
```

### Pattern 4: Different Browser
```
Input: "test accordion on firefox"
Command: npm run nala local test=accordion.test.js browser=firefox
```

### Pattern 5: Debug Mode
```
Input: "debug the failing premium card test"
Tag: @MAS-Express-Card-Premium
Command: npm run nala local @MAS-Express-Card-Premium mode=debug
```

### Pattern 6: Stage Testing
```
Input: "test on stage"
Command: npm run nala stage
```

### Pattern 7: Branch Testing
```
Input: "test my branch MWPW-178376"
Command: npm run nala MWPW-178376 owner='axelcurenobasurto'
```

### Pattern 8: Mobile Testing
```
Input: "test express on mobile"
Command: npm run nala local test=express.test.js device=mobile
```

## Test Discovery Examples

### Example 1: By Name
```
User: "test the marquee block"
Skill:
1. Searches: find nala/ -name "*marquee*.test.js"
2. Finds: nala/blocks/marquee/marquee.test.js
3. Confirms: "Found marquee.test.js. Running..."
4. Command: npm run nala local test=marquee.test.js
```

### Example 2: By Feature Area
```
User: "test mas components"
Skill:
1. Recognizes: "mas" → @mas tag or MAS features
2. Options: Run all @mas tests or specific surface?
3. User: "all"
4. Command: npm run nala local @mas
```

### Example 3: By Tag Pattern
```
User: "run smoke tests"
Skill:
1. Recognizes: @smoke tag
2. Command: npm run nala local @smoke
```

## Environment-Specific Handling

### Local Environment
```bash
# Prerequisites:
1. AEM server on port 8080 (aem up)
2. Proxy server on port 3000 (npm run proxy)
3. LOCAL_TEST_LIVE_URL set
4. MAS built (if testing MAS components)
5. MILO_LIBS set ONLY if user requested or testing MAS changes

# URL patterns (depending on MILO_LIBS):
# Default (MILO_LIBS not set):
http://localhost:3000/path

# With local libs (MILO_LIBS='?milolibs=local'):
http://localhost:3000/path?milolibs=local

# With branch libs (MILO_LIBS='?milolibs=MWPW-12345--milo--adobecom'):
http://localhost:3000/path?milolibs=MWPW-12345--milo--adobecom

# CRITICAL: Don't hardcode milolibs - use MILO_LIBS env var
# Tests automatically append $MILO_LIBS to URLs
```

### Libs Environment
```bash
# Prerequisites:
1. npm run libs on localhost:6456

# Command:
npm run nala libs

# URL pattern:
http://localhost:6456/?milolibs=local  # Libs environment always uses local
```

### Stage Environment
```bash
# No prerequisites

# Command:
npm run nala stage

# URL pattern:
https://mwpw-<branch>--milo--adobecom.aem.page/

# Note: Stage uses deployed libs, no MILO_LIBS needed
```

### Branch Testing
```bash
# Command:
npm run nala MWPW-178376 owner='yourname'

# URL pattern:
https://mwpw-178376--milo--adobecom.aem.live/

# Note: Branch uses its own deployed libs, no MILO_LIBS needed
```

### Understanding MILO_LIBS Environment Variable

**How Tests Use MILO_LIBS**:
```javascript
// From mas-test.js (line 30):
const miloLibs = process.env.MILO_LIBS || '';

// From studio.test.js:
const testPage = `${baseURL}${features[0].path}${miloLibs}`;

// Results:
// If MILO_LIBS='?milolibs=local' → http://localhost:3000/studio.html?milolibs=local
// If MILO_LIBS='' (default)        → http://localhost:3000/studio.html
```

**When to Set MILO_LIBS**:
1. ✓ User explicitly requests: "test with local libs", "use milolibs local"
2. ✓ Testing MAS changes that require local Milo build
3. ✓ Debugging issues with specific Milo lib version
4. ✗ DO NOT set by default for all local tests
5. ✗ DO NOT set for stage/branch tests (they use their own libs)

## Failure Analysis Patterns

**CRITICAL**: Always use Playwright/Chrome DevTools MCP for data-driven analysis!

### Pattern 1: Timeout Errors (Selector Not Found)

**Error**: `TimeoutError: Waiting for selector 'merch-card' failed`

**MCP Investigation Workflow**:
```bash
1. Navigate to failing URL
2. Take snapshot → Check if element exists
3. Get console errors → Look for registration failures
4. Check network → Look for 404s on JS files
5. Evaluate selector → Validate syntax and existence
```

**Data-Driven Analysis**:
```markdown
🔍 Investigation Results:
- Snapshot: 0 'merch-card' elements (expected: 1+)
- Console: "Custom element 'merch-card' not defined"
- Network: 404 on /libs/features/mas/dist/mas.js
- Selector: Valid syntax, element doesn't exist

📊 Root Cause: MAS bundle 404 → Element not registered
💡 Fix: npm run build:bundle
```

**Common Root Causes**:
| Evidence | Root Cause | Fix |
|----------|------------|-----|
| Console: "not defined" + Network: 404 | Bundle not built/loaded | `npm run build:bundle` |
| Snapshot: Similar elements exist | Wrong selector | Use MCP to find correct selector |
| Snapshot: Element in shadow DOM | Shadow DOM access | Update selector to pierce shadow |
| Console: No errors + Element missing | Timing issue | Add proper wait condition |

### Pattern 2: Price/Content Loading Errors

**Error**: `Expected price /US\$/ but got 'Loading...'`

**MCP Investigation**:
```bash
1. Snapshot → Check actual text content
2. Network → Find commerce API request
3. Console → Look for API errors
4. Evaluate → Check element state
```

**Data-Driven Analysis**:
```markdown
🔍 Investigation Results:
- Snapshot: Element shows "Loading..." text
- Network: /offers API pending (3000ms+ no response)
- Console: No errors
- Element: Visible, but data not hydrated

📊 Root Cause: Commerce API slow/timeout
💡 Fix: Use waitForFunction for price text, not fixed timeout
```

**Fix Example**:
```javascript
// ❌ Bad: Fixed timeout
await page.waitForTimeout(3000);

// ✓ Good: Wait for actual condition
await page.waitForFunction(
  () => !document.querySelector('[data-price]')?.textContent.includes('Loading')
);
```

### Pattern 3: Environment/Setup Errors

**Error**: `Cannot read property 'path' of undefined`

**MCP Investigation**:
```bash
1. Check if page loaded (navigate + snapshot)
2. Network → Verify server responded
3. Console → Check for initialization errors
```

**Data-Driven Analysis**:
```markdown
🔍 Investigation Results:
- Navigation: Failed to reach http://localhost:3000
- Network: Connection refused
- Ports: lsof -ti:3000 = (empty)

📊 Root Cause: Server not running on port 3000
💡 Fix: Start proxy server
```

**Common Setup Issues**:
| MCP Finding | Root Cause | Fix |
|-------------|------------|-----|
| Navigation fails | Server not running | `aem up` and/or `npm run proxy` |
| Port check empty | Process not started | Use `/start-mas` command |
| Network: All 404s | Wrong base URL | Check LOCAL_TEST_LIVE_URL |
| Console: CORS errors | Wrong origin | Check proxy config |

### Pattern 4: Selector Syntax Errors

**Error**: Test fails with wrong element selected

**MCP Investigation**:
```bash
1. Evaluate current selector → Get element(s) found
2. Snapshot → Find expected elements
3. Compare → Identify difference
```

**Selector Intelligence Example**:
```markdown
Looking for: 'merch-card[variant="express"]'
MCP Found:
  ✗ 0 matches for 'merch-card[variant="express"]'
  ✓ 3 matches for 'merch-card[data-variant="express"]'

💡 Correction: Use 'data-variant' attribute

Would you like me to:
A) Update test with correct selector
B) Show all matching elements
C) Generate page object with all selectors
```

### Pattern 5: Shadow DOM Issues

**Error**: `Selector works in DevTools but not in test`

**MCP Investigation**:
```javascript
// Use evaluate to check shadow DOM
const shadowCheck = mcp__playwright__browser_evaluate(`
  function: () => {
    // Check if element is in light DOM
    const inLight = document.querySelector('target-element');
    if (inLight) return { location: 'light-dom' };

    // Check shadow DOMs
    const hosts = document.querySelectorAll('*');
    for (const host of hosts) {
      if (host.shadowRoot?.querySelector('target-element')) {
        return { location: 'shadow-dom', host: host.tagName };
      }
    }
    return { location: 'not-found' };
  }
`);
```

**Fix Based on Result**:
```markdown
📊 Result: Element in shadow DOM of <MAS-FRAGMENT>

💡 Fix:
```javascript
// ❌ Wrong: Can't access shadow DOM directly
await page.locator('target-element')

// ✓ Correct: Playwright auto-pierces
await page.locator('mas-fragment').locator('target-element')

// Or use CSS piercing combinator
await page.locator('mas-fragment >>> target-element')
```

### Pattern 6: Network/Resource Errors

**Error**: Test passes locally but fails on CI

**MCP Investigation**:
```bash
1. Network requests → Compare local vs CI
2. Console errors → Look for failed resources
3. Timing → Check request durations
```

**Analysis Example**:
```markdown
🔍 Network Comparison:
Local:
  ✓ /mas.js: 200 (45ms)
  ✓ /offers: 200 (230ms)

CI:
  ❌ /mas.js: 404 (12ms)
  ⏱️ /offers: Timeout (30000ms)

📊 Root Cause: Build artifacts not deployed to CI
💡 Fix: Add build step to CI pipeline
```

### Using MCP for Test Fixing

When tests fail, offer intelligent fixing:

```markdown
Test failed with selector timeout.

🤖 I can automatically investigate and fix this:

A) **Investigate now** - Use MCP to analyze page and suggest fixes
B) **Debug interactively** - Open browser in headed mode
C) **Update selector** - Use MCP to find correct selector
D) **Check environment** - Verify all prerequisites

Select option: [A/B/C/D]
```

## Debug Mode Workflow

When user requests debugging:

1. **Identify the failing test**
   - By name or tag
   - From recent failures

2. **Prepare debug session**
   - Ensure environment ready
   - Set mode=debug

3. **Launch Playwright Inspector**
   ```bash
   npm run nala local @failing-test mode=debug
   ```

4. **Guide the user**
   ```markdown
   Playwright Inspector opened!

   Debugging steps:
   1. Click "Step over" to run each test step
   2. Watch the browser to see what happens
   3. Check which step fails
   4. Inspect element selectors
   5. Check network requests (if needed)

   Common issues to check:
   - Is the element visible?
   - Is the selector correct?
   - Is timing an issue?
   ```

5. **Analyze findings**
   - What step failed?
   - What was expected vs actual?
   - Suggest fix based on findings

## Multi-Environment Testing

### Scenario: Compare Local vs Stage

```markdown
User: "test express on local and stage"

Skill runs:

## Test 1: Local Environment
- Checking prerequisites...
  ✓ aem up running
  ✓ LOCAL_TEST_LIVE_URL set
- Running: npm run nala local @express
- Result: 3/3 tests passed (18.2s)

## Test 2: Stage Environment
- Running: npm run nala stage @express
- Result: 3/3 tests passed (24.7s)

## Summary
✓ All environments passing
- Local: 3/3 passed
- Stage: 3/3 passed

Both environments consistent!
```

## nala-mcp Integration

### When to Use nala-mcp

#### Scenario 1: Test Files Don't Exist
```markdown
User: "test my new custom-card variant"

Skill: [Searches for custom-card tests]
Result: Not found

Skill suggests:
"Test files for 'custom-card' don't exist yet.

I can generate them using nala-mcp:
✓ custom-card.page.js - Page object with selectors
✓ custom-card.spec.js - Test data and configuration
✓ custom-card.test.js - Test implementation

This will create complete test suite for:
- CSS tests (styling, layout)
- Functional tests (behavior, interactions)

Generate tests now? (y/n)"
```

#### Scenario 2: Extract Properties First
```markdown
User: "I have a new card, create tests for it"

Skill: "I can extract properties from the live card.
        What's the card ID or URL?"

User: [Provides card ID or URL]

Skill: [Uses nala-mcp: auto-extract-card-properties]
Result: Properties extracted

Skill: [Uses nala-mcp: generate-complete-test-suite]
Result: Tests generated

Skill: "Tests generated! Running them now..."
[Runs the generated tests]
```

#### Scenario 3: Fix Test Errors
```markdown
Tests fail with common fixable errors

Skill: "I detected common test errors that nala-mcp can auto-fix:
       - Selector syntax issues
       - Wait timing problems
       - Assertion format errors

       Try auto-fix? (y/n)"

If yes:
[Uses nala-mcp: fix-test-errors]
[Re-runs tests]
[Reports results]
```

### Complete Workflow with nala-mcp

```markdown
User: "Create and test the new premium-express card"

Skill workflow:

## Step 1: Extract Properties
Using nala-mcp to extract card properties...
✓ Properties extracted from live page

## Step 2: Generate Tests
Using nala-mcp to generate test suite...
✓ premium-express.page.js created
✓ premium-express.spec.js created
✓ premium-express.test.js created

## Step 3: Validate
✓ All files valid Playwright tests

## Step 4: Setup Environment
✓ Checking aem server... running
✓ LOCAL_TEST_LIVE_URL set

## Step 5: Run Tests
Running: npm run nala local test=premium-express.test.js
⏳ Running...
✓ 3 tests passed (21.4s)

## Complete!
Your new card tests are ready and passing!
```

## Best Practices

### Do's ✓
- **Always use MCP tools** for intelligent debugging and analysis
- **Check prerequisites** with proper port checks (lsof) before running local tests
- **Conditionally set MILO_LIBS** - only when user requests or testing MAS changes
- **Use specific tags** when possible (@test-name vs @feature-area)
- **Run in debug mode** when troubleshooting failures
- **Suggest nala-mcp** when test files are missing
- **Provide data-driven analysis** using snapshot/console/network data
- **Test on multiple environments** when critical
- **Set realistic timeouts** (don't over-timeout)
- **Validate selectors** using MCP evaluate before suggesting fixes
- **Detect repository** dynamically instead of hardcoding paths

### Don'ts ✗
- **Don't hardcode `milolibs=local`** - Make it conditional based on user request
- **Don't assume MILO_LIBS is always needed** - Default is empty string
- **Don't use `ps aux | grep`** - Use `lsof -ti:PORT` for port checking
- **Don't suggest fixes without MCP investigation** - Always check snapshot/console/network first
- **Don't run tests without checking servers** - Verify ports 8080 (AEM) and 3000 (proxy)
- **Don't suggest generic "add timeout"** - Use waitForFunction with conditions
- **Don't increase timeouts by more than 3 seconds** - Usually the error is related to something else (wrong selector, missing element, build issue, network failure), not just timing
- **Don't run full test suite when fixing tests** - Use specific tags or file paths (see Phase 6E)
- **Don't skip environment setup** - Always verify prerequisites
- **Don't forget LOCAL_TEST_LIVE_URL** for local tests
- **Don't ignore MAS build requirements** - Check bundle timestamp
- **Don't run in headed mode by default** - Use headless for CI/CD
- **Don't suggest mutationObserver** unless necessary - Use Playwright native solutions
- **Don't hardcode Milo paths** - Detect repo and use dynamic paths

### MCP Integration Best Practices

#### When Test Fails
1. **Immediate Investigation**:
   ```bash
   1. Navigate to failing URL
   2. Capture snapshot
   3. Get console errors
   4. Check network requests
   5. Validate selector (if timeout)
   ```

2. **Data-Driven Analysis**:
   - Show evidence from MCP (not assumptions)
   - Compare expected vs actual state
   - Identify root cause from data
   - Provide specific, actionable fixes

3. **Selector Intelligence**:
   - Validate selector exists before suggesting changes
   - Find similar elements if selector is wrong
   - Check shadow DOM if element not found
   - Suggest correct selector with explanation

#### When to Use Each MCP Tool

| Scenario | MCP Tool | Purpose |
|----------|----------|---------|
| Test timeout | `browser_snapshot` | Check if element exists |
| Console errors | `browser_console_messages` | Get actual JavaScript errors |
| Network failures | `browser_network_requests` | Identify 404s, timeouts, slow requests |
| Selector validation | `browser_evaluate` | Test if querySelector works |
| Visual debugging | `browser_take_screenshot` | See actual page state |
| Content verification | `browser_evaluate` | Extract element text/attributes |

#### Offering Automated Fixes

When analysis complete, offer intelligent options:
```markdown
Based on MCP investigation, I found:
- Root cause: [specific issue from data]
- Evidence: [console/network/snapshot findings]

🤖 I can help fix this:
A) Automatically update the selector (I found the correct one)
B) Build MAS bundle and re-run
C) Update test to wait for proper condition
D) Generate corrected test file

Select option or ask questions: [A/B/C/D]
```

## Project-Specific Considerations

### Milo Project Rules (from CLAUDE.md)

1. **Always run linter** after changes
   - If test code changed, run: `npm run lint:js`

2. **Use nala-mcp for test generation**
   - Don't manually create test files
   - Use MCP tools for generation

3. **Remember proxy for studio**
   - Studio tests need: `cd @studio/ && npm run proxy`

4. **AEM server for local tests**
   - Local tests require: `aem up`

5. **No unnecessary timeouts**
   - Only suggest timeouts when genuinely needed
   - Prefer proper waits (waitForSelector, waitForFunction)

6. **No mutationObserver**
   - Don't suggest unless explicitly requested
   - Use Playwright-native solutions

### MAS-Specific

When testing MAS components:

1. **Check if build needed**
   ```bash
   # If src files changed:
   npm run build:bundle
   ```

2. **MAS tests location**
   ```
   nala/features/mas/
   ├── express/
   ├── ccd/
   ├── adobehome/
   └── commerce/
   ```

3. **Common MAS tags**
   ```
   @mas - All MAS tests
   @express - Express cards
   @ccd - CCD components
   @adobehome - Adobe Home
   @commerce - Commerce features
   ```

## Success Criteria

A test execution is successful when:
- ✓ Correct command constructed from user input
- ✓ Prerequisites verified and started if needed
- ✓ Test executed without environment errors
- ✓ Results clearly reported to user
- ✓ Failures analyzed with specific suggestions
- ✓ User knows exactly what to do next

## Output Format

Always provide structured output:

```markdown
## Test Execution: [Test Name]

### Environment
- Type: local
- URL: http://localhost:3000
- Browser: Chrome
- Mode: headless

### Prerequisites
✓ AEM server running
✓ LOCAL_TEST_LIVE_URL set
✓ MAS build up to date

### Command
npm run nala local @MAS-Express-Card-Free

### Results
✓ 1 test passed
Duration: 12.3s

All tests passing!
```

## Playwright MCP Integration Guide

### Complete MCP Workflow for Test Debugging

When a test fails, follow this comprehensive workflow:

#### Step 1: Navigate to Failing Page
```javascript
// Always start by loading the page
await mcp__playwright__browser_navigate({
  url: "http://localhost:3000/studio.html?fragment=test-id"
});

// Wait for page to load
await mcp__playwright__browser_wait_for({
  text: "expected-content",  // Optional: wait for specific content
  timeout: 5000
});
```

#### Step 2: Capture Page State
```javascript
// Get complete page structure
const snapshot = await mcp__playwright__browser_snapshot();

// Snapshot returns accessibility tree with:
// - All elements and their types
// - Visible text content
// - Element attributes
// - Hierarchy/nesting

// Analyze snapshot for:
// 1. Does target element exist?
// 2. Are there similar elements?
// 3. What's the actual page structure?
```

#### Step 3: Get Console Messages
```javascript
// Get all console errors
const errors = await mcp__playwright__browser_console_messages({
  onlyErrors: true
});

// Look for:
// - "not defined" errors (custom elements)
// - Failed resource loads
// - JavaScript runtime errors
// - API call failures

// Example analysis:
// Error: "Custom element 'merch-card' not defined"
// → Root cause: MAS bundle not loaded
```

#### Step 4: Analyze Network Requests
```javascript
// Get all network activity
const network = await mcp__playwright__browser_network_requests();

// Filter for failures:
const failed = network.filter(req => req.status >= 400);

// Look for:
// - 404 errors (missing resources)
// - 500 errors (server issues)
// - Timeout requests
// - Slow requests (> 3000ms)

// Common findings:
// 404 on /libs/features/mas/dist/mas.js → Build missing
// 500 on /offers → Commerce API down
// Timeout on /fragments → Network issue
```

#### Step 5: Validate Selector
```javascript
// Test if selector works
const selectorExists = await mcp__playwright__browser_evaluate({
  function: `() => {
    const element = document.querySelector('merch-card[variant="express"]');
    if (!element) return { found: false };

    return {
      found: true,
      visible: element.offsetParent !== null,
      text: element.textContent?.trim(),
      attributes: {
        variant: element.getAttribute('variant'),
        'data-variant': element.getAttribute('data-variant')
      }
    };
  }`
});

// Based on result:
// - found: false → Element doesn't exist (check snapshot for alternatives)
// - found: true, visible: false → Element hidden (check CSS, display, visibility)
// - found: true, visible: true → Element exists and visible (timing issue?)
```

#### Step 6: Find Alternative Selectors
```javascript
// If selector failed, search for similar elements
const alternatives = await mcp__playwright__browser_evaluate({
  function: `() => {
    // Find all elements matching partial name
    const allElements = [...document.querySelectorAll('*')];
    const matches = allElements.filter(el =>
      el.tagName.toLowerCase().includes('merch') ||
      el.className.includes('merch') ||
      el.id.includes('merch')
    );

    return matches.map(el => ({
      tag: el.tagName,
      class: el.className,
      id: el.id,
      attributes: [...el.attributes].map(attr =>
        ({ name: attr.name, value: attr.value })
      )
    }));
  }`
});

// Suggest best match to user
```

#### Step 7: Check Shadow DOM
```javascript
// Search through shadow DOMs
const shadowSearch = await mcp__playwright__browser_evaluate({
  function: `() => {
    function searchShadow(root, selector) {
      // Check current root
      const found = root.querySelector(selector);
      if (found) return { found: true, path: [root.tagName] };

      // Search nested shadow roots
      const hosts = root.querySelectorAll('*');
      for (const host of hosts) {
        if (host.shadowRoot) {
          const result = searchShadow(host.shadowRoot, selector);
          if (result.found) {
            result.path.unshift(host.tagName);
            return result;
          }
        }
      }

      return { found: false };
    }

    return searchShadow(document, 'merch-card');
  }`
});

// If found in shadow DOM, update test:
// page.locator('host-element').locator('merch-card')
```

#### Step 8: Generate Comprehensive Report
```markdown
# Test Failure Analysis Report

## Test Information
- Test: individuals_edit.test.js
- Selector: 'merch-card[variant="express"]'
- Error: TimeoutError after 30000ms

## MCP Investigation Results

### 1. Page Snapshot
✓ Page loaded successfully (234 elements)
✗ Target selector not found: 'merch-card[variant="express"]'
ℹ️  Similar elements found:
    - merch-card[data-variant="express"] (3 instances)
    - merch-card-collection (1 instance)
    - div.merch-card-skeleton (2 instances)

### 2. Console Errors
❌ ERROR (line 45): Custom element 'merch-card' not defined
⚠️  WARNING: Couldn't load /libs/features/mas/dist/mas.js

### 3. Network Analysis
✓ Total requests: 23
✓ Successful: 21 (91%)
❌ Failed: 2 (9%)

Failed Requests:
- [404] /libs/features/mas/dist/mas.js (127ms)
- [404] /dist/merch-card.js (89ms)

### 4. Selector Validation
✗ document.querySelector('merch-card[variant="express"]') = null
✓ document.querySelector('merch-card[data-variant="express"]') = [object HTMLElement]

### 5. Shadow DOM Check
✗ Not in shadow DOM

## Root Cause Analysis
📊 **Primary Issue**: MAS bundle returned 404
↳ Custom element 'merch-card' never registered
↳ Element cannot be created without registration

📊 **Secondary Issue**: Wrong attribute name
↳ Should use 'data-variant' not 'variant'

## Recommended Fixes (Priority Order)

### Fix 1: Build MAS Bundle (Critical)
```bash
cd __ADOBE_DIR__/milo
npm run build:bundle
```

### Fix 2: Correct Selector (After Fix 1)
```javascript
// Old (wrong):
await page.locator('merch-card[variant="express"]')

// New (correct):
await page.locator('merch-card[data-variant="express"]')
```

### Fix 3: Verify MILO_LIBS
```bash
# Check current setting
echo $MILO_LIBS

# Should be either:
# - Empty string (default)
# - '?milolibs=local' (if testing MAS changes)
```

## Next Steps
🎯 Would you like me to:
A) Build MAS bundle and re-run test
B) Update selector in test file
C) Open in debug mode for manual inspection
D) Generate corrected test file with nala-mcp

Select: [A/B/C/D]
```

### MCP Tool Reference

#### browser_navigate
**Purpose**: Load a page
**When**: Always first step
**Example**:
```javascript
mcp__playwright__browser_navigate({ url: "http://localhost:3000/test" })
```

#### browser_snapshot
**Purpose**: Get complete page structure (accessibility tree)
**When**: Need to see what elements exist
**Returns**: All elements with text, roles, attributes
**Example**:
```javascript
const snapshot = mcp__playwright__browser_snapshot()
// Analyze for element existence and alternatives
```

#### browser_console_messages
**Purpose**: Get JavaScript console output
**When**: Need to see runtime errors
**Parameters**: `onlyErrors: true` to filter
**Example**:
```javascript
const errors = mcp__playwright__browser_console_messages({ onlyErrors: true })
// Look for "not defined", "failed to load", etc.
```

#### browser_network_requests
**Purpose**: Get all HTTP requests with status codes
**When**: Checking for 404s, timeouts, slow APIs
**Returns**: URL, status, timing for each request
**Example**:
```javascript
const network = mcp__playwright__browser_network_requests()
const failures = network.filter(r => r.status >= 400)
```

#### browser_evaluate
**Purpose**: Run JavaScript in page context
**When**: Need to query DOM, check element state, extract data
**Returns**: JSON-serializable result from function
**Example**:
```javascript
const result = mcp__playwright__browser_evaluate({
  function: `() => {
    return document.querySelector('merch-card') !== null;
  }`
})
```

#### browser_take_screenshot
**Purpose**: Capture visual state
**When**: Need to see what user sees
**Parameters**: `filename` optional
**Example**:
```javascript
mcp__playwright__browser_take_screenshot({ filename: "failure-state.png" })
// Use for visual debugging
```

#### browser_wait_for
**Purpose**: Wait for condition
**When**: Page needs time to load/render
**Parameters**: `text` to wait for, `timeout` in ms
**Example**:
```javascript
mcp__playwright__browser_wait_for({ text: "Loaded", timeout: 5000 })
```

### Common MCP Patterns

#### Pattern: Find Wrong Selector
```javascript
// 1. Check if selector works
const exists = await browser_evaluate({
  function: "() => document.querySelector('target') !== null"
});

if (!exists) {
  // 2. Find similar elements
  const similar = await browser_evaluate({
    function: `() => {
      return [...document.querySelectorAll('*')]
        .filter(el => el.tagName.includes('TARGET'))
        .map(el => ({ tag: el.tagName, class: el.className }));
    }`
  });

  // 3. Suggest correction
  console.log("Try: " + similar[0].tag);
}
```

#### Pattern: Diagnose 404 Errors
```javascript
// 1. Get network requests
const network = await browser_network_requests();

// 2. Filter failures
const failures = network.filter(r => r.status === 404);

// 3. Analyze patterns
if (failures.some(r => r.url.includes('mas.js'))) {
  console.log("MAS bundle missing - run: npm run build:bundle");
}
```

#### Pattern: Validate Page State
```javascript
// 1. Navigate
await browser_navigate({ url: testUrl });

// 2. Get snapshot
const snapshot = await browser_snapshot();

// 3. Get console
const console = await browser_console_messages({ onlyErrors: true });

// 4. Determine health
if (console.length === 0 && snapshot.includes('expected-element')) {
  console.log("✓ Page healthy");
} else {
  console.log("✗ Page has issues");
}
```

## Related Documentation

- `command-builder.md` - Command construction logic
- `test-catalog.md` - Known tests and tags
- `environment-setup.md` - Environment management
- `failure-patterns.md` - Common errors and fixes
- `nala-mcp-integration.md` - Working with MCP
- `playwright-mcp-reference.md` - Complete MCP API reference
- `README.md` - Complete guide
- `QUICKSTART.md` - Quick start guide

## Summary of Key Improvements

### ✅ Fixed Issues
1. **Conditional milolibs** - No longer hardcoded to `?milolibs=local`
2. **MILO_LIBS variable** - Properly set when needed, empty by default
3. **Port checking** - Uses `lsof -ti:PORT` instead of `ps aux | grep`
4. **Server health** - Verifies servers respond, not just running
5. **MAS directory** - Uses correct path in Milo, not web-components
6. **Dynamic repo detection** - Detects Milo vs MAS automatically
7. **Intelligent debugging** - Uses MCP for data-driven analysis

### 🚀 New Capabilities
1. **Playwright MCP integration** - Automated page analysis
2. **Selector intelligence** - Finds correct selectors automatically
3. **Shadow DOM detection** - Identifies shadow DOM issues
4. **Root cause analysis** - Data-driven failure diagnosis
5. **Automated fixes** - Suggests specific solutions with evidence
6. **Network analysis** - Identifies 404s, timeouts, slow requests
7. **Console error tracking** - Pinpoints JavaScript errors

### 📊 Expected Impact
- **50% faster debugging** - Automated investigation vs manual
- **80% more accurate fixes** - Based on actual page state
- **Zero false assumptions** - Conditional logic instead of hardcoded
- **Better error messages** - Show evidence, not guesses
- **Less user intervention** - Smart automation handles common issues
