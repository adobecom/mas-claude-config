#!/usr/bin/env bash
# install.sh — Interactive wizard to set up Claude Code for MAS development.
# Run this after cloning mas-claude-config. Safe to re-run anytime.
#
# Usage:
#   ./install.sh                    # Full interactive wizard
#   ./install.sh --config-only      # Config files only
#   ./install.sh --plugins-only     # Plugins only
#   ./install.sh --mcp-only         # MCP servers only
#   ./install.sh --non-interactive  # Silent install with all defaults
#   ./install.sh --mas-dir PATH     # Override MAS repo path
#   ./install.sh --adobe-dir PATH   # Override adobe parent path

set -euo pipefail

# ─── Colors & symbols ─────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"
ARROW="${CYAN}→${NC}"

# ─── UI helpers ───────────────────────────────────────────────────────────────

print_banner() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║  MAS Claude Code — Setup Wizard                            ║${NC}"
  echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${BOLD}║${NC}                                                              ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  Sets up your Claude Code environment for MAS development:   ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  • Coding rules, skills, commands, agents                    ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  • Auto-linting hooks (ESLint + Prettier on save)            ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  • Claude Code plugins                                       ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  • MCP servers (Jira, GitHub, MAS fragments)                 ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  • Worktree manager for parallel branch testing              ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}                                                              ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  ${DIM}Takes about 3–5 minutes. Safe to re-run anytime.${NC}           ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}                                                              ${BOLD}║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

section() {
  echo ""
  echo -e "${BOLD}${BLUE}── $1 ─────────────────────────────────────────────────${NC}"
  echo ""
}

info()    { echo -e "  ${CHECK} $1"; }
fail()    { echo -e "  ${CROSS} $1"; }
warn()    { echo -e "  ${WARN} $1"; }
step()    { echo -e "  ${ARROW} $1"; }
note()    { echo -e "  ${DIM}$1${NC}"; }

