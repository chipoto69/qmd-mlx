#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

uv venv .venv --python python3
uv pip install --python .venv/bin/python   huggingface_hub   httpx   pytest   fastapi   uvicorn

cat <<MSG
Dev Python environment ready:
  $ROOT/.venv

Activate with:
  source .venv/bin/activate
MSG
