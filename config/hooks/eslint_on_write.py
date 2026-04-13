#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///
"""
PostToolUse hook: runs eslint --fix on JS files written/edited by Claude Code
inside apps/experience-qa/ using the root-level ESLint 9 flat config.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

TARGET_EXTENSIONS = {'.js', '.mjs', '.cjs'}
TARGET_SUBDIR = 'apps/experience-qa'


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

        project_dir = Path(os.environ.get('CLAUDE_PROJECT_DIR', ''))
        target_root = project_dir / TARGET_SUBDIR

        try:
            path.relative_to(target_root)
        except ValueError:
            sys.exit(0)

        eslint_bin = project_dir / 'node_modules' / '.bin' / 'eslint'
        if not eslint_bin.exists():
            sys.exit(0)

        subprocess.run(
            [str(eslint_bin), '--fix', str(path)],
            cwd=str(project_dir),
            capture_output=True,
        )

        sys.exit(0)

    except Exception:
        sys.exit(0)


if __name__ == '__main__':
    main()
