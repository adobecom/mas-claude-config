---
name: reviewer-npeltier-self-improve
allowed-tools: Agent
description: Fetch recent PR reviews by npeltier via gh api and update the reviewer expertise file with new patterns. Returns ~300 token summary to main context.
argument-hint: [pr_count (default 20)]
---

# Reviewer Mental Model: npeltier — Self-Improve

Spawn a **general-purpose subagent** with this prompt:

> Update `.claude/commands/mental-model/reviewer-npeltier/expertise.yaml`
> by analyzing recent PR reviews from npeltier on adobecom/mas.
>
> **Step 1**: Read the current expertise.yaml to understand existing values, red_flags, vocabulary.
>
> **Step 2**: Fetch recent PRs where npeltier reviewed:
> ```bash
> gh api "repos/adobecom/mas/pulls?state=all&per_page=${1:-20}" --paginate \
>   --jq '.[] | select(.number) | .number' | head -${1:-20}
> ```
>
> **Step 3**: For each PR number, fetch npeltier's reviews and comments:
> ```bash
> gh api "repos/adobecom/mas/pulls/{number}/reviews" \
>   --jq '.[] | select(.user.login == "npeltier") | {state, body}'
> gh api "repos/adobecom/mas/pulls/{number}/comments" \
>   --jq '.[] | select(.user.login == "npeltier") | {body, path, line}'
> ```
>
> **Step 4**: Analyze the fetched reviews for:
> - New vocabulary patterns not in review_vocabulary
> - New values or increased evidence for existing values
> - New red_flags or green_flags not captured
> - New domain_opinions expressed
> - New gotchas about his review behavior
>
> **Step 5**: Edit expertise.yaml to add new findings. For existing values, append new evidence entries.
> For new patterns, add new entries to the appropriate section.
>
> **Step 6**: Validate:
> - `python3 -c "import yaml; yaml.safe_load(open('.claude/commands/mental-model/reviewer-npeltier/expertise.yaml'))"`
> - `wc -l .claude/commands/mental-model/reviewer-npeltier/expertise.yaml` (must be <= 1000)
>
> Return a summary (under 10 lines):
> - PRs analyzed: N
> - New patterns found: [list]
> - Values with new evidence: [list]
> - Sections updated: [list]
> - Final line count: N/1000

Do NOT read the expertise file in the main context. The subagent handles it.
