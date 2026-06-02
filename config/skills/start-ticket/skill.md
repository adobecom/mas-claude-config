---
name: start-ticket
description: Start working on a NEW or UNFAMILIAR Jira ticket — gathers Jira context, runs targeted codebase analysis, and only pulls FluffyJaws (Slack/wiki) research when the ticket actually needs it. Only invoke when explicitly asked to "start", "begin", or "pick up" a ticket, NOT for switching context on an already-known ticket.
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

Launch **1 agent** to fetch Jira context. This must complete before Phase 4 because its output feeds Phase 3.5 triage and the downstream agents.

**Do NOT call any FluffyJaws tools in this phase.** Phase 3 is corp-jira only — FluffyJaws (if needed) belongs in Phase 4 as a single gated unit.

Prompt the agent with:
> Gather full context for Jira ticket TICKET.
>
> 1. Call `mcp__corp-jira__search_jira_issues` with JQL: `key = TICKET`
>    Extract: summary, description, acceptance criteria, status, assignee, reporter, priority, linked issues, epic
> 2. Call `mcp__corp-jira__get_jira_comments` with issueKey: TICKET
>    Extract: last 5 comments with authors and dates
>
> Return a structured summary with: Title, Description (verbatim — preserve file:line references, quoted code, and technical keywords), Acceptance Criteria (numbered), Status, Assignee, Reporter, Priority, Linked Issues, and Key Comments. Also preserve technical keywords, component names, and feature areas verbatim — they'll be used as search anchors downstream.

Once this agent returns, store the **ticket summary**, **description**, **reporter/assignee identity**, and **key terms** (component names, feature areas) for Phase 3.5 and Phase 4.

### Phase 3.5: Triage (decide what Phase 4 actually needs)

Before launching Phase 4 agents, evaluate the Jira summary against a small set of deterministic checks. **No tool calls in this phase** — pure inspection of Phase 3 output.

#### FluffyJaws gate (default: SKIP)

Run FluffyJaws in Phase 4 **only if at least one** of these conditions holds:

- **No verified RCA in description**: Description does NOT contain phrases like `root cause`, `verified`, `evidence`, `repro`, `confirmed`, or explicit `file.js:line` references.
- **Cross-team / cross-repo signal**: Description or linked issues mention CC, Express, DA, Milo blocks, Odin, or other consumer surfaces — context likely lives in Slack/wiki, not just the MAS codebase.
- **Sparse description**: Description is fewer than ~300 characters and lacks ACs — the ticket reporter expects you to dig.
- **Story or epic with > 3 ACs**: Larger scope where team decisions and prior Slack discussion matter.

**Skip FluffyJaws if**: Description has file:line evidence AND a stated root cause / proposed fix AND reporter == current user (you filed it yourself, you already have context). This is the common "verified bug fix" path.

Record the decision as `fjGate = "run"` or `fjGate = "skip"` and use it in Phase 4.

#### Codebase Explorer mode

Pick the right prompt shape for Phase 4 Agent A:

- **`verify` mode**: Phase 3 returned ≥ 1 explicit `path/file.{js,ts,jsx}:\d+` reference → the description names the code. Job is to confirm those locations still exist + surface adjacent tests.
- **`discover` mode**: No file references in the description → search the codebase by keywords/components.

Record the decision as `codebaseMode = "verify"` or `codebaseMode = "discover"`.

### Phase 4: Codebase + (optional) FluffyJaws Research

Launch agents **in parallel** (single message with multiple Agent tool calls). Always launch the Codebase Explorer. Launch FluffyJaws **only if Phase 3.5 set `fjGate = "run"`**.

**Agent A: Codebase Explorer** (subagent_type: Explore)

Use the prompt that matches `codebaseMode`:

##### verify-mode prompt:
> I'm starting work on Jira ticket TICKET: "[paste ticket title]"
>
> The description names these specific code locations: [list each file:line reference verbatim from Phase 3].
>
> For each reference:
> - Verify the file still exists at that path
> - Verify the named symbol (function/getter/method) is still at that line (note any drift)
> - Read 5-10 lines of surrounding context
>
> Then locate:
> - Existing unit tests for the named files (look in `studio/test/`, `web-components/test/`, neighboring `test/` dirs)
> - Any NALA E2E tests touching the same feature area
> - Constants or shared utilities referenced in the cited code
>
> Return a concise file:line listing with one-line annotations. Keep output under 30 lines. **Do NOT propose fixes** — just verify the map.