prompt_yn() {
  local prompt="$1"
  local default="${2:-y}"
  local hint
  if [ "$default" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  if [ "$NON_INTERACTIVE" = "true" ]; then
    echo "$default"
    return
  fi
  read -rp "  $prompt $hint: " answer
  answer="${answer:-$default}"
  echo "${answer:0:1}" | tr '[:upper:]' '[:lower:]'
}

prompt_input() {
  local prompt="$1"
  local default="${2:-}"
  local secret="${3:-false}"
  if [ "$NON_INTERACTIVE" = "true" ]; then
    echo "$default"
    return
  fi
  local hint=""
  [ -n "$default" ] && hint=" (default: $default)"
  if [ "$secret" = "true" ]; then
    read -rsp "  $prompt$hint: " value
    echo ""
  else
    read -rp "  $prompt$hint: " value
  fi
  echo "${value:-$default}"
}

# Simple checkbox menu (no ncurses needed)
# Usage: prompt_checklist "Header" "item1:desc1" "item2:desc2" ...
# Returns: space-separated list of selected item names
prompt_checklist() {
  local header="$1"
  shift
  local items=("$@")
  local selected=()

  if [ "$NON_INTERACTIVE" = "true" ]; then
    # In non-interactive mode, select items marked with * prefix (recommended)
    for item in "${items[@]}"; do
      local name="${item%%:*}"
      local rest="${item#*:}"
      local recommended="${rest%%:*}"
      [ "$recommended" = "yes" ] && selected+=("$name")
    done
    echo "${selected[*]}"
    return
  fi

  echo "  $header"
  echo ""
  echo -e "  ${DIM}Toggle with number keys, Enter to confirm${NC}"
  echo ""

  local state=()
  for item in "${items[@]}"; do
    local rest="${item#*:}"
    local recommended="${rest%%:*}"
    [ "$recommended" = "yes" ] && state+=("x") || state+=(" ")
  done

  while true; do
    local i=0
    for item in "${items[@]}"; do
      local name="${item%%:*}"
      local rest="${item#*:}"
      local desc="${rest#*:}"
      local checkbox="[ ]"
      [ "${state[$i]}" = "x" ] && checkbox="${GREEN}[x]${NC}"
      printf "  %s  %d) %-28s %s\n" "$(echo -e "$checkbox")" "$((i+1))" "$name" "$desc"
      ((i++))
    done
    echo ""
    read -rp "  Enter numbers to toggle (or press Enter to confirm): " input
    [ -z "$input" ] && break
    for num in $input; do
      if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#items[@]}" ]; then
        local idx=$((num-1))
        [ "${state[$idx]}" = "x" ] && state[$idx]=" " || state[$idx]="x"
      fi
    done
    # Clear the printed lines
    local clear_lines=$(( ${#items[@]} + 3 ))
    for ((j=0; j<clear_lines; j++)); do printf '\033[1A\033[2K'; done
  done

  local result=()
  local i=0
  for item in "${items[@]}"; do
    local name="${item%%:*}"
    [ "${state[$i]}" = "x" ] && result+=("$name")
    ((i++))
  done
  echo "${result[*]:-}"
}

print_summary_box() {
  local lines=("$@")
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║  Setup Complete!                                            ║${NC}"
  echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${BOLD}║${NC}                                                              ${BOLD}║${NC}"
  for line in "${lines[@]}"; do
    printf "${BOLD}║${NC}  %-60s${BOLD}║${NC}\n" "$line"
  done
  echo -e "${BOLD}║${NC}                                                              ${BOLD}║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# ─── Argument parsing ─────────────────────────────────────────────────────────

MODE="full"
NON_INTERACTIVE="false"
CUSTOM_MAS_DIR=""
CUSTOM_ADOBE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-only)     MODE="config"; shift ;;
    --plugins-only)    MODE="plugins"; shift ;;
    --mcp-only)        MODE="mcp"; shift ;;
    --non-interactive) NON_INTERACTIVE="true"; shift ;;
    --mas-dir)         CUSTOM_MAS_DIR="$2"; shift 2 ;;
    --adobe-dir)       CUSTOM_ADOBE_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Path setup ───────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_BUNDLE="$SCRIPT_DIR/config"

MAS_DIR=""
ADOBE_DIR=""

detect_paths() {
  section "Project Paths"

  # Detect MAS_DIR
  local candidate
  if [ -n "$CUSTOM_MAS_DIR" ]; then
    candidate="$CUSTOM_MAS_DIR"
  else
    # Default: sibling mas/ directory
    candidate="$(cd "$SCRIPT_DIR/../mas" 2>/dev/null && pwd)" || candidate=""
  fi

  if [ -n "$candidate" ] && [ -f "$candidate/package.json" ]; then
    local pkg_name
    pkg_name=$(node -e "console.log(require('$candidate/package.json').name || '')" 2>/dev/null || echo "")
    if [[ "$pkg_name" =~ mas|merch|studio ]]; then
      info "Detected MAS repo: $candidate (package: $pkg_name)"
    else
      info "Detected directory: $candidate"
    fi
    if [ "$NON_INTERACTIVE" = "false" ]; then
      local confirm
      confirm=$(prompt_yn "Use this path?" "y")
      if [ "$confirm" != "y" ]; then
        candidate=$(prompt_input "Enter path to MAS repo" "")
      fi
    fi
  else
    warn "Could not auto-detect MAS repo"
    candidate=$(prompt_input "Enter path to MAS repo" "$HOME/Web/adobe/mas")
  fi

  MAS_DIR="$(cd "$candidate" && pwd)"

  # Detect ADOBE_DIR
  if [ -n "$CUSTOM_ADOBE_DIR" ]; then
    ADOBE_DIR="$CUSTOM_ADOBE_DIR"
  else
    ADOBE_DIR="$(dirname "$MAS_DIR")"
  fi

  info "MAS directory:   $MAS_DIR"
  info "Adobe directory: $ADOBE_DIR"
}

# ─── Phase: Prerequisites ─────────────────────────────────────────────────────

