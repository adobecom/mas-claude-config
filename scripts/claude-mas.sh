# MAS Claude shell helpers
# Sourced from ~/.zshrc and ~/.bashrc by mas-claude-config/install.sh.
#
# Provides:
#   claude-mas [MWPW-XXXXX|main] [claude-flags...]
#       Open Claude Code in a MAS worktree (auto-creates if missing).
#       No args → opens main mas repo.
#   claude-mas-team [MWPW-XXXXX|main] [claude-flags...]
#       Same as claude-mas, but launches a cmux Claude Code agent team
#       (cmux claude-teams) so spawned teammates show as cmux splits.
#   mas
#       cd into the main mas repo.
#
# Paths come from $MAS_DIR and $ADOBE_DIR (exported below). install.sh
# personalizes these at install time; you can override them in your rc.

# ─── Paths ────────────────────────────────────────────────────────────────────
# These are set by install.sh to the teammate's actual install location.
# If unset (e.g. sourced standalone), fall back to the conventional layout.
: "${ADOBE_DIR:=$HOME/Web/adobe}"
: "${MAS_DIR:=$ADOBE_DIR/mas}"
export ADOBE_DIR MAS_DIR

# ─── claude-mas ───────────────────────────────────────────────────────────────
claude-mas() {
    local worktrees_base="$ADOBE_DIR/worktrees"

    if [[ -z "$1" ]]; then
        echo "→ main ($MAS_DIR)"
        cd "$MAS_DIR" && claude
        return
    fi

    local ticket="$1"
    shift

    local target_dir
    if [[ "$ticket" == "main" ]]; then
        target_dir="$MAS_DIR"
    else
        target_dir="$worktrees_base/$ticket"
    fi

    if [[ ! -d "$target_dir" ]]; then
        echo "→ creating worktree for $ticket"
        (cd "$ADOBE_DIR" && bash worktrees/wt new "$ticket") || return 1
    fi

    echo "→ $ticket ($target_dir)"
    cd "$target_dir" && claude "$@"
}

# ─── claude-mas-team ────────────────────────────────────────────────────────────
# Like claude-mas, but launches a cmux Claude Code agent team instead of a plain
# Claude session. cmux's `claude-teams` shims tmux and sets
# CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1, so spawned teammates render as cmux
# splits. All flags after the ticket are forwarded to Claude Code.
claude-mas-team() {
    if ! command -v cmux >/dev/null 2>&1; then
        echo "claude-mas-team: cmux not found in PATH" >&2
        return 1
    fi

    local worktrees_base="$ADOBE_DIR/worktrees"

    if [[ -z "$1" ]]; then
        echo "→ main team ($MAS_DIR)"
        cd "$MAS_DIR" && cmux claude-teams
        return
    fi

    local ticket="$1"
    shift

    local target_dir
    if [[ "$ticket" == "main" ]]; then
        target_dir="$MAS_DIR"
    else
        target_dir="$worktrees_base/$ticket"
    fi

    if [[ ! -d "$target_dir" ]]; then
        echo "→ creating worktree for $ticket"
        (cd "$ADOBE_DIR" && bash worktrees/wt new "$ticket") || return 1
    fi

    echo "→ $ticket team ($target_dir)"
    cd "$target_dir" && cmux claude-teams "$@"
}

# ─── mas ──────────────────────────────────────────────────────────────────────
# cd shortcut to main mas repo.
unalias mas 2>/dev/null
mas() {
    cd "$MAS_DIR"
}
