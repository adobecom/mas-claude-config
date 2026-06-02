#!/usr/bin/env bash
# drift-check.sh — Reports STRUCTURAL drift between the live mas/.claude/ and this
# backup bundle: files present in one but missing from the other. Read-only.
#
# Why structural and not content: export.sh sanitizes absolute paths to __MAS_DIR__
# placeholders in the backup, so a content diff always reports path-bearing files as
# "different" (false positives). The drift that actually bites is missing/extra files
# (an undeployed command, a dead skill left in the backup) — that's what this catches.
#
# Usage: ./drift-check.sh   →   exits 0 if in sync, 1 if drift found.
# On drift, run ./export.sh (live → backup) to reconcile.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE="$(cd "$SCRIPT_DIR/../mas" && pwd)/.claude"
BACKUP="$SCRIPT_DIR/config"

# Same includes/excludes as export.sh — keep these two lists in sync with it.
INCLUDES=(rules skills commands agents hooks)
EXCLUDES=(settings.local.json data audits plans research _hooks \
          skills-archive agents-archive commands-archive .DS_Store \
          __pycache__ '*.pyc' '*.lock' user-skills)

PRUNE=()
for e in "${EXCLUDES[@]}"; do PRUNE+=(-name "$e" -o); done
PRUNE=("${PRUNE[@]:0:${#PRUNE[@]}-1}")  # drop trailing -o

list_rel() {  # list_rel <root> <subdir> — relative file paths under root/subdir, excluded items pruned
  local root="$1" sub="$2"
  [ -d "$root/$sub" ] || return 0
  ( cd "$root" && find "$sub" \( "${PRUNE[@]}" \) -prune -o -type f -print ) | sort
}

drift=0
for item in "${INCLUDES[@]}"; do
  only_live=$(comm -23 <(list_rel "$LIVE" "$item") <(list_rel "$BACKUP" "$item"))
  only_backup=$(comm -13 <(list_rel "$LIVE" "$item") <(list_rel "$BACKUP" "$item"))
  if [ -n "$only_live" ] || [ -n "$only_backup" ]; then
    drift=1
    echo "── $item ──"
    [ -n "$only_live" ]   && echo "$only_live"   | sed 's/^/  + live only (export to add):    /'
    [ -n "$only_backup" ] && echo "$only_backup" | sed 's/^/  - backup only (export --delete): /'
  fi
done

if [ "$drift" -eq 0 ]; then
  echo "✓ in sync — live and backup hold the same files"
  exit 0
fi
echo
echo "drift found — run ./export.sh to reconcile (live → backup)"
exit 1
