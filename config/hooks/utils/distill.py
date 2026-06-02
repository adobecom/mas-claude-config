"""
Session-end distillation detector. Reads the session transcript and writes
draft memory entries to ~/.claude/projects/<slug>/memory/_pending/ when
specific learnable-moment signals are present.

Three signals (deterministic, no LLM call):

  1. Rebuke      — user message contains a corrective phrase shortly after
                   an assistant edit/tool action.
  2. Revert      — same file_path receives an Edit/Write whose new_string
                   contains a string that was the old_string of an earlier
                   Edit on that file (i.e. the change was undone).
  3. Friction    — the same error string appears in tool_result outputs
                   (or PreToolUse blocks) three or more times.

Drafts are NEVER auto-promoted. Acceptance is manual: the user moves the
file out of _pending/ into the parent memory/ dir.

Fail-silent: any exception in detection becomes a no-op. The stop hook
must keep exit code 0.
"""
from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

REBUKE_PATTERNS = [
    r"\bno[,.\s]",
    r"\bstop\b",
    r"\bdon't\b",
    r"\bwrong\b",
    r"\binstead\b",
    r"\bactually,?\s",
    r"\bnot like that\b",
    r"\bthat's not\b",
    r"\bdo not\b",
    r"\brevert\b",
]
REBUKE_RE = re.compile("|".join(REBUKE_PATTERNS), re.IGNORECASE)

FRICTION_MIN_COUNT = 3
MAX_USER_MESSAGE_CHARS = 500
MAX_SNIPPET_CHARS = 200


def _memory_dir() -> Path | None:
    """Resolve the auto-memory dir for the current project. Returns None if
    we can't determine it (e.g. CLAUDE_PROJECT_DIR not set)."""
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if not project_dir:
        return None
    abs_path = Path(project_dir).resolve()
    slug = str(abs_path).replace("/", "-")
    return Path.home() / ".claude" / "projects" / slug / "memory"


