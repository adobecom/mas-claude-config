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
  echo -e "${BOLD}║${NC}  • Secret-leak prevention hooks (blocks credentials)         ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  • Claude Code plugins                                       ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  • MCP servers (Jira, Wiki, FluffyJaws)                      ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  • Worktree manager + claude-mas shell helper                ${BOLD}║${NC}"
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

  # Copy subdirectory CLAUDE.md files (studio/, io/, studio/src/aem/, etc.).
  # The mas repo gitignores **/CLAUDE.md, so these are per-machine files —
  # but the team still wants them shared. Install.sh copies them in from
  # mas-claude-config/subdir-claude-md/, mirroring the path structure.
  # Overwrites local edits (same contract as the root CLAUDE.md install above).
  local subdir_claude_src="$SCRIPT_DIR/subdir-claude-md"
  if [ -d "$subdir_claude_src" ]; then
    local subdir_count=0
    while IFS= read -r src; do
      local rel="${src#$subdir_claude_src/}"
      local dest="$MAS_DIR/$rel"
      mkdir -p "$(dirname "$dest")"
      cp "$src" "$dest"
      subdir_count=$((subdir_count + 1))
    done < <(find "$subdir_claude_src" -name "CLAUDE.md" -type f 2>/dev/null)
    info "Installed $subdir_count subdir CLAUDE.md file(s)"
  fi

  # Copy .graphifyignore (only if user hasn't customized one)
  if [ -f "$SCRIPT_DIR/.graphifyignore" ] && [ ! -f "$MAS_DIR/.graphifyignore" ]; then
    cp "$SCRIPT_DIR/.graphifyignore" "$MAS_DIR/.graphifyignore"
    info "Installed .graphifyignore"
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
    "github@claude-plugins-official:yes:GitHub PR/issue skills and workflows"
    "figma@claude-plugins-official:no:Convert Figma designs to code (needs Figma access)"
    "claude-mem@thedotmack:no:Persistent cross-session memory (advanced)"
    "explanatory-output-style@claude-plugins-official:no:Educational insights while coding (verbose)"
  )

  local selected
  selected=$(prompt_checklist "Plugins" "${PLUGIN_ITEMS[@]}")

  if [ -z "$selected" ]; then
    warn "No plugins selected, skipping"
    return
  fi

  echo ""
  step "Installing marketplace plugins..."
  for plugin in $selected; do
    if claude plugins install "$plugin" 2>/dev/null; then
      info "Installed $plugin"
    else
      warn "Could not install $plugin (may already be installed or unavailable)"
    fi
  done

  # ── challenge@local — bundled custom plugin ───────────────────────────────
  echo ""
  echo -e "  ${BOLD}Local Plugin: challenge${NC}"
  note "  Spawns Architect, Adversary, Simplifier, and Reviewer agents"
  note "  to stress-test design decisions before a PR."
  echo ""
  local install_challenge
  install_challenge=$(prompt_yn "Install challenge plugin?" "y")
  if [ "$install_challenge" = "y" ]; then
    local challenge_dest="$HOME/.claude/plugins/challenge"
    if [ -d "$challenge_dest" ]; then
      info "challenge plugin already installed"
    else
      mkdir -p "$challenge_dest"
      cp -r "$SCRIPT_DIR/challenge-plugin/." "$challenge_dest/"
      info "challenge plugin installed"
    fi
  fi
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

  # ── Shared: Adobe-AIFoundations/adobe-mcp-servers monorepo ──────────────────
  # Both corp-jira and adobe-wiki ship from this monorepo. Clone once.
  local adobe_mcps_dir="$ADOBE_DIR/adobe-mcp-servers"
  ensure_adobe_mcps_monorepo() {
    local subdir="$1"  # e.g. "src/corp-jira"
    if [ ! -d "$adobe_mcps_dir" ]; then
      step "Cloning Adobe-AIFoundations/adobe-mcp-servers..."
      if ! git clone --quiet git@github.com:Adobe-AIFoundations/adobe-mcp-servers.git "$adobe_mcps_dir" 2>/dev/null; then
        warn "git clone failed — make sure you have access to Adobe-AIFoundations/adobe-mcp-servers"
        note "Visit https://github.com/Adobe-AIFoundations/adobe-mcp-servers to request access."
        return 1
      fi
    fi
    # Build the requested subdir if dist/ is missing.
    local sub="$adobe_mcps_dir/$subdir"
    if [ ! -f "$sub/dist/index.js" ] && [ -d "$sub" ]; then
      step "Building $subdir..."
      (cd "$sub" && npm install --silent && npm run build --silent 2>/dev/null || true)
    fi
    return 0
  }

  # ── 1. corp-jira ────────────────────────────────────────────────────────────
  echo -e "  ${BOLD}1/4  Corp Jira${NC}"
  note "  Lets Claude read, create, and update Jira tickets."
  note "  Used by: /start-ticket, /tickets, /jira-ticket-creator"
  echo ""

  local setup_jira
  setup_jira=$(prompt_yn "Configure corp-jira?" "y")
  if [ "$setup_jira" = "y" ]; then
    if ensure_adobe_mcps_monorepo "src/corp-jira"; then
      local jira_entry_point="$adobe_mcps_dir/src/corp-jira/dist/index.js"
      if [ ! -f "$jira_entry_point" ]; then
        warn "Build artifact not found at $jira_entry_point"
        warn "Run manually: cd $adobe_mcps_dir/src/corp-jira && npm install && npm run build"
      else
        echo ""
        note "  Create a Jira PAT:"
        note "    1. https://jira.corp.adobe.com/secure/ViewProfile.jspa"
        note "    2. → Personal Access Tokens → Create token (any name, default scopes)"
        note "  Verify it works before pasting:"
        note "    curl -H \"Authorization: Bearer <PAT>\" \\"
        note "         \"https://jira.corp.adobe.com/rest/api/3/myself\""
        note "  Full troubleshooting (CAPTCHA, 302/401, etc.):"
        note "    https://github.com/Adobe-AIFoundations/adobe-mcp-servers/tree/main/src/corp-jira"
        echo ""
        local jira_pat
        jira_pat=$(prompt_input "Jira Personal Access Token (hidden)" "" "true")

        if [ -n "$jira_pat" ]; then
          local jira_email="${USER}@adobe.com"
          add_mcp_server "corp-jira" "{
            \"command\": \"node\",
            \"args\": [\"$jira_entry_point\"],
            \"env\": {
              \"JIRA_PERSONAL_ACCESS_TOKEN\": \"$jira_pat\",
              \"JIRA_EMAIL\": \"$jira_email\",
              \"JIRA_API_BASE_URL\": \"https://jira.corp.adobe.com/rest/api/2\"
            }
          }"
          enable_mcp_in_settings "corp-jira"
          info "corp-jira configured"
          ((mcps_configured++))
        else
          warn "Skipped (no PAT entered)"
        fi
      fi
    fi
  fi

  echo ""

  # ── 2. GitHub (gh CLI, no MCP) ───────────────────────────────────────────────
  echo -e "  ${BOLD}2/4  GitHub${NC}"
  note "  We use the 'gh' CLI for GitHub interactions (PRs, issues, comments)."
  note "  Used by: /review-pr, /mas-pr-creator, gh pr create/edit/comment"
  echo ""

  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      info "gh CLI installed and authenticated"
    else
      warn "gh CLI installed but not authenticated"
      note "Run: gh auth login"
    fi
  else
    warn "gh CLI not found"
    note "Install: brew install gh    (then run: gh auth login)"
  fi

  echo ""

  # ── 3. Adobe Wiki ────────────────────────────────────────────────────────────
  echo -e "  ${BOLD}3/4  Adobe Wiki${NC}"
  note "  Lets Claude read, search, update, and comment on Adobe Wiki (wiki.corp.adobe.com)."
  note "  Useful for: runbooks, internal docs, PR-context lookup."
  echo ""

  local setup_wiki
  setup_wiki=$(prompt_yn "Configure adobe-wiki MCP?" "y")
  if [ "$setup_wiki" = "y" ]; then
    if ensure_adobe_mcps_monorepo "src/adobe-wiki"; then
      local wiki_entry_point="$adobe_mcps_dir/src/adobe-wiki/dist/index.js"
      if [ ! -f "$wiki_entry_point" ]; then
        warn "Build artifact not found at $wiki_entry_point"
        warn "Run manually: cd $adobe_mcps_dir/src/adobe-wiki && npm install && npm run build"
      else
        echo ""
        note "  Create a Wiki PAT:"
        note "    1. https://wiki.corp.adobe.com → avatar → Settings → Personal Access Tokens"
        note "    2. Create token (any name, default scopes), copy it"
        note "  Upstream docs (tools, PlantUML, Confluence storage format):"
        note "    https://github.com/Adobe-AIFoundations/adobe-mcp-servers/tree/main/src/adobe-wiki"
        echo ""
        local wiki_pat
        wiki_pat=$(prompt_input "Wiki Personal Access Token (hidden)" "" "true")

        if [ -n "$wiki_pat" ]; then
          add_mcp_server "adobe-wiki" "{
            \"command\": \"node\",
            \"args\": [\"$wiki_entry_point\"],
            \"env\": {
              \"WIKI_MCP_TOKEN\": \"$wiki_pat\",
              \"WIKI_MCP_HOST\": \"wiki.corp.adobe.com\"
            }
          }"
          enable_mcp_in_settings "adobe-wiki"
          info "adobe-wiki configured"
          ((mcps_configured++))
        else
          warn "Skipped (no PAT entered)"
        fi
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

    local fj_mcp_cmd="fj"
    local fj_mcp_args="[\"mcp\"]"
    if command -v fj-mcp &>/dev/null; then
      fj_mcp_cmd="fj-mcp"
      fj_mcp_args="[\"--api\", \"https://api.fluffyjaws.adobe.com\"]"
      info "fj-mcp shim found — using current MCP invocation pattern"
    else
      warn "fj-mcp shim not found — falling back to legacy 'fj mcp' wiring"
      note "  Upgrade fj to get the dedicated fj-mcp binary"
    fi

    local setup_fj
    setup_fj=$(prompt_yn "Configure FluffyJaws MCP?" "y")
    if [ "$setup_fj" = "y" ]; then
      if [ "$fj_authed" = "false" ]; then
        step "Running fj login (browser flow will open)..."
        fj login
      fi
      add_mcp_server "fluffyjaws" "{
        \"command\": \"$fj_mcp_cmd\",
        \"args\": $fj_mcp_args,
        \"env\": {\"FJ_API_HOST\": \"https://api.fluffyjaws.adobe.com\"}
      }"
      enable_mcp_in_settings "fluffyjaws"
      info "FluffyJaws MCP configured"
      ((mcps_configured++))
    fi
  else
    warn "fj CLI not found — FluffyJaws is an Adobe internal tool"
    note "  Install it from: go/fluffyjaws or ask a teammate for the installer"
    note "  Once installed, run: fj login (then re-run ./install.sh --mcp-only)"
  fi

  echo ""
  info "$mcps_configured MCP server(s) configured"

  # ── Migration notes for upgraders ──────────────────────────────────────────
  # Surface drift between the old wizard layout and the new one. Read-only —
  # we never delete anything for the user, just flag what's stale.

  local old_jira_clone="$ADOBE_DIR/remote-corp-jira-mcp"
  if [ -d "$old_jira_clone" ]; then
    echo ""
    warn "Old Jira MCP clone detected at: $old_jira_clone"
    note "The Jira MCP source moved to Adobe-AIFoundations/adobe-mcp-servers."
    note "Safe to delete the old clone:"
    note "  rm -rf $old_jira_clone"
  fi

  # MAS MCP entry left over from the old wizard: it pointed at a path that may
  # no longer exist (mas-mcp-server source isn't on origin/main).
  if [ -f "$MCP_JSON_PATH" ]; then
    local stale_mas_entry
    stale_mas_entry=$(python3 - <<'PYEOF'
import json, os, sys
mcp_path = os.path.expanduser("~/.claude/mcp.json")
try:
    cfg = json.loads(open(mcp_path).read())
except Exception:
    sys.exit(0)
mas = cfg.get("servers", {}).get("mas")
if not mas:
    sys.exit(0)
args = mas.get("args") or []
entry = args[0] if args else None
if entry and not os.path.exists(entry):
    print(entry)
PYEOF
    )
    if [ -n "$stale_mas_entry" ]; then
      echo ""
      warn "MAS MCP entry in ~/.claude/mcp.json points to a missing path:"
      note "  $stale_mas_entry"
      note "The 'mas' MCP was removed from this wizard (source isn't on origin/main yet)."
      note "Clean up the orphan entry with:"
      note "  claude mcp remove mas"
    fi
  fi

  # Stale FluffyJaws wiring: previous wizard versions used `fj mcp` against the
  # default host. Current contract is `fj-mcp --api https://api.fluffyjaws.adobe.com`
  # (fj API moved to api.fluffyjaws.adobe.com; the bare host is now Banyan/VPN-gated).
  if [ -f "$MCP_JSON_PATH" ]; then
    local legacy_fj
    legacy_fj=$(python3 - <<'PYEOF'
import json, os, sys
mcp_path = os.path.expanduser("~/.claude/mcp.json")
try:
    cfg = json.loads(open(mcp_path).read())
except Exception:
    sys.exit(0)
fj = cfg.get("mcpServers", {}).get("fluffyjaws") or cfg.get("servers", {}).get("fluffyjaws")
if not fj:
    sys.exit(0)
cmd = fj.get("command", "")
args = fj.get("args") or []
env = fj.get("env") or {}
if cmd == "fj" and "mcp" in args:
    print("legacy")
elif cmd == "fj-mcp" and not env.get("FJ_API_HOST") and not any("api.fluffyjaws.adobe.com" in str(a) for a in args):
    print("missing-host")
PYEOF
    )
    if [ "$legacy_fj" = "legacy" ]; then
      echo ""
      warn "FluffyJaws MCP wired with legacy 'fj mcp' invocation"
      note "Current pattern uses the dedicated fj-mcp shim with explicit API host."
      note "Re-run to update:"
      note "  ./install.sh --mcp-only"
    elif [ "$legacy_fj" = "missing-host" ]; then
      echo ""
      warn "FluffyJaws MCP missing FJ_API_HOST/--api — may break when bare host is VPN-gated"
      note "Re-run to apply the current wiring:"
      note "  ./install.sh --mcp-only"
    fi
  fi
}

