---
name: pm-prior-art
description: Search existing MWPW Jira tickets and GitHub issues/PRs for duplicate or related work before authoring a new spec. Use when a PM is about to propose a feature and should check what already exists. Activates on "is there already a ticket", "prior art", "check for duplicates", "has this been done", "related work", "before I spec".
tags: [pm, jira, prior-art, duplicates, mwpw]
---

# PM Prior-Art Search

## Purpose
Before a PM authors a spec, surface existing MWPW tickets and GitHub work so they
don't duplicate effort and can link dependencies. Pairs with `pm-spec-author`.

## When to use
- A PM describes a feature idea and you don't yet know if it exists.
- Always run this BEFORE `pm-spec-author` drafts a spec.

## Steps

1. **Search Jira (MWPW project)** via `mcp__corp-jira__search_jira_issues`:
   - JQL: `project = MWPW AND text ~ "<key terms>" ORDER BY updated DESC`
   - Report open/in-progress matches with key, summary, status, assignee.

2. **Search GitHub** for the same terms:
   - `gh issue list --repo adobecom/mas --search "<terms>" --state all --limit 20`
   - `gh pr list --repo adobecom/mas --search "<terms>" --state all --limit 20`

3. **Summarize for the PM:**
   - Exact duplicates -> recommend extending the existing ticket, not a new one.
   - Related work -> note as dependencies/links for the new spec.
   - Nothing found -> say so explicitly and hand off to `pm-spec-author`.

## Output
A short list: `MWPW-XXXX (status) — summary` and `gh#NN — title`, grouped into
"duplicate", "related", or "none". Never invent ticket numbers — only report
results the MCP/gh actually returned.
