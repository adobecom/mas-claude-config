#!/bin/bash
input=$(cat)

# --- Read everything we need from the harness JSON. Newline-delimited so
# empty fields keep their position (whitespace-splitting would collapse them). ---
jq_get() { echo "$input" | jq -r "$1 // \"\"" 2>/dev/null; }
cwd=$(jq_get '.cwd')
model_name=$(jq_get '.model.display_name')
effort=$(jq_get '.effort.level')
ctx_pct=$(jq_get '.context_window.used_percentage')
ctx_size=$(jq_get '.context_window.context_window_size')
cost=$(jq_get '.cost.total_cost_usd')
lines_add=$(jq_get '.cost.total_lines_added')
lines_rem=$(jq_get '.cost.total_lines_removed')
rl5=$(jq_get '.rate_limits.five_hour.used_percentage')
rl7=$(jq_get '.rate_limits.seven_day.used_percentage')

WORKTREES_BASE="__ADOBE_DIR__/worktrees"
MAS_BASE="__MAS_DIR__"
PORTS_FILE="$WORKTREES_BASE/.ports"

# ANSI color codes
CYAN='\033[36m'
MAGENTA='\033[35m'
BLUE='\033[34m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# --- Branch: git is the source of truth. cwd only locates the repo dir. ---
# Works whether we're in the main mas/ repo on a feature branch or in a
# worktree; no override file to go stale.
[ -z "$cwd" ] && cwd="$PWD"
branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
[ -z "$branch" ] && branch="main"

# repo dir on disk (for editor/Finder links). A worktree has its own dir;
# everything else points at the main repo.
if [ -d "$WORKTREES_BASE/$branch" ]; then
  repo_dir="$WORKTREES_BASE/$branch"
else
  repo_dir="$MAS_BASE"
fi

# --- Port: main=3000, worktree=3000+offset from .ports ---
# Main repo always serves on offset 0 (AEM 3000 / proxy 8080), whatever
# branch is checked out. A worktree gets its offset from .ports.
port=""
proxy=""
if [ "$repo_dir" = "$MAS_BASE" ]; then
  port="3000"
  proxy="8080"
elif [ -f "$PORTS_FILE" ]; then
  offset=$(grep "^${branch}=" "$PORTS_FILE" | head -n 1 | cut -d'=' -f2)
  if [[ "$offset" =~ ^[0-9]+$ ]]; then
    port=$((3000 + offset))
    proxy=$((8080 + offset))
  fi
fi

# --- PR (cached in git config, falls back to gh) ---
pr_url=""
if [ "$branch" != "main" ]; then
  pr_url=$(git -C "$repo_dir" --no-optional-locks config --get "branch.${branch}.pr-url" 2>/dev/null)
  if [ -z "$pr_url" ]; then
    pr_url=$(gh pr view "$branch" --repo adobecom/mas --json url -q .url 2>/dev/null)
    if [ -n "$pr_url" ]; then
      git -C "$repo_dir" --no-optional-locks config "branch.${branch}.pr-url" "$pr_url" 2>/dev/null
    fi
  fi
fi
pr_tag=""
if [ -n "$pr_url" ]; then
  pr_num=$(echo "$pr_url" | grep -o '[0-9]*$')
  pr_tag="  \033]8;;${pr_url}\033\\PR #${pr_num}\033]8;;\033\\"
fi

# --- Editor + Finder links ---
code_link="\033]8;;vscode://file/${repo_dir}\033\\\\${MAGENTA}Code${RESET}\033]8;;\033\\\\"
finder_link="\033]8;;file://${repo_dir}\033\\\\${MAGENTA}Finder${RESET}\033]8;;\033\\\\"

# --- Local link (only when a port resolved) ---
local_link=""
if [ -n "$port" ]; then
  if [ "$port" = "3000" ]; then
    local_url="http://localhost:${port}/studio.html"
  else
    local_url="http://localhost:${port}/studio.html?proxy.port=${proxy}"
  fi
  local_link="\033]8;;${local_url}\033\\\\${BLUE}Local${RESET}\033]8;;\033\\\\  "
fi

