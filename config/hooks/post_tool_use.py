#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///

"""
PostToolUse hook — records which mental-model domains were touched
by Write/Edit/MultiEdit. Appends domain names to .claude/.touched_domains.
Consumer: stop.py (reports stale domains at session end).
"""

import json
import os
import sys
from pathlib import Path

DOMAIN_MAP = {
    "studio/": "mas-studio",
    "io/www/": "mas-io",
    "io/studio/": "mas-io",
    "web-components/": "mas-web-components",
    "nala/": "mas-nala",
    ".github/": "mas-cicd",
}

LOOP_GUARD = ".claude/commands/mental-model/"


def main():
    try:
        data = json.load(sys.stdin)
        tool = data.get("tool_name", "")
        inp = data.get("tool_input", {})

        if tool not in ("Write", "Edit", "MultiEdit"):
            sys.exit(0)

        paths = []
        if tool in ("Write", "Edit"):
            p = inp.get("file_path")
            if p:
                paths.append(p)
        else:
            for e in inp.get("edits", []):
                p = e.get("file_path")
                if p:
                    paths.append(p)

        project = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
        domains = set()
        for fp in paths:
            rel = os.path.relpath(fp, project)
            if rel.startswith(LOOP_GUARD):
                continue
            for prefix, domain in DOMAIN_MAP.items():
                if rel.startswith(prefix):
                    domains.add(domain)

        if domains:
            sentinel = Path(project) / ".claude" / ".touched_domains"
            with open(sentinel, "a") as f:
                for d in domains:
                    f.write(d + "\n")
    except (json.JSONDecodeError, OSError, KeyError, ValueError):
        pass
    sys.exit(0)


if __name__ == "__main__":
    main()
