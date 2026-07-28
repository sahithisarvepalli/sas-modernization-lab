from pathlib import Path

REQUIRED_PATHS = [
    "README.md",
    "CONTRIBUTING.md",
    ".devcontainer/devcontainer.json",
    ".github/workflows/ci.yml",
    ".github/workflows/sas-static-checks.yml",
    ".github/workflows/repo-guardrails.yml",
    "docs/ARCHITECTURE.md",
    "docs/MIGRATION_GUIDE.md",
    "docs/OPERATIONS_RUNBOOK.md",
    "docs/ROADMAP.md",
    "docs/BRANCHING_STRATEGY.md",
    "src/macros/logging.sas",
    "src/macros/validation.sas",
    "src/sas/module_a_advanced_core/main.sas",
    "src/sas/module_b_modernization_simulation/main.sas",
    "src/sas/module_c_api_reporting/main.sas",
    "src/python/interop_entry.py",
    "config/.env.example",
]


def test_required_paths_exist() -> None:
    missing = [path for path in REQUIRED_PATHS if not Path(path).exists()]
    assert not missing, f"Missing required paths: {missing}"
