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
    # SAS library files — reusable macros and module examples
    "sas_code/macros/logging.sas",
    "sas_code/macros/validation.sas",
    "sas_code/modules/module_a_advanced_core/main.sas",
    "sas_code/modules/module_b_modernization_simulation/main.sas",
    "sas_code/modules/module_c_api_reporting/main.sas",
    # Healthcare ACA pipeline stages
    "sas_code/00_config_and_macros.sas",
    "sas_code/01_data_ingestion.sas",
    "sas_code/02_data_cleaning.sas",
    "sas_code/03_aca_business_logic.sas",
    "sas_code/04_ods_reporting.sas",
    # Python interop layer (src/ is Python-only)
    "src/python/interop_entry.py",
    "config/.env.example",
]


def test_required_paths_exist() -> None:
    missing = [path for path in REQUIRED_PATHS if not Path(path).exists()]
    assert not missing, f"Missing required paths: {missing}"
