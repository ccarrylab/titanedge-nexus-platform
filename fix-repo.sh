#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

echo "Scanning repo: $ROOT"

# Remove generated/local artifacts
find . -type d -name '.terraform' -prune -exec rm -rf {} + 2>/dev/null || true
find . -type f \( \
  -name '*.tfstate' -o \
  -name '*.tfstate.*' -o \
  -name '*.tfplan' -o \
  -name 'crash.log' -o \
  -name '.DS_Store' -o \
  -name '*.swp' -o \
  -name '*~' \
\) -delete 2>/dev/null || true

# Add/refresh repo ignore rules
cat > .gitignore <<'EOF'
.terraform/
**/.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
*.log
.DS_Store
.vscode/
.idea/
*.swp
*~
EOF

# Improve pre-commit coverage if config exists
if [ -f .pre-commit-config.yaml ]; then
  python3 - <<'PY'
from pathlib import Path
p = Path(".pre-commit-config.yaml")
text = p.read_text()
if "antonbabenko/pre-commit-terraform" not in text:
    text += """

  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.100.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: tflint
"""
p.write_text(text)
PY
fi

echo "Done. Review with: git status"
