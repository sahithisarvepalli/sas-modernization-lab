# Operations Runbook

## Local bootstrap checks

```bash
make install
make lint
make test
make validate
```

## CI expectations

- `CI` runs lint, tests, and validation
- `SAS Static Checks` scans `.sas` files for risky patterns
- `Repo Guardrails` verifies mandatory structure, docs, and basic secret patterns

## Incident response

If CI fails:
1. Re-run the failing command locally.
2. Fix the specific scaffold or guardrail issue.
3. Update docs if operating steps changed.
