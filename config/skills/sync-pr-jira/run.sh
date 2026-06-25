#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$HERE/sync.log"
MAX_LOG_BYTES=$((5 * 1024 * 1024))

if [ -f "$HERE/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$HERE/.env"
    set +a
fi
export GH_TOKEN="${GH_TOKEN:-}"

if [ -f "$LOG" ] && [ "$(wc -c <"$LOG")" -gt "$MAX_LOG_BYTES" ]; then
    mv "$LOG" "$LOG.1"
fi

stamp() { date '+%Y-%m-%dT%H:%M:%S%z'; }

output="$(node "$HERE/decide.mjs" 2>&1 | node "$HERE/apply.mjs" "$@" 2>&1)"
status=$?

{
    echo "===== $(stamp) ====="
    echo "$output"
} >>"$LOG"

if [ "$status" -ne 0 ] || printf '%s' "$output" | grep -qE '✗|ERROR'; then
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        summary="$(printf '%s' "$output" | grep -E '✗|ERROR' | head -10)"
        [ -z "$summary" ] && summary="run failed (exit $status), see sync.log on $(hostname)"
        payload="$(printf '{"text":"⚠️ PR→Jira sync failure on %s:\\n```%s```"}' "$(hostname)" "$summary")"
        curl -sf -X POST -H 'Content-Type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL" >/dev/null || true
    fi
    exit 1
fi

exit 0
