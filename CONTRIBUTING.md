# Contributing

## Workflow

1. Create a feature branch from `main`.
2. Run `make lint`, `make test`, and `make validate` before opening a PR.
3. Update docs when behavior or operating steps change.
4. Keep SAS examples free of secrets and absolute local paths.

## Development environment

- Preferred setup: open the repository in the included dev container.
- Install hooks with `pre-commit install --install-hooks` if you are not using the dev container.

## Pull requests

Use the PR template and capture:
- what was replicated from the reference repo
- what was adapted for SAS modernization lab
- command results for lint/test/validate
- follow-up backlog items