def _load_transcript(transcript_path: str) -> list[dict]:
    """Read a Claude Code transcript JSONL into a list of records. Returns
    empty list on any error."""
    try:
        records = []
        with open(transcript_path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    records.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        return records
    except OSError:
        return []


def _user_text(record: dict) -> str:
    """Extract user message text from a transcript record."""
    if record.get("type") != "user":
        return ""
    msg = record.get("message", {})
    content = msg.get("content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text":
                parts.append(item.get("text", ""))
        return "\n".join(parts)
    return ""


def _assistant_tool_uses(record: dict) -> list[dict]:
    """Extract tool_use blocks from an assistant message."""
    if record.get("type") != "assistant":
        return []
    msg = record.get("message", {})
    content = msg.get("content", [])
    if not isinstance(content, list):
        return []
    return [b for b in content if isinstance(b, dict) and b.get("type") == "tool_use"]


def _tool_results(record: dict) -> list[dict]:
    """Extract tool_result blocks from a user (tool-result) message."""
    if record.get("type") != "user":
        return []
    msg = record.get("message", {})
    content = msg.get("content", [])
    if not isinstance(content, list):
        return []
    return [b for b in content if isinstance(b, dict) and b.get("type") == "tool_result"]


def detect_rebuke(records: list[dict]) -> list[dict]:
    """Return events where a user message matches a rebuke pattern AND the
    immediately preceding assistant turn made an edit/write."""
    findings = []
    last_edit_assistant_idx = None

    for i, rec in enumerate(records):
        if rec.get("type") == "assistant":
            for tu in _assistant_tool_uses(rec):
                if tu.get("name") in ("Edit", "Write", "MultiEdit"):
                    last_edit_assistant_idx = i
                    break
            continue

        if rec.get("type") != "user":
            continue
        if last_edit_assistant_idx is None:
            continue

        text = _user_text(rec).strip()
        if not text:
            continue
        if text.startswith("<") or text.startswith("["):
            continue

        if not REBUKE_RE.search(text[:MAX_USER_MESSAGE_CHARS]):
            continue

        if i - last_edit_assistant_idx > 2:
            continue

        snippet = text[:MAX_SNIPPET_CHARS].strip().replace("\n", " ")
        findings.append({"kind": "rebuke", "snippet": snippet})

        last_edit_assistant_idx = None

    return findings


def detect_revert(records: list[dict]) -> list[dict]:
    """Detect Edit-then-revert: the same file_path receives an Edit whose
    new_string contains a fragment that was the old_string of an earlier
    Edit on that file."""
    findings = []
    history: dict[str, list[tuple[str, str]]] = {}

    for rec in records:
        for tu in _assistant_tool_uses(rec):
            if tu.get("name") not in ("Edit", "MultiEdit"):
                continue
            inp = tu.get("input", {}) or {}
            edits = []
            if tu["name"] == "Edit":
                fp = inp.get("file_path")
                old = inp.get("old_string", "")
                new = inp.get("new_string", "")
                if fp:
                    edits.append((fp, old, new))
            else:
                fp = inp.get("file_path")
                for e in inp.get("edits", []) or []:
                    if fp:
                        edits.append((fp, e.get("old_string", ""), e.get("new_string", "")))

            for fp, old, new in edits:
                prev = history.setdefault(fp, [])
                old_trim = old.strip()
                if old_trim and len(old_trim) >= 20:
                    for p_old, p_new in prev:
                        if p_new and len(p_new.strip()) >= 20 and p_new.strip() in old.strip():
                            if new.strip() != p_new.strip():
                                findings.append({
                                    "kind": "revert",
                                    "snippet": f"{Path(fp).name}: edit reverted within session",
                                })
                                break
                prev.append((old, new))

    seen = set()
    unique = []
    for f in findings:
        key = f["snippet"]
        if key in seen:
            continue
        seen.add(key)
        unique.append(f)
    return unique


def detect_friction(records: list[dict]) -> list[dict]:
    """Detect the same error class appearing 3+ times in tool_result content."""
    error_counts: dict[str, int] = {}
    error_re = re.compile(r"(BLOCKED|Permission denied|ENOENT|EACCES|MODULE_NOT_FOUND|command not found|hook error|fatal:)", re.IGNORECASE)

    for rec in records:
        for tr in _tool_results(rec):
            content = tr.get("content", "")
            if isinstance(content, list):
                content = "\n".join(
                    c.get("text", "") if isinstance(c, dict) else str(c) for c in content
                )
            if not isinstance(content, str):
                continue
            for m in error_re.finditer(content[:2000]):
                key = m.group(1).lower()
                error_counts[key] = error_counts.get(key, 0) + 1

    findings = []
    for key, count in error_counts.items():
        if count >= FRICTION_MIN_COUNT:
            findings.append({
                "kind": "friction",
                "snippet": f'"{key}" hit {count}× in this session',
            })
    return findings


def write_draft(memory_dir: Path, session_id: str, findings: list[dict]) -> Path | None:
    """Write a single draft markdown file for this session's findings.
    Returns the path written, or None if nothing was written."""
    if not findings:
        return None
    pending_dir = memory_dir / "_pending"
    try:
        pending_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        return None

    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    short_session = (session_id or "unknown")[:8]
    path = pending_dir / f"{ts}-{short_session}.md"

    lines = [
        "---",
        f"name: draft-{ts}-{short_session}",
        "description: Auto-detected learnable moment — review and either move into memory/ (accept) or delete (reject)",
        "metadata:",
        "  type: feedback",
        "  status: pending",
        f"  session_id: {session_id or 'unknown'}",
        f"  detected_at: {datetime.now(timezone.utc).isoformat()}",
        "---",
        "",
        "# Auto-detected from session — pending review",
        "",
        "The session-end detector flagged the events below as likely learnable moments.",
        "If any of them captures a real lesson worth keeping, edit this file into a proper",
        "memory entry and move it out of `_pending/` into the parent `memory/` directory.",
        "Otherwise delete it.",
        "",
    ]
    for f in findings:
        lines.append(f"## {f['kind']}")
        lines.append("")
        lines.append(f"  {f['snippet']}")
        lines.append("")

    try:
        path.write_text("\n".join(lines))
        return path
    except OSError:
        return None


def detect_and_write(transcript_path: str | None, session_id: str | None) -> Path | None:
    """Entry point called from stop.py. Returns the draft file path on
    success, None otherwise. Never raises."""
    try:
        if not transcript_path or not os.path.exists(transcript_path):
            return None
        memory_dir = _memory_dir()
        if memory_dir is None:
            return None

        records = _load_transcript(transcript_path)
        if not records:
            return None

        findings = []
        findings.extend(detect_rebuke(records))
        findings.extend(detect_revert(records))
        findings.extend(detect_friction(records))

        if not findings:
            return None

        return write_draft(memory_dir, session_id or "", findings)
    except Exception:
        return None


def count_pending() -> int:
    """Return the number of pending entries for the current project.
    Returns 0 on any error."""
    try:
        memory_dir = _memory_dir()
        if memory_dir is None:
            return 0
        pending_dir = memory_dir / "_pending"
        if not pending_dir.exists():
            return 0
        return sum(1 for p in pending_dir.iterdir() if p.is_file() and p.suffix == ".md")
    except Exception:
        return 0