phase_prerequisites() {
  section "Prerequisites"

  local all_ok=true

  # node
  if command -v node &>/dev/null; then
    local node_ver
    node_ver=$(node --version)
    info "node $node_ver"
  else
    fail "node not found — install from https://nodejs.org"
    all_ok=false
  fi

  # npm
  if command -v npm &>/dev/null; then
    info "npm $(npm --version)"
  else
    fail "npm not found"
    all_ok=false
  fi

  # gh CLI
  if command -v gh &>/dev/null; then
    local gh_user
    gh_user=$(gh api user --jq .login 2>/dev/null || echo "unauthenticated")
    if [ "$gh_user" = "unauthenticated" ]; then
      warn "gh CLI found but not authenticated — run 'gh auth login'"
    else
      info "gh CLI (authenticated as $gh_user)"
    fi
  else
    warn "gh CLI not found — some features won't work. Install: https://cli.github.com"
  fi

  # claude CLI
  if command -v claude &>/dev/null; then
    info "claude CLI $(claude --version 2>/dev/null | head -1)"
  else
    fail "claude CLI not found — install Claude Code first"
    all_ok=false
  fi

  # uv (for Python hooks)
  if command -v uv &>/dev/null; then
    info "uv $(uv --version)"
  else
    warn "uv not found — needed for Python hooks"
    if [ "$NON_INTERACTIVE" = "false" ]; then
      local install_uv
      install_uv=$(prompt_yn "Install uv now?" "y")
      if [ "$install_uv" = "y" ]; then
        step "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.cargo/bin:$PATH"
        if command -v uv &>/dev/null; then
          info "uv installed successfully"
        else
          warn "uv install may need a shell restart. Continuing..."
        fi
      fi
    fi
  fi

  if [ "$all_ok" = "false" ]; then
    echo ""
    fail "Critical prerequisites missing. Please install them and re-run."
    exit 1
  fi
}

# ─── Phase: Config ────────────────────────────────────────────────────────────

