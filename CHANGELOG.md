# Changelog
All notable changes to this project will be documented here.

## [Unreleased]
### Added
- Initial platform setup with EKS, Terraform, GitHub Actions
- Pre-commit hooks with Checkov, tfsec, detect-secrets
- Multi‑environment support (dev, stage, prod)

## [1.1.0] - 2026-06-12
### Added
- Three-layer test suite: static (Go), unit (terraform test + mock_provider), integration (Terratest)
- GitHub Actions CI pipeline with OIDC authentication — no static AWS keys
- KMS envelope encryption for EKS secrets with automatic key rotation
- RDS password auto-generated via random_password, stored in Secrets Manager
- CloudWatch log groups, CPU alarm, and platform dashboard
- Dependabot for GitHub Actions version tracking

### Fixed
- Hardcoded database master password replaced with Secrets Manager-backed random password
- Security group now explicitly bound to platform VPC (was defaulting to account default VPC)
- RDS now enforces storage encryption, backup retention, and subnet placement
- Stray tfplan artifact removed from working tree; .gitignore updated to cover all plan/state artifacts

### Security
- EKS secrets encrypted at rest with rotating KMS key
- GitHub Actions uses short-lived OIDC credentials
- RDS and Redis isolated in private subnets, no public access
