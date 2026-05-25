#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------
# Full repository fix for titanedge-nexus-platform (macOS-safe)
# ----------------------------------------------------------------------

# Sanity checks
if [ ! -f "README.md" ] || [ ! -f "Makefile" ]; then
    echo "❌ Please run this script from the root of your titanedge-nexus-platform repository."
    exit 1
fi

echo "🔧 Starting full repository fixes (macOS compatible)..."

# Backup everything first
BACKUP_DIR=".backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp README.md Makefile .pre-commit-config.yaml "$BACKUP_DIR/" 2>/dev/null || true
echo "📦 Backups saved to $BACKUP_DIR"

# ----------------------------------------------------------------------
# 1. Fix README title and add badges
# ----------------------------------------------------------------------
echo "📝 Updating README.md ..."
cp README.md README.md.bak
sed -i.bak '1s/.*/# Titanedge Nexus Platform/' README.md
rm README.md.bak 2>/dev/null || true

# Add badges after line 1 using portable method
{
    head -n1 README.md
    echo ""
    echo "[![CI/CD](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/terraform.yml/badge.svg)](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/terraform.yml)"
    echo "[![Security](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/security.yml/badge.svg)](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/security.yml)"
    echo "[![Terraform Version](https://img.shields.io/badge/terraform-%3E%3D%201.5.0-blue)](https://terraform.io)"
    echo "[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)"
    echo ""
    tail -n +2 README.md
} > README.md.tmp && mv README.md.tmp README.md

# Add Quick Start if missing
if ! grep -q "## Quick Start" README.md; then
    printf '\n## Quick Start\n\n```bash\ngit clone https://github.com/ccarrylab/titanedge-nexus-platform.git\ncd titanedge-nexus-platform\nmake init ENV=dev\nmake plan ENV=dev\nmake apply-dev\n```\n' >> README.md
fi

# Add Prerequisites if missing
if ! grep -q "## Prerequisites" README.md; then
    printf '\n## Prerequisites\n\n- **Terraform** ≥ 1.5.0\n- **kubectl** ≥ 1.27\n- **AWS CLI** ≥ 2.13\n- **Go** ≥ 1.21\n- **make**, **pre-commit**, **terraform-docs**, **tflint**, **checkov**\n' >> README.md
fi

# Add Operational Runbook if missing
if ! grep -q "## Operational Runbook" README.md; then
    printf '\n## Operational Runbook\n\n- [Rotate IAM credentials](docs/runbooks/rotate-iam.md)\n- [Handle Terraform state lock](docs/runbooks/state-unlock.md)\n- [Promote release stage → prod](docs/runbooks/promote.md)\n' >> README.md
    mkdir -p docs/runbooks
    echo "# Rotate IAM Credentials" > docs/runbooks/rotate-iam.md
    echo "" >> docs/runbooks/rotate-iam.md
    echo "Placeholder: steps to rotate and update AWS IAM keys." >> docs/runbooks/rotate-iam.md
    echo "# Handle Terraform State Lock" > docs/runbooks/state-unlock.md
    echo "" >> docs/runbooks/state-unlock.md
    echo "Placeholder: commands to force-unlock if needed." >> docs/runbooks/state-unlock.md
    echo "# Promotion Stage → Prod" > docs/runbooks/promote.md
    echo "" >> docs/runbooks/promote.md
    echo "Placeholder: CI steps and approval process." >> docs/runbooks/promote.md
fi

# ----------------------------------------------------------------------
# 2. Create standard documents
# ----------------------------------------------------------------------
echo "📄 Creating CHANGELOG.md, CONTRIBUTING.md, SECURITY.md..."

cat > CHANGELOG.md << 'EOF'
# Changelog
All notable changes to this project will be documented here.

## [Unreleased]
### Added
- Initial platform setup with EKS, Terraform, GitHub Actions
- Pre-commit hooks with Checkov, tfsec, detect-secrets
- Multi‑environment support (dev, stage, prod)
EOF

cat > CONTRIBUTING.md << 'EOF'
# Contributing

## Branch naming
`feature/`, `fix/`, `docs/`, `chore/`

## Pull request process
1. Run `make pre-commit` locally
2. Ensure `make plan ENV=dev` passes
3. Request review from maintainers
EOF

cat > SECURITY.md << 'EOF'
# Security Policy

## Reporting a vulnerability
Please email security@example.com – we will respond within 48 hours.

## Scope
- All Terraform configurations
- Kubernetes manifests
- CI/CD pipelines (GitHub Actions)
- Pre-commit hooks

## Disclosure process
1. Reporter sends details to security@example.com
2. Maintainer acknowledges within 48 hours
3. Fix is prepared and deployed
4. Public disclosure after 30 days
EOF

