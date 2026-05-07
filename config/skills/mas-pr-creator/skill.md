---
name: mas-pr-creator
description: Automatically detect PR creation intent and guide the process. Extracts JIRA ticket from branch, generates proper PR title and body, runs pre-flight checks, and creates PR using gh CLI. Use when user wants to create/raise/submit a PR.
tags: [pr, pull-request, github, jira, review]
triggers:
  - "create pr"
  - "create pull request"
  - "raise pr"
  - "open pr"
  - "submit pr"
  - "make pr"
  - "ready for review"
  - "ready to create pr"
  - "create a pr"
---

# MAS PR Creator

## Purpose
Automatically detect when user wants to create a pull request and guide them through the MAS-specific PR creation process, ensuring all team standards are met.

## When to Use This Skill

### Automatic Triggers
- User mentions creating/raising/submitting a PR
- User says they're "ready for review"
- User asks about PR process or template
- User asks "how do I create a PR"

### Common Phrases
1. "create pr", "create a pr", "create pull request"
2. "raise pr", "open pr", "submit pr"
3. "ready for review", "ready to submit"
4. "make a pr for this"
5. "can you create a pr"
6. "how do I create a pr for this"

## Quick Reference

### What This Skill Does
1. ✅ Detects PR creation intent
2. ✅ Extracts JIRA ticket from branch name
3. ✅ Runs pre-flight checks (git, linter)
4. ✅ Runs reviewer pre-check via mental model (MAS architect red_flags)
5. ✅ Asks user for short description
6. ✅ Generates proper PR title and body
7. ✅ Invokes `/create-pr` command
8. ✅ Returns PR URL

### Pre-Flight Checks
- Git status (all changes committed?)
- Remote sync (branch pushed?)
- Linter passes
- Branch has JIRA ticket number
- On correct repository

## Workflow

### Step 1: Detect Intent

When user mentions any trigger phrase, immediately activate this skill.

**Examples:**
```
User: "I'm ready to create a PR"
→ Skill activates

User: "Can you open a pull request for this?"
→ Skill activates

User: "Ready for review"
→ Skill activates
```

### Step 2: Validate Environment

Check current repository and branch:

```bash
# Verify we're in MAS repo
pwd | grep -q "/mas" || echo "Not in MAS repo"

# Get current branch
git branch --show-current

# Extract JIRA ticket (MWPW-XXXXX pattern)
branch=$(git branch --show-current)
jira_number=$(echo "$branch" | grep -oE 'MWPW-[0-9]+')
```

**Requirements:**
- Must be in MAS repository
- Branch name must contain JIRA ticket (MWPW-XXXXX format)
- Not on main/master branch

**If validation fails:**
```
❌ Cannot create PR:
- Current branch: feature-branch
- Issue: Branch doesn't contain JIRA ticket number

Please use branch naming: MWPW-XXXXX-description
Example: MWPW-182720-add-position-button
```

### Step 3: Check Git Status

```bash
# Check for uncommitted changes
git status --porcelain

# Check if branch is pushed to remote
git status -sb | grep -q "ahead"
```

**If uncommitted changes:**
```
⚠️ You have uncommitted changes:
M studio/src/editor-panel.js
A studio/src/position-button.js

Please commit your changes first:
  git add .
  git commit -m "Your commit message"

Then try creating the PR again.
```

**If not pushed to remote:**
```
⚠️ Branch not pushed to remote.

Push your branch first:
  git push -u origin MWPW-182720-description

Then try creating the PR again.
```

### Step 4: Run Linter

```bash
npm run lint
```

**If linter fails:**
```
❌ Linter errors found. Please fix before creating PR:

studio/src/editor-panel.js:45 - Unexpected underscore prefix
studio/src/utils.js:120 - Prefer template literals

Fix with:
  npm run lint
```

### Step 4.5: Reviewer Pre-Check (via Mental Model)

Before creating the PR, run an automated check against the MAS architect's review values.

**Spawn an Explore subagent** with this prompt:

