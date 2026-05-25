#!/bin/bash
set -euo pipefail

echo "🚀 Starting repository improvements..."

# 1. Generate module documentation with terraform-docs (if installed)
if command -v terraform-docs &> /dev/null; then
    echo "📝 Generating module READMEs with terraform-docs..."
    for mod in terraform/modules/*/; do
        if [ -f "${mod}/main.tf" ]; then
            terraform-docs markdown table "$mod" > "${mod}/README.md"
            echo "   Updated ${mod}/README.md"
        fi
    done
else
    echo "⚠️  terraform-docs not installed. Skip module doc generation. Install with: brew install terraform-docs"
fi

# 2. Create CONTRIBUTING.md if it doesn't exist
if [ ! -f CONTRIBUTING.md ]; then
    echo "📝 Creating CONTRIBUTING.md..."
    cat > CONTRIBUTING.md << 'EOF'
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
EOF
else
    echo "✅ CONTRIBUTING.md already exists."
fi

# 3. Enhance Makefile with missing targets (if not already present)
if ! grep -q "test:" Makefile 2>/dev/null; then
    echo "🔧 Adding targets to Makefile..."
    cat >> Makefile << 'EOF'

# ----- Additional targets -----
.PHONY: test docs lint precommit apply-dev destroy-dev

test:
	cd tests && go test -v ./...

docs:
	@for mod in terraform/modules/*/; do \
		if [ -f "$${mod}/main.tf" ]; then \
			terraform-docs markdown table "$${mod}" > "$${mod}/README.md"; \
			echo "Updated $${mod}/README.md"; \
		fi \
	done

lint: precommit

precommit:
	pre-commit run --all-files

apply-dev:
	cd terraform/environments/dev && terraform apply -auto-approve

destroy-dev:
	cd terraform/environments/dev && terraform destroy -auto-approve
EOF
else
    echo "✅ Makefile already contains additional targets."
fi

# 4. Create .tflint.hcl with AWS plugin (if missing)
if [ ! -f .tflint.hcl ]; then
    echo "⚙️  Creating .tflint.hcl..."
    cat > .tflint.hcl << 'EOF'
plugin "aws" {
    enabled = true
    version = "0.25.0"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
EOF
else
    echo "✅ .tflint.hcl already exists."
fi

# 5. Create SECURITY.md (if missing)
if [ ! -f SECURITY.md ]; then
    echo "🔒 Creating SECURITY.md..."
    cat > SECURITY.md << 'EOF'
# Security Policy

## Reporting a Vulnerability

We take security seriously. If you discover a security issue, please **do not** open a public issue.

Email the maintainers at: [your-email@example.com] (replace with real address)

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact

We will respond within 48 hours and coordinate a fix.

## Security Best Practices in This Repo

- No hardcoded secrets or account IDs.
- Backend configuration via gitignored files or GitHub Secrets.
- Terraform state encrypted in S3.
- Pre-commit hooks run tflint + tfsec.
- (Add more as appropriate)
EOF
else
    echo "✅ SECURITY.md already exists."
fi

# 6. Run pre-commit to verify everything
echo "🧹 Running pre-commit hooks..."
pre-commit run --all-files || {
    echo "⚠️  Some pre-commit hooks failed. Fix issues manually and re-run."
    exit 1
}

echo "🎉 All improvements applied successfully!"
echo "Next: commit the changes with: git add . && git commit -m 'docs: add CONTRIBUTING, SECURITY, tflint config, enhance Makefile'"