# ----------------------------------------------------------------------
# 3. Create Architecture Decision Records (ADRs)
# ----------------------------------------------------------------------
echo "📐 Creating ADRs in docs/decisions/ ..."
mkdir -p docs/decisions

cat > docs/decisions/001-choose-eks.md << 'EOF'
# ADR 001: Choose EKS over ECS

## Context
Need a container orchestration platform with rich ecosystem and control plane.

## Decision
Use Amazon EKS. Provides Kubernetes API, broader tooling (Istio, Prometheus), and no vendor lock-in.

## Consequences
Higher operational overhead, but better alignment with platform engineering goals.
EOF

cat > docs/decisions/002-oidc-for-credentials.md << 'EOF'
# ADR 002: Use OIDC Instead of Long‑Lived Credentials

## Context
GitHub Actions need to assume AWS roles to plan/apply Terraform.

## Decision
Use OIDC federation between GitHub and AWS IAM. No static secrets.

## Consequences
Eliminates credential rotation; requires IAM role trust policy configuration.
EOF

# ----------------------------------------------------------------------
# 4. Fix Makefile: remove duplicate lint, add help, add docs target
# ----------------------------------------------------------------------
echo "🔨 Fixing Makefile (duplicate lint + help target) ..."

cp Makefile Makefile.bak
# Remove second 'lint' definition (keep first, but we'll replace all with a consolidated one)
awk '/^lint:/{flag=1} flag && /^[a-zA-Z0-9_-]+:/{flag=0} !flag' Makefile.bak > Makefile.tmp
mv Makefile.tmp Makefile

# Append new consolidated targets
cat << 'EOF' >> Makefile

# Consolidated lint: runs both tflint and pre-commit
lint: tflint pre-commit ## Run all linters (TFLint + pre-commit)

tflint:
	@echo "Running TFLint..."
	cd terraform && tflint --init && tflint -f compact

pre-commit:
	pre-commit run --all-files

docs: ## Generate Terraform module documentation
	@for mod in terraform/modules/*/; do \
		echo "Generating docs for $$mod"; \
		terraform-docs markdown table --output-file README.md $$mod; \
	done

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
EOF

# ----------------------------------------------------------------------
# 5. Enhance .pre-commit-config.yaml
# ----------------------------------------------------------------------
echo "🔒 Upgrading pre-commit config (add Checkov, docs, detect-secrets, hygiene)..."

cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.88.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_checkov
      - id: terraform_docs
EOF

# Create empty secrets baseline
if [ ! -f ".secrets.baseline" ]; then
    echo "{}" > .secrets.baseline
fi

# ----------------------------------------------------------------------
# 6. Run terraform-docs on modules (if installed)
# ----------------------------------------------------------------------
if command -v terraform-docs &> /dev/null; then
    echo "📚 Generating Terraform module READMEs (make docs)..."
    make docs || echo "⚠️ make docs failed – you may have no modules yet."
else
    echo "⚠️ terraform-docs not found. Skipping module doc generation."
    echo "   Install from https://terraform-docs.io or run 'make docs' later."
fi

# ----------------------------------------------------------------------
# 7. Output summary and remaining manual steps
# ----------------------------------------------------------------------
echo ""
echo "✅ All automated fixes applied successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 MANUAL STEPS (cannot be fully automated)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. GitHub repo description & topics (web UI or 'gh repo edit'):"
echo "   Description: 'Multi-environment EKS platform with Terraform, GitOps, and security scanning'"
echo "   Topics: terraform, kubernetes, aws, eks, gitops, platform-engineering, devops, iac"
echo ""
echo "2. Pin GitHub Actions to SHA hashes:"
echo "   - Edit .github/workflows/*.yml"
echo "   - Replace 'uses: actions/checkout@v4' with a full SHA (e.g., actions/checkout@b4ffde65...)"
echo "   - Use https://github.com/actions/checkout/commits/main for the latest SHA"
echo ""
echo "3. Add Trivy scanning:"
echo "   - Create .github/workflows/trivy.yml (see https://aquasecurity.github.io/trivy)"
echo ""
echo "4. Add Infracost for FinOps:"
echo "   - Follow https://www.infracost.io/docs/ci_cd/github_actions"
echo ""
echo "5. Evaluate Atlantis/Digger – document in a comment or ADR"
echo ""
echo "6. Generate SBOM (e.g., with Syft) in CI"
echo ""
echo "7. Review and commit changes:"
echo "   git add . && git commit -m 'Full repository fix based on expert review' && git push"
echo ""
echo "8. If you have Terraform modules, ensure their READMEs are committed (run 'make docs' again later)."
