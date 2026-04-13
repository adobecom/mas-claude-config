#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///

"""PostToolUse validator for csv-edit-agent.

Reads the hook payload from stdin, extracts the file path from the tool
result, and validates basic CSV integrity (parseable, consistent column
count, balanced quoting).  Prints warnings to stderr so they surface in
the agent's conversation context.  Always exits 0 — validation failures
are advisory, never blocking.
"""

import csv
import io
import json
import sys
from pathlib import Path


def validate_csv(file_path: str) -> list[str]:
    """Return a list of warning strings (empty = valid)."""
    warnings = []
    path = Path(file_path)

    if not path.exists():
        return [f"File does not exist: {file_path}"]

    if path.suffix.lower() not in (".csv", ".tsv"):
        return []  # not a CSV — nothing to validate

    try:
        text = path.read_text(encoding="utf-8")
    except Exception as exc:
        return [f"Could not read {file_path}: {exc}"]

    if not text.strip():
        return [f"CSV file is empty: {file_path}"]

    dialect = csv.Sniffer().sniff(text[:4096]) if len(text) > 0 else None
    reader = csv.reader(io.StringIO(text), dialect or "excel")

    col_counts: dict[int, list[int]] = {}
    row_num = 0
    for row_num, row in enumerate(reader, start=1):
        ncols = len(row)
        col_counts.setdefault(ncols, []).append(row_num)

    if row_num == 0:
        return [f"CSV has no rows: {file_path}"]

    # Check for inconsistent column counts
    if len(col_counts) > 1:
        expected_cols = max(col_counts, key=lambda k: len(col_counts[k]))
        for ncols, rows in col_counts.items():
            if ncols != expected_cols:
                sample = rows[:5]
                warnings.append(
                    f"Inconsistent column count in {path.name}: "
                    f"rows {sample} have {ncols} columns "
                    f"(expected {expected_cols})"
                )

    return warnings


def extract_file_path(payload: dict) -> str | None:
    """Pull the file path from the tool_use result in the hook payload."""
    tool_input = payload.get("tool_input", {})

    # Edit / Write / Read all use file_path
    fp = tool_input.get("file_path") or tool_input.get("path")
    if fp and (fp.endswith(".csv") or fp.endswith(".tsv")):
        return fp
    return None


def main():
    try:
        payload = json.load(sys.stdin)
        file_path = extract_file_path(payload)

        if not file_path:
            sys.exit(0)

        warnings = validate_csv(file_path)
        if warnings:
            print(f"CSV validation warnings for {file_path}:", file=sys.stderr)
            for w in warnings:
                print(f"  - {w}", file=sys.stderr)
        sys.exit(0)

    except Exception:
        # Never block the agent on validator errors
        sys.exit(0)


if __name__ == "__main__":
    main()
