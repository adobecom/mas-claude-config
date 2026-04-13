---
name: reviewer-npeltier-plan-build-improve
allowed-tools: Agent
description: End-to-end workflow with npeltier's review values as constraints. Chains plan -> build -> refresh reviewer model via sequential subagents.
argument-hint: [implementation_request]
---

# Reviewer Mental Model: npeltier — Plan Build Improve

Chain three subagents sequentially:

**Step 1 — Plan** (Plan subagent):
> Read `.claude/commands/mental-model/reviewer-npeltier/expertise.yaml`.
> Plan this implementation with npeltier's values as constraints: $ARGUMENTS
> Ensure the plan avoids all red_flags and follows his domain_opinions.
> Return the plan for user review.

Wait for user approval of the plan before proceeding.

**Step 2 — Build** (general-purpose subagent):
> Implement the approved plan from Step 1.
> Follow npeltier's coding preferences:
> - Reuse existing utilities (value rank 2)
> - Use precise naming (value rank 4)
> - Respect module boundaries (value rank 5)
> - Use correct error semantics (value rank 6)
> Return a summary of files changed.

**Step 3 — Self-Improve** (general-purpose subagent):
> Fetch npeltier's most recent 10 PR reviews via gh api.
> Update `.claude/commands/mental-model/reviewer-npeltier/expertise.yaml`
> with any new patterns discovered.
> Return a summary of changes to the expertise file.