phase_config() {
  detect_paths

  section "Installing Configuration"

  local claude_dest="$MAS_DIR/.claude"

  # Backup existing config
  if [ -d "$claude_dest" ]; then
    local backup_name=".claude.backup.$(date +%Y%m%d_%H%M%S)"
    step "Backing up existing .claude/ → $backup_name"
    mv "$claude_dest" "$MAS_DIR/$backup_name"
    info "Backup created: $MAS_DIR/$backup_name"
  fi

  # Copy config bundle
  step "Copying configuration files..."
  mkdir -p "$claude_dest"
  rsync -a "$CONFIG_BUNDLE/" "$claude_dest/"

  # Count items
  local rule_count skill_count cmd_count agent_count hook_count
  rule_count=$(find "$claude_dest/rules" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  skill_count=$(find "$claude_dest/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  cmd_count=$(find "$claude_dest/commands" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  agent_count=$(find "$claude_dest/agents" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  hook_count=$(find "$claude_dest/hooks" -name "*.py" -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')

  info "Rules:    $rule_count files"
  info "Skills:   $skill_count directories"
  info "Commands: $cmd_count files"
  info "Agents:   $agent_count files"
  info "Hooks:    $hook_count Python scripts"

  # Copy project CLAUDE.md
  if [ -f "$SCRIPT_DIR/mas-claude.md" ]; then
    cp "$SCRIPT_DIR/mas-claude.md" "$MAS_DIR/CLAUDE.md"
    info "Installed MAS CLAUDE.md"
  fi

  # Replace path placeholders
  step "Configuring paths..."
  find "$claude_dest" "$MAS_DIR/CLAUDE.md" \
    -type f \( -name "*.md" -o -name "*.json" -o -name "*.py" -o -name "*.yaml" \) \
    2>/dev/null | while read -r file; do
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' \
          -e "s|__MAS_DIR__|$MAS_DIR|g" \
          -e "s|__ADOBE_DIR__|$ADOBE_DIR|g" \
          "$file"
      else
        sed -i \
          -e "s|__MAS_DIR__|$MAS_DIR|g" \
          -e "s|__ADOBE_DIR__|$ADOBE_DIR|g" \
          "$file"
      fi
  done
  info "Path placeholders replaced"

  # Make hooks executable
  find "$claude_dest/hooks" -name "*.py" -exec chmod +x {} \;
}

# ─── Phase: Plugins ───────────────────────────────────────────────────────────

phase_plugins() {
  section "Claude Code Plugins"

  echo "  Select which plugins to install."
  echo "  Pre-checked items are recommended for all MAS developers."
  echo ""

  local PLUGIN_ITEMS=(
    "context7@claude-plugins-official:yes:Auto-fetches Spectrum/Lit docs while coding"
    "superpowers@claude-plugins-official:yes:TDD, planning, and code review workflows"
    "playwright@claude-plugins-official:yes:Browser automation for testing"
    "chrome-devtools-mcp@claude-plugins-official:yes:Debug console errors and network requests"
    "commit-commands@claude-plugins-official:yes:Standardized commit and PR workflows"
    "figma@claude-plugins-official:no:Convert Figma designs to code (needs Figma access)"
    "claude-mem@thedotmack:no:Persistent cross-session memory (advanced)"
  )

  local selected
  selected=$(prompt_checklist "Plugins" "${PLUGIN_ITEMS[@]}")

  if [ -z "$selected" ]; then
    warn "No plugins selected, skipping"
    return
  fi

  echo ""
  step "Installing plugins..."
  for plugin in $selected; do
    if claude plugins install "$plugin" 2>/dev/null; then
      info "Installed $plugin"
    else
      warn "Could not install $plugin (may already be installed or unavailable)"
    fi
  done
}

# ─── Phase: MCP servers ───────────────────────────────────────────────────────

MCP_JSON_PATH="$HOME/.claude/mcp.json"

read_mcp_json() {
  if [ -f "$MCP_JSON_PATH" ]; then
    cat "$MCP_JSON_PATH"
  else
    echo '{"servers":{}}'
  fi
}

write_mcp_json() {
  local content="$1"
  mkdir -p "$(dirname "$MCP_JSON_PATH")"
  echo "$content" > "$MCP_JSON_PATH"
}

add_mcp_server() {
  # add_mcp_server NAME JSON_BLOCK
  local name="$1"
  local json_block="$2"
  local current
  current=$(read_mcp_json)
  # Use python3 to safely merge JSON
  local result
  result=$(python3 - "$name" "$json_block" <<'PYEOF'
import json, sys
name = sys.argv[1]
new_server = json.loads(sys.argv[2])
content = open('/dev/stdin').read() if False else None

import os
mcp_path = os.path.expanduser("~/.claude/mcp.json")
try:
    current = json.loads(open(mcp_path).read()) if os.path.exists(mcp_path) else {"servers": {}}
except Exception:
    current = {"servers": {}}

# Only add if not already configured (preserve existing tokens)
if "servers" not in current:
    current["servers"] = {}
if name not in current["servers"]:
    current["servers"][name] = new_server
    print(json.dumps(current, indent=2))
    sys.exit(0)
else:
    # Server exists - update non-secret fields only
    existing = current["servers"][name]
    for k, v in new_server.items():
        if k != "env":
            existing[k] = v
    print(json.dumps(current, indent=2))
PYEOF
  )
  write_mcp_json "$result"
}

enable_mcp_in_settings() {
  local server_name="$1"
  local settings_path="$HOME/.claude/settings.json"
  if [ ! -f "$settings_path" ]; then
    return
  fi
  python3 - "$server_name" "$settings_path" <<'PYEOF'
import json, sys
name = sys.argv[1]
path = sys.argv[2]
try:
    s = json.loads(open(path).read())
except Exception:
    s = {}
if "enabledMcpjsonServers" not in s:
    s["enabledMcpjsonServers"] = []
if name not in s["enabledMcpjsonServers"]:
    s["enabledMcpjsonServers"].append(name)
    open(path, "w").write(json.dumps(s, indent=2) + "\n")
PYEOF
}

phase_mcp() {
  detect_paths

  section "MCP Servers"
  echo "  MCP servers connect Claude to external tools."
  echo "  Configure the ones your workflow needs."
  echo ""

  local mcps_configured=0

  # ── 1. corp-jira ────────────────────────────────────────────────────────────
  echo -e "  ${BOLD}1/4  Corp Jira${NC}"
  note "  Lets Claude read, create, and update Jira tickets."
  note "  Used by: /start-ticket, /tickets, /jira-ticket-creator"
  echo ""

  local setup_jira
  setup_jira=$(prompt_yn "Configure corp-jira?" "y")
  if [ "$setup_jira" = "y" ]; then
    # Clone the MCP server if not already present
    local jira_mcp_dir="$ADOBE_DIR/remote-corp-jira-mcp"
    if [ ! -d "$jira_mcp_dir" ]; then
      step "Cloning adobecom/remote-corp-jira-mcp..."
      git clone --quiet https://github.com/adobecom/remote-corp-jira-mcp.git "$jira_mcp_dir"
      step "Building..."
      (cd "$jira_mcp_dir" && npm install --silent && npm run build --silent 2>/dev/null || true)
      info "Corp Jira MCP server ready"
    else
      info "Corp Jira MCP server already present: $jira_mcp_dir"
    fi

    local jira_entry_point="$jira_mcp_dir/dist/index.js"
    [ ! -f "$jira_entry_point" ] && jira_entry_point="$jira_mcp_dir/src/index.js"

    echo ""
    note "  Get your Jira PAT: https://jira.corp.adobe.com → Profile → Personal Access Tokens"
    local jira_pat
    jira_pat=$(prompt_input "Jira Personal Access Token (hidden)" "" "true")

    if [ -n "$jira_pat" ]; then
      local jira_email="${USER}@adobe.com"
      add_mcp_server "corp-jira" "{
        \"command\": \"node\",
        \"args\": [\"$jira_entry_point\"],
        \"env\": {
          \"JIRA_PERSONAL_ACCESS_TOKEN\": \"$jira_pat\",
          \"JIRA_EMAIL\": \"$jira_email\"
        }
      }"
      enable_mcp_in_settings "corp-jira"
      info "corp-jira configured"
      ((mcps_configured++))
    else
      warn "Skipped (no PAT entered)"
    fi
  fi

  echo ""

  # ── 2. GitHub ────────────────────────────────────────────────────────────────
  echo -e "  ${BOLD}2/4  GitHub${NC}"
  note "  Lets Claude interact with GitHub PRs, issues, and repos."
  note "  Used by: /review-pr, /mas-pr-creator"
  echo ""

  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    note "  You have 'gh' authenticated. You can use that (no extra config needed)"
    note "  or set up the GitHub MCP server for richer integration."
    local setup_gh
    setup_gh=$(prompt_yn "Also set up GitHub MCP server?" "n")
    if [ "$setup_gh" = "y" ]; then
      local gh_pat
      gh_pat=$(prompt_input "GitHub Personal Access Token (hidden)" "" "true")
      if [ -n "$gh_pat" ]; then
        add_mcp_server "github" "{
          \"command\": \"npx\",
          \"args\": [\"-y\", \"@modelcontextprotocol/server-github\"],
          \"env\": {
            \"GITHUB_PERSONAL_ACCESS_TOKEN\": \"$gh_pat\"
          }
        }"
        info "GitHub MCP configured"
        ((mcps_configured++))
      fi
    else
      info "Using gh CLI (no MCP server needed)"
    fi
  else
    local setup_gh
    setup_gh=$(prompt_yn "Configure GitHub MCP server?" "y")
    if [ "$setup_gh" = "y" ]; then
      note "  Create a PAT at: https://github.com/settings/tokens"
      note "  Required scopes: repo, read:org"
      local gh_pat
      gh_pat=$(prompt_input "GitHub Personal Access Token (hidden)" "" "true")
      if [ -n "$gh_pat" ]; then
        add_mcp_server "github" "{
          \"command\": \"npx\",
          \"args\": [\"-y\", \"@modelcontextprotocol/server-github\"],
          \"env\": {
            \"GITHUB_PERSONAL_ACCESS_TOKEN\": \"$gh_pat\"
          }
        }"
        info "GitHub MCP configured"
        ((mcps_configured++))
      fi
    fi
  fi

  echo ""

  # ── 3. MAS Content Fragments ─────────────────────────────────────────────────
  echo -e "  ${BOLD}3/4  MAS Content Fragments${NC}"
  note "  Lets Claude search, create, and publish AEM content fragments."
  note "  Used by: /test-mcp, fragment operations, bulk publish"
  echo ""

  local setup_mas
  setup_mas=$(prompt_yn "Configure MAS MCP server?" "y")
  if [ "$setup_mas" = "y" ]; then
    local mas_mcp_dir="$MAS_DIR/mas-mcp-server"
    local mas_entry="$mas_mcp_dir/dist/index.js"

    if [ ! -d "$mas_mcp_dir" ]; then
      warn "MAS MCP server not found at $mas_mcp_dir"
      warn "Make sure you have the full MAS repo and run 'npm install'"
    else
      # Build if dist/ is missing or stale
      if [ ! -f "$mas_entry" ]; then
        step "Building MAS MCP server..."
        (cd "$mas_mcp_dir" && npm install --silent && npm run build --silent 2>/dev/null || true)
      fi

      if [ -f "$mas_entry" ]; then
        add_mcp_server "mas" "{
          \"command\": \"node\",
          \"args\": [\"$mas_entry\"],
          \"env\": {}
        }"
        enable_mcp_in_settings "mas"
        info "MAS MCP configured → $mas_entry"
        ((mcps_configured++))
        echo ""
        warn "IMS authentication required separately:"
        note "  cd $mas_mcp_dir && npm run auth"
      else
        warn "Build failed — check $mas_mcp_dir for errors"
      fi
    fi
  fi

  echo ""

  # ── 4. FluffyJaws ────────────────────────────────────────────────────────────
  echo -e "  ${BOLD}4/4  FluffyJaws (Adobe internal knowledge)${NC}"
  note "  Searches Slack, wiki, Jira, AEM docs, and pipeline infrastructure."
  note "  Used by: /start-ticket context gathering, AEM/Adobe questions"
  echo ""

  if command -v fj &>/dev/null; then
    local fj_authed=false
    if fj whoami &>/dev/null 2>&1; then
      fj_authed=true
      info "fj CLI found and authenticated"
    else
      warn "fj CLI found but not authenticated"
    fi

    local setup_fj
    setup_fj=$(prompt_yn "Configure FluffyJaws MCP?" "y")
    if [ "$setup_fj" = "y" ]; then
      if [ "$fj_authed" = "false" ]; then
        step "Running fj login (browser flow will open)..."
        fj login
      fi
      add_mcp_server "fluffyjaws" "{
        \"command\": \"fj\",
        \"args\": [\"mcp\"],
        \"env\": {}
      }"
      enable_mcp_in_settings "fluffyjaws"
      info "FluffyJaws MCP configured"
      ((mcps_configured++))
    fi
  else
    warn "fj CLI not found — FluffyJaws is an Adobe internal tool"
    note "  Install it from: go/fluffyjaws or ask a teammate for the installer"
    note "  Once installed, run: fj login && fj mcp"
    note "  Then re-run: ./install.sh --mcp-only"
  fi

  echo ""
  info "$mcps_configured MCP server(s) configured"
}

