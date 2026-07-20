# SAS Modernization Lab

A portfolio repository for advanced SAS programming, modernization patterns,
and open-source SAS interoperability — including **SASPy**, **SAS Viya
(python-swat)**, and SAS Compute REST API workflows — targeting insurance
and finance use cases.

## Quick start

```bash
make install
make lint
make test
make validate
```

Open in VS Code for the best experience: the included dev container installs
the [SAS extension](https://marketplace.visualstudio.com/items?itemName=SAS.sas-lsp)
(syntax highlighting, code intelligence), SASPy, python-swat, and all
tooling automatically.

## SASPy / SAS Viya connection setup

1. Copy the connection config template:

   ```bash
   cp config/sascfg_personal.py.example config/sascfg_personal.py
   ```

2. Edit `config/sascfg_personal.py` — choose `iom_workspace` for a
   traditional SAS Workspace Server or `http_viya` for SAS Viya.

3. Copy and populate local environment overrides:

   ```bash
   cp config/.env.example .env
   ```

4. Verify the connection from Python:

   ```python
   from src.python.saspy_session import get_sas_session

   with get_sas_session() as sas:
       print(sas.submit("proc options; run;")["LOG"])
   ```

`config/sascfg_personal.py` and `.authinfo` are gitignored — never commit
credentials.

## Repository layout

| Path | Purpose |
|------|---------|
| `src/sas/` | SAS module programs (one subdirectory per module) |
| `src/macros/` | Shared SAS macros (logging, validation, utilities) |
| `src/python/` | SASPy session helper, SAS Viya REST client, interop entry |
| `pipelines/` | Orchestration entrypoints (batch, Airflow, etc.) |
| `config/` | Connection config templates (`.env.example`, `sascfg_personal.py.example`) |
| `docs/` | Architecture, migration guide, runbook, roadmap, branching strategy |
| `tests/` | Smoke tests for structure and Python interop |
| `scripts/` | SAS static checker and repo guardrail scripts |

## Python interoperability packages

| Package | Purpose |
|---------|---------|
| [`saspy`](https://github.com/sassoftware/saspy) | SAS/Python bridge — IOM (on-prem), HTTP (SAS Viya), COM (Windows) |
| [`python-swat`](https://github.com/sassoftware/python-swat) | SAS Viya CAS (Cloud Analytic Services) — in-memory analytics |
| `pandas` / `numpy` | DataFrame interchange with SASPy |
| `requests` | SAS Viya REST API (Compute Service, Folders, Jobs) |

## Active quality gates

- SAS static checks — required header block, no absolute `libname` paths, no
  risky shell patterns
- Repo guardrails — required docs and folder structure
- Python linting with Ruff
- Markdown linting with markdownlint
- Shell script linting with ShellCheck
- YAML validation with pre-commit

## Module roadmap

1. **Module A** — advanced SAS macro framework and PROC SQL optimization patterns
2. **Module B** — legacy modernization simulation (mainframe-to-SAS handoffs)
3. **Module C** — SAS Viya REST API reporting and SASPy interop expansion

