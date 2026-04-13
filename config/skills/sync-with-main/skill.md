---
name: sync-with-main
description: Safely sync feature branch with main, auto-resolve dist conflicts, rebuild bundles, and push. Use when updating branch from main, resolving merge conflicts, or preparing for PR. Activates on "sync with main", "merge main", "update from main", "resolve conflicts".
tags: [git, merge, sync, build, dist]
triggers:
  - "sync with main"
  - "merge main"
  - "update from main"
  - "pull from main"
  - "resolve conflicts"
  - "update branch"
  - "rebase main"
  - "merge from main"
---

# Sync With Main

## Purpose

Automate the common workflow of syncing a feature branch with main, handling conflicts in generated bundle files, rebuilding dependencies, and pushing to remote. This is especially useful in the MAS project where `web-components/dist/` files frequently conflict due to concurrent feature development.

## When to Use This Skill

### Automatic Triggers
- User mentions syncing or merging with main
- User has conflicts to resolve
- User wants to update their feature branch
- Before creating a PR (to ensure branch is current)

### Common Phrases
1. "sync with main", "sync my branch"
2. "merge main into my branch"
3. "update from main", "update branch"
4. "resolve conflicts", "fix conflicts"
5. "pull latest from main"
6. "rebase on main"

## Quick Reference

### What This Skill Does
1. ✅ Pre-flight checks (clean state, correct branch)
2. ✅ Fetch latest from origin
3. ✅ Merge main into current branch
4. ✅ Auto-resolve dist file conflicts (rebuild anyway)
5. ✅ Stop and prompt for source file conflicts
6. ✅ Run npm install (handle new dependencies)
7. ✅ Run npm run build (regenerate bundles)
8. ✅ Run npm run lint (verify code quality)
9. ✅ Commit and push to remote

### Files Auto-Resolved (No User Action)
- `web-components/dist/*` (18 bundle files)
- `*.map` source map files
- `package-lock.json`

### Files Requiring Manual Resolution
- Any `src/` source files
- Test files (`*.test.js`)
- Configuration files (`.json`, `.mjs`, etc.)

## Workflow

### Step 1: Pre-Flight Checks

```bash
# Check current branch (must not be main)
branch=$(git branch --show-current)
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  echo "Cannot sync main with itself"
  exit 1
fi

# Check for uncommitted changes
status=$(git status --porcelain)
if [ -n "$status" ]; then
  echo "Warning: You have uncommitted changes"
fi

# Verify remote is accessible
git ls-remote --exit-code origin main
```

**If on main branch:**
```
❌ Cannot sync main with itself.

You're currently on the main branch. Please checkout your feature branch:
  git checkout MWPW-XXXXX-description
```

**If uncommitted changes:**
```
⚠️ You have uncommitted changes:
M studio/src/editor-panel.js
A studio/src/new-file.js

Options:
1. Commit them first: git add . && git commit -m "WIP"
2. Stash them: git stash
3. Continue anyway (changes will be included in merge commit)

How would you like to proceed? (commit/stash/continue)
```

### Step 2: Fetch and Merge

```bash
# Fetch latest from origin
git fetch origin main

# Merge main into current branch
git merge origin/main
```

**Three possible outcomes:**
1. **No conflicts** → Continue to Step 4
2. **Only dist/auto-resolvable conflicts** → Continue to Step 3
3. **Source file conflicts** → Stop and prompt user

### Step 3: Conflict Resolution

**Detect conflict types:**
```bash
# Get list of conflicting files
conflicts=$(git diff --name-only --diff-filter=U)

# Categorize conflicts
dist_conflicts=$(echo "$conflicts" | grep "^web-components/dist/")
lock_conflicts=$(echo "$conflicts" | grep "package-lock.json")
map_conflicts=$(echo "$conflicts" | grep "\.map$")
src_conflicts=$(echo "$conflicts" | grep -v "^web-components/dist/" | grep -v "package-lock.json" | grep -v "\.map$")
```

**Auto-resolve dist files:**
```bash
# Accept theirs for dist files (will be rebuilt anyway)
git checkout --theirs web-components/dist/
git add web-components/dist/

# Accept theirs for package-lock.json (npm install will fix)
if [ -n "$lock_conflicts" ]; then
  git checkout --theirs package-lock.json
  git add package-lock.json
fi

# Accept theirs for source maps
if [ -n "$map_conflicts" ]; then
  for file in $map_conflicts; do
    git checkout --theirs "$file"
    git add "$file"
  done
fi
```

