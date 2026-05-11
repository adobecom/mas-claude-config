#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""PreToolUse hook: block writes that contain secrets/credentials.

Matches Write/Edit/MultiEdit (content scanning) and Bash (command + redirect target).

Exit codes:
  0 - pass (clean, override present, or skip path)
  2 - block (blocking finding present)

Errors fail-open and log to ~/.claude/logs/hook-errors.log.
Block events are logged (redacted) to ~/.claude/logs/secret-leak-attempts.jsonl.

Override marker:  <!-- secret-ok: <reason >= 3 chars> -->
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

HOOK_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(HOOK_DIR))
import _secret_rules as rules  # noqa: E402

HOME = Path.home()
LOG_DIR = HOME / ".claude" / "logs"
ERROR_LOG = LOG_DIR / "hook-errors.log"
ATTEMPT_LOG = LOG_DIR / "secret-leak-attempts.jsonl"


# Detects shell redirect into a tier-1 path.
BASH_TIER1_REDIRECT_RE = re.compile(
    r"""(?x)
    (?: >>? | \btee\s+(?:-a\s+)? | \bcp\s+\S+\s+ | \bmv\s+\S+\s+ )
    \s*
    ([^\s|;&<>]*
        (?: \.claude/ | CLAUDE\.md | \.env(?:\.[\w-]*)?\b | \.mcp\.json )
        [^\s|;&<>]*
    )
    """
)


def _log_error(msg: str) -> None:
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with ERROR_LOG.open("a") as f:
            f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")
    except OSError:
        pass


def _log_attempt(payload: dict) -> None:
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with ATTEMPT_LOG.open("a") as f:
            f.write(json.dumps(payload) + "\n")
    except OSError:
        pass


def _extract(input_data: dict) -> tuple[str, str, str]:
    """Return (tool_name, content, file_path) — content/file_path may be empty."""
    tool = input_data.get("tool_name", "")
    ti = input_data.get("tool_input", {}) or {}

    if tool == "Write":
        return tool, ti.get("content", "") or "", ti.get("file_path", "") or ""
    if tool == "Edit":
        return tool, ti.get("new_string", "") or "", ti.get("file_path", "") or ""
    if tool == "MultiEdit":
        edits = ti.get("edits", []) or []
        content = "\n".join(e.get("new_string", "") or "" for e in edits)
        return tool, content, ti.get("file_path", "") or ""
    if tool == "Bash":
        return tool, ti.get("command", "") or "", ""
    return tool, "", ""


def _bash_redirect_target(command: str) -> str | None:
    m = BASH_TIER1_REDIRECT_RE.search(command)
    return m.group(1) if m else None


def _format_block_message(findings: list[rules.Finding], file_path: str) -> str:
    lines = ["Secret-leak detector blocked this write:", ""]
    for f in findings:
        lines.append(f"  Line {f.line}: [{f.pattern}] {f.snippet}  (tier={f.tier})")
    lines.append("")
    if file_path:
        lines.append(f"File: {file_path}")
        lines.append("")
    lines.extend([
        "If this is a documented, intentional reference (e.g. SOC2 audit example,",
        "format documentation, test fixture), add this marker to the content:",
        "",
        "    <!-- secret-ok: <reason >=3 chars> -->",
        "",
        "Otherwise: rotate the credential immediately and use ${process.env.X}",
        "or another placeholder.",
    ])
    return "\n".join(lines)


def main() -> int:
    try:
        input_data = json.load(sys.stdin)
    except Exception as exc:
        _log_error(f"failed to read stdin: {exc!r}")
        return 0

    try:
        tool, content, file_path = _extract(input_data)
        if tool not in {"Write", "Edit", "MultiEdit", "Bash"}:
            return 0
        if not content:
            return 0

        # For Bash, decide the effective file_path from the redirect target.
        if tool == "Bash":
            target = _bash_redirect_target(content)
            file_path = target or ""

        findings = rules.find_findings(content, file_path)
        if not findings:
            return 0

        blocking = rules.blocking(findings)
        warns = rules.warn_only(findings)

        if not blocking and warns:
            # Warnings only — print advisory but don't block.
            print(
                "[secret-leak] non-blocking advisory:",
                ", ".join(f"{f.pattern} (line {f.line})" for f in warns),
                file=sys.stderr,
            )
            return 0

        if blocking:
            _log_attempt({
                "ts": datetime.now(timezone.utc).isoformat(),
                "tool": tool,
                "file": file_path,
                "tier1": rules.path_is_tier1(file_path),
                "findings": [f.to_log_dict() for f in blocking],
                "action": "block",
            })
            print(_format_block_message(blocking, file_path), file=sys.stderr)
            return 2

        return 0

    except Exception as exc:
        _log_error(f"unhandled error: {exc!r}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