# --- Remote link ---
branch_lower=$(echo "$branch" | tr '[:upper:]' '[:lower:]')
remote_url="https://${branch_lower}--mas--adobecom.aem.live/studio.html"
remote_link="\033]8;;${remote_url}\033\\\\${BLUE}Remote${RESET}\033]8;;\033\\\\"

# --- Branch label (clickable Jira link for MWPW branches) ---
if [ "$branch" = "main" ]; then
  branch_label="${CYAN}${branch}${RESET}"
else
  jira_url="https://jira.corp.adobe.com/browse/${branch}"
  branch_label="\033]8;;${jira_url}\033\\\\${CYAN}${branch}${RESET}\033]8;;\033\\\\"
fi

# ============================ LINE 1 ============================
printf "%b ${DIM}→${RESET} %b%b  %b  %b%b" \
  "$branch_label" "$local_link" "$remote_link" "$code_link" "$finder_link" "$pr_tag"

# ============================ LINE 2 ============================
# Metrics row. Each segment renders only when its field is present, so the
# line degrades gracefully on Bedrock/API (no cost, no rate_limits).
segments=()

# Context window usage bar (green < 60% < yellow < 85% < red)
if [[ "$ctx_pct" =~ ^[0-9]+ ]]; then
  pct=${ctx_pct%.*}
  filled=$(( pct / 10 ))
  [ "$filled" -gt 10 ] && filled=10
  empty=$(( 10 - filled ))
  if [ "$pct" -ge 85 ]; then bar_color="$RED"
  elif [ "$pct" -ge 60 ]; then bar_color="$YELLOW"
  else bar_color="$GREEN"; fi
  bar=""
  for ((i=0;i<filled;i++)); do bar="${bar}▓"; done
  for ((i=0;i<empty;i++)); do bar="${bar}░"; done
  ctx_note="ctx"
  if [[ "$ctx_size" =~ ^[0-9]+$ ]] && [ "$ctx_size" -ge 1000000 ]; then ctx_note="ctx·1M"; fi
  segments+=("${bar_color}${bar}${RESET} ${pct}% ${DIM}${ctx_note}${RESET}")
else
  # No usage yet (before first API response, or right after /compact)
  segments+=("${DIM}░░░░░░░░░░ —% ctx${RESET}")
fi

# Session cost + lines changed
cost_seg=""
if [[ "$cost" =~ ^[0-9] ]] && awk "BEGIN{exit !($cost > 0)}"; then
  cost_seg=$(printf "${GREEN}\$%.2f${RESET}" "$cost")
fi
lines_seg=""
if [[ "$lines_add" =~ ^[0-9]+$ && "$lines_rem" =~ ^[0-9]+$ ]] && [ $((lines_add + lines_rem)) -gt 0 ]; then
  lines_seg="${DIM}+${lines_add}/-${lines_rem}${RESET}"
fi
if [ -n "$cost_seg" ] || [ -n "$lines_seg" ]; then
  joined="$cost_seg"
  [ -n "$cost_seg" ] && [ -n "$lines_seg" ] && joined="$joined $lines_seg"
  [ -z "$cost_seg" ] && joined="$lines_seg"
  segments+=("$joined")
fi

# Overall usage (Claude.ai Pro/Max only)
usage_seg=""
if [[ "$rl5" =~ ^[0-9] ]]; then
  usage_seg="${DIM}5h${RESET} ${rl5%.*}%"
fi
if [[ "$rl7" =~ ^[0-9] ]]; then
  [ -n "$usage_seg" ] && usage_seg="$usage_seg  "
  usage_seg="${usage_seg}${DIM}7d${RESET} ${rl7%.*}%"
fi
[ -n "$usage_seg" ] && segments+=("$usage_seg")

# Model + effort
if [ -n "$model_name" ]; then
  model_seg="${DIM}${model_name}${RESET}"
  [ -n "$effort" ] && model_seg="${model_seg} ${DIM}·${RESET} ${effort}"
  segments+=("$model_seg")
fi

if [ ${#segments[@]} -gt 0 ]; then
  printf "\n"
  sep=""
  for seg in "${segments[@]}"; do
    printf "%b%b" "$sep" "$seg"
    sep="  ${DIM}|${RESET}  "
  done
fi