# ─── Phase: Worktrees ─────────────────────────────────────────────────────────

phase_worktrees() {
  detect_paths

  section "Worktree Manager"

  echo "  The 'wt' script lets you run multiple MAS branches simultaneously,"
  echo "  each on its own AEM port — great for reviewing PRs or context-switching."
  echo ""
  echo "  Example:"
  echo -e "    ${DIM}bash worktrees/wt new MWPW-123456    # create isolated checkout${NC}"
  echo -e "    ${DIM}bash worktrees/wt start MWPW-123456  # start AEM on port 3001${NC}"
  echo -e "    ${DIM}bash worktrees/wt list               # show all worktrees + ports${NC}"
  echo ""

  local setup_wt
  setup_wt=$(prompt_yn "Install worktree tooling?" "y")
  if [ "$setup_wt" = "y" ]; then
    local wt_dir="$ADOBE_DIR/worktrees"
    mkdir -p "$wt_dir"

    if [ -f "$SCRIPT_DIR/worktrees/wt" ]; then
      cp "$SCRIPT_DIR/worktrees/wt" "$wt_dir/wt"
      chmod +x "$wt_dir/wt"
      info "Installed wt to $wt_dir/wt"
    else
      warn "worktrees/wt not found in bundle"
    fi

    # Create .ports file if missing
    if [ ! -f "$wt_dir/.ports" ]; then
      touch "$wt_dir/.ports"
      info "Created empty .ports registry"
    else
      info ".ports registry already exists"
    fi

    # Install adobe-level CLAUDE.md
    if [ -f "$SCRIPT_DIR/adobe-claude.md" ]; then
      local adobe_claude="$ADOBE_DIR/CLAUDE.md"
      if [ ! -f "$adobe_claude" ]; then
        cp "$SCRIPT_DIR/adobe-claude.md" "$adobe_claude"
        # Replace placeholders in the file
        if [[ "$OSTYPE" == "darwin"* ]]; then
          sed -i '' \
            -e "s|__ADOBE_DIR__|$ADOBE_DIR|g" \
            -e "s|__MAS_DIR__|$MAS_DIR|g" \
            "$adobe_claude"
        else
          sed -i \
            -e "s|__ADOBE_DIR__|$ADOBE_DIR|g" \
            -e "s|__MAS_DIR__|$MAS_DIR|g" \
            "$adobe_claude"
        fi
        info "Installed adobe/CLAUDE.md with worktree docs"
      else
        info "adobe/CLAUDE.md already exists (not overwritten)"
      fi
    fi
  fi
}

