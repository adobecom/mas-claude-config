---
name: pm-spec-author
description: Interview a product manager and draft a code-grounded, dev-ready MWPW spec — reading real code (Scout), content (Odin), and architecture (CLAUDE.md) so the spec references actual files, variants, fragments, and locales. Use when a PM wants to write a spec, propose a feature, or turn an idea into a ticket. Activates on "write a spec", "spec this out", "I want a feature", "draft a ticket for", "turn this into a spec".
tags: [pm, spec, authoring, mwpw, scout, odin]
---

# PM Spec Author

## Purpose
Turn a PM's feature idea into a developer-ready MWPW spec grounded in the real
codebase and content — not guesses. The PM brings product judgment; this skill
brings codebase/content truth.

## Preconditions
- Run `pm-prior-art` first. If a duplicate exists, stop and recommend extending it.

## Steps

1. **Interview the PM** (one question at a time): problem, target users,
   acceptance criteria, scope boundaries, target locales.

2. **Ground in real code** using Scout (local checkout):
   - `mcp__scout__search` / `mcp__scout__explain_symbol` to find the real
     components/variants involved (e.g. confirm which merch-card variants exist
     before claiming a new one is needed).
   - Read the relevant `CLAUDE.md` architecture docs for the affected layer.

3. **Ground in real content** using Odin where the spec touches fragments:
   - `mcp__odin-prod__search-aem-content-fragments` to confirm which
     fragments/variants/locales exist — surface content gaps (e.g. "de_DE
     fragment missing") as dependencies.

4. **Draft the spec** in this structure:
   - **Problem** — one paragraph, user-facing.
   - **Target users** — who and in what context.
   - **Proposed change** — what changes, referencing REAL files/variants/fragments.
   - **Acceptance criteria** — testable, PM-authored.
   - **Affected areas** — actual file paths (from Scout) and fragments (from Odin).
   - **Open questions / dependencies** — incl. any content gaps found.

5. **Hand off to filing:** offer to file via the `jira-ticket-creator` skill
   (which handles MWPW required fields). Pass the drafted spec as the description.

## Discipline
- Never claim a file/variant/fragment exists without confirming it via Scout/Odin.
- If Scout returns nothing for a claimed component, say so — don't fabricate paths.
- Keep the spec scannable: one fact per bullet, no preambles.
