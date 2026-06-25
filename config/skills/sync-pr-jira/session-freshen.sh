#!/usr/bin/env bash
# SessionStart freshen: read-only PR→Jira plan summary. NEVER writes to Jira.
# Reads the Jira token from the corp-jira MCP config at runtime (no copy, no .env)
# so it can dedupe against live Jira status and show only genuine diffs.
# Quiet by design — emits one context line only when there are real pending moves.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v gh >/dev/null 2>&1 || exit 0
gh auth status >/dev/null 2>&1 || exit 0

plan="$(node "$HERE/decide.mjs" 2>/dev/null)" || exit 0

creds="$(python3 -c "
import json,os
try:
    e=json.load(open(os.path.expanduser('~/.claude.json'))).get('mcpServers',{}).get('corp-jira',{}).get('env',{})
    print(e.get('JIRA_PERSONAL_ACCESS_TOKEN',''))
    print(e.get('JIRA_EMAIL',''))
except Exception:
    pass
" 2>/dev/null)"
JIRA_PAT="$(printf '%s' "$creds" | sed -n 1p)"
JIRA_EMAIL="$(printf '%s' "$creds" | sed -n 2p)"

export JIRA_PAT JIRA_EMAIL
printf '%s' "$plan" | node "$HERE/freshen-summary.mjs" 2>/dev/null
exit 0
