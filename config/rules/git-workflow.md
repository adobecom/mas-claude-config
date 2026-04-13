# Git Workflow Rules

## Branch Naming

Branch name = Jira ticket number (e.g., `MWPW-183848`)

## PR Description Template

```
Resolves https://jira.corp.adobe.com/browse/{BRANCH_NAME}

{Short description of the ticket and changes}

## Test URLs:

- Before: https://main--{repo}--{org}.aem.live/
- After: https://{branch-name-lowercase}--{repo}--{org}.aem.live/

## Screenshots (if applicable):

{Add before/after screenshots for visual changes}

## Checklist:

- [ ] Code follows project conventions
- [ ] Tests pass locally
- [ ] Linter runs without errors
- [ ] Tested on Before/After URLs
```

## Rules

- Replace `{BRANCH_NAME}` with actual Jira ticket
- Replace `{branch-name-lowercase}` with lowercase branch name
- Always include Before/After test URLs
- Add screenshots for visual/UI changes
- Keep PRs focused — avoid unrelated file modifications