> Read `.claude/commands/mental-model/mas-architect/expertise.yaml`.
> Read the git diff for this PR: `git diff main..HEAD`
>
> Check the diff against the architect's red_flags and top 3 values:
> 1. scope_discipline — Are all changes traceable to one ticket?
> 2. factorization_and_reuse — Does any new code duplicate existing utilities?
> 3. no_dead_or_throwaway_code — Is there unused code, console.logs, or one-off scripts?
>
> Also check: precise_naming, wrong_error_semantics, exporting_private_internals.
>
> Return a structured report (under 15 lines):
> - **Pass/Warn/Fail** for each checked value
> - For any Warn/Fail: cite the specific file:line and the red_flag triggered
> - Overall verdict: "Ready for review" or "Fix before submitting"

**If the check returns warnings or failures:**
```
⚠️ Reviewer Pre-Check (MAS architect mental model):

- ❌ scope_discipline: studio/src/utils.js:45 — change unrelated to ticket scope
- ⚠️ factorization_and_reuse: studio/src/locale-helper.js:12 — similar logic exists in paths.js

Recommended: Fix these before creating PR, or the reviewer will likely request changes.
Continue anyway? (yes/fix first)
```

**If the check passes:**
```
✅ Reviewer Pre-Check: No red flags detected. Ready for review.
```

### Step 5: Gather PR Information

**Ask user for description:**
```
What's a short one-line description for this PR?
(Or I can infer from your recent commits)
```

**If user wants auto-description:**
```bash
# Get recent commit messages on this branch
git log main..HEAD --oneline | head -5
```

**Generate suggestion:**
```
Based on your commits, I suggest:
"Add position button to editor panel"

Use this? (yes/no/modify)
```

### Step 6: Invoke Slash Command

Once all checks pass and description gathered:

```
✅ Pre-flight checks passed!
✅ Branch: MWPW-182720-add-position-button
✅ Description: Add position button to editor panel

Creating PR...
```

**Invoke the command:**
```
/create-pr
```

The slash command will:
1. Generate PR title: `MWPW-182720: Add position button to editor panel`
2. Generate PR body with template
3. Create PR via `gh pr create`
4. Return PR URL

### Step 7: Report Success

```
✅ PR Created Successfully!

📋 PR #405: MWPW-182720: Add position button to editor panel
🔗 https://github.com/adobecom/mas/pull/405

Next steps:
1. Verify PR description and checklist
2. Request reviewers
3. Share in #mas-code-reviews Slack channel
4. Prepare demo for Thursday standup
```

## MAS-Specific PR Requirements

### PR Title Format
```
MWPW-NUMBER: Short description in sentence case
```

**Examples:**
- ✅ `MWPW-182720: Add position button to editor panel`
- ✅ `MWPW-181070: Add surface locale / acom locale`
- ❌ `Add position button` (missing ticket)
- ❌ `MWPW-182720 - Add position button` (wrong format)

### PR Body Template

```markdown
[Short description paragraph explaining what this PR does and why]

Resolves https://jira.corp.adobe.com/browse/MWPW-NUMBER
QA Checklist: https://wiki.corp.adobe.com/display/adobedotcom/M@S+Engineering+QA+Use+Cases

Please do the steps below before submitting your PR for a code review or QA

- [ ] C1. Cover code with Unit Tests
- [ ] C2. Add a Nala test (double check with #fishbags if nala test is needed)
- [ ] C3. Verify all Checks are green (unit tests, nala tests)
- [ ] C4. PR description contains working Test Page link where the feature can be tested
- [ ] C5: you are ready to do a demo from Test Page in PR (bonus: write a working demo script that you'll use on Thursday, you can eventually put in your PR)
- [ ] C.6 read your Jira one more time to validate that you've addressed all AC's and nothing is missing

Test URLs:

- Before: https://main--mas--adobecom.aem.live/
- After: https://mwpw-NUMBER--mas--adobecom.aem.live/
```

### Test URLs
Always include test URLs with proper branch naming:
- Before: `https://main--mas--adobecom.aem.live/`
- After: `https://mwpw-NUMBER--mas--adobecom.aem.live/` (lowercase, branch format)

