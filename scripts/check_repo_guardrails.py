"""Repository guardrail checks for bootstrap structure and docs."""

from __future__ import annotations

import sys
from pathlib import Path

REQUIRED_PATHS = [
    Path("README.md"),
    Path("CONTRIBUTING.md"),
    Path("docs/ARCHITECTURE.md"),
    Path("docs/MIGRATION_GUIDE.md"),
    Path("docs/OPERATIONS_RUNBOOK.md"),
    Path("docs/ROADMAP.md"),
    Path("docs/BRANCHING_STRATEGY.md"),
    Path("src/sas/module_a_advanced_core"),
    Path("src/sas/module_b_modernization_simulation"),
    Path("src/sas/module_c_api_reporting"),
    Path("src/macros"),
    Path("src/python"),
    Path("pipelines"),
    Path("tests"),
    Path("config"),
    Path("data/sample"),
    Path(".github/workflows/ci.yml"),
    Path(".github/workflows/sas-static-checks.yml"),
    Path(".github/workflows/repo-guardrails.yml"),
]


def main() -> int:
    missing = [str(path) for path in REQUIRED_PATHS if not path.exists()]
    if missing:
        print("Repo guardrails failed:", file=sys.stderr)
        for path in missing:
            print(f"- Missing required path: {path}", file=sys.stderr)
        return 1

    print(f"Repo guardrails passed for {len(REQUIRED_PATHS)} required paths.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
