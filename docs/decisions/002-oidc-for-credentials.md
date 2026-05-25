# ADR 002: Use OIDC Instead of Long‑Lived Credentials

## Context
GitHub Actions need to assume AWS roles to plan/apply Terraform.

## Decision
Use OIDC federation between GitHub and AWS IAM. No static secrets.

## Consequences
Eliminates credential rotation; requires IAM role trust policy configuration.
