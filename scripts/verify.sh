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
test -f scripts/benchmark-qmd-pr619-vmlx.sh
test -f scripts/benchmark-qmd-pr619-gguf.sh
test -f docs/benchmarks/qmd-pr619-public-benchmark-2026-05-31.md
test -f patches/vmlx-1.5.49-qwen3-reranker-causal.patch
test -f docs/vmlx-qwen3-rerank-root-cause.md

echo '== bash syntax =='
for f in scripts/*.sh; do
  bash -n "$f"
done

echo '== python syntax =='
python3 -m py_compile scripts/download_mlx_models.py tests/fakes/fake_openai_provider.py

echo '== workflow fixtures =='
test -f tests/fixtures/trace-packets/agent-trace-sample.md

echo 'verification ok'
