# Architecture

The lab uses a lightweight bootstrap architecture:

- SAS modules under `src/sas/` for scenario-specific programs
- shared macros under `src/macros/`
- Python interoperability helpers under `src/python/`
- `pipelines/` for orchestration entrypoints
- GitHub Actions for CI, SAS static analysis, and repo guardrails

This scaffold is intentionally additive and keeps runtime assumptions minimal while module implementations are built out.
