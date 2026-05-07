#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///
"""
PostToolUse hook: enforces Spectrum Web Components best practices on
studio/src/**/*.js files. Blocks (exit 2) when violations are found.

Escape hatch: add `audit-ok:` anywhere on the offending line to suppress.
"""

import json
import os
import re
import sys
from pathlib import Path

TARGET_SUBDIR = 'studio/src'

# (regex_pattern, violation_message, applicable_suffixes)
# suffixes are matched against the full filename (e.g. '.css.js' vs '.js')
RULES = [
    (r'<textarea[\s>/]', 'Use <sp-textfield multiline> instead of native <textarea>', ('.js',)),
    (r'<input[\s>/]', 'Use <sp-textfield>, <sp-search>, or <sp-checkbox> instead of native <input>', ('.js',)),
    (r'<select[\s>/]', 'Use <sp-picker> instead of native <select>', ('.js',)),
    (r'<button[\s>/]', 'Use <sp-button> or <sp-action-button> instead of native <button>', ('.js',)),
    (r'style="', 'No inline styles — use CSS custom properties', ('.js', '.css.js')),
    (r'::part\(', 'No ::part() selectors — use CSS custom properties instead', ('.css.js',)),
]

COMPILED_RULES = [(re.compile(p), msg, exts) for p, msg, exts in RULES]


def file_suffix_matches(filename: str, suffixes: tuple) -> bool:
    for suffix in suffixes:
        if filename.endswith(suffix):
            return True
    return False


def audit_content(content: str, filename: str) -> list[str]:
    violations = []
    lines = content.splitlines()
    for lineno, line in enumerate(lines, 1):
        if 'audit-ok:' in line:
            continue
        for pattern, message, suffixes in COMPILED_RULES:
            if not file_suffix_matches(filename, suffixes):
                continue
            if pattern.search(line):
                violations.append(f'  Line {lineno}: {message}')
                break
    return violations


def collect_files(tool_name: str, tool_input: dict) -> list[tuple[str, str | None]]:
    """Return list of (file_path, new_content_or_None) to audit."""
    if tool_name in ('Write', 'Edit'):
        path = tool_input.get('file_path', '')
        content = tool_input.get('content') or tool_input.get('new_string', '')
        return [(path, content)] if path else []
    elif tool_name == 'MultiEdit':
        result = []
        for edit in tool_input.get('edits', []):
            path = edit.get('file_path', '')
            content = edit.get('new_string', '')
            if path:
                result.append((path, content))
        return result
    return []


def main():
    try:
        data = json.load(sys.stdin)
        tool_name = data.get('tool_name', '')
        tool_input = data.get('tool_input', {})

        if tool_name not in ('Write', 'Edit', 'MultiEdit'):
            sys.exit(0)

        project_dir = Path(os.environ.get('CLAUDE_PROJECT_DIR', ''))
        target_root = project_dir / TARGET_SUBDIR

        files = collect_files(tool_name, tool_input)
        all_violations = []

        for file_path, content in files:
            path = Path(file_path)

            try:
                path.relative_to(target_root)
            except ValueError:
                continue

            if not content:
                continue

            violations = audit_content(content, path.name)
            if violations:
                rel = path.relative_to(project_dir)
                all_violations.append(f'{rel}:')
                all_violations.extend(violations)

        if all_violations:
            print('Spectrum audit violations found — fix before proceeding:\n', file=sys.stderr)
            for line in all_violations:
                print(line, file=sys.stderr)
            print('\nTo suppress a specific line, add `audit-ok: <reason>` as a comment on that line.', file=sys.stderr)
            sys.exit(2)

        sys.exit(0)

    except Exception:
        sys.exit(0)


if __name__ == '__main__':
    main()
