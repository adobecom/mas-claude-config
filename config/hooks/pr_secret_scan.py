#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""PreToolUse hook: scan the PR diff + body for secrets before `gh pr create|edit`.

Activates only on `gh pr create` and `gh pr edit` Bash commands.
Scans (a) `git diff origin/<base>...HEAD` and (b) the PR body extracted from
the command. Uses the same `_secret_rules` matcher as `secret_leak_gate.py`.

Exit codes:
  0 - pass (clean, no PR command, no git available, override marker present)
  2 - block (HIGH/SHAPE/MEDIUM-in-tier1 finding present)

Fail-open: any unexpected exception logs to ~/.claude/logs/hook-errors.log and
returns 0 — the per-write `secret_leak_gate.py` provides the safety net.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
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

PR_COMMAND_RE = re.compile(r"\bgh\s+pr\s+(?:create|edit)\b")


def _log_error(msg: str) -> None:
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with ERROR_LOG.open("a") as f:
            f.write(f"[{datetime.now(timezone.utc).isoformat()}] [pr_scan] {msg}\n")
    except OSError:
        pass


def _log_attempt(payload: dict) -> None:
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with ATTEMPT_LOG.open("a") as f:
            f.write(json.dumps(payload) + "\n")
    except OSError:
        pass


def _find_flag_value(cmd: str, flag: str) -> str | None:
    m = re.search(rf'{re.escape(flag)}=(?:"([^"]*)"|\'([^\']*)\'|(\S+))', cmd)
    if m:
        return next(g for g in m.groups() if g is not None)
    m = re.search(rf'{re.escape(flag)}\s+"((?:[^"\\]|\\.)*)"', cmd)
    if m:
        return m.group(1).replace('\\"', '"').replace("\\\\", "\\")
    m = re.search(rf"{re.escape(flag)}\s+'([^']*)'", cmd)
    if m:
        return m.group(1)
    m = re.search(rf"{re.escape(flag)}\s+(\S+)", cmd)
    if m:
        return m.group(1)
    return None


def _extract_heredoc_body(cmd: str) -> str | None:
    m = re.search(
        r"--body\s+\"?\$\(\s*cat\s+<<\s*['\"]?(\w+)['\"]?\s*\n(.*?)\n\1\s*\)\"?",
        cmd,
        re.DOTALL,
    )
    return m.group(2) if m else None


def _extract_pr_body(cmd: str) -> str:
    body = _extract_heredoc_body(cmd)
    if body is not None:
        return body
    body = _find_flag_value(cmd, "--body")
    if body is not None:
        return body
    body = _find_flag_value(cmd, "-b")
    if body is not None:
        return body
    body_file = _find_flag_value(cmd, "--body-file")
    if body_file:
        try:
            with open(os.path.expanduser(body_file), "r", encoding="utf-8") as f:
                return f.read()
        except OSError:
            return ""
    return ""


def _detect_base_ref(cmd: str) -> str:
    """Try --base flag first, else default to origin/main."""
    base = _find_flag_value(cmd, "--base") or _find_flag_value(cmd, "-B")
    if base:
        return f"origin/{base}" if "/" not in base else base
    return "origin/main"


def _get_diff(base_ref: str) -> str:
    try:
        result = subprocess.run(
            ["git", "diff", f"{base_ref}...HEAD"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            _log_error(f"git diff failed: {result.stderr.strip()}")
            return ""
        return result.stdout
    except (OSError, subprocess.TimeoutExpired) as exc:
        _log_error(f"git diff exception: {exc!r}")
        return ""


def _filter_diff_to_added_lines(diff: str) -> str:
    """Extract only lines added in the diff (lines starting with '+', not '+++')."""
    added = []
    for line in diff.splitlines():
        if line.startswith("+") and not line.startswith("+++"):
            added.append(line[1:])
    return "\n".join(added)


def _current_diff_paths(base_ref: str) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", f"{base_ref}...HEAD"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            return []
        return [p.strip() for p in result.stdout.splitlines() if p.strip()]
    except (OSError, subprocess.TimeoutExpired):
        return []


def _format_block_message(findings: list[rules.Finding], source: str) -> str:
    lines = [f"PR secret-scan blocked: secret detected in {source}:", ""]
    for f in findings[:10]:
        lines.append(f"  [{f.pattern}] {f.snippet}  (tier={f.tier})")
    if len(findings) > 10:
        lines.append(f"  ... and {len(findings) - 10} more")
    lines.append("")
    lines.append("Rotate the credential, remove it from the diff/body, and try again.")
    lines.append("Or add `<!-- secret-ok: <reason> -->` to the PR body for documented references.")
    return "\n".join(lines)


def main() -> int:
    try:
        input_data = json.load(sys.stdin)
    except Exception as exc:
        _log_error(f"failed to read stdin: {exc!r}")
        return 0

    try:
        if input_data.get("tool_name") != "Bash":
            return 0
        cmd = input_data.get("tool_input", {}).get("command", "") or ""
        if not PR_COMMAND_RE.search(cmd):
            return 0

        body = _extract_pr_body(cmd)
        # Override marker on the body short-circuits the whole scan.
        if rules.has_override(body):
            return 0

        base_ref = _detect_base_ref(cmd)
        raw_diff = _get_diff(base_ref)
        if not raw_diff and not body:
            # Nothing to scan; fail open.
            return 0

        added = _filter_diff_to_added_lines(raw_diff)
        diff_paths = _current_diff_paths(base_ref)
        # Heuristic file_path: if any tier-1 path is in the diff, treat the scan as tier-1.
        synthetic_path = next(
            (p for p in diff_paths if rules.path_is_tier1(p)),
            diff_paths[0] if diff_paths else "",
        )

        all_findings: list[tuple[str, rules.Finding]] = []
        for f in rules.find_findings(added, synthetic_path):
            all_findings.append(("diff", f))
        for f in rules.find_findings(body, synthetic_path):
            all_findings.append(("pr_body", f))

        blocking_findings = [(src, f) for src, f in all_findings if not f.tier.endswith("_warn")]

        if not blocking_findings:
            return 0

        _log_attempt({
            "ts": datetime.now(timezone.utc).isoformat(),
            "tool": "Bash",
            "subtype": "pr_create_or_edit",
            "base_ref": base_ref,
            "findings": [
                {"source": src, **f.to_log_dict()} for src, f in blocking_findings
            ],
            "action": "block",
        })

        source_summary = ", ".join(sorted({src for src, _ in blocking_findings}))
        only_findings = [f for _, f in blocking_findings]
        print(_format_block_message(only_findings, source_summary), file=sys.stderr)
        return 2

    except Exception as exc:
        _log_error(f"unhandled error: {exc!r}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
