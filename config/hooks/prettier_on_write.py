#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///
"""
PostToolUse hook: runs prettier on files written/edited by Claude Code
that match the mas lint-staged patterns:
  - web-components/**/*.{js,mjs,css}
  - studio/**/*.{js,mjs,css}
"""

import json
import os
import subprocess
import sys
from pathlib import Path

MAS_SUBDIRS = {'web-components', 'studio'}
TARGET_EXTENSIONS = {'.js', '.mjs', '.css'}


def main():
    try:
        input_data = json.load(sys.stdin)

        if input_data.get('tool_name') not in ('Write', 'Edit', 'MultiEdit'):
            sys.exit(0)

        file_path = input_data.get('tool_input', {}).get('file_path', '')
        if not file_path:
            sys.exit(0)

        path = Path(file_path)

        if path.suffix not in TARGET_EXTENSIONS:
            sys.exit(0)

        # Resolve mas root relative to CLAUDE_PROJECT_DIR
        project_dir = Path(os.environ.get('CLAUDE_PROJECT_DIR', ''))
        mas_root = project_dir / 'apps' / 'mas'

        try:
            rel = path.relative_to(mas_root)
        except ValueError:
            sys.exit(0)

        if rel.parts[0] not in MAS_SUBDIRS:
            sys.exit(0)

        prettier_bin = mas_root / 'node_modules' / '.bin' / 'prettier'
        if not prettier_bin.exists():
            sys.exit(0)

        subprocess.run(
            [str(prettier_bin), '--write', str(path)],
            cwd=str(mas_root),
            capture_output=True,
        )

        sys.exit(0)

    except Exception:
        sys.exit(0)


if __name__ == '__main__':
    main()