# ─── Phase: Summary ───────────────────────────────────────────────────────────

INSTALLED_CONFIG=false
INSTALLED_PLUGINS=false
INSTALLED_MCPS=0

phase_summary() {
  local lines=()
  [ "$INSTALLED_CONFIG" = "true" ] && lines+=("✓ Configuration: rules, skills, commands, agents, hooks")
  [ "$INSTALLED_PLUGINS" = "true" ] && lines+=("✓ Plugins installed")
  [ "$INSTALLED_MCPS" -gt 0 ] && lines+=("✓ $INSTALLED_MCPS MCP server(s) configured")
  lines+=("")
  lines+=("Remaining manual steps:")
  lines+=("  1. Run 'npm install' in mas/ (if not done)")
  lines+=("  2. Copy .env from a teammate (IMS credentials)")
  if [ "$INSTALLED_MCPS" -gt 0 ]; then
    lines+=("  3. Authenticate MAS MCP: cd mas-mcp-server && npm run auth")
  fi
  lines+=("")
  lines+=("Try it: open Claude Code in mas/ and run /start-ticket")
  lines+=("")
  lines+=("Update later: git pull && ./install.sh")

  print_summary_box "${lines[@]}"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

case "$MODE" in
  full)
    print_banner
    phase_prerequisites
    phase_config
    INSTALLED_CONFIG=true
    phase_plugins
    INSTALLED_PLUGINS=true
    phase_mcp
    phase_worktrees
    phase_summary
    ;;
  config)
    phase_prerequisites
    phase_config
    info "Config installed."
    ;;
  plugins)
    phase_plugins
    info "Plugins installed."
    ;;
  mcp)
    phase_mcp
    ;;
esac
