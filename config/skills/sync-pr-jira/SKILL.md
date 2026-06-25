---
name: sync-pr-jira
description: Sync your open PRs' review state to their Jira ticket status (Code Review / In Development / Ready For QA) and re-request stale reviewers. Computes the correct transition per PR from GitHub signals, prints a dry-run by default, applies only with --apply. Use when the user asks to "sync PRs to Jira", "update ticket statuses", "track my PRs", "move tickets based on review state", or "re-request reviews".
tags: [pr, jira, review, automation, workflow]
---

# Sync PR ↔ Jira Status

Maps each open PR's GitHub review/check state to the correct Jira status and (optionally) applies it.

## When to run
User says: sync PRs to Jira, update my ticket statuses, what needs action, re-request reviews, move tickets.

## Config
`config.json` in this skill dir holds: my handles, QA handles (`qa[]`), required approvals (2), the Nala Gate name, and ignored checks. **QA handles must be filled in** — if any `qa[].githubLogin` still starts with `REPLACE_`, stop and ask the user for Milica's GitHub login + Jira username before applying anything.

## Decision rules (mirrored in decide.mjs — source of truth)

A PR's checks are "green" when every check **except** those in `ignoreChecks` (Nala Gate + its skipped sub-jobs) is SUCCESS/SKIPPED. Nala Gate is expected to fail until 2 approvals — never treat it as a blocker.

| Condition (first match wins) | Target Jira status |
|---|---|
| A reviewer `CHANGES_REQUESTED` **or** any reviewer/QA comment newer than my last commit | **In Development** |
| ≥2 approvals **and** checks green **and** no pending feedback | **Ready For QA** (+ assign QA) |
| Checks green, fewer than 2 approvals | **Code Review** |
| Checks failing/running (non-Nala) | no change |

"Newer than my last commit" = the comment came in after I last pushed, so it's unaddressed. Older feedback on stale code is ignored (and the reviewer should be re-requested instead).

## Steps

1. **Run the engine** (deterministic, no side effects):
   ```bash
   node .claude/skills/sync-pr-jira/decide.mjs
   ```
   Returns a JSON array: `{number, title, ticket, approvalCount, target, assignQa, reason}` per PR.

2. **For each decision with a `target`**, read the ticket's current Jira status:
   - `mcp__corp-jira__search_jira_issues` with `jql: "key in (TICKET1, TICKET2, ...)"`, `fields: ["status","assignee"]` (one batched call).
   - Skip PRs where `target === current status` (no-op).

3. **Verify the transition is reachable** before applying:
   - `mcp__corp-jira__get_jira_transitions` for each ticket that needs a change.
   - If `target` is in the available transition names → apply directly.
   - If not reachable (Jira workflow is a directed graph), report it as "manual: TARGET not reachable from CURRENT" — do **not** force a path unless the user asks.

4. **Print the dry-run table** (always, before any write):
   ```
   | PR | Ticket | Jira now | → Target | Why |
   ```
   Plus a separate list of **re-request actions**: reviewers whose review predates my last commit (from step 1 data — the engine flags stale reviews; re-request those via `gh pr edit <n> --add-reviewer <login>`).

5. **Apply only if invoked with `--apply`** (user said "apply", "do it", "go"):
   - Transition: `mcp__corp-jira__transition_jira_status_by_name({issueIdOrKey, statusName})`.
   - If `assignQa`: also `mcp__corp-jira__update_jira_issue({issueIdOrKey, fields: {assignee: {name: <qa.jiraName>}}})`.
   - Re-request stale reviewers via `gh pr edit`.
   - Report each action's success/failure.

   Without `--apply`: end with "Dry-run only. Re-run with `--apply` to commit these N changes."

## Guardrails
- Never move a ticket to a status its workflow can't reach from current — report instead.
- Never assign QA without moving to Ready For QA.
- Backward moves (→ In Development) are disruptive: in the dry-run, mark them with ⚠ so they're easy to scan.
- If `gh` or the MCP errors on one PR, continue the rest and report the failure — don't abort the batch.
