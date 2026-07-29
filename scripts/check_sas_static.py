"""Static checks for SAS source files."""

from __future__ import annotations

import re
import sys
from pathlib import Path

REQUIRED_HEADERS = ("Purpose:", "Inputs:", "Outputs:", "Usage:")
ABSOLUTE_LIBNAME_PATTERN = re.compile(
    r"^\s*libname\s+\w+\s+['\"](/|[A-Za-z]:\\)", re.IGNORECASE | re.MULTILINE
)
RISKY_EXECUTION_PATTERNS = {
    "x command": re.compile(r"^\s*x\s+['\"]", re.IGNORECASE | re.MULTILINE),
    "systask": re.compile(r"\bsystask\b", re.IGNORECASE),
    "filename pipe": re.compile(r"^\s*filename\s+\w+\s+pipe\b", re.IGNORECASE | re.MULTILINE),
}


def main() -> int:
    # Only scan SAS library files (macros and modules) — these require
    # structured documentation headers. Pipeline stage programs (00-04)
    # use a different block-comment convention and are excluded here.
    sas_dirs = [Path("sas_code/macros"), Path("sas_code/modules")]
    sas_files = sorted(f for d in sas_dirs if d.exists() for f in d.rglob("*.sas"))
    violations: list[str] = []

    for path in sas_files:
        text = path.read_text(encoding="utf-8")
        missing_headers = [header for header in REQUIRED_HEADERS if header not in text]
        if missing_headers:
            violations.append(f"{path}: missing headers {', '.join(missing_headers)}")

        if ABSOLUTE_LIBNAME_PATTERN.search(text):
            violations.append(f"{path}: hardcoded absolute libname path found")

        for label, pattern in RISKY_EXECUTION_PATTERNS.items():
            if pattern.search(text):
                violations.append(f"{path}: risky shell execution pattern found ({label})")

    if violations:
        print("SAS static checks failed:", file=sys.stderr)
        for violation in violations:
            print(f"- {violation}", file=sys.stderr)
        return 1

    print(f"SAS static checks passed for {len(sas_files)} file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
