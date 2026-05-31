#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo '== git root =='
git rev-parse --show-toplevel

echo '== required files =='
test -f agent.md
test -f AGENTS.md
test -f .gitignore
test -f README.md
test -f workflows/qmd-openai-mlx-provider/plan.md
test -f tests/fakes/fake_openai_provider.py
test -f scripts/test-qmd-pr619-fake-openai.sh

echo '== bash syntax =='
for f in scripts/*.sh; do
  bash -n "$f"
done

echo '== python syntax =='
python3 -m py_compile scripts/download_mlx_models.py tests/fakes/fake_openai_provider.py

echo '== workflow fixtures =='
test -f tests/fixtures/trace-packets/agent-trace-sample.md

echo 'verification ok'