# ─── Phase: User-level skills & statusline ───────────────────────────────────

phase_user_skills() {
  section "User-Level Skills & Statusline"

  echo "  These install to ~/.claude/ (global, not per-repo):"
  echo ""
  echo "  • mas-unit-test-runner        — run/fix/write WTR unit tests"
  echo "  • nala-test-runner            — run/debug Nala E2E tests"
  echo "  • extension-devtools-debugger — debug the MAS Studio Chrome extension"
  echo "  • statusline                  — branch, port, Jira link, Local/Remote links"
  echo ""

  local install_user
  install_user=$(prompt_yn "Install user-level skills and statusline?" "y")
  if [ "$install_user" != "y" ]; then
    return
  fi

  local user_skills_src="$SCRIPT_DIR/config/user-skills"
  local user_skills_dest="$HOME/.claude/skills"
  mkdir -p "$user_skills_dest"

  for skill_dir in "$user_skills_src"/*/; do
    local skill_name
    skill_name=$(basename "$skill_dir")
    local dest="$user_skills_dest/$skill_name"
    local action="Installed"
    if [ -d "$dest" ]; then
      rm -rf "$dest"
      action="Updated"
    fi
    mkdir -p "$dest"
    cp -r "$skill_dir." "$dest/"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' \
        -e "s|__MAS_DIR__|$MAS_DIR|g" \
        -e "s|__ADOBE_DIR__|$ADOBE_DIR|g" \
        "$dest/SKILL.md" 2>/dev/null || true
    else
      sed -i \
        -e "s|__MAS_DIR__|$MAS_DIR|g" \
        -e "s|__ADOBE_DIR__|$ADOBE_DIR|g" \
        "$dest/SKILL.md" 2>/dev/null || true
    fi
    info "$action skill: $skill_name"
  done

  # Statusline
  local statusline_dest="$HOME/.claude/statusline-command.sh"
  local statusline_action="Installed"
  if [ -f "$statusline_dest" ]; then
    cp "$statusline_dest" "${statusline_dest}.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    statusline_action="Updated"
  fi
  cp "$SCRIPT_DIR/statusline-command.sh" "$statusline_dest"
  chmod +x "$statusline_dest"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' \
      -e "s|__MAS_DIR__|$MAS_DIR|g" \
      -e "s|__ADOBE_DIR__|$ADOBE_DIR|g" \
      "$statusline_dest"
  else
    sed -i \
      -e "s|__MAS_DIR__|$MAS_DIR|g" \
      -e "s|__ADOBE_DIR__|$ADOBE_DIR|g" \
      "$statusline_dest"
  fi
  local settings_path="$HOME/.claude/settings.json"
  if [ -f "$settings_path" ]; then
    python3 - "$statusline_dest" "$settings_path" <<'PYEOF'
import json, sys
statusline_path = sys.argv[1]
settings_path = sys.argv[2]
try:
    with open(settings_path) as f:
        s = json.load(f)
except Exception:
    s = {}
s["statusLine"] = {"type": "command", "command": f"bash {statusline_path}"}
with open(settings_path, "w") as f:
    json.dump(s, f, indent=2)
PYEOF
    info "Statusline configured in ~/.claude/settings.json"
  else
    note "To enable statusline, add to ~/.claude/settings.json:"
    note "  \"statusLine\": {\"type\": \"command\", \"command\": \"bash $statusline_dest\"}"
  fi
  info "$statusline_action statusline"
}

# ─── Phase: Secret-leak prevention hooks ─────────────────────────────────────

phase_secret_hooks() {
  section "Secret-Leak Prevention Hooks"

  echo "  Installs PreToolUse hooks that block writes containing credentials"
  echo "  (GitHub PATs, AWS keys, Figma/Slack/OpenAI/Anthropic tokens, PEM keys,"
  echo "  DB URIs with passwords, and high-entropy strings in .claude/ files)."
  echo ""
  echo "  Plus a 'gh pr create|edit' diff scanner and an audit script (/scan-secrets)."
  echo ""
  echo "  Override marker for documented references:  <!-- secret-ok: <reason> -->"
  echo ""

  local install_hooks
  install_hooks=$(prompt_yn "Install secret-leak prevention hooks?" "y")
  if [ "$install_hooks" != "y" ]; then
    return
  fi

  local hooks_src="$SCRIPT_DIR/config/hooks"
  local hooks_dest="$HOME/.claude/hooks"
  mkdir -p "$hooks_dest" "$hooks_dest/scripts" "$HOME/.claude/commands"

  # Copy the 3 hook files + 1 audit script
  for f in _secret_rules.py secret_leak_gate.py pr_secret_scan.py; do
    cp "$hooks_src/$f" "$hooks_dest/$f"
    info "Installed: ~/.claude/hooks/$f"
  done
  cp "$hooks_src/scripts/scan-existing-secrets.py" "$hooks_dest/scripts/scan-existing-secrets.py"
  info "Installed: ~/.claude/hooks/scripts/scan-existing-secrets.py"

  chmod +x "$hooks_dest/secret_leak_gate.py" \
           "$hooks_dest/pr_secret_scan.py" \
           "$hooks_dest/scripts/scan-existing-secrets.py"

  # Copy the slash command (lives in user's commands dir, not the project)
  if [ -f "$SCRIPT_DIR/config/commands/scan-secrets.md" ]; then
    cp "$SCRIPT_DIR/config/commands/scan-secrets.md" "$HOME/.claude/commands/scan-secrets.md"
    info "Installed slash command: /scan-secrets"
  fi

  # Merge the two PreToolUse matcher blocks into ~/.claude/settings.json
  # Use Python so we can do a structured merge — bash JSON editing is error-prone.
  local settings_path="$HOME/.claude/settings.json"
  python3 - "$settings_path" "$hooks_dest" <<'PYEOF'
import json
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
hooks_dest = sys.argv[2]

LEAK_HOOK = {
    "matcher": "Write|Edit|MultiEdit|Bash",
    "hooks": [{
        "type": "command",
        "command": f"uv run {hooks_dest}/secret_leak_gate.py",
    }],
}
PR_HOOK = {
    "matcher": "Bash",
    "hooks": [{
        "type": "command",
        "command": f"uv run {hooks_dest}/pr_secret_scan.py",
    }],
}

if settings_path.exists():
    try:
        s = json.loads(settings_path.read_text())
    except Exception:
        s = {}
else:
    s = {}

s.setdefault("hooks", {})
pre = s["hooks"].setdefault("PreToolUse", [])

def already_wired(target_cmd: str) -> bool:
    for block in pre:
        for h in block.get("hooks", []) or []:
            if isinstance(h, dict) and target_cmd in (h.get("command") or ""):
                return True
    return False

added = 0
if not already_wired("secret_leak_gate.py"):
    pre.insert(0, LEAK_HOOK)
    added += 1
if not already_wired("pr_secret_scan.py"):
    insert_at = 1 if added else 0
    pre.insert(insert_at, PR_HOOK)
    added += 1

settings_path.parent.mkdir(parents=True, exist_ok=True)
settings_path.write_text(json.dumps(s, indent=2) + "\n")
print(f"settings.json: added {added} new matcher block(s)")
PYEOF

  info "Wired hooks in ~/.claude/settings.json"

  # Sanity check: run the audit script to surface any existing leaks the user should rotate.
  echo ""
  step "Running one-shot audit to surface existing leaks (if any)..."
  set +e
  python3 "$hooks_dest/scripts/scan-existing-secrets.py" 2>&1 | tail -40
  local audit_exit=$?
  set -e
  if [ "$audit_exit" -ne 0 ]; then
    echo ""
    warn "Audit found existing secrets — rotate them and remove from disk."
    note "Re-run anytime with:  /scan-secrets  (in Claude Code)"
    note "Or directly:          python3 ~/.claude/hooks/scripts/scan-existing-secrets.py"
  else
    info "No leaks found."
  fi
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

# ─── Phase: Shell helpers (claude-mas, mas) ───────────────────────────────────

phase_shell_helpers() {
  detect_paths

  section "Shell Helpers"

  echo "  Installs two shell functions you can use from any terminal:"
  echo ""
  echo -e "    ${DIM}claude-mas MWPW-123456   # open Claude Code in that worktree (creates if missing)${NC}"
  echo -e "    ${DIM}claude-mas main          # open Claude Code in main mas repo${NC}"
  echo -e "    ${DIM}claude-mas               # same as 'claude-mas main'${NC}"
  echo -e "    ${DIM}mas                      # cd into main mas repo${NC}"
  echo ""

  local install_helpers
  install_helpers=$(prompt_yn "Install shell helpers (claude-mas, mas)?" "y")
  if [ "$install_helpers" != "y" ]; then
    return
  fi

  local helper_src="$SCRIPT_DIR/scripts/claude-mas.sh"
  if [ ! -f "$helper_src" ]; then
    warn "scripts/claude-mas.sh not found in bundle"
    return
  fi

  local marker_begin="# >>> mas-claude-config: claude-mas (managed) >>>"
  local marker_end="# <<< mas-claude-config: claude-mas (managed) <<<"

  local block_file
  block_file=$(mktemp)
  cat > "$block_file" <<EOF
$marker_begin
export ADOBE_DIR="$ADOBE_DIR"
export MAS_DIR="$MAS_DIR"
[ -f "$helper_src" ] && . "$helper_src"
$marker_end
EOF

  local installed_any=0
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    # Skip non-existent rc files that aren't the default for this shell.
    if [ ! -f "$rc" ]; then
      case "$rc" in
        *zshrc) [ -n "${ZSH_VERSION:-}" ] || [ "${SHELL##*/}" = "zsh" ] || continue ;;
        *bashrc) [ -n "${BASH_VERSION:-}" ] || [ "${SHELL##*/}" = "bash" ] || continue ;;
      esac
    fi

    if [ -f "$rc" ] && grep -q "mas-claude-config: claude-mas (managed)" "$rc"; then
      # Update the existing block in-place via awk.
      local tmp
      tmp=$(mktemp)
      awk -v b="$marker_begin" -v e="$marker_end" -v bf="$block_file" '
        $0 == b {
          while ((getline line < bf) > 0) print line
          close(bf)
          skip = 1
          next
        }
        skip && $0 == e { skip = 0; next }
        !skip { print }
      ' "$rc" > "$tmp" && mv "$tmp" "$rc"
      info "Updated managed block in $rc"
    else
      printf '\n' >> "$rc"
      cat "$block_file" >> "$rc"
      info "Appended managed block to $rc"
    fi
    installed_any=1
  done

  rm -f "$block_file"

  if [ "$installed_any" -eq 1 ]; then
    note "Run 'source ~/.zshrc' (or restart your shell) to start using:"
    note "  claude-mas <branch>"
    note "  mas"
  else
    warn "No shell rc files found — add this line manually to your shell rc:"
    note "  . \"$helper_src\""
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
    phase_user_skills
    phase_secret_hooks
    phase_plugins
    INSTALLED_PLUGINS=true
    phase_mcp
    phase_worktrees
    phase_shell_helpers
    phase_summary
    ;;
  config)
    phase_prerequisites
    phase_config
    phase_user_skills
    phase_secret_hooks
    phase_shell_helpers
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
