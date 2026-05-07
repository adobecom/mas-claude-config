#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
SessionStart hook: check if graphify knowledge graph is stale.
Compares graph.json mtime against the latest git commit timestamp.
If stale, injects a reminder into the session context.

Does NOT auto-rebuild (that would block session start for 30-60s).
Instead, tells Claude the graph is stale so it can offer to run --update.
"""

import json
import os
import subprocess
import sys
from pathlib import Path


def get_latest_commit_time():
    """Get the unix timestamp of the latest git commit."""
    try:
        result = subprocess.run(
            ['git', 'log', '-1', '--format=%ct'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            return int(result.stdout.strip())
    except Exception:
        pass
    return None


def get_graph_mtime():
    """Get the mtime of graphify-out/graph.json."""
    graph_path = Path('graphify-out/graph.json')
    if graph_path.exists():
        return graph_path.stat().st_mtime
    return None


def get_commits_since_graph():
    """Count commits since graph.json was last modified."""
    graph_mtime = get_graph_mtime()
    if graph_mtime is None:
        return None
    try:
        result = subprocess.run(
            ['git', 'log', '--oneline', f'--since={int(graph_mtime)}'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            lines = [l for l in result.stdout.strip().split('\n') if l.strip()]
            return len(lines)
    except Exception:
        pass
    return None


def main():
    try:
        input_data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    graph_path = Path('graphify-out/graph.json')
    if not graph_path.exists():
        sys.exit(0)

    graph_mtime = get_graph_mtime()
    commit_time = get_latest_commit_time()

    if graph_mtime is None or commit_time is None:
        sys.exit(0)

    if commit_time <= graph_mtime:
        sys.exit(0)

    commits_behind = get_commits_since_graph()
    staleness_msg = f"{commits_behind} commit(s)" if commits_behind else "unknown number of commits"

    output = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": (
                f"graphify: Knowledge graph is STALE — {staleness_msg} "
                f"landed since last graph build. Run `/graphify . --update` "
                f"to refresh, or ask the user if they want to update."
            )
        }
    }
    print(json.dumps(output))
    sys.exit(0)


if __name__ == '__main__':
    main()
