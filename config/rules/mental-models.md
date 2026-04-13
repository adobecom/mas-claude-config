# Mental Model Integration Rules

Mental models provide structured reviewer/domain expertise via subagents (~500 tokens per query).

## Automatic Triggers

### When Planning (plan mode, /speckit.plan, or any implementation planning)
Before creating a plan for changes that touch files in npeltier's ownership areas:
- `io/www/`, `io/studio/` (primary owner — deep review)
- `studio/src/` (active reviewer — architectural focus)
- `web-components/src/` (light review)

Spawn an Explore subagent:
> Read `.claude/commands/mental-model/reviewer-npeltier/expertise.yaml`.
> For the planned changes to [files], summarize which of npeltier's values (ranked 1-7)
> and red_flags apply. Return under 10 lines.

Use the returned constraints when writing the plan.

### When Creating a PR (mas-pr-creator skill)
After linter passes but before PR creation, the skill automatically runs a reviewer
pre-check. This is built into the skill — no manual action needed.

### When Reviewing a PR (/review-pr)
The review-pr command automatically loads reviewer context for changed files that
overlap with npeltier's ownership_map. No manual action needed.

### After Session (automatic via hooks)
The stop hook reports which domains were touched and suggests running self-improve.
Run the suggested commands to keep expertise files current.

## Available Commands

```
/mental-model:reviewer-npeltier:question [question]    # ~200 tokens
/mental-model:reviewer-npeltier:plan [request]          # ~300 tokens
/mental-model:reviewer-npeltier:self-improve [count]    # ~300 tokens returned
/mental-model:reviewer-npeltier:plan_build_improve [request]
```

## When NOT to Use

- Pure CSS changes (npeltier gives hearts, not blocks)
- nala/ test-only changes (rubber-stamp area)
- .github/workflows/ changes (light review)
- Changes that don't touch any files in his ownership_map
