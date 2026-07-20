# Migration Guide

## Legacy SAS to modernized workflow

1. Isolate reusable logic into macros under `src/macros/`.
2. Separate module-specific programs under `src/sas/module_*`.
3. Externalize environment and path assumptions into `config/`.
4. Add Python interoperability only at defined handoff points.
5. Validate code through SAS static checks and repository guardrails before PR submission.
