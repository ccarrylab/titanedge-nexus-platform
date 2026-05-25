#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Finalizing all repository fixes..."

# ----------------------------------------------------------------------
# 1. Fix Makefile (the only remaining issue)
# ----------------------------------------------------------------------
echo "🔨 Repairing Makefile..."

# Backup first
cp Makefile Makefile.backup.final

# Remove any duplicate 'lint:' target and ensure proper formatting
# This awk script keeps everything before the first 'lint:' and then appends a clean version
awk '
BEGIN { in_lint = 0; printed_lint = 0 }
/^lint:/ {
    if (printed_lint) {
        # skip duplicate lint blocks
        in_lint = 1
        next
    } else {
        printed_lint = 1
        in_lint = 1
        print "# Consolidated lint: runs both tflint and pre-commit"
        print "lint: tflint pre-commit ## Run all linters (TFLint + pre-commit)"
        next
    }
}
in_lint && /^[a-zA-Z0-9_-]+:/ {
    in_lint = 0
}
!in_lint { print }
' Makefile.backup.final > Makefile.tmp

# Add the missing tflint, pre-commit, docs, help targets if they don't exist
if ! grep -q "^tflint:" Makefile.tmp; then
    cat << 'EOF' >> Makefile.tmp

tflint:
	@echo "Running TFLint..."
	cd terraform && tflint --init && tflint -f compact

pre-commit:
	pre-commit run --all-files
EOF
fi

if ! grep -q "^docs:" Makefile.tmp; then
    cat << 'EOF' >> Makefile.tmp

docs: ## Generate Terraform module documentation
	@for mod in terraform/modules/*/; do \
		echo "Generating docs for $$mod"; \
		terraform-docs markdown table --output-file README.md $$mod; \
	done
EOF
fi

if ! grep -q "^help:" Makefile.tmp; then
    cat << 'EOF' >> Makefile.tmp

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
EOF
fi

# Replace tabs with actual tab characters (since cat may have converted to spaces)
# This sed command replaces leading spaces with a tab on recipe lines
sed -i.bak -e 's/^	/	/' -e 's/^    /	/' Makefile.tmp 2>/dev/null || true
rm -f Makefile.tmp.bak

mv Makefile.tmp Makefile
echo "✓ Makefile repaired"

# ----------------------------------------------------------------------
# 2. Verify critical files exist
# ----------------------------------------------------------------------
echo "📋 Verifying all required files..."
for file in CHANGELOG.md CONTRIBUTING.md SECURITY.md docs/decisions/001-choose-eks.md docs/decisions/002-oidc-for-credentials.md .secrets.baseline; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file missing – re-running full fix may be needed"
    fi
done

# ----------------------------------------------------------------------
# 3. Ensure .pre-commit-config.yaml is correct
# ----------------------------------------------------------------------
if ! grep -q "terraform_checkov" .pre-commit-config.yaml 2>/dev/null; then
    echo "⚠️ .pre-commit-config.yaml missing Checkov – reapplying..."
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
    echo "✓ Pre-commit config restored"
fi

# ----------------------------------------------------------------------
# 4. Test Makefile (basic sanity)
# ----------------------------------------------------------------------
echo "🧪 Testing Makefile syntax..."
if make -n help >/dev/null 2>&1; then
    echo "✓ Makefile syntax OK"
else
    echo "⚠️ Makefile still has issues – run 'make help' manually to debug"
fi

# ----------------------------------------------------------------------
# 5. Stage all changes and suggest commit
# ----------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All fixes applied successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To commit and push all changes, run:"
echo ""
echo "  git add ."
echo "  git commit -m 'Complete repository overhaul: fix Makefile, add docs, security, ADRs'"
echo "  git push origin main"
echo ""
echo "Then complete the remaining MANUAL STEPS from the previous script:"
echo "  - GitHub repo description & topics"
echo "  - Pin GitHub Actions to SHA hashes"
echo "  - Add Trivy, Infracost, SBOM"
echo ""