**Branch to URL conversion:**
```
Branch: MWPW-182720-add-position-button
URL: https://mwpw-182720--mas--adobecom.aem.live/
      └─────────┘
      lowercase MWPW-NUMBER only
```

## Common Issues and Solutions

### Issue 1: Branch Without JIRA Ticket

**Problem:**
```bash
$ git branch --show-current
feature-new-button
```

**Solution:**
```
❌ Branch name doesn't contain JIRA ticket number.

Please create a new branch with proper naming:
  git checkout -b MWPW-XXXXX-description

Or rename current branch:
  git branch -m MWPW-XXXXX-new-button
```

### Issue 2: Uncommitted Changes

**Problem:**
```bash
$ git status --porcelain
M studio/src/editor-panel.js
?? studio/src/new-file.js
```

**Solution:**
```
⚠️ You have uncommitted changes. Please commit first:

  git add .
  git commit -m "Add position button functionality"
  git push

Then run this skill again.
```

### Issue 3: Linter Errors

**Problem:**
```bash
$ npm run lint
Error: Unexpected underscore prefix (studio/src/utils.js:45)
```

**Solution:**
```
❌ Linter errors must be fixed before creating PR.

Fix the errors shown above, then try again.
Run: npm run lint
```

### Issue 4: Not on MAS Repository

**Problem:**
```bash
$ pwd
/Users/user/Web/milo
```

**Solution:**
```
❌ This skill is for the MAS repository only.

Current directory: /Users/user/Web/milo
Expected: __MAS_DIR__

Please navigate to the MAS repo and try again.
```

### Issue 5: Already on Main Branch

**Problem:**
```bash
$ git branch --show-current
main
```

**Solution:**
```
❌ Cannot create PR from main branch.

Please create a feature branch first:
  git checkout -b MWPW-XXXXX-description

Make your changes, commit, and push.
Then try creating the PR again.
```

## Advanced Features

### Auto-Description from Commits

If user doesn't provide description, analyze recent commits:

```bash
# Get commit messages since branching from main
git log main..HEAD --oneline --format="%s"
```

**Generate smart description:**
```javascript
// Remove common prefixes
commits = commits.map(msg =>
    msg.replace(/^(fix|feat|chore|refactor|test|docs|style):/i, '')
       .replace(/^MWPW-\d+:?\s*/i, '')
       .trim()
);

// Find common theme or use first meaningful commit
description = inferDescription(commits);
```

### Checklist Pre-Population

Analyze changes to help with checklist:

```bash
# Check for test files
find . -path "*/test/*.test.js" -newer $(git merge-base HEAD main) -type f

# Check for NALA tests
find nala/ -name "*.test.js" -newer $(git merge-base HEAD main) -type f

# Run tests
npm test 2>&1 | grep -q "passing" && echo "✅ Tests passing"
```

**Pre-populate checklist:**
```
Based on your changes:
- ✅ C1: Found new unit tests in test/editor-panel.test.js
- ⚠️ C2: No NALA test found - check with #fishbags if needed
- ✅ C3: All tests passing locally
- ⚠️ C4: Remember to add test URLs to description
- ✅ C5: Demo ready
- ⚠️ C6: Don't forget to validate JIRA ACs
```

### Draft PR Option

Offer to create as draft first:

```
Would you like to create this as a draft PR?
(You can mark it ready for review later)

yes/no
```

If yes:
```bash
gh pr create --draft --title "..." --body "..."
```

## Integration with Other Skills

### After PR Creation

Suggest running PR review:
```
✅ PR created: #405

Want me to run a self-review first?
  /review-pr 405

This will check:
- Getter patterns
- Spectrum imports
- Dead code
- Test coverage
- All MAS coding conventions
```

### Before PR Creation

If major changes, suggest cleanup:
```
I notice you have 15 changed files. Before creating PR:

1. Run linter: npm run lint
2. Check for dead code
3. Verify all tests pass: npm test
4. Build artifacts updated (if needed)

Want me to run these checks? (yes/no)
```

## Output Format

