## SAS Healthcare Analytics Playground

> Enterprise-grade SAS learning portfolio with a clear separation between
> Python code in `src/` and all SAS assets in `sas_code/`.

[![SAS](https://img.shields.io/badge/SAS-9.4%2B%20%7C%20Viya%204-0275d8?logo=sas)](https://www.sas.com)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python)](https://python.org)
[![saspy](https://img.shields.io/badge/saspy-5.x-blue)](https://sassoftware.github.io/saspy/)
[![Dev Containers](https://img.shields.io/badge/Dev%20Container-ready-007ACC?logo=visualstudiocode)](https://containers.dev)

## Overview

This repository demonstrates a local SAS development workflow built on VS Code
Dev Containers, Docker, JupyterLab, and `saspy`. The main example is an ACA
Healthcare Payer analytics pipeline with four stages:

| Stage | File | Purpose |
|-------|------|---------|
| 00 | `sas_code/00_config_and_macros.sas` | Global config, librefs, audit macros |
| 01 | `sas_code/01_data_ingestion.sas` | Bronze ingestion and validation |
| 02 | `sas_code/02_data_cleaning.sas` | Silver cleaning, hash lookups, dedup |
| 03 | `sas_code/03_aca_business_logic.sas` | Gold ACA logic, FTE, 1095-C codes |
| 04 | `sas_code/04_ods_reporting.sas` | ODS Excel/PDF reporting |

Reusable SAS examples live separately under `sas_code/macros/` and
`sas_code/modules/`. Python interop code lives under `src/python/` only.

## Repository Layout

```
sas-modernization-lab/
├── .devcontainer/
├── data/
│   ├── raw/
│   └── processed/
├── notebooks/
├── sas_code/
│   ├── 00_config_and_macros.sas
│   ├── 01_data_ingestion.sas
│   ├── 02_data_cleaning.sas
│   ├── 03_aca_business_logic.sas
│   ├── 04_ods_reporting.sas
│   ├── macros/
│   └── modules/
├── src/
│   └── python/
├── saspy_config.py
├── requirements.txt
└── README.md
```

## Clear Separation

- `src/` is Python-only.
- `sas_code/` contains all SAS source files.
- `data/raw/` contains simulated inputs.
- `data/processed/` stores generated Bronze, Silver, Gold, and reporting outputs.
- `sas_modernization_lab.egg-info/` is a local editable-install artifact and is
  ignored by git.

## Quick Start

### Dev Container

1. Install Docker Desktop and VS Code with the Dev Containers extension.
2. Open the repository and choose Reopen in Container.
3. The container installs Python, Java, saspy, JupyterLab, and editor tooling.

### Local Python environment

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
make lint
make test
make validate
```

## SASPy Connection Profiles

`saspy_config.py` provides three example profiles:

| Profile | Use case |
|---------|----------|
| `stdio_local` | Local SAS executable |
| `iom_workspace` | SAS 9.4 Workspace Server |
| `http_viya` | SAS Viya 4 Compute API |

Example usage:

```python
import saspy

sas = saspy.SASsession(cfgfile='saspy_config.py', cfgname='stdio_local')
print(sas.submit('proc options; run;')['LOG'])
sas.endsas()
```

## Running the Pipeline

Open `notebooks/saspy_execution.ipynb` in JupyterLab to execute the full
pipeline interactively. The notebook:

- connects to SAS through `saspy`
- runs stages 01 through 04
- previews Bronze, Silver, and Gold datasets in pandas
- writes ODS Excel and PDF outputs into `data/processed/reports/`

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
|------|------------|
| Bronze | `PROC IMPORT`, regex validation, row-count checks |
| Silver | `DECLARE HASH`, arrays, `ANYDTDTE`, deduplication |
| Gold | `INTCK`, `INTNX`, `PROC TRANSPOSE`, `SELECT/WHEN` |
| Reports | `PROC REPORT`, `PROC TABULATE`, `ODS EXCEL`, `ODS PDF` |

## Notes

- The repository intentionally keeps SAS examples out of `src/`.
- `data/processed/` is for generated output only.
- Credentials belong in `~/.authinfo` or the Viya token flow, not in the repo.

## License

MIT. This repository is for learning and portfolio purposes only.

### Stage 03 — Gold Business Logic

| Technique | Usage |
|-----------|-------|
| `INTCK('month', start, end, 'C')` | Count full months of employment in year |
| `INTNX('year', date, n, 'same')` | Compute Nth service anniversary date |
| `PROC TRANSPOSE` | Reshape wide monthly columns to long (employee × month) |
| `WHICHC()` | Map month abbreviation to integer |
| `SELECT / WHEN / OTHERWISE` | ACA 1095-C offer code determination (switch-case) |
| `IFC()` inline in `PROC SQL` | Conditional string expression in SELECT |
| `PROC SQL CASE WHEN` | Multi-branch FTE classification aggregation |
| `sum(condition)` in SQL | Count rows matching boolean condition |

### Stage 04 — Reporting

| Technique | Usage |
|-----------|-------|
| `ODS EXCEL` | Multi-sheet workbook with autofilter, frozen headers |
| `ODS PDF style=Journal2` | Bookmarked regulatory PDF report |
| `PROC REPORT` + `COMPUTE` | Columnar report with conditional cell shading |
| `CALL DEFINE(_col_, 'style', ...)` | Runtime cell-level style overrides |
| `RBREAK AFTER / SUMMARIZE` | Grand total rows in PROC REPORT |
| `PROC TABULATE` | Cross-tabulation with nested CLASS variables |
| `ODS PROCLABEL` | Custom PDF bookmark labels |

---

## ACA Compliance Context

This pipeline implements the **IRC §4980H Employer Shared Responsibility**
("play-or-pay") rules. Key thresholds:

| Rule | Threshold |
|------|-----------|
| Full-time employee | ≥ 130 hours/month (avg 30 hrs/week × 4.33 wks) |
| Applicable Large Employer (ALE) | ≥ 50 full-time equivalents/month |
| Wellness incentive cap | 30% of total annual plan premium |
| Tobacco-cessation incentive cap | 50% of total annual plan premium |

### 1095-C Line 14 Codes assigned by `03_aca_business_logic.sas`

| Code | Description |
|------|-------------|
| `1A` | Qualifying Offer: MEC + minimum value, employee-only affordable |
| `1B` | MEC offered to employee only |
| `1C` | MEC offered to employee and spouse |
| `1E` | MEC offered to employee and all family members |
| `1H` | No offer of coverage |

### Line 16 Safe Harbor codes

| Code | Description |
|------|-------------|
| `2A` | Employee not employed during the month |
| `2B` | Employee is not full-time (part-time safe harbor) |
| `2C` | Employee enrolled in coverage offered |
| `2F` | W-2 affordability safe harbor |

---

## Development Commands

```bash
make install    # pip install -r requirements.txt -e .[dev]
make lint       # ruff check + markdownlint
make test       # pytest tests/ -v --cov=src
make validate   # repo guardrails + static SAS checks
```

### Run tests individually

```bash
pytest tests/test_structure.py -v      # repo structure checks
pytest tests/test_python_entry.py -v   # Python module smoke tests
```

---

## Project Configuration Files

| File | Purpose |
|------|---------|
| `saspy_config.py` | SASPy connection profiles (IOM / Viya / stdio) |
| `config/sascfg_personal.py` | Personal connection overrides (gitignored) |
| `.devcontainer/devcontainer.json` | VS Code Dev Container extensions and settings |
| `.devcontainer/Dockerfile` | Python 3.11 + Java + JupyterLab runtime |
| `pyproject.toml` | Python package metadata and tool configuration |
| `.pre-commit-config.yaml` | Pre-commit hooks (ruff, markdownlint, shellcheck) |

---

## Security Notes

- **Never commit credentials** — `config/sascfg_personal.py`, `.authinfo`,
  and `.sas_viya_token` are gitignored.
- **authinfo format** (chmod 0600):
  ```
  machine hostname login USERNAME password YOURPASSWORD
  ```
- Leave `omrpw` / `pw` fields empty in `saspy_config.py`; saspy reads from
  `~/.authinfo` automatically.

---

## References

- [SASPy Documentation](https://sassoftware.github.io/saspy/)
- [SAS 9.4 PROC REPORT](https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/proc/n0r9dp4tshpj56n1bnukvhk3gbnc.htm)
- [ODS EXCEL Reference](https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/odsug/n17mnqxdajppekn1gsxm5pv87gwy.htm)
- [IRS Instructions for Forms 1094-C and 1095-C](https://www.irs.gov/pub/irs-pdf/i109495c.pdf)
- [IRC §4980H — Employer Shared Responsibility](https://www.irs.gov/affordable-care-act/employers/employer-shared-responsibility-provisions)
- [SAS Hash Object Programming](https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/ledsoptsref/n0f0e27aesb9c4n1mjr0u9gkmzf3.htm)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/BRANCHING_STRATEGY.md](docs/BRANCHING_STRATEGY.md).

## License

MIT — see [LICENSE](LICENSE). Not for use in actual regulatory filing without
independent legal and actuarial review.


## Repository layout

| Path | Purpose |
| ---- | ------- |
| `sas_code/` | All SAS source files, including the ACA pipeline and examples |
| `sas_code/modules/` | Reusable SAS module examples |
| `sas_code/macros/` | Shared SAS macros (logging, validation, utilities) |
| `src/python/` | Python-only package code: SASPy session helper, SAS Viya client, interop entry |
| `pipelines/` | Orchestration entrypoints (batch, Airflow, etc.) |
| `config/` | Connection config templates (`.env.example`, `sascfg_personal.py.example`) |
| `docs/` | Architecture, migration guide, runbook, roadmap, branching strategy |
| `tests/` | Smoke tests for structure and Python interop |
| `scripts/` | SAS static checker and repo guardrail scripts |

## Python interoperability packages

| Package | Purpose |
| ------- | ------- |
| [`saspy`](https://github.com/sassoftware/saspy) | SAS/Python bridge — IOM (on-prem), HTTP (SAS Viya), COM (Windows) |
| [`python-swat`](https://github.com/sassoftware/python-swat) | SAS Viya CAS (Cloud Analytic Services) — in-memory analytics |
| `pandas` / `numpy` | DataFrame interchange with SASPy |
| `requests` | SAS Viya REST API (Compute Service, Folders, Jobs) |

## Active quality gates

- SAS static checks — required header block, no absolute `libname` paths, no
  risky shell patterns
- Repo guardrails — required docs and folder structure
- Structure test — verifies the Python-only `src/` split and the full
  `sas_code/` pipeline layout
- Python linting with Ruff
- Markdown linting with markdownlint
- Shell script linting with ShellCheck
- YAML validation with pre-commit

## Module roadmap

1. **Module A** — advanced SAS macro framework and PROC SQL optimization patterns
2. **Module B** — legacy modernization simulation (mainframe-to-SAS handoffs)
3. **Module C** — SAS Viya REST API reporting and SASPy interop expansion
