# Architecture

## Overview

The lab follows a layered architecture that mirrors real SAS production
environments while keeping the open-source toolchain self-contained.

```
┌─────────────────────────────────────────────────────────┐
│                  VS Code Dev Container                   │
│  ┌─────────────┐  ┌───────────────┐  ┌───────────────┐  │
│  │  SAS files  │  │ SASPy (IOM /  │  │  SAS Viya     │  │
│  │  src/sas/   │  │ HTTP bridge)  │  │  python-swat  │  │
│  │  src/macros/│  │               │  │  REST client  │  │
│  └─────────────┘  └───────┬───────┘  └───────┬───────┘  │
└──────────────────────────┬┴──────────────────┴──────────┘
                           │                   │
          ┌────────────────▼──────┐   ┌────────▼──────────┐
          │  SAS Workspace Server  │   │  SAS Viya / CAS   │
          │  (IOM — on-prem/Grid) │   │  (HTTP / REST)    │
          └───────────────────────┘   └───────────────────┘
```

## Connection modes

| Mode | Package | Use case |
|------|---------|---------|
| IOM | `saspy` | Traditional SAS Workspace Server, on-prem or SAS Grid |
| HTTP | `saspy` | SAS Viya Compute Service over HTTPS |
| CAS | `python-swat` | SAS Viya in-memory analytics (Cloud Analytic Services) |
| REST | `requests` | SAS Viya micro-services (Folders, Jobs, Reports) |

Connection profiles are declared in `config/sascfg_personal.py` (gitignored).
See `config/sascfg_personal.py.example` for the full template.

## Source layout

- `src/sas/` — SAS module programs; one subdirectory per module, each with
  a `main.sas` and a required header block
- `src/macros/` — shared SAS macros (logging, dataset validation); included
  by modules via `%include`
- `src/python/` — Python interop layer:
  - `saspy_session.py` — context manager for SASPy sessions
  - `viya_client.py` — SAS Viya REST API client scaffold
  - `interop_entry.py` — status payload entrypoint used by CI smoke tests
- `pipelines/` — orchestration entrypoints (batch submission, Airflow DAGs)
- `config/` — connection config templates; never commit `sascfg_personal.py`

## Quality gates

GitHub Actions enforce three independent workflows on every push and PR:

| Workflow | What it checks |
|----------|---------------|
| `ci.yml` | Python lint (Ruff), tests (pytest), pre-commit hooks |
| `sas-static-checks.yml` | SAS header completeness, absolute `libname` paths, risky shell patterns |
| `repo-guardrails.yml` | Required folder/file structure, secret-pattern scan |

