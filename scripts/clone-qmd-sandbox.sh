#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$ROOT/.sandbox/qmd"
mkdir -p "$ROOT/.sandbox"

if [ ! -d "$SANDBOX/.git" ]; then
  git clone https://github.com/tobi/qmd.git "$SANDBOX"
fi

cd "$SANDBOX"
git fetch origin --prune
# Reference branches. If GitHub removes/renames them, fail loudly.
git fetch origin pull/619/head:reference/pr-619-openai-compatible
git fetch origin pull/689/head:reference/pr-689-openai-provider || true

# Work branch based on PR #619 because that is the closest external-provider prior art.
git checkout -B rudy/mlx-openai-provider reference/pr-619-openai-compatible

echo "qmd sandbox ready: $SANDBOX"
git status -sb
git branch --list 'reference/*' 'rudy/*'
