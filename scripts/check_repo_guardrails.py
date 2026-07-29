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
    # SAS code — all SAS lives under sas_code/, src/ is Python-only
    Path("sas_code/macros"),
    Path("sas_code/modules/module_a_advanced_core"),
    Path("sas_code/modules/module_b_modernization_simulation"),
    Path("sas_code/modules/module_c_api_reporting"),
    Path("sas_code/00_config_and_macros.sas"),
    Path("sas_code/01_data_ingestion.sas"),
    Path("sas_code/02_data_cleaning.sas"),
    Path("sas_code/03_aca_business_logic.sas"),
    Path("sas_code/04_ods_reporting.sas"),
    # Python source and supporting structure
    Path("src/python"),
    Path("pipelines"),
    Path("tests"),
    Path("config"),
    Path("data/raw"),
    Path("data/processed"),
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
