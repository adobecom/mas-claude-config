#!/usr/bin/env bash
# export.sh — Refreshes the mas-claude-config bundle from the live mas/.claude/ directory.
# Run this whenever you update your Claude Code configuration and want to share the changes.
#
# Usage: ./export.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAS_DIR="$(cd "$SCRIPT_DIR/../mas" && pwd)"
ADOBE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUNDLE_DIR="$SCRIPT_DIR"
SOURCE_CLAUDE="$MAS_DIR/.claude"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "  ${GREEN}✓${NC} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }
error()   { echo -e "  ${RED}✗${NC} $1"; }

echo ""
echo -e "${BOLD}MAS Claude Config — Export${NC}"
echo "  Source: $SOURCE_CLAUDE"
echo "  Bundle: $BUNDLE_DIR"
echo ""

# ─── Validate source ───────────────────────────────────────────────────────────

if [ ! -d "$SOURCE_CLAUDE" ]; then
  error "Source directory not found: $SOURCE_CLAUDE"
  exit 1
fi

# ─── Copy config/ files ────────────────────────────────────────────────────────

CONFIG_DEST="$BUNDLE_DIR/config"
mkdir -p "$CONFIG_DEST"

# Files/dirs to include
INCLUDES=(
  "settings.json"
  "KNOWLEDGE_INDEX.md"
  "CLAUDE.md"
  "rules"
  "skills"
  "commands"
  "agents"
  "hooks"
  "examples"
)

# Files/dirs to exclude (within included dirs)
EXCLUDES=(
  "settings.local.json"
  "data"
  "audits"
  "plans"
  "research"
  "_hooks"
  "skills-archive"
  "agents-archive"
  "commands-archive"
  ".DS_Store"
  "__pycache__"
)

# Build rsync exclude args
RSYNC_EXCLUDES=()
for exc in "${EXCLUDES[@]}"; do
  RSYNC_EXCLUDES+=("--exclude=$exc")
done

# Copy each included item
for item in "${INCLUDES[@]}"; do
  src="$SOURCE_CLAUDE/$item"
  if [ -e "$src" ]; then
    if [ -d "$src" ]; then
      rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$src/" "$CONFIG_DEST/$item/"
    else
      cp "$src" "$CONFIG_DEST/$item"
    fi
    info "Copied $item"
  else
    warn "Not found, skipping: $item"
  fi
done

# ─── Copy project-level files ─────────────────────────────────────────────────

cp "$MAS_DIR/CLAUDE.md" "$BUNDLE_DIR/mas-claude.md" 2>/dev/null && info "Copied mas/CLAUDE.md → mas-claude.md" || warn "mas/CLAUDE.md not found"

# Mirror subdirectory CLAUDE.md files (studio/, io/, studio/src/aem/, etc.) back
# into the bundle so the team gets the latest authored versions. Only mirrors
# files that already exist in the bundle — we don't auto-discover new ones to
# avoid sweeping in personal/experimental CLAUDE.md files.
SUBDIR_CLAUDE_DEST="$BUNDLE_DIR/subdir-claude-md"
if [ -d "$SUBDIR_CLAUDE_DEST" ]; then
  subdir_copied=0
  while IFS= read -r tracked; do
    rel="${tracked#$SUBDIR_CLAUDE_DEST/}"
    src="$MAS_DIR/$rel"
    if [ -f "$src" ]; then
      cp "$src" "$tracked"
      subdir_copied=$((subdir_copied + 1))
    else
      warn "subdir CLAUDE.md missing in mas/, kept stale copy: $rel"
    fi
  done < <(find "$SUBDIR_CLAUDE_DEST" -name "CLAUDE.md" -type f 2>/dev/null)
  info "Mirrored $subdir_copied subdir CLAUDE.md file(s)"
fi

# Copy adobe/CLAUDE.md but strip the <claude-mem-context> block
if [ -f "$ADOBE_DIR/CLAUDE.md" ]; then
  python3 - "$ADOBE_DIR/CLAUDE.md" "$BUNDLE_DIR/adobe-claude.md" <<'PYEOF'
import sys, re
content = open(sys.argv[1]).read()
# Remove <claude-mem-context>...</claude-mem-context> blocks (including newlines around them)
content = re.sub(r'\n*<claude-mem-context>.*?</claude-mem-context>\n*', '\n', content, flags=re.DOTALL)
content = content.rstrip() + '\n'
open(sys.argv[2], 'w').write(content)
PYEOF
  info "Copied adobe/CLAUDE.md → adobe-claude.md (stripped claude-mem blocks)"
fi

# ─── Copy worktree manager ────────────────────────────────────────────────────

if [ -f "$ADOBE_DIR/worktrees/wt" ]; then
  cp "$ADOBE_DIR/worktrees/wt" "$BUNDLE_DIR/worktrees/wt"
  chmod +x "$BUNDLE_DIR/worktrees/wt"
  info "Copied worktrees/wt"
else
  warn "worktrees/wt not found"
fi

# ─── Path sanitization ────────────────────────────────────────────────────────
# Replace absolute paths with placeholders. Order matters — longest first.

echo ""
echo "Sanitizing paths..."

# Collect all text files in the bundle (exclude binary/git)
SANITIZE_TARGETS=("$CONFIG_DEST" "$BUNDLE_DIR/mas-claude.md" "$BUNDLE_DIR/adobe-claude.md")
[ -d "$SUBDIR_CLAUDE_DEST" ] && SANITIZE_TARGETS+=("$SUBDIR_CLAUDE_DEST")

