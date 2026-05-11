#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///
"""
PostToolUse hook: runs eslint --fix on JS files written/edited by Claude Code
that match the mas lint targets:
  - web-components/**/*.{js,mjs,cjs}
  - studio/**/*.{js,mjs,cjs}

Resolves the mas root by walking up from CLAUDE_PROJECT_DIR looking for a
`node_modules/.bin/eslint`. Handles both the main mas repo and worktrees.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

MAS_SUBDIRS = {'web-components', 'studio'}
TARGET_EXTENSIONS = {'.js', '.mjs', '.cjs'}


def find_mas_root(start: Path) -> Path | None:
    for candidate in [start, *start.parents]:
        if (candidate / 'node_modules' / '.bin' / 'eslint').exists():
            return candidate
    return None


def main():
    try:
        input_data = json.load(sys.stdin)

        if input_data.get('tool_name') not in ('Write', 'Edit', 'MultiEdit'):
            sys.exit(0)

        file_path = input_data.get('tool_input', {}).get('file_path', '')
        if not file_path:
            sys.exit(0)

        path = Path(file_path).resolve()

        if path.suffix not in TARGET_EXTENSIONS:
            sys.exit(0)

        project_dir = Path(os.environ.get('CLAUDE_PROJECT_DIR', '')).resolve()
        if not project_dir.exists():
            sys.exit(0)

        mas_root = find_mas_root(project_dir)
        if mas_root is None:
            sys.exit(0)

        try:
            rel = path.relative_to(mas_root)
        except ValueError:
            sys.exit(0)

        if not rel.parts or rel.parts[0] not in MAS_SUBDIRS:
            sys.exit(0)

        eslint_bin = mas_root / 'node_modules' / '.bin' / 'eslint'

        subprocess.run(
            [str(eslint_bin), '--fix', str(path)],
            cwd=str(mas_root),
            capture_output=True,
            timeout=15,
        )

        sys.exit(0)

    except Exception:
        sys.exit(0)


if __name__ == '__main__':
    main()