##### discover-mode prompt:
> I'm starting work on Jira ticket TICKET: "[paste ticket title and description]"
>
> Key terms from the ticket: [extract component names, feature areas, technical keywords]
>
> Search the MAS codebase at __MAS_DIR__ for files related to this ticket:
> - Relevant component files in `studio/src/`, `web-components/src/`, `io/`
> - Related test files in `nala/`, `studio/test/`, `web-components/test/`
> - Configuration or model files that might be affected
> - Similar past implementations or patterns
> - Predecessor ticket commits (`git log --oneline --grep="PREDECESSOR_TICKET"` for each linked issue)
>
> Return: list of relevant files with brief purpose annotations, existing test coverage, and any related patterns found. Keep output under 30 lines.

**Agent B: FluffyJaws Research** — only if `fjGate = "run"`

> Search for additional context about Jira ticket TICKET: "[paste ticket title]"
>
> Key terms: [component names, feature areas]
>
> 1. Call `mcp__fluffyjaws__slack_search` with query: "TICKET" to find Slack discussions
> 2. Call `mcp__fluffyjaws__slack_search` with key component/feature terms from the ticket
> 3. Call `mcp__fluffyjaws__wiki_documentation_search` with the specific feature/component keywords
> 4. (Optional) Call `mcp__fluffyjaws__full_documentation_search` only if step 3 returned no results
>
> Return: relevant Slack discussions (summarized), wiki/documentation links, architectural context, and team decisions found. Keep output under 25 lines.

### Phase 5: Context Synthesis

After all launched agents return, combine their findings into a structured briefing:

```
# Ticket Briefing: TICKET

## Summary
[One-paragraph summary from Jira description]

## Acceptance Criteria
1. [From Jira ticket]
2. ...

## Status
- **Status**: [current status]
- **Assignee / Reporter**: [...]
- **Priority**: [priority]
- **Epic/Parent**: [if any]

## Codebase Impact
- **Primary files**: [list from explorer agent — file:line]
- **Test coverage**: [existing tests for affected areas]
- **Related patterns**: [similar implementations found]

## Additional Context
[Include this section ONLY if FluffyJaws ran in Phase 4]
- **Slack discussions**: [key points]
- **Wiki/docs**: [relevant links]
- **Related tickets**: [linked issues from Jira]

## Key Comments
[Notable discussion points from Jira comments]

## Worktree
- **Status**: [created/exists/not created]
- **Path**: [worktree path if applicable]
- **AEM port**: [port if applicable]

## Research Footprint
- Jira: ✓
- Codebase Explorer ([verify|discover] mode): ✓
- FluffyJaws: [✓ ran | ✗ skipped — see "Want more context?" below]
```

If FluffyJaws was skipped, append a one-line footer:

> 💡 Want Slack/wiki context too? Say "pull fluffyjaws for TICKET" and I'll launch the FluffyJaws research agent.

### Phase 6: Next Steps

After presenting the briefing, suggest appropriate next steps based on ticket complexity:

- **Complex feature** (multiple acceptance criteria, architectural impact, > 5 files in scope): "This looks like a substantial feature. I'd recommend running `/speckit.specify` to create a spec, then `/speckit.plan` for implementation planning."
- **Medium task** (clear scope, 2-5 files): "This has clear scope. Want to jump into planning with `/speckit.plan`, or start coding directly?"
- **Simple fix** (single file, verified RCA, obvious change): "This looks straightforward. Want to start coding?"

Do NOT automatically transition to the next step. Wait for the user to decide.

---

## Efficiency Notes (for the model invoking this skill)

This skill is built for **efficiency-by-default**, not exhaustive-by-default:

- **Phase 3 never touches FluffyJaws.** Even if Phase 4 ends up calling FJ, Phase 3 stays a clean corp-jira-only call. This means the user can interrupt with "skip FJ" after Phase 3 and the cost is already minimized.
- **FluffyJaws is opt-in.** Default is SKIP. The triage rules in Phase 3.5 cover the common "verified bug fix" path — those tickets typically don't need Slack/wiki context.
- **Codebase verify-mode** is dramatically cheaper than discover-mode (~5-10 file reads vs ~30+ greps). Always prefer verify when the description names files.
- The user can always opt into FluffyJaws after the briefing via the footer hint. Better to render a fast briefing first and let the user expand than to spend 30 seconds on FJ they didn't need.
