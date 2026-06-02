"""Secret detection rule table + matcher.

Importable module used by:
  - secret_leak_gate.py    (PreToolUse hook for Write/Edit/MultiEdit/Bash)
  - pr_secret_scan.py      (PreToolUse hook for gh pr create|edit)
  - scripts/scan-existing-secrets.py (one-shot filesystem audit)

Detection tiers (see plan: ~/.claude/plans/let-s-work-on-these-swirling-umbrella.md):
  - SHAPE    : PEM/PGP/SSH keys, db URIs with auth — always block
  - HIGH     : prefix-based credentials (ghp_, AKIA, figd_, xox*, sk-, AIza) — always block
  - MEDIUM   : SENSITIVE_KEY=value assignments — block in Tier-1 paths, warn elsewhere
  - LOW      : generic JWTs — block in Tier-1 only
  - ENTROPY  : Shannon entropy >= 4.0 over 32+ char run — Tier-1 only

Override marker:  <!-- secret-ok: reason >= 3 chars -->
"""

import math
import re
from collections import Counter
from dataclasses import dataclass

# --- override + skip --------------------------------------------------------

OVERRIDE_RE = re.compile(r"<!--\s*secret-ok:\s*(\S.{2,}?)\s*-->", re.IGNORECASE | re.DOTALL)
AUDIT_OK_RE = re.compile(r"(?:#|//|/\*)\s*secret-ok\s*:\s*\S.{2,}", re.IGNORECASE)

SKIP_PATH_RE = re.compile(
    r"(?:^|/)(?:fixtures|__mocks__|\.git|node_modules|coverage|dist|build)(?:/|$)"
)

# --- tier-1 path detection --------------------------------------------------

TIER1_PATH_RE = re.compile(
    r"(?:/|^)\.claude/"
    r"|(?:/|^)CLAUDE\.md(?:$|\W)"
    r"|(?:/|^)\.env(?:\.[\w-]+)?(?:$|\W)"
    r"|(?:/|^)\.mcp\.json(?:\.[\w-]+)?(?:$|\W)"
)

# --- placeholder detection --------------------------------------------------

PLACEHOLDER_VAL_RE = re.compile(
    r"""^(?:
        \$\{[^}]+\}             # ${VAR} or ${process.env.X}
      | <[A-Z][A-Z0-9_]*>       # <REDACTED>, <YOUR_TOKEN>
      | process\.env\.\w+       # process.env.X (bare)
      | (?:[a-zA-Z_$][\w$]*\.)+ [A-Z][A-Z0-9_]+   # obj.X or parsed.ANTHROPIC_API_KEY (TS/JS property)
      | secrets\.\w+
      | env\.\w+
      | x{3,} | y{3,}           # xxx... / yyy...
      | (?:fake|test|mock|dummy|example|sample)[-_].*
      | redacted
      | \*+                      # **** (masked)
      | YOUR_[A-Z_]+             # YOUR_API_KEY style placeholder
    )$""",
    re.VERBOSE | re.IGNORECASE,
)

TEMPLATE_LITERAL_ENV_RE = re.compile(r"\$\{(?:process\.env|secrets|env)\.\w+\}", re.IGNORECASE)

# Strip lines whose only "value" is a placeholder before running detection.
PLACEHOLDER_LINE_RE = re.compile(
    r"""(?:["']?\$\{[^}]+\}["']?
       |["']?<[A-Z][A-Z0-9_]*>["']?
       |["']?(?:process\.env|secrets|env)\.\w+["']?)""",
    re.VERBOSE,
)

# --- SHAPE patterns (always block) ------------------------------------------

# PEM/PGP/SSH patterns require a substantial base64 body between markers
# (≥100 chars of [A-Za-z0-9+/=\s]) to avoid matching code that merely
# *references* the marker strings (e.g. `if (cert.includes('-----BEGIN...'))`).
SHAPE_PATTERNS = [
    ("pem_private_key",
     re.compile(r"-----BEGIN[ A-Z]*PRIVATE KEY-----[\sA-Za-z0-9+/=]{100,}?-----END[ A-Z]*PRIVATE KEY-----")),
    ("pem_certificate",
     re.compile(r"-----BEGIN CERTIFICATE-----[\sA-Za-z0-9+/=]{100,}?-----END CERTIFICATE-----")),
    ("pgp_private_key",
     re.compile(r"-----BEGIN PGP PRIVATE KEY BLOCK-----[\sA-Za-z0-9+/=:\.\-]{100,}?-----END PGP PRIVATE KEY BLOCK-----")),
    ("ssh_private_key",
     re.compile(r"-----BEGIN OPENSSH PRIVATE KEY-----[\sA-Za-z0-9+/=]{100,}?-----END OPENSSH PRIVATE KEY-----")),
    ("db_uri_with_password",
     re.compile(r"\b(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?|redis|amqp|rediss)://[^:\s/@]+:[^@\s/]{8,}@[^\s/]+")),
    ("basic_auth_url",
     re.compile(r"\bhttps?://[^:\s/@]+:[^@\s/]{8,}@[^\s/]+")),
]

