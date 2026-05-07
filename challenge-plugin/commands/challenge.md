---
description: "Challenge a PR with expert agents (Architect, Adversary, Simplifier, Reviewer) for an objective second opinion on design decisions"
argument-hint: "<pr-url-or-number>"
triggers:
  - "challenge pr"
  - "challenge my pr"
  - "challenge this pr"
  - "would this pass review"
  - "stress test my pr"
---

# Challenge PR

Spawn four expert agents to challenge the design decisions in a pull request. Each agent reviews from a distinct lens and delivers a verdict.

**Input:** "$ARGUMENTS"

## Workflow

### 1. Parse Input

Determine the PR to review:
- If the input is a full GitHub URL (contains `github.com`), use it directly with `gh pr view <URL>`
- If the input is a number, resolve it against the current repo with `gh pr view <number>`
- If no input is provided, try `gh pr view` to check if the current branch has an open PR

If no PR can be resolved, tell the user and stop.

### 2. Gather PR Context

Run these commands to collect the PR data:

```bash
gh pr view <PR> --json title,body,baseRefName,headRefName,files,url
```

```bash
gh pr diff <PR>
```

Store the results. You will pass them to all three agents.

### 3. Gather Enriched Context (Optional)

These steps pull additional context when available. Skip gracefully if any step fails — they are enhancements, not requirements.

**Jira ticket context:**
Check if the PR title or branch name contains a Jira ticket ID (pattern: `MWPW-\d+` or similar project keys). If found:
1. Use ToolSearch to load `mcp__corp-jira__search_jira_issues`
2. Call `mcp__corp-jira__search_jira_issues` with the ticket ID to get the ticket description and acceptance criteria
3. Store the ticket summary and acceptance criteria — pass to all agents as "Requirements Context"

If no ticket ID is found, skip this step.

**Project conventions:**
Read the repo's CLAUDE.md file (if it exists) using the Read tool. Store the conventions — pass specifically to the Simplifier agent as "Project Conventions".

**Related open PRs:**
Run `gh pr list --state open --json number,title,files --limit 10` to find other open PRs. Check if any touch overlapping files with the current PR. If found, note them — pass to the Architect agent as "Related PRs".

### 4. Launch Four Agents in Parallel

Spawn all four agents **in a single message** so they run in parallel. Each agent receives a context package tailored to its lens.

For each agent, use the Agent tool with:
- `subagent_type`: the agent name (`challenge:architect`, `challenge:adversary`, `challenge:simplifier`, `challenge:mas-architect`)

**All agents receive (base context):**
- The PR title, description, base branch, and URL
- The complete diff output
- The list of changed files
- Jira requirements context (if gathered)
- Instruction: "Review this PR through your lens. Be direct. Follow your output format exactly."

**Architect additionally receives:**
- Related open PRs touching overlapping files (if gathered)

**Simplifier additionally receives:**
- Project conventions from CLAUDE.md (if gathered)

**MAS architect additionally receives:**
- Instruction: "Read `.claude/commands/mental-model/mas-architect/expertise.yaml` first. Check the diff against the architect's ranked values, red flags, and review vocabulary."

### 5. Present the Challenge Report

After all four agents return, compile the results into this format:

```
-- Challenge Report: <PR title> (<PR URL>) -----

  Architect -- <verdict>
   "<one-line summary>"
   <numbered concerns with file references>

  Adversary -- <verdict>
   "<one-line summary>"
   <numbered concerns with file references>

  Simplifier -- <verdict>
   "<one-line summary>"
   <numbered concerns with file references>

  MAS Architect -- <verdict>
   "<one-line summary>"
   <numbered concerns with value rank and file references>

----------------------------------------------------------------------
```

If an agent has no concerns, show their verdict and summary but note "No concerns raised."

Do NOT add your own commentary, synthesis, or recommendations. Present the four expert opinions and let the user decide what to act on.
