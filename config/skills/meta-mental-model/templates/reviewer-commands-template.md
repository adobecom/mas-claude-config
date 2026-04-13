# Command File Templates for Reviewer Mental Models (Subagent-Delegating)
#
# Replace {{NAME}}, {{GITHUB}}, {{EXPERTISE_PATH}}, {{REPO}}.
# All commands spawn subagents to keep expertise.yaml out of the main context.
# Key difference from domain models: self-improve uses gh api, not file reading.
#
# ===================================================================
# FILE 1: question.md
# ===================================================================

---
name: reviewer-{{GITHUB}}-question
allowed-tools: Agent
description: "Would {{NAME}} flag this?" — spawns a subagent to check against reviewer expertise. ~200 tokens returned to main context.
argument-hint: [question]
---

# Reviewer Mental Model: {{NAME}} — Question

Spawn an **Explore subagent** with this prompt:

> Read `.claude/commands/mental-model/reviewer-{{GITHUB}}/expertise.yaml`.
> Using the reviewer's values, red_flags, green_flags, and review_vocabulary,
> answer this question: $ARGUMENTS
>
> Return a structured answer (under 15 lines):
> - **Verdict**: Would {{NAME}} flag this? (yes/no/maybe)
> - **Why**: Which value or red_flag applies (cite rank and name)
> - **Evidence**: Relevant PR citation from expertise.yaml
> - **Suggestion**: How to preemptively address it

Do NOT read the expertise file in the main context.


# ===================================================================
# FILE 2: plan.md
# ===================================================================

---
name: reviewer-{{GITHUB}}-plan
allowed-tools: Agent
description: Load {{NAME}}'s review values as constraints before planning a PR. Spawns a Plan subagent.
argument-hint: [user_request]
---

# Reviewer Mental Model: {{NAME}} — Plan

Spawn a **Plan subagent** with this prompt:

> Read `.claude/commands/mental-model/reviewer-{{GITHUB}}/expertise.yaml`.
> Extract the reviewer's top values, red_flags, and domain_opinions.
>
> Then plan this change with those as constraints: $ARGUMENTS
>
> The plan must:
> - Avoid all red_flags listed in the expertise
> - Follow the reviewer's domain_opinions on architecture
> - Keep PR scope aligned with their scope_discipline value
>
> Return a concise plan (under 30 lines) noting which reviewer values
> are satisfied and any potential friction points.

Do NOT read the expertise file in the main context.


# ===================================================================
# FILE 3: self-improve.md
# ===================================================================

---
name: reviewer-{{GITHUB}}-self-improve
allowed-tools: Agent
description: Fetch recent PR reviews by {{NAME}} via gh api and update the reviewer expertise file.
argument-hint: [pr_count (default 20)]
---

# Reviewer Mental Model: {{NAME}} — Self-Improve

Spawn a **general-purpose subagent** with this prompt:

> Update `.claude/commands/mental-model/reviewer-{{GITHUB}}/expertise.yaml`
> by fetching recent PR reviews.
>
> 1. Read the current expertise.yaml
> 2. Fetch recent closed PRs reviewed by {{GITHUB}}:
>    `gh api "repos/{{REPO}}/pulls?state=closed&per_page=$1" --paginate`
> 3. For each PR, fetch reviews filtered to {{GITHUB}}:
>    `gh api "repos/{{REPO}}/pulls/{number}/reviews"`
>    `gh api "repos/{{REPO}}/pulls/{number}/comments"`
> 4. Extract new patterns, vocabulary, values not in current expertise
> 5. Edit expertise.yaml with new findings
> 6. Validate YAML, enforce 1000-line limit
>
> Return a summary (under 10 lines):
> - PRs analyzed: N
> - New patterns found: list
> - Sections updated: list

Do NOT read the expertise file in the main context.


# ===================================================================
# FILE 4: plan_build_improve.md
# ===================================================================

---
name: reviewer-{{GITHUB}}-plan-build-improve
allowed-tools: Agent
description: End-to-end workflow with {{NAME}}'s review values. Chains plan -> build -> refresh reviewer model.
argument-hint: [implementation_request]
---

# Reviewer Mental Model: {{NAME}} — Plan Build Improve

Chain three subagents sequentially:

**Step 1 — Plan**: Spawn a Plan subagent:
> Read reviewer expertise, then plan with their values as constraints: $ARGUMENTS

**Step 2 — Build**: After plan is approved, spawn a general-purpose subagent:
> Implement the plan from Step 1.

**Step 3 — Self-Improve**: Spawn a general-purpose subagent:
> Fetch recent PR reviews by {{GITHUB}} and update the expertise file.
> Return a summary of changes.
