# Contributing to TitanEdge Nexus

## Development workflow
1. `make test` — must pass before any PR (no credentials needed)
2. `make fmt` — run before committing
3. All new modules must have a `README.md` and at least one `terraform test`

## Branch strategy
- `main` — production-ready, protected
- `fix/*` — bug fixes
- `feat/*` — new features

## Adding a new environment
Copy `terraform/environments/dev`, update `terraform.tfvars`, and add a backend config.
