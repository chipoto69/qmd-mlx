#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -x .venv/bin/python ]; then
  scripts/setup-dev-env.sh
fi

.venv/bin/python scripts/download_mlx_models.py "$@"
