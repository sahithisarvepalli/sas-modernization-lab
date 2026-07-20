# Pull Request

## Summary

## Type of change

- [ ] SAS macro / program addition or update
- [ ] SASPy / Python interop change
- [ ] SAS Viya workflow addition
- [ ] CI / guardrail / tooling change
- [ ] Documentation update

## SAS-specific checklist

- [ ] All new `.sas` files include the required header block (`Purpose:`, `Inputs:`, `Outputs:`, `Usage:`)
- [ ] No hardcoded absolute `libname` paths
- [ ] No risky shell-execution patterns (`x` command, `systask`, `filename pipe`)
- [ ] SASPy / Viya credentials read from environment — no secrets in code

## Validation

- `make lint`:
- `make test`:
- `make validate`:

## CI workflow summary

- CI:
- SAS Static Checks:
- Repo Guardrails:

## Follow-up backlog

- [ ] Module A implementation
- [ ] Module B modernization simulation
- [ ] Module C API reporting expansion
