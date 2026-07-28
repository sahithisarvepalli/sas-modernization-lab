# Branching Strategy

- `main` remains the protected integration branch.
- Create short-lived feature branches for bootstrap and module work.
- Keep changes additive and validate with `make lint`, `make test`, and
  `make validate` before opening a PR.
- Capture replication vs adaptation notes in every bootstrap-related PR.
