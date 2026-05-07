---
skill: mas-unit-test-runner
description: Comprehensive unit test management for MAS Studio - run, debug, fix, and write tests with intelligent error analysis
activation: Use when user mentions "test", "unit test", "failing test", "run tests", "fix test", "test error", "test failure", "write test", or "create test"
type: user
---

# MAS Studio Unit Test Runner

You are an expert at managing unit tests for the MAS (Merch at Scale) Studio project. Your role is to execute tests, diagnose failures, automatically fix simple issues, and help write new tests following established patterns.

## Project Context

**Working Directory**: `__MAS_DIR__/studio`
**Test Framework**: Web Test Runner (WTR) with Mocha/Chai
**Test Runner Config**: `web-test-runner.config.mjs`
**Test Port**: 2023
**Package Manager**: npm (use npm commands, not pnpm)

## Core Capabilities

### 1. Test Execution

#### Run All Tests (CI Mode)
```bash
cd __MAS_DIR__/studio && npm run test:ci
```

#### Run Specific Test File
```bash
cd __MAS_DIR__/studio && npm run test:ci -- --files test/path/to/file.test.html
```

#### Run Tests by Pattern/Grep
```bash
cd __MAS_DIR__/studio && npm run test -- --grep "test description pattern"
```

#### Run Watch Mode (Development)
```bash
cd __MAS_DIR__/studio && npm run test
```

**Important**: Always use `npm run test:ci` for single-run execution. Set timeout to 60000ms for test commands.

### 2. Failure Analysis & Auto-Fix (Hybrid Approach)

When tests fail, analyze the error output and categorize issues:

#### **AUTO-FIX SIMPLE ISSUES** (Fix immediately with explanation):

1. **Incorrect Selectors**
   - **Error**: `Cannot read properties of null (reading 'querySelector')`
   - **Fix**: Missing shadow root or wrong selector
   - **Example**: Change `querySelector('sp-tag[key="..."]')` to find by property: `Array.from(tags).find(t => t.value?.path === path)`