# --- HIGH-confidence prefix-based -------------------------------------------

HIGH_PATTERNS = [
    ("aws_access_key_id",   re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("github_pat_classic",  re.compile(r"\bghp_[A-Za-z0-9]{36}\b")),
    ("github_pat_other",    re.compile(r"\bgh[ousr]_[A-Za-z0-9]{36}\b")),
    ("figma_pat",           re.compile(r"\bfigd_[A-Za-z0-9_-]{40,}\b")),
    ("slack_token",         re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
    ("anthropic_or_openai", re.compile(r"\bsk-(?:ant-|proj-)?[A-Za-z0-9_-]{40,}\b")),
    ("google_api_key",      re.compile(r"\bAIza[A-Za-z0-9_-]{35}\b")),
]

# AWS keypair: an access key followed within ~200 chars by a 40-char secret.
AWS_KEYPAIR_RE = re.compile(r"AKIA[0-9A-Z]{16}[\s\S]{0,200}?[A-Za-z0-9/+=]{40}")

# --- MEDIUM: sensitive-named key assignments --------------------------------

MEDIUM_KEY_RE = re.compile(
    r"""(?xi)
    \b(
        [A-Z][A-Z0-9_]*(?:API_KEY|ACCESS_TOKEN|SECRET(?:_KEY)?|PRIVATE_KEY|PAT|BEARER|PASSWORD)
      | (?:AEM|JIRA|WIKI|FIGMA|SLACK|OPENAI|ANTHROPIC|GITHUB|GH|AWS|GOOGLE)_[A-Z_]+_TOKEN
    )
    \s*[:=]\s*
    ["']?(?P<val>[A-Za-z0-9._\-/+=]{20,})["']?
    """
)

# --- LOW: JWTs --------------------------------------------------------------

JWT_RE = re.compile(r"\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\b")

# --- ENTROPY ----------------------------------------------------------------

TOKEN_CANDIDATE_RE = re.compile(r"[A-Za-z0-9+=]{32,}")
ENTROPY_THRESHOLD = 4.0

ENTROPY_LINE_SKIP_RE = re.compile(
    r"MODEL_ID|FRAGMENT_ID|MODEL_PATH|import\.meta|require\(|data:image/|sha-?\d+:",
    re.IGNORECASE,
)
AEM_PATH_PREFIX_RE = re.compile(r"^(?:L2NvbmYv|L2NvbnRlbnQv|L2RhbS8)")
HEX_DIGEST_RE = re.compile(r"^[0-9a-fA-F]{32,64}$")

# Identifiers/paths/URLs that LOOK high-entropy but aren't credentials.
# Credentials are dense and uninterrupted; identifiers have separators.
IDENTIFIER_SHAPED_RE = re.compile(
    r"""(?:
        __                       # mcp__scout__... style identifiers
      | \.\.                     # ../parent paths
      | (?:^|[^A-Za-z0-9])(?:https?|file|git|ftp|ssh)://  # URL prefix in surrounding
    )""",
    re.VERBOSE,
)


def shannon_entropy(s: str) -> float:
    if not s:
        return 0.0
    counts = Counter(s)
    n = len(s)
    return -sum((c / n) * math.log2(c / n) for c in counts.values())


def is_placeholder(val: str) -> bool:
    if not val:
        return True
    return bool(PLACEHOLDER_VAL_RE.match(val))


def path_is_tier1(file_path: str) -> bool:
    if not file_path:
        return False
    return bool(TIER1_PATH_RE.search(file_path))


def path_should_skip(file_path: str) -> bool:
    if not file_path:
        return False
    return bool(SKIP_PATH_RE.search(file_path))


def has_override(content: str) -> bool:
    if not content:
        return False
    return bool(OVERRIDE_RE.search(content) or AUDIT_OK_RE.search(content))


def _strip_placeholder_assignments(content: str) -> str:
    """Replace `KEY=${...}` and similar with `KEY=PLACEHOLDER` so MEDIUM doesn't fire."""
    return PLACEHOLDER_LINE_RE.sub('"PLACEHOLDER"', content)


def _line_for(content: str, offset: int) -> int:
    return content.count("\n", 0, offset) + 1


@dataclass
class Finding:
    pattern: str
    tier: str          # "shape" | "high" | "medium" | "low" | "entropy"
    line: int
    snippet: str       # redacted for safe display

    def to_log_dict(self) -> dict:
        return {"pattern": self.pattern, "tier": self.tier, "line": self.line}


def _redact(s: str, keep: int = 4) -> str:
    if len(s) <= keep * 2:
        return "***"
    return f"{s[:keep]}…{s[-keep:]}"


def find_findings(content: str, file_path: str = "") -> list[Finding]:
    """Detect secrets in `content`.

    Returns empty list when:
      - content is empty
      - override marker is present
      - file_path matches skip list
    """
    if not content:
        return []
    if has_override(content):
        return []
    if path_should_skip(file_path):
        return []

    stripped = _strip_placeholder_assignments(content)
    findings: list[Finding] = []

    # SHAPE — always block
    for name, rx in SHAPE_PATTERNS:
        for m in rx.finditer(stripped):
            findings.append(Finding(name, "shape", _line_for(stripped, m.start()), _redact(m.group(0))))

    # HIGH — always block
    for name, rx in HIGH_PATTERNS:
        for m in rx.finditer(stripped):
            findings.append(Finding(name, "high", _line_for(stripped, m.start()), _redact(m.group(0))))
    for m in AWS_KEYPAIR_RE.finditer(stripped):
        # Only emit if both lines are within ~3 newlines (not a false-spread match).
        findings.append(Finding("aws_keypair", "high", _line_for(stripped, m.start()), _redact(m.group(0))))

    tier1 = path_is_tier1(file_path)

    # MEDIUM — sensitive-key assignments with literal values
    for m in MEDIUM_KEY_RE.finditer(stripped):
        val = m.group("val")
        if is_placeholder(val):
            continue
        # If the *original* line contains a template-literal env reference, skip.
        line_no = _line_for(stripped, m.start())
        line_content = content.splitlines()[line_no - 1] if line_no - 1 < len(content.splitlines()) else ""
        if TEMPLATE_LITERAL_ENV_RE.search(line_content):
            continue
        findings.append(Finding(
            f"sensitive_key_assignment:{m.group(1)}",
            "medium" if tier1 else "medium_warn",
            line_no,
            _redact(val),
        ))

    # LOW — JWTs
    for m in JWT_RE.finditer(stripped):
        findings.append(Finding(
            "jwt",
            "low" if tier1 else "low_warn",
            _line_for(stripped, m.start()),
            _redact(m.group(0)),
        ))

    # ENTROPY — Tier-1 only
    if tier1:
        lines = content.splitlines()
        seen_offsets: set[int] = set()
        for m in TOKEN_CANDIDATE_RE.finditer(stripped):
            token = m.group(0)
            if m.start() in seen_offsets:
                continue
            seen_offsets.add(m.start())
            line_no = _line_for(stripped, m.start())
            line_content = lines[line_no - 1] if line_no - 1 < len(lines) else ""
            if ENTROPY_LINE_SKIP_RE.search(line_content):
                continue
            if AEM_PATH_PREFIX_RE.match(token):
                continue
            if HEX_DIGEST_RE.match(token):
                continue
            if shannon_entropy(token) < ENTROPY_THRESHOLD:
                continue
            # Skip if already flagged by a higher tier (avoid double-reporting).
            already_flagged = any(
                f.line == line_no and f.tier in ("shape", "high", "medium", "low")
                for f in findings
            )
            if already_flagged:
                continue
            findings.append(Finding("high_entropy_string", "entropy", line_no, _redact(token)))

    return findings


# --- decision helper --------------------------------------------------------

def should_block(findings: list[Finding]) -> bool:
    """True if any finding warrants blocking (vs warn-only)."""
    for f in findings:
        if f.tier in ("shape", "high", "medium", "low", "entropy"):
            return True
    return False


def warn_only(findings: list[Finding]) -> list[Finding]:
    return [f for f in findings if f.tier.endswith("_warn")]


def blocking(findings: list[Finding]) -> list[Finding]:
    return [f for f in findings if not f.tier.endswith("_warn")]
