---
name: start-ticket
description: Start working on a NEW or UNFAMILIAR Jira ticket — gathers Jira context, FluffyJaws research, and codebase analysis into a structured briefing. Only invoke when explicitly asked to "start", "begin", or "pick up" a ticket, NOT for switching context on an already-known ticket.
tags: [jira, ticket, start, worktree, context, planning]
triggers:
  - "start ticket"
  - "start working on MWPW"
  - "pick up MWPW"
  - "begin ticket"
  - "start MWPW"
  - "let me start MWPW"
  - "starting MWPW"
  - "start-ticket"
do_not_trigger:
  - "switch to MWPW"
  - "let's switch to MWPW"
  - "continue working on MWPW"
  - "resume MWPW"
  - "go back to MWPW"
  - "back to MWPW"
  - "switch back to MWPW"
---

# Start Ticket

## Intent Detection

When the user mentions starting work on a Jira ticket, extract the ticket number:

1. Look for `MWPW-\d+` pattern in the user's message
2. If not found, check the current git branch: `git branch --show-current`
3. If still not found, ask: "What MWPW ticket are you working on?"

## Execution

Once you have the ticket number (`TICKET`), follow these phases in order.

### Phase 2: Worktree Check

Run:
```bash
cd __ADOBE_DIR__ && bash worktrees/wt list
```

Check if `TICKET` appears in the output:
- **Worktree exists**: Note the path and port assignment. Report it to the user.
- **No worktree**: Ask the user: "No worktree found for TICKET. Would you like me to create one?" If yes, run `bash worktrees/wt new TICKET` from `__ADOBE_DIR__`.

After resolving the worktree, update the statusline tracker:
```bash
echo "TICKET" > ~/.claude/active-worktree
```

### Phase 3: Jira Context (sequential — runs first)

Launch **1 agent** to fetch Jira context. This must complete before Phase 4 because its output feeds the downstream agents.

Prompt the agent with:
> Gather full context for Jira ticket TICKET.
>
> 1. Call `mcp__corp-jira__search_jira_issues` with JQL: `key = TICKET`
>    Extract: summary, description, acceptance criteria, status, assignee, priority, linked issues, epic
> 2. Call `mcp__corp-jira__get_jira_comments` with issueKey: TICKET
>    Extract: last 5 comments with authors and dates
> 3. Call `mcp__fluffyjaws__jira_ticket_search` with the ticket ID for enriched context
>
> Return a structured summary with: Title, Description, Acceptance Criteria (numbered), Status, Assignee, Priority, Linked Issues, and Key Comments.

Once this agent returns, store the **ticket summary**, **description**, and **key terms** (component names, feature areas) for use in Phase 4.

### Phase 4: Codebase + FluffyJaws Research (parallel — uses Jira context)

Launch **2 agents in parallel** (both in a single message with multiple Agent tool calls). Pass the Jira summary and key terms from Phase 3 to both agents.

**Agent A: Codebase Explorer** (subagent_type: Explore)

> I'm starting work on Jira ticket TICKET: "[paste ticket title and description from Phase 3]"
>
> Key terms from the ticket: [extract component names, feature areas, and technical keywords from the Jira description]
>
> Search the MAS codebase at __MAS_DIR__ for files related to this ticket.
> Based on the ticket topic, search for:
> - Relevant component files in `studio/src/`, `web-components/src/`
> - Related test files in `nala/`, `web-components/test/`
> - Configuration or model files that might be affected
> - Similar past implementations or patterns
> - Predecessor ticket commits (check `git log --oneline --grep="PREDECESSOR_TICKET"` for any linked issues)
>
> Return: list of relevant files with brief purpose annotations, existing test coverage for affected areas, and any related patterns found.

**Agent B: FluffyJaws Research**

> Search for additional context about Jira ticket TICKET: "[paste ticket title from Phase 3]"
>
> Key terms: [component names, feature areas from Jira description]
>
> 1. Call `mcp__fluffyjaws__slack_search` with query: "TICKET" to find Slack discussions
> 2. Call `mcp__fluffyjaws__slack_search` with key component/feature terms from the ticket (e.g., "pagination studio", "card picker performance")
> 3. Call `mcp__fluffyjaws__wiki_documentation_search` with the specific feature/component keywords
> 4. Call `mcp__fluffyjaws__full_documentation_search` with the feature topic for broader docs
>
> Return: relevant Slack discussions (summarized), wiki/documentation links, architectural context, and any team decisions found.

### Phase 5: Context Synthesis

After all agents return, combine their findings into a structured briefing:

```
# Ticket Briefing: TICKET

## Summary
[One-paragraph summary from Jira description]

## Acceptance Criteria
1. [From Jira ticket]
2. ...

## Status
- **Status**: [current status]
- **Assignee**: [assignee]
- **Priority**: [priority]
- **Epic/Parent**: [if any]

## Codebase Impact
- **Primary files**: [list from explorer agent]
- **Test coverage**: [existing tests for affected areas]
- **Related patterns**: [similar implementations found]

## Additional Context
- **Slack discussions**: [key points from FluffyJaws]
- **Wiki/docs**: [relevant links]
- **Related tickets**: [linked issues from Jira]

## Key Comments
[Notable discussion points from Jira comments]

## Worktree
- **Status**: [created/exists/not created]
- **Path**: [worktree path if applicable]
- **AEM port**: [port if applicable]
```

### Phase 6: Next Steps

After presenting the briefing, suggest appropriate next steps based on ticket complexity:

- **Complex feature** (multiple acceptance criteria, architectural impact): "This looks like a substantial feature. I'd recommend running `/speckit.specify` to create a spec, then `/speckit.plan` for implementation planning."
- **Medium task** (clear scope, few files): "This has clear scope. Want to jump into planning with `/speckit.plan`, or start coding directly?"
- **Simple fix** (single file, obvious change): "This looks straightforward. Want to start coding?"

Do NOT automatically transition to the next step. Wait for the user to decide.
