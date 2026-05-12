#!/bin/bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')

WORKTREES_BASE="__ADOBE_DIR__/worktrees"
MAS_BASE="__MAS_DIR__"
PORTS_FILE="$WORKTREES_BASE/.ports"

# ANSI color codes
CYAN='\033[36m'
MAGENTA='\033[35m'
BLUE='\033[34m'
GREEN='\033[32m'
YELLOW='\033[33m'
DIM='\033[2m'
RESET='\033[0m'

ACTIVE_WT_FILE="$HOME/.claude/active-worktree"

branch=""
port=""

if [[ "$cwd" == "$WORKTREES_BASE/"* ]]; then
  branch=$(echo "$cwd" | sed "s|$WORKTREES_BASE/||" | cut -d'/' -f1)
elif [[ -f "$ACTIVE_WT_FILE" ]]; then
  branch=$(cat "$ACTIVE_WT_FILE")
fi

if [[ -z "$branch" || "$branch" == "main" ]]; then
  branch="main"
  port="3000"
elif [ -f "$PORTS_FILE" ]; then
  offset=$(grep "^${branch}=" "$PORTS_FILE" | cut -d'=' -f2)
  if [ -n "$offset" ]; then
    port=$((3000 + offset))
  fi
fi

if [ -n "$branch" ] && [ -n "$port" ]; then
  proxy="8080"

  pr_url=""
  if [ "$branch" != "main" ]; then
    wt_dir="$WORKTREES_BASE/$branch"
    if [ -d "$wt_dir" ]; then
      pr_url=$(git -C "$wt_dir" --no-optional-locks config --get "branch.${branch}.pr-url" 2>/dev/null)
      if [ -z "$pr_url" ]; then
        pr_url=$(gh pr view "$branch" --repo adobecom/mas --json url -q .url 2>/dev/null)
        if [ -n "$pr_url" ]; then
          git -C "$wt_dir" --no-optional-locks config "branch.${branch}.pr-url" "$pr_url" 2>/dev/null
        fi
      fi
    fi
  fi

  pr_tag=""
  if [ -n "$pr_url" ]; then
    pr_num=$(echo "$pr_url" | grep -o '[0-9]*$')
    pr_tag="  \033]8;;${pr_url}\033\\PR #${pr_num}\033]8;;\033\\"
  fi

  # VS Code link
  if [ "$branch" = "main" ]; then
    vscode_path="$MAS_BASE"
  else
    vscode_path="$WORKTREES_BASE/$branch"
  fi
  vscode_link="\033]8;;vscode://file/${vscode_path}\033\\\\${MAGENTA}VS Code${RESET}\033]8;;\033\\\\"

  # Finder link
  if [ "$branch" = "main" ]; then
    finder_path="$MAS_BASE"
  else
    finder_path="$WORKTREES_BASE/$branch"
  fi
  finder_link="\033]8;;file://${finder_path}\033\\\\${MAGENTA}Finder${RESET}\033]8;;\033\\\\"

  # Local URL (clickable "Local" link)
  if [ "$port" = "3000" ]; then
    local_url="http://localhost:${port}/studio.html"
  else
    local_url="http://localhost:${port}/studio.html?proxy.port=${proxy}"
  fi
  local_link="\033]8;;${local_url}\033\\\\${BLUE}Local${RESET}\033]8;;\033\\\\"

  # Remote URL (clickable "Remote" link)
  branch_lower=$(echo "$branch" | tr '[:upper:]' '[:lower:]')
  remote_url="https://${branch_lower}--mas--adobecom.aem.live/studio.html"
  remote_link="\033]8;;${remote_url}\033\\\\${BLUE}Remote${RESET}\033]8;;\033\\\\"

  # Branch label (clickable Jira link for non-main branches)
  if [ "$branch" = "main" ]; then
    branch_label="${CYAN}${branch}${RESET}"
  else
    jira_url="https://jira.corp.adobe.com/browse/${branch}"
    branch_label="\033]8;;${jira_url}\033\\\\${CYAN}${branch}${RESET}\033]8;;\033\\\\"
  fi

  # Optional branch description
  ACTIVE_WT_DESC_FILE="$HOME/.claude/active-worktree-desc"
  desc_tag=""
  if [[ -f "$ACTIVE_WT_DESC_FILE" ]]; then
    desc=$(cat "$ACTIVE_WT_DESC_FILE")
    if [[ -n "$desc" ]]; then
      desc_tag="  ${DIM}${desc}${RESET}"
    fi
  fi

  printf "%b%b ${DIM}→${RESET} %b  %b  %b  %b%b" \
    "$branch_label" "$desc_tag" "$local_link" "$remote_link" "$vscode_link" "$finder_link" "$pr_tag"
elif [ -n "$branch" ]; then
  printf "${CYAN}%s${RESET}" "$branch"
fi
