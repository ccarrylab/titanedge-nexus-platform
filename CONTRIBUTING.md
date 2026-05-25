# Contributing to TitanEdge Nexus Platform

We love your input! Please follow these guidelines.

## Getting Started
- Fork the repo and create a branch from `main`.
- Install pre-commit hooks: `pre-commit install`
- Run `make precommit` before committing.

## Code Style
- Terraform: `terraform fmt -recursive`
- Go tests: `go fmt ./tests/...`
- Commit messages: Conventional Commits (feat:, fix:, docs:, etc.)

## Pull Request Process
1. Update documentation (module READMEs, `docs/` folder) if needed.
2. Ensure all tests pass: `make test`
3. Request review from at least one maintainer.

## Adding a New Module
- Place under `terraform/modules/`
- Include `variables.tf`, `outputs.tf`, and generate `README.md` with `terraform-docs`.
- Use the module in `terraform/environments/dev` first.

## Security
- Never commit secrets, account IDs, or bucket names.
- Report vulnerabilities via email (see SECURITY.md).

Thank you!