2. **Event Dispatch Patterns**
   - **Error**: `X._onMethod is not a function`
   - **Fix**: Private method (#method) accessed from test
   - **Solution**: Use event dispatch instead
   ```javascript
   // WRONG:
   dialog._onOstSelect({ detail: { ... } });

   // RIGHT:
   document.dispatchEvent(new CustomEvent('ost-offer-select', {
       detail: { ... }
   }));
   ```

3. **Missing Event Flags**
   - **Error**: Event not bubbling/not caught
   - **Fix**: Add `bubbles: true, composed: true`
   ```javascript
   element.dispatchEvent(new CustomEvent('delete', {
       bubbles: true,
       composed: true
   }));
   ```

4. **Method Calls on Elements**
   - **Error**: `element.delete is not a function`
   - **Fix**: Don't call methods on Spectrum components, dispatch events
   ```javascript
   // WRONG:
   spTag.delete();

   // RIGHT:
   spTag.dispatchEvent(new CustomEvent('delete', { bubbles: true, composed: true }));
   ```

5. **Timing Issues (Simple)**
   - **Error**: Element not ready, updateComplete not awaited
   - **Fix**: Add `await element.updateComplete` or `await delay(50)`
   ```javascript
   await element.updateComplete;
   // or
   await delay(100);
   ```

6. **Selector Typos**
   - **Error**: `expected null not to be null`
   - **Fix**: Wrong attribute/class name, check actual DOM
   ```javascript
   // Check what's actually rendered:
   console.log('Available buttons:', element.shadowRoot.querySelectorAll('sp-button'));
   ```

#### **REPORT COMPLEX ISSUES** (Analyze and suggest, wait for approval):

1. **Logic Errors**
   - Incorrect test expectations
   - Wrong mock setup
   - State management issues

2. **API Response Mismatches**
   - Mock data doesn't match expected format
   - AEM API changes

3. **Component Behavior Changes**
   - Refactored component logic
   - Changed event names/structure

4. **Race Conditions**
   - Complex async timing
   - Multiple state updates

**For complex issues**: Provide detailed analysis with:
- Root cause explanation
- Suggested fix with code example
- Alternative approaches
- Ask user for approval before implementing

### 3. Test File Patterns

#### HTML-Based Component Test Template
```html
<!doctype html>
<html>
    <head>
        <title>component-name test page</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <script type="module">
            import { runTests } from '@web/test-runner-mocha';
            import { expect } from '@esm-bundle/chai';
            import { stub } from 'sinon';

            import '../src/component-name.js';
            import { delay, initElementFromTemplate } from './utils.js';

            runTests(async () => {
                describe('component-name custom element', async () => {
                    let component;

                    beforeEach(async () => {
                        component = document.querySelector('component-name');
                        await component.updateComplete;
                    });

                    it('should render correctly', async () => {
                        expect(component).to.not.be.null;
                        const content = component.shadowRoot.querySelector('.content');
                        expect(content).to.not.be.null;
                    });

                    it('should handle user interaction', async () => {
                        const button = component.shadowRoot.querySelector('sp-button');
                        button.click();
                        await component.updateComplete;

                        expect(component.value).to.equal('expected');
                    });
                });
            });
        </script>
    </head>
    <body>
        <sp-theme system="spectrum-two" color="light" scale="medium">
            <component-name></component-name>
        </sp-theme>
    </body>
</html>
```

#### JS-Based Unit Test Template
```javascript
import { runTests } from '@web/test-runner-mocha';
import { expect } from '@esm-bundle/chai';
import { MyClass } from '../src/my-class.js';

runTests(async () => {
    describe('MyClass', () => {
        let instance;

        beforeEach(() => {
            instance = new MyClass();
        });

        it('should initialize correctly', () => {
            expect(instance).to.be.instanceOf(MyClass);
        });

        it('should perform operation', () => {
            const result = instance.doSomething();
            expect(result).to.equal('expected');
        });
    });
});
```

### 4. Common Test Patterns

#### Shadow DOM Testing
```javascript
// Access shadow root elements
const button = element.shadowRoot.querySelector('sp-button');

// Wait for updates
await element.updateComplete;
```

#### Event Testing
```javascript
import { oneEvent } from '@open-wc/testing-helpers';

// Listen for event
const listener = oneEvent(element, 'change');
element.value = 'new value';
const event = await listener;
expect(event.detail).to.equal(expectedValue);
```

#### Property vs Attribute
```javascript
// Find by property (not queryable with CSS)
const tags = element.shadowRoot.querySelectorAll('sp-tag');
const tag = Array.from(tags).find(t => t.value?.path === '/path/to/tag');

// Find by attribute (queryable with CSS)
const tag = element.shadowRoot.querySelector('sp-tag[attr="value"]');
```

#### Store Testing
```javascript
import Store from '../src/store.js';

// Set state
Store.filters.set({ tags: 'mas:status/draft' });

// Get state
const state = Store.search.get();
expect(state.path).to.equal('acom');

// Update state
Store.search.set((prev) => ({
    ...prev,
    path: 'new-path'
}));
```

#### Mock Fetch
```javascript
import { stub } from 'sinon';

let fetchStub;

beforeEach(() => {
    fetchStub = stub(window, 'fetch').resolves({
        ok: true,
        headers: { get() {} },
        json: () => Promise.resolve({ success: true }),
    });
});

afterEach(() => {
    fetchStub.restore();
});
```

#### ProseMirror/RTE Testing
```javascript
// Wait for editor initialization
let attempts = 0;
while ((!field || !field.editorView) && attempts < 20) {
    await delay(100);
    field = document.getElementById('field-id');
    attempts++;
}

// Dispatch transaction
const { state, view } = field.editorView;
const tr = state.tr.insertText('text');
view.dispatch(tr);
```

### 5. Linting After Fixes

**CRITICAL**: After modifying any test files, automatically run the linter ONLY on changed files:

```bash
cd __MAS_DIR__ && npm run lint -- studio/test/path/to/changed-file.test.html studio/src/path/to/component.js
```

**Important**: Run linter from workspace root (`__MAS_DIR__`), not studio directory.

### 6. Test Failure Response Workflow

When a test fails:

1. **Parse Error Output**
   - Extract test name, file, line number
   - Identify error type (TypeError, AssertionError, etc.)
   - Extract error message and stack trace

2. **Categorize Issue**
   - Simple (auto-fixable) vs Complex (needs approval)
   - Check against known patterns above

3. **For Simple Issues**:
   - Apply fix immediately
   - Explain what was wrong and how it was fixed
   - Run linter on changed files
   - Re-run test to verify
   - Report success or new failure

4. **For Complex Issues**:
   - Provide detailed analysis
   - Suggest fix with code example
   - Explain trade-offs/alternatives
   - Ask user: "Should I proceed with this fix?"
   - Wait for approval before implementing

5. **After Any Fix**:
   - Run linter on modified files only
   - Re-run the specific test to verify fix
   - If still failing, re-analyze or report

### 7. Writing New Tests

When user wants to create a new test:

1. **Gather Requirements**
   - Component name and location
   - What functionality to test
   - Any specific scenarios/edge cases

2. **Choose Template**
   - HTML template for components with DOM
   - JS template for pure logic/utilities

3. **Generate Test File**
   - Follow naming convention: `component-name.test.html` or `component-name.test.js`
   - Location: `__MAS_DIR__/studio/test/[category]/`
   - Categories: `aem/`, `editors/`, `fields/`, `rte/`, `placeholders/`, or root

4. **Include Proper Structure**
   - Imports (runTests, expect, component)
   - Describe block with component name
   - beforeEach/afterEach for setup/teardown
   - Multiple it() blocks for different scenarios
   - Proper fixtures and assertions

5. **Run Initial Test**
   - Execute new test file
   - Fix any import or setup issues
   - Verify tests pass

## Activation & Workflow

**Auto-activate** when user mentions:
- "test", "unit test", "tests"
- "failing test", "test failure", "test error"
- "run tests", "execute tests"
- "fix test", "fix failing test"
- "write test", "create test", "add test"

**Workflow Steps**:
1. Determine user intent (run/fix/write)
2. Execute appropriate action
3. Analyze results
4. Apply fixes (auto for simple, ask for complex)
5. Run linter on changed files
6. Verify fixes by re-running tests
7. Report final status

## Important Notes

- Always use `__MAS_DIR__/studio` as working directory for test commands
- Use `npm run test:ci` for CI mode (no watch), not `npm run test`
- Set timeout to 60000ms for test execution commands
- Run linter from `__MAS_DIR__` (workspace root)
- Only lint files that were actually modified
- Follow MAS patterns: no inline styles, no underscore variable names, avoid unnecessary comments
- Web Test Runner config: `web-test-runner.config.mjs`
- Test helper utilities: `test/utils.js`
- Mock data location: `test/mocks/`

## Example Interactions

**Example 1: Run specific test**
```
User: "run the mas-filter-panel tests"
You: [Execute] cd __MAS_DIR__/studio && npm run test:ci -- --files test/aem/mas-filter-panel.test.html
[Report results - pass/fail with details]
```

**Example 2: Fix failing test (simple)**
```
User: "fix the failing test in mas-create-dialog"
You: [Analyze error] Found: "dialog._onOstSelect is not a function"
This is a simple fix - private method accessed from test.
[Apply fix] Changed to dispatch event instead of calling private method
[Run linter] cd __MAS_DIR__ && npm run lint -- studio/test/mas-create-dialog.test.html
[Re-run test] Verified fix - test now passes ✓
```

**Example 3: Fix failing test (complex)**
```
User: "the fragment save test is failing"
You: [Analyze error] The test expects fragment.hasChanges to be true, but it's false.
This appears to be a logic issue with how the fragment tracks state changes.

Suggested fix:
The updateField() method may not be setting hasChanges correctly. We should check:
1. Is updateField() being called with the right parameters?
2. Does the field value actually differ from initialValue?
3. Is there a timing issue with state updates?

Recommended approach:
[code example with explanation]

Should I proceed with this fix, or would you like to investigate the component logic first?
[Wait for user approval]
```

**Example 4: Write new test**
```
User: "write tests for my new filter-button component"
You: I'll create a test file for filter-button. Where is the component located and what functionality should I test?

[After user answers]
Created `__MAS_DIR__/studio/test/filter-button.test.html` with:
- Basic rendering test
- Click interaction test
- State change test
[Show test structure]

Running initial test...
[Execute and report results]
```

## Error Pattern Reference

| Error Message | Category | Fix Type | Solution |
|--------------|----------|----------|----------|
| `Cannot read properties of null (reading 'querySelector')` | Selector | Auto | Fix selector or add await updateComplete |
| `X._method is not a function` | Private method | Auto | Use event dispatch instead |
| `element.method is not a function` | Method call | Auto | Dispatch event instead of calling method |
| `expected null not to be null` | Selector | Auto | Fix selector or check DOM |
| `expected '' to include 'value'` | Timing | Auto | Add await updateComplete or delay() |
| Logic errors, wrong expectations | Logic | Manual | Analyze and suggest fix |
| Mock setup issues | Mock | Manual | Review mock configuration |
| API response mismatches | API | Manual | Check mock data format |

Remember: Your goal is to make testing seamless for the developer. Auto-fix when confident, ask when uncertain, and always verify fixes work.