### Success Case

```markdown
🎉 PR Created Successfully!

**PR #405**: MWPW-182720: Add position button to editor panel
**URL**: https://github.com/adobecom/mas/pull/405
**Branch**: MWPW-182720-add-position-button → main

**Description**: Add position button to editor panel that allows reordering merch cards

**Test URLs**:
- Before: https://main--mas--adobecom.aem.live/
- After: https://mwpw-182720--mas--adobecom.aem.live/

---

**Next Steps**:
1. ✅ Review the PR description and checklist
2. ✅ Request reviewers (@team-member-1, @team-member-2)
3. ✅ Share in #mas-code-reviews Slack
4. ✅ Prepare demo for Thursday standup
5. ✅ Validate all JIRA ACs met

**Quick Links**:
- JIRA: https://jira.corp.adobe.com/browse/MWPW-182720
- Test Page: https://mwpw-182720--mas--adobecom.aem.live/
- QA Checklist: https://wiki.corp.adobe.com/display/adobedotcom/M@S+Engineering+QA+Use+Cases

---

Want me to run a self-review?
  /review-pr 405
```

### Failure Case

```markdown
❌ Cannot create PR - Pre-flight checks failed

**Issue 1**: Uncommitted changes
```
M studio/src/editor-panel.js
A studio/src/position-button.js
```

Fix:
  git add .
  git commit -m "Add position button functionality"

**Issue 2**: Linter errors
```
studio/src/utils.js:45 - Unexpected underscore prefix
```

Fix:
  npm run lint

---

After fixing these issues, try again:
  "create pr" or /create-pr
```

## Configuration

### Required Tools
- `gh` CLI (GitHub CLI)
- `git` command line
- `npm` (for linter)

### Check if gh CLI installed:
```bash
command -v gh >/dev/null 2>&1 || echo "gh CLI not installed"
```

If not installed:
```
❌ GitHub CLI (gh) is required for PR creation.

Install it:
  macOS: brew install gh

Then authenticate:
  gh auth login

After setup, try creating PR again.
```

## Best Practices

### 1. Always Run Pre-Flight Checks
Never skip validation - it prevents broken PRs.

### 2. Use Descriptive Titles
PR title should clearly explain what changed:
- ✅ "Add position button to editor panel"
- ❌ "Update editor"

### 3. Include Context in Description
Explain the "why" not just the "what":
```
This PR adds a position button to the editor panel that allows users
to reorder merch cards within a fragment. This addresses the issue
where users couldn't change card order without manual editing.
```

### 4. Verify Test URLs
Before creating PR, manually check test URL works:
```bash
# Test URL should be accessible
curl -I https://mwpw-182720--mas--adobecom.aem.live/
```

### 5. Review Checklist
Make sure you can honestly check all items:
- C1: Tests written and passing
- C2: NALA test added (or confirmed not needed)
- C3: All checks green
- C4: Test URLs working
- C5: Demo prepared
- C6: JIRA ACs validated

## Quick Reference Commands

```bash
# Check if ready for PR
git status
npm run lint
npm test

# Create PR (via skill)
"create pr"

# Create PR (via command)
/create-pr

# Review your own PR
/review-pr <number>

# Check PR status
gh pr view <number>

# Add reviewers
gh pr edit <number> --add-reviewer @username
```

## Success Criteria

Before marking task complete, verify:

- ✅ User intent detected correctly
- ✅ Branch has JIRA ticket number
- ✅ All pre-flight checks passed
- ✅ PR title format correct: `MWPW-NUMBER: Description`
- ✅ PR body includes full template
- ✅ Test URLs included with correct branch name
- ✅ JIRA link correct format
- ✅ PR created successfully
- ✅ PR URL returned to user
- ✅ Next steps provided

## Notes

- This skill should activate automatically on PR intent keywords
- If pre-conditions fail, provide clear guidance instead of erroring
- Always use lowercase for branch name in test URLs
- PR title should be sentence case, not title case
- The slash command `/create-pr` does the actual PR creation
- This skill is the "intent detection + orchestration" layer