**Stop for source file conflicts:**
```
⚠️ Source file conflicts detected that require manual resolution:

Conflicting files:
  - studio/src/mas-fragment-editor.js
  - web-components/src/merch-card.js
  - nala/tests/card.test.js

Please resolve these conflicts manually using your editor, then run:
  /sync-with-main continue

To see the conflicts:
  git diff --name-only --diff-filter=U

To abort the merge:
  git merge --abort
```

### Step 4: Rebuild Dependencies

```bash
# Install any new dependencies
npm install

# Rebuild all packages (regenerates dist files)
npm run build

# Run linter
npm run lint
```

**If build fails:**
```
❌ Build failed. Please fix the errors before continuing:

[build error output]

After fixing, run:
  npm run build
  /sync-with-main continue
```

**If lint fails:**
```
⚠️ Linter errors found:

studio/src/file.js:45 - Unexpected underscore prefix

Fix with: npm run lint
Then run: /sync-with-main continue
```

### Step 5: Commit and Push

```bash
# Stage all changes
git add .

# Create merge commit
git commit -m "Merge main into $branch, rebuild dist files"

# Push to remote
git push origin $branch
```

**Commit message format:**
```
Merge main into MWPW-185783, rebuild dist files
```

## Continue Command

When user runs `/sync-with-main continue` after resolving conflicts:

```bash
# Verify no more conflicts
remaining=$(git diff --name-only --diff-filter=U)
if [ -n "$remaining" ]; then
  echo "Still have unresolved conflicts:"
  echo "$remaining"
  exit 1
fi

# Continue from Step 4 (rebuild)
npm install
npm run build
npm run lint

# Stage and commit
git add .
git commit -m "Merge main into $branch, resolve conflicts"
git push origin $branch
```

## Common Issues and Solutions

### Issue 1: Merge Already in Progress

**Problem:**
```bash
$ git merge origin/main
error: Merging is not possible because you have unmerged files.
```

**Solution:**
```
⚠️ A merge is already in progress.

Options:
1. Continue the merge: /sync-with-main continue
2. Abort and start fresh: git merge --abort
```

### Issue 2: Build Fails After Merge

**Problem:**
```bash
$ npm run build
Error: Cannot find module './utils'
```

**Solution:**
```
❌ Build failed due to missing imports or broken code.

This usually happens when main introduced changes that conflict
with your feature branch at the code level, not just in dist files.

Steps to fix:
1. Review the error above
2. Fix the import/code issue
3. Run: npm run build
4. Run: /sync-with-main continue
```

### Issue 3: Cannot Push (Behind Remote)

**Problem:**
```bash
$ git push
error: failed to push some refs
hint: Updates were rejected because the remote contains work
```

**Solution:**
```
⚠️ Remote branch has new changes since you started.

The branch was updated while you were resolving conflicts.

Options:
1. Force push (if you're sure): git push --force-with-lease
2. Pull and merge again: git pull origin $branch

Recommended: Use --force-with-lease (safer than --force)
```

### Issue 4: Large Number of Conflicts

**Problem:**
Many dist files conflicting (normal when main has many changes).

**Solution:**
```
📋 Found 18 conflicting dist files.

These are auto-generated bundles that will be rebuilt.
Auto-resolving all dist conflicts and rebuilding...

[Proceeds automatically]
```

## Output Format

### Success Case (No Conflicts)

```markdown
✅ Branch synced with main successfully!

**Branch**: MWPW-185783
**Merged from**: origin/main

**Actions taken**:
1. ✅ Fetched latest from origin/main
2. ✅ Merged with no conflicts
3. ✅ Installed dependencies
4. ✅ Rebuilt all bundles (18 dist files)
5. ✅ Linter passed
6. ✅ Committed: "Merge main into MWPW-185783, rebuild dist files"
7. ✅ Pushed to origin

Your branch is now up-to-date with main!

**Next steps**:
- Continue working on your feature
- Or create a PR: /create-pr
```

### Success Case (Auto-Resolved Conflicts)

