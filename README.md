# SAS Healthcare Analytics Playground

Enterprise-grade SAS learning portfolio with a clean split between Python code in `src/` and SAS code in `sas_code/`.

[![SAS](https://img.shields.io/badge/SAS-9.4%2B%20%7C%20Viya%204-0275d8?logo=sas)](https://www.sas.com)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python)](https://python.org)
[![saspy](https://img.shields.io/badge/saspy-5.x-blue)](https://sassoftware.github.io/saspy/)
[![Dev Containers](https://img.shields.io/badge/Dev%20Container-ready-007ACC?logo=visualstudiocode)](https://containers.dev)

## Overview

This repository demonstrates a local SAS development workflow built on VS Code Dev Containers, Docker, JupyterLab, and `saspy`.

Primary example: ACA Healthcare Payer analytics pipeline.

| Stage | File | Purpose |
| --- | --- | --- |
| 00 | `sas_code/00_config_and_macros.sas` | Global config, librefs, and audit macros |
| 01 | `sas_code/01_data_ingestion.sas` | Bronze ingestion and validation |
| 02 | `sas_code/02_data_cleaning.sas` | Silver cleaning, hash lookups, and dedup |
| 03 | `sas_code/03_aca_business_logic.sas` | Gold ACA logic, FTE, and 1095-C codes |
| 04 | `sas_code/04_ods_reporting.sas` | ODS Excel/PDF reporting |

Reusable SAS examples live under `sas_code/macros/` and `sas_code/modules/`.

## Repository Layout

```text
sas-modernization-lab/
├── .devcontainer/
├── config/
├── data/
│   ├── raw/
│   └── processed/
├── docs/
├── notebooks/
├── pipelines/
├── sas_code/
│   ├── 00_config_and_macros.sas
│   ├── 01_data_ingestion.sas
│   ├── 02_data_cleaning.sas
│   ├── 03_aca_business_logic.sas
│   ├── 04_ods_reporting.sas
│   ├── macros/
│   └── modules/
├── scripts/
├── src/
│   └── python/
├── tests/
├── pyproject.toml
├── requirements.txt
└── saspy_config.py
```

## Separation Rules

- `src/` is Python-only.
- `sas_code/` contains all SAS source files.
- `data/raw/` contains simulated source inputs.
- `data/processed/` is for generated datasets and report outputs.
- `sas_modernization_lab.egg-info/` is a local editable-install artifact and is ignored by git.

## Quick Start

### Dev Container

1. Install Docker Desktop and VS Code with the Dev Containers extension.
2. Open the repository and choose Reopen in Container.
3. The container installs Python, Java, saspy, JupyterLab, and editor tooling.

### Local Environment

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
make lint
make test
make validate
```

## SASPy Profiles

`/workspaces/sas-modernization-lab/saspy_config.py` provides these connection profiles:

| Profile | Use Case |
| --- | --- |
| `stdio_local` | Local SAS executable |
| `iom_workspace` | SAS 9.4 Workspace Server |
| `http_viya` | SAS Viya 4 Compute API |

Example:

```python
import saspy

sas = saspy.SASsession(cfgfile='saspy_config.py', cfgname='stdio_local')
print(sas.submit('proc options; run;')['LOG'])
sas.endsas()
```

## Running The Pipeline

Open `notebooks/saspy_execution.ipynb` and run cells in order. The notebook:

- connects to SAS through `saspy`
- runs stages 01 to 04
- previews Bronze, Silver, and Gold datasets in pandas
- writes ODS outputs to `data/processed/reports/`

Useful commands:

```bash
make lint
make test
make validate
python scripts/check_repo_guardrails.py
python scripts/check_sas_static.py
```

## SAS Techniques Summary

| Area | Techniques |
| --- | --- |
| Bronze | `PROC IMPORT`, regex validation, row-count checks |
| Silver | `DECLARE HASH`, arrays, `ANYDTDTE`, deduplication |
| Gold | `INTCK`, `INTNX`, `PROC TRANSPOSE`, `SELECT/WHEN` |
| Reports | `PROC REPORT`, `PROC TABULATE`, `ODS EXCEL`, `ODS PDF` |

## ACA Compliance Context

This pipeline models the IRC §4980H Employer Shared Responsibility rules.

| Rule | Threshold |
| --- | --- |
| Full-time employee | >= 130 hours/month |
| Applicable Large Employer (ALE) | >= 50 full-time equivalents/month |
| Wellness incentive cap | 30% of total annual plan premium |
| Tobacco-cessation incentive cap | 50% of total annual plan premium |

### 1095-C Offer Codes

| Code | Description |
| --- | --- |
| `1A` | Qualifying offer |
| `1B` | MEC offered to employee only |
| `1C` | MEC offered to employee and spouse |
| `1E` | MEC offered to employee and family |
| `1H` | No offer of coverage |

## Quality Gates

- `python scripts/check_sas_static.py`
- `python scripts/check_repo_guardrails.py`
- `pytest tests/test_structure.py -v`
- Ruff, markdownlint, ShellCheck, and YAML checks via pre-commit and CI

## References

- [SASPy Documentation](https://sassoftware.github.io/saspy/)
- [SAS 9.4 PROC REPORT](https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/proc/n0r9dp4tshpj56n1bnukvhk3gbnc.htm)
- [ODS EXCEL Reference](https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/odsug/n17mnqxdajppekn1gsxm5pv87gwy.htm)
- [IRS Instructions for Forms 1094-C and 1095-C](https://www.irs.gov/pub/irs-pdf/i109495c.pdf)

## Contributing

See `CONTRIBUTING.md` and `docs/BRANCHING_STRATEGY.md`.

## License

MIT. For learning and portfolio purposes only.
