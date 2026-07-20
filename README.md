# SAS Modernization Lab

A portfolio repository for advanced SAS programming, modernization patterns,
and SAS + Python interoperability for insurance and finance workflows.

## What this bootstrap adds

This branch bootstraps the repository so pull requests immediately run CI
checks, validate SAS guardrails, and open cleanly in a VS Code dev container.

### Reused from `insurance-analytics-project`

- `pyproject.toml` + `requirements.txt` dual dependency strategy
- Makefile-driven developer workflow (`make lint`, `make test`,
  `make validate`)
- Devcontainer bootstrap pattern with Dockerfile + `setup.sh`
- GitHub Actions convention to install Python dependencies then run Make
  targets
- VS Code Python/Ruff/Markdown/YAML editor defaults

### Adapted for SAS modernization lab

- SAS-specific repository layout under `src/sas`, `src/macros`, and
  `pipelines`
- SAS static checks for headers, risky shell execution, and absolute
  `libname` paths
- Repo guardrails for required docs/folders and secret-pattern scanning
- Minimal Python interoperability entrypoint and scaffold tests

## Quick start

```bash
make install
make lint
make test
make validate
```

## Repository layout

- `src/sas/` — SAS module scaffolds
- `src/macros/` — shared SAS macros
- `src/python/` — Python interop helpers
- `pipelines/` — orchestration placeholders
- `docs/` — architecture, migration, runbook, roadmap, branching guidance
- `config/` — local configuration examples
- `tests/` — bootstrap smoke tests

## Active quality gates

- Python linting with Ruff
- Markdown linting with markdownlint
- YAML validation with pre-commit
- Shell script linting with ShellCheck
- SAS static checks for headers and risky patterns
- Repo guardrails for required docs and folders

## Next implementation areas

1. Module A — advanced SAS macro + PROC SQL patterns
2. Module B — legacy modernization simulation workflows
3. Module C — API reporting and SAS/Python interop expansion