find "${SANITIZE_TARGETS[@]}" \
  -type f \( -name "*.md" -o -name "*.json" -o -name "*.py" -o -name "*.yaml" -o -name "*.sh" \) \
  2>/dev/null | while read -r file; do
    # Replace in order: longest path first
    LEGACY_MAS="$(dirname "$ADOBE_DIR")/mas"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' \
        -e "s|$MAS_DIR|__MAS_DIR__|g" \
        -e "s|$ADOBE_DIR/mas|__MAS_DIR__|g" \
        -e "s|$ADOBE_DIR|__ADOBE_DIR__|g" \
        -e "s|$LEGACY_MAS|__MAS_DIR__|g" \
        "$file"
    else
      sed -i \
        -e "s|$MAS_DIR|__MAS_DIR__|g" \
        -e "s|$ADOBE_DIR/mas|__MAS_DIR__|g" \
        -e "s|$ADOBE_DIR|__ADOBE_DIR__|g" \
        -e "s|$LEGACY_MAS|__MAS_DIR__|g" \
        "$file"
    fi
done

info "Paths sanitized (replaced with __MAS_DIR__ and __ADOBE_DIR__)"

# Also sanitize the worktrees/wt script (uses ADOBE_DIR at runtime, not hardcoded, but check)
if [ -f "$BUNDLE_DIR/worktrees/wt" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' \
      -e "s|$MAS_DIR|__MAS_DIR__|g" \
      -e "s|$ADOBE_DIR|__ADOBE_DIR__|g" \
      "$BUNDLE_DIR/worktrees/wt"
  else
    sed -i \
      -e "s|$MAS_DIR|__MAS_DIR__|g" \
      -e "s|$ADOBE_DIR|__ADOBE_DIR__|g" \
      "$BUNDLE_DIR/worktrees/wt"
  fi
fi

# Strip claude-mem-context blocks from any .md files in config/ and the subdir bundle
STRIP_TARGETS=("$CONFIG_DEST")
[ -d "$SUBDIR_CLAUDE_DEST" ] && STRIP_TARGETS+=("$SUBDIR_CLAUDE_DEST")
find "${STRIP_TARGETS[@]}" -name "*.md" -type f | while read -r file; do
  python3 - "$file" <<'PYEOF'
import sys, re
content = open(sys.argv[1]).read()
content = re.sub(r'\n*<claude-mem-context>.*?</claude-mem-context>\n*', '\n', content, flags=re.DOTALL)
content = content.rstrip() + '\n'
open(sys.argv[1], 'w').write(content)
PYEOF
done

# ─── Security verification ────────────────────────────────────────────────────

echo ""
echo "Running security checks..."

SECRETS_FOUND=0

# Check for known secret patterns
SECRET_PATTERNS=(
  "kakduk"                         # IMS password pattern
  "ghp_[A-Za-z0-9]"               # GitHub PAT
  "NDQw[A-Za-z0-9+/=]"            # Base64 Jira PAT prefix
  "sk-ant-"                        # Anthropic API key
  "sk-[A-Za-z0-9]"                 # OpenAI API key
  "access_token.*=.*['\"][^'\"]+['\"]"  # access_token assignments
)

SCAN_TARGETS=("$CONFIG_DEST" "$BUNDLE_DIR/mas-claude.md" "$BUNDLE_DIR/adobe-claude.md")
[ -d "$SUBDIR_CLAUDE_DEST" ] && SCAN_TARGETS+=("$SUBDIR_CLAUDE_DEST")

for pattern in "${SECRET_PATTERNS[@]}"; do
  if grep -r "$pattern" "${SCAN_TARGETS[@]}" \
     --include="*.md" --include="*.json" --include="*.py" --include="*.yaml" \
     --include="*.sh" -l 2>/dev/null | grep -q .; then
    error "Potential secret found matching pattern: $pattern"
    grep -r "$pattern" "${SCAN_TARGETS[@]}" \
      --include="*.md" --include="*.json" --include="*.py" --include="*.yaml" \
      -l 2>/dev/null
    SECRETS_FOUND=1
  fi
done

# Check for remaining absolute paths
if grep -r "/Users/" "${SCAN_TARGETS[@]}" \
   --include="*.md" --include="*.json" --include="*.py" \
   -l 2>/dev/null | grep -q .; then
  warn "Remaining absolute paths found (may be OK if they're in examples or comments):"
  grep -r "/Users/" "${SCAN_TARGETS[@]}" --include="*.md" --include="*.json" --include="*.py" \
    2>/dev/null | head -5
fi

if [ "$SECRETS_FOUND" -eq 1 ]; then
  echo ""
  error "Export ABORTED — secrets detected. Review and fix before sharing."
  exit 1
fi

info "No secrets detected"

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}Export complete.${NC}"
echo ""

RULE_COUNT=$(find "$CONFIG_DEST/rules" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
SKILL_COUNT=$(find "$CONFIG_DEST/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
CMD_COUNT=$(find "$CONFIG_DEST/commands" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
AGENT_COUNT=$(find "$CONFIG_DEST/agents" -name "*.md" 2>/dev/null | grep -v archive | wc -l | tr -d ' ')
HOOK_COUNT=$(find "$CONFIG_DEST/hooks" -name "*.py" -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')

echo "  Rules:    $RULE_COUNT files"
echo "  Skills:   $SKILL_COUNT directories"
echo "  Commands: $CMD_COUNT files"
echo "  Agents:   $AGENT_COUNT files"
echo "  Hooks:    $HOOK_COUNT Python scripts"
echo ""
echo "  Commit and push to share with the team:"
echo "    cd mas-claude-config"
echo "    git add -A && git commit -m 'chore: update config bundle'"
echo "    git push"
echo ""
