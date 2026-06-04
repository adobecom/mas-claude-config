#!/usr/bin/env python3
"""
PostToolUse hook: arm the PR babysitter after a push to a PR branch or a
`gh pr create`.

The hook does NOT poll CI or judge failures itself. Following the
post_pr_jira_transition.py precedent, it detects the triggering event,
initializes a small state file (retry budget), and emits
hookSpecificOutput.additionalContext that instructs Claude to run the
babysitting loop. All CI reasoning (flaky vs real, when to rerun, when to
stop) lives in Claude — the hook stays credential-free and dumb.

Activation:
- Bash tool calls whose command contains `git push` (branch must have an
  open PR) OR `gh pr create` (PR URL must appear in stdout).
- Repo must be under an allowed owner (default: adobecom).
- Disabled when env BABYSIT_PR=0.

State file: ~/.claude/state/babysit-<owner>-<repo>-<pr>.json
  { "pr": 795, "repo": "adobecom/mas", "branch": "MWPW-...",
    "retries": {}, "max_retries_per_job": 2,
    "autofixes": {}, "max_autofix_per_type": 1 }
  (autofixes tracks per-type caps, e.g. {"sync": 1} once a behind-main
  sync has run — see category H in the emitted instructions.)

Failure mode: any exception prints to stderr and exits 0 (non-blocking).
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

ALLOWED_OWNERS = {"adobecom"}
# Repos where the 'run nala' label gates merge (and a labelless push hard-fails
# the run-nala workflow on synchronize). Auto-apply the label on arm.
RUN_NALA_LABEL = "run nala"
RUN_NALA_REPOS = {"adobecom/mas"}
MAX_RETRIES_PER_JOB = 2
STATE_DIR = Path.home() / ".claude" / "state"
PR_URL_RE = re.compile(r"https://github\.com/([^/\s]+)/([^/\s]+)/pull/(\d+)")


def git(cwd: str, *args: str) -> str:
    try:
        r = subprocess.run(
            ["git", "-C", cwd, *args],
            capture_output=True, text=True, timeout=5,
        )
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception as e:  # noqa: BLE001
        print(f"babysit_pr_arm: git {' '.join(args)} failed: {e}", file=sys.stderr)
        return ""


def gh(cwd: str, *args: str) -> bool:
    try:
        r = subprocess.run(
            ["gh", *args], capture_output=True, text=True, timeout=15, cwd=cwd,
        )
        return r.returncode == 0
    except Exception as e:  # noqa: BLE001
        print(f"babysit_pr_arm: gh {' '.join(args)} failed: {e}", file=sys.stderr)
        return False


def gh_json(cwd: str, *args: str) -> dict | list | None:
    try:
        r = subprocess.run(
            ["gh", *args],
            capture_output=True, text=True, timeout=15, cwd=cwd,
        )
        if r.returncode != 0:
            return None
        return json.loads(r.stdout)
    except Exception as e:  # noqa: BLE001
        print(f"babysit_pr_arm: gh {' '.join(args)} failed: {e}", file=sys.stderr)
        return None


def resolve_pr(cwd: str, stdout: str, is_create: bool) -> tuple[str, str, int] | None:
    """Return (owner, repo, pr_number) or None."""
    if is_create:
        m = PR_URL_RE.search(stdout)
        if m:
            return m.group(1), m.group(2), int(m.group(3))
        return None
    # push path: find the open PR for the current branch
    data = gh_json(
        cwd, "pr", "view", "--json", "number,url,state",
    )
    if not isinstance(data, dict):
        return None
    if data.get("state") != "OPEN":
        return None
    m = PR_URL_RE.search(data.get("url") or "")
    if not m:
        return None
    return m.group(1), m.group(2), int(data["number"])


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception as e:  # noqa: BLE001
        print(f"babysit_pr_arm: bad stdin: {e}", file=sys.stderr)
        return 0

    if os.environ.get("BABYSIT_PR") == "0":
        return 0
    if payload.get("tool_name") != "Bash":
        return 0

    command = (payload.get("tool_input") or {}).get("command") or ""
    is_push = "git push" in command
    is_create = "gh pr create" in command
    if not (is_push or is_create):
        return 0

    resp = payload.get("tool_response") or {}
    stdout = ""
    if isinstance(resp, dict):
        stdout = resp.get("stdout") or resp.get("output") or ""
    elif isinstance(resp, str):
        stdout = resp

    cwd = payload.get("cwd") or "."
    resolved = resolve_pr(cwd, stdout, is_create)
    if not resolved:
        return 0
    owner, repo, pr = resolved
    if owner not in ALLOWED_OWNERS:
        return 0

    full_repo = f"{owner}/{repo}"
    branch = git(cwd, "branch", "--show-current")

    # Idempotently ensure the 'run nala' label (gates merge; a labelless push
    # hard-fails the run-nala workflow on synchronize). Re-adding is a no-op.
    label_applied = False
    if full_repo in RUN_NALA_REPOS:
        label_applied = gh(
            cwd, "pr", "edit", str(pr), "--repo", full_repo,
            "--add-label", RUN_NALA_LABEL,
        )

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state_path = STATE_DIR / f"babysit-{owner}-{repo}-{pr}.json"
    if state_path.exists():
        try:
            state = json.loads(state_path.read_text())
        except Exception:  # noqa: BLE001
            state = {}
    else:
        state = {}
    # New push resets the budgets — fresh CI run, fresh chances.
    state.update({
        "pr": pr,
        "repo": full_repo,
        "branch": branch,
        "retries": {},
        "max_retries_per_job": MAX_RETRIES_PER_JOB,
        "autofixes": {},
        "max_autofix_per_type": 1,
    })
    state_path.write_text(json.dumps(state, indent=2))

    label_note = (
        f"The '{RUN_NALA_LABEL}' label was auto-applied.\n\n"
        if label_applied else
        (f"NOTE: failed to auto-apply the '{RUN_NALA_LABEL}' label — apply it "
         f"yourself with `gh pr edit {pr} --repo {full_repo} --add-label "
         f"'{RUN_NALA_LABEL}'`, since a labelless push hard-fails run-nala.\n\n"
         if full_repo in RUN_NALA_REPOS else "")
    )

    message = (
        f"[PR babysitter armed] A change was pushed to {full_repo} PR #{pr} "
        f"(branch {branch}). {label_note}Babysit it until all checks are green.\n\n"
        f"POLL: `gh pr checks {pr} --repo {full_repo}`. While checks run, "
        "ScheduleWakeup (~270s) with an identical prompt to continue the loop; "
        "do NOT block the session. State/budgets live in "
        f"{state_path}.\n\n"
        "When all pass: announce green, delete the state file, omit "
        "ScheduleWakeup (loop ends).\n\n"
        "On FAILURE, classify before acting (pull detail via "
        f"`gh api repos/{full_repo}/check-runs/<job-id>/annotations` or "
        "`gh run view`):\n\n"
        "AUTO-FIX & PUSH (deterministic; cap 1 per type per session via "
        "state.autofixes — if a type already hit its cap, STOP instead):\n"
        "  A. Stale dist — 'Build and Test Web Components' fails its "
        "'uncommitted changes' step: run `npm run build` in web-components/, "
        "commit web-components/dist/*, push.\n"
        "  B. Prettier Check fails: `npx prettier --write` the listed files, "
        "commit, push.\n"
        "  C. dist-ONLY merge conflict (gh pr view --json mergeable shows "
        "CONFLICTING and conflicts are confined to web-components/dist/*): take "
        "base, rebuild from merged source, commit, push. Any SOURCE-file "
        "conflict: STOP and ask.\n"
        "  H. Behind-main flaky E2E — when a category-D unrelated/flaky E2E "
        "fails AND the branch is behind main "
        "(`git rev-list --count HEAD..origin/main` > 0 after "
        "`git fetch origin main`): a stale branch is a known MAS Docs/Studio "
        "E2E flake cause, so SYNC BEFORE spending a rerun. Run the "
        "`sync-with-main` skill (merge origin/main, auto-resolve dist "
        "conflicts, rebuild, push). Cap 1/session via state.autofixes.sync. "
        "Any SOURCE-file conflict during the merge: STOP and ask. The push "
        "re-arms this hook with fresh budgets. If the branch is already "
        "current (0 behind), skip H and fall through to D.\n"
        "  (Each new push re-arms this hook and resets budgets — fine.)\n\n"
        "AUTO-RERUN (no code change):\n"
        "  D. Flaky/unrelated E2E (NALA studio/milo failures not touching "
        "changed files, or marked flaky/passed-on-retry): FIRST check H "
        "(sync if behind main); if already current, "
        "`gh run rerun <run-id> --failed`, cap "
        f"{MAX_RETRIES_PER_JOB}/job via state.retries.\n"
        "  G. Infra (runner died, npm/registry blip, cancelled/timeout with no "
        "assertion failure): rerun once, NOT counted against the flaky cap.\n\n"
        "STOP & REPORT (never auto-edit code, never rerun):\n"
        "  E. Real test failure touching changed files.\n"
        "  F. Unit-test/lint/build failure that isn't the stale-dist step.\n"
        "  Any job that exhausted its retry or autofix cap.\n"
        "  External gates (Kodiak, CLA, codecov) — these are not yours to fix; "
        "report and wait.\n\n"
        "Kill switch: BABYSIT_PR=0 disables arming; honor an explicit "
        "'stop babysitting' anytime."
    )

    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": message,
        }
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