```markdown
✅ Branch synced with main successfully!

**Branch**: MWPW-185783
**Merged from**: origin/main

**Conflicts auto-resolved**:
- web-components/dist/mas.js
- web-components/dist/commerce.js
- web-components/dist/merch-card.js
- (+ 15 more dist files)
- package-lock.json

**Actions taken**:
1. ✅ Fetched latest from origin/main
2. ✅ Auto-resolved 18 dist conflicts
3. ✅ Installed dependencies
4. ✅ Rebuilt all bundles
5. ✅ Linter passed
6. ✅ Committed: "Merge main into MWPW-185783, resolve dist conflicts"
7. ✅ Pushed to origin

Your branch is now up-to-date with main!
```

### Paused Case (Manual Resolution Needed)

```markdown
⚠️ Sync paused - manual resolution required

**Branch**: MWPW-185783
**Merged from**: origin/main

**Auto-resolved** (18 files):
- web-components/dist/* (all rebuilt)
- package-lock.json

**Requires manual resolution** (2 files):
- studio/src/mas-fragment-editor.js
- web-components/src/merch-card.js

**Instructions**:
1. Open each conflicting file in your editor
2. Look for conflict markers: <<<<<<< HEAD
3. Resolve each conflict (keep your changes, their changes, or both)
4. Save the files
5. Run: /sync-with-main continue

**Useful commands**:
- See all conflicts: git diff --name-only --diff-filter=U
- Abort merge: git merge --abort
- Open conflicts in VS Code: code $(git diff --name-only --diff-filter=U)
```

### Failure Case

```markdown
❌ Sync failed

**Issue**: Build failed after merge

**Error**:
```
Error: Cannot find module './new-util'
at studio/src/editor.js:15
```

**What happened**:
The merge completed, but the build failed. This means there are
code-level incompatibilities between main and your branch.

**To fix**:
1. Review the error above
2. Fix the missing import or code issue
3. Run: npm run build
4. If build succeeds, run: /sync-with-main continue

**To abort**:
  git merge --abort
  git reset --hard HEAD~1
```

## Best Practices

### 1. Sync Frequently
Don't let your branch drift too far from main:
- Sync at least once per day if main is active
- Sync before creating a PR

### 2. Commit Before Syncing
Always commit or stash your work before syncing:
```bash
git add .
git commit -m "WIP: current progress"
```

### 3. Review Conflicts Carefully
For source file conflicts:
- Understand what main changed and why
- Understand what your branch changed and why
- Merge intentionally, don't just accept one side

### 4. Test After Syncing
After sync completes, test your feature still works:
```bash
npm test
# Manual testing on test URL
```

### 5. Use Descriptive Commit Messages
The auto-generated commit message includes context:
```
Merge main into MWPW-185783, resolve dist conflicts
```

## Integration with Other Skills

### Before Creating a PR
```
Want to sync with main before creating PR?
This ensures your branch is up-to-date.

  /sync-with-main

Then:
  /create-pr
```

### After Sync Completes
```
✅ Sync complete!

Suggestions:
- Run tests: npm test
- Create PR: /create-pr
- Review changes: git log --oneline main..HEAD
```

## Success Criteria

Before marking sync complete, verify:

- ✅ Pre-flight checks passed
- ✅ Fetch from origin successful
- ✅ Merge completed (with or without conflict resolution)
- ✅ All dist conflicts auto-resolved
- ✅ Source conflicts resolved by user (if any)
- ✅ npm install succeeded
- ✅ npm run build succeeded
- ✅ npm run lint passed
- ✅ Changes committed
- ✅ Pushed to remote origin

## Quick Reference Commands

```bash
# Full sync (this skill)
/sync-with-main

# Continue after resolving conflicts
/sync-with-main continue

# Manual equivalent
git fetch origin main
git merge origin/main
npm install
npm run build
npm run lint
git add .
git commit -m "Merge main, rebuild dist"
git push

# Abort merge if things go wrong
git merge --abort

# Check conflict status
git diff --name-only --diff-filter=U

# View what main changed
git log HEAD..origin/main --oneline
```

## Notes

- This skill auto-resolves dist file conflicts because they are always regenerated from source
- Source file conflicts require human judgment and are never auto-resolved
- The skill supports a "continue" command to resume after manual conflict resolution
- Always pushes to remote after successful sync
- Uses `--force-with-lease` if needed (safer than `--force`)
- Commit messages include branch name and conflict resolution context
