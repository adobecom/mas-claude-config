#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""One-shot audit: walk filesystem and report files containing secrets.

Reuses _secret_rules from the parent hooks directory so detection guarantees
match the PreToolUse `secret_leak_gate.py` hook.

Usage:
    scan-existing-secrets.py [path ...]
    scan-existing-secrets.py --json
    scan-existing-secrets.py --include-low
    scan-existing-secrets.py --help

Default scan paths:
    ~/.claude/  (excluding logs, state, cache, projects, todos)
    /Users/axelcurenobasurto/Web/adobe/mas/.claude/
    /Users/axelcurenobasurto/Web/adobe/mas-claude-config/

Exit codes:
    0 - clean
    1 - HIGH or SHAPE finding(s)
    2 - MEDIUM in tier-1 path(s)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HOOK_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HOOK_DIR))
import _secret_rules as rules  # noqa: E402

HOME = Path.home()

DEFAULT_TARGETS = [
    HOME / ".claude",
    Path("/Users/axelcurenobasurto/Web/adobe/mas/.claude"),
    Path("/Users/axelcurenobasurto/Web/adobe/mas-claude-config"),
]

# Subdirectories to skip even when scanning a default root.
# These contain Claude Code's own internal data (telemetry, snapshots, paste cache,
# usage data, session logs) that the user doesn't author and shouldn't be triaging.
SKIP_DIR_NAMES = {
    "logs", "state", "cache", "projects", "todos",
    "node_modules", ".git", "coverage", "dist", "build", "__pycache__",
    "fixtures", "__mocks__",
    # Claude Code internal/auto-generated
    "telemetry", "shell-snapshots", "paste-cache", "usage-data",
    "sessions", "file-history", "history-backups",
    "data",  # mas/.claude/data/ — session data
    # claude-mem context files contain redacted activity summaries
    ".claude-mem",
    # the cache directory inside a plugin install
    "plugin-cache",
}

# File extensions to scan (text-shaped). Skip binary.
TEXT_SUFFIXES = {
    ".md", ".markdown", ".txt", ".json", ".jsonl", ".yaml", ".yml",
    ".sh", ".bash", ".zsh", ".fish",
    ".py", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx",
    ".env", ".envrc", ".config", ".conf", ".ini", ".toml",
    ".pem", ".key", ".crt", ".cert",
    ".log",
}

# Max file size we'll scan (avoid pulling in huge logs).
MAX_FILE_BYTES = 2 * 1024 * 1024  # 2 MiB


def _should_skip_dir(p: Path) -> bool:
    return p.name in SKIP_DIR_NAMES or p.name.startswith(".")  # hidden dirs except .claude


def _walk(root: Path):
    """Yield text-like file paths under root, skipping known noise directories."""
    if not root.exists():
        return
    if root.is_file():
        yield root
        return
    stack = [root]
    while stack:
        cur = stack.pop()
        try:
            entries = list(cur.iterdir())
        except (OSError, PermissionError):
            continue
        for e in entries:
            if e.is_symlink():
                continue
            if e.is_dir():
                # Allow `.claude` itself but block standard hidden + skipped names.
                if e.name == ".claude":
                    stack.append(e)
                    continue
                if e.name in SKIP_DIR_NAMES:
                    continue
                if e.name.startswith(".") and e.name not in (".claude",):
                    continue
                stack.append(e)
            elif e.is_file():
                if e.suffix not in TEXT_SUFFIXES and e.name not in {".env"}:
                    continue
                try:
                    if e.stat().st_size > MAX_FILE_BYTES:
                        continue
                except OSError:
                    continue
                yield e


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def scan_path(root: Path, include_low: bool) -> list[dict]:
    rows: list[dict] = []
    for f in _walk(root):
        content = _read_text(f)
        if not content:
            continue
        findings = rules.find_findings(content, str(f))
        for finding in findings:
            if finding.tier in ("low_warn", "medium_warn") and not include_low:
                continue
            if finding.tier == "low" and not include_low:
                # Even tier-1 LOW (JWT) is too noisy by default for the audit
                # since AEM JWTs are everywhere in session logs.
                continue
            rows.append({
                "path": str(f),
                "line": finding.line,
                "pattern": finding.pattern,
                "tier": finding.tier,
                "redacted": finding.snippet,
            })
    return rows


def _exit_code(rows: list[dict]) -> int:
    has_high_or_shape = any(r["tier"] in ("shape", "high") for r in rows)
    has_medium_tier1 = any(r["tier"] == "medium" for r in rows)
    if has_high_or_shape:
        return 1
    if has_medium_tier1:
        return 2
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("paths", nargs="*", type=Path,
                        help="paths to scan (default: ~/.claude, mas/.claude, mas-claude-config)")
    parser.add_argument("--json", action="store_true",
                        help="emit JSON findings instead of text")
    parser.add_argument("--include-low", action="store_true",
                        help="also report LOW (jwt) findings — noisy")
    args = parser.parse_args()

    targets = args.paths or DEFAULT_TARGETS
    all_rows: list[dict] = []
    for t in targets:
        all_rows.extend(scan_path(Path(t), include_low=args.include_low))

    # De-dup identical findings (same path, line, pattern).
    seen = set()
    unique: list[dict] = []
    for r in all_rows:
        key = (r["path"], r["line"], r["pattern"])
        if key in seen:
            continue
        seen.add(key)
        unique.append(r)

    if args.json:
        print(json.dumps(unique, indent=2))
    else:
        if not unique:
            print("No secrets detected.")
        else:
            # Group by file for readability.
            by_file: dict[str, list[dict]] = {}
            for r in unique:
                by_file.setdefault(r["path"], []).append(r)
            for path in sorted(by_file):
                print(f"\n{path}")
                for r in by_file[path]:
                    print(f"  Line {r['line']:>5}  [{r['tier']:<6}] {r['pattern']:<40} {r['redacted']}")
            print()
            print(f"Total: {len(unique)} finding(s) in {len(by_file)} file(s)")

    return _exit_code(unique)


if __name__ == "__main__":
    sys.exit(main())
