#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------
# Full repository fix for titanedge-nexus-platform
# Based on expert review feedback
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
    cat << 'EOF' >> README.md

## Quick Start

```bash
git clone https://github.com/ccarrylab/titanedge-nexus-platform.git
cd titanedge-nexus-platform
make init ENV=dev
make plan ENV=dev
make apply-dev
