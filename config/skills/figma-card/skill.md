---
name: figma-card
description: Quick slash command to convert a Figma design into a MAS merch card variant. Usage /figma-card <figma-url>. Accepts optional --name and --surface args.
---

# /figma-card

Quick entry point for converting Figma designs to MAS merch card variants.

## Usage

```
/figma-card <figma-url>
/figma-card <figma-url> --name my-variant
/figma-card <figma-url> --name my-variant --surface spectrum2
```

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| `<url>` | Yes | — | Figma URL (must contain `figma.com/design/`) |
| `--name` | No | prompts | Variant name in kebab-case |
| `--surface` | No | prompts | `spectrum2` (default) or `consonant` (ACOM) |

## Workflow

1. **Parse the URL** — extract `fileKey` and `nodeId` from the Figma URL
2. **Set defaults** — if `--name` or `--surface` not provided, ask the user
3. **Delegate to `figma-to-merch-card` skill** — invoke the full workflow with pre-filled Phase 0

### URL Parsing

Extract from: `https://figma.com/design/:fileKey/:fileName?node-id=:nodeId`
- `fileKey` = segment after `/design/`
- `nodeId` = value of `node-id` query param, convert `-` to `:`

### Pre-fill and Delegate

Once URL is parsed and name/surface are determined, follow the `figma-to-merch-card` skill workflow starting from Phase 1 (Design Extraction). Phase 0 (Setup) is already complete.

Read the full skill at: `.claude/skills/figma-to-merch-card/skill.md`

## Examples

```
/figma-card https://www.figma.com/design/rHeuOYAwNriEkl6Nr5HIQ5/Simplified-plans?node-id=239-238252
→ Prompts for variant name and surface, then runs full workflow

/figma-card https://www.figma.com/design/rHeuOYAwNriEkl6Nr5HIQ5/Simplified-plans?node-id=239-238252 --name express-ai --surface spectrum2
→ Skips prompts, goes straight to design extraction
```
