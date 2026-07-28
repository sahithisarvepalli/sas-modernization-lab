#!/bin/bash
set -euo pipefail

export PYTHONPATH="${PYTHONPATH:-/workspaces/sas-modernization-lab}"

echo "=================================================="
echo "🚀 SAS Modernization Lab - Dev Container Setup"
echo "=================================================="

echo "🔧 Cleaning up git configuration..."
for _gcfg in "${HOME:-/root}/.gitconfig" /home/vscode/.gitconfig; do
    if [ -f "$_gcfg" ]; then
        rm -rf "$_gcfg"
        touch "$_gcfg"
    fi
done
unset _gcfg
git config --global --add safe.directory /workspaces/sas-modernization-lab || true

echo "📦 Installing Python dependencies..."
python -m pip install --upgrade pip setuptools wheel >/dev/null
python -m pip install -r requirements.txt
python -m pip install -e .[dev]

echo "🔗 Installing pre-commit hooks..."
pre-commit install --install-hooks || echo "⚠️  Pre-commit hook installation skipped"

echo "✅ Dev container setup complete"
