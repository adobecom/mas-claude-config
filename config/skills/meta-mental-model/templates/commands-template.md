# Command File Templates for Mental Model System (Subagent-Delegating)
#
# Replace {{DOMAIN}}, {{SCOPE}}, {{EXPERTISE_PATH}}, and {{CODEBASE_PATH}}.
# All commands spawn subagents to keep expertise.yaml out of the main context.
#
# ===================================================================
# FILE 1: question.md
# ===================================================================

---
name: {{DOMAIN}}-question
allowed-tools: Agent
description: Answer questions about {{SCOPE}} by spawning a subagent that reads the expertise file. Keeps main context clean (~200 tokens returned).
argument-hint: [question]
---

# {{DOMAIN}} Mental Model — Question

Spawn an **Explore subagent** with this prompt:

> You are a domain expert for {{DOMAIN}}. Read the expertise file at
> `{{EXPERTISE_PATH}}` and the relevant source files in `{{CODEBASE_PATH}}`.
>
> Answer this question: $ARGUMENTS
>
> Return a structured answer (under 15 lines):
> - **Answer**: Direct response
> - **Evidence**: file:line references from the codebase
> - **Pattern**: Which architectural pattern applies (if any)

Do NOT read the expertise file in the main context. The subagent handles it.


# ===================================================================
# FILE 2: plan.md
# ===================================================================

---
name: {{DOMAIN}}-plan
allowed-tools: Agent
description: Create implementation plans for {{SCOPE}}. Spawns a Plan subagent that loads domain expertise before planning.
argument-hint: [user_request]
---

# {{DOMAIN}} Mental Model — Plan

Spawn a **Plan subagent** with this prompt:

> Read the expertise file at `{{EXPERTISE_PATH}}` to understand architecture,
> key files, patterns, and gotchas for {{DOMAIN}}.
>
> Then create an implementation plan for: $ARGUMENTS
>
> The plan must reference actual file paths and patterns from the expertise.
> Note any gotchas or integration points that apply.
>
> Return a concise plan (under 30 lines) with:
> - **Files to modify**: paths from expertise
> - **Approach**: which pattern to follow
> - **Risks**: relevant gotchas

Do NOT read the expertise file in the main context. The subagent handles it.


# ===================================================================
# FILE 3: self-improve.md
# ===================================================================

---
name: {{DOMAIN}}-self-improve
allowed-tools: Agent
description: Validate and update the {{DOMAIN}} expertise file against the actual codebase. Spawns a general-purpose subagent with write access.
argument-hint: [check_git_diff (true/false)] [focus_area (optional)]
---

# {{DOMAIN}} Mental Model — Self-Improve

Spawn a **general-purpose subagent** with this prompt:

> Validate and update `{{EXPERTISE_PATH}}` against the codebase at `{{CODEBASE_PATH}}`.
>
> 1. Read the current expertise.yaml
> 2. If "$1" is "true": check `git diff {{CODEBASE_PATH}}` for recent changes
> 3. Verify all listed file paths exist (Glob)
> 4. Grep for documented function names to verify they still exist
> 5. Fix any discrepancies via Edit
> 6. Enforce max 1000 lines
> 7. Validate YAML: `python3 -c "import yaml; yaml.safe_load(open('{{EXPERTISE_PATH}}'))"`
>
> Return a summary (under 10 lines):
> - Discrepancies found/fixed: N
> - Files added/removed: list
> - Final line count: N/1000


# ===================================================================
# FILE 4: plan_build_improve.md
# ===================================================================

---
name: {{DOMAIN}}-plan-build-improve
allowed-tools: Agent
description: End-to-end {{DOMAIN}} workflow. Chains plan -> build -> self-improve via sequential subagents.
argument-hint: [implementation_request]
---

# {{DOMAIN}} Mental Model — Plan Build Improve

Chain three subagents sequentially:

**Step 1 — Plan**: Spawn a Plan subagent:
> Read `{{EXPERTISE_PATH}}`, then plan: $ARGUMENTS

**Step 2 — Build**: After plan is approved, spawn a general-purpose subagent:
> Implement the plan from Step 1.

**Step 3 — Self-Improve**: Spawn a general-purpose subagent:
> Run self-improve on `{{EXPERTISE_PATH}}` with check_git_diff=true.
> Return a summary of changes to the expertise file.
