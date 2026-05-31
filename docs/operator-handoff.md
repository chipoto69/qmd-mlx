# Operator Handoff - qmd-mlx

Date: 2026-05-31

## Repo

```text
local:  /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx
remote: https://github.com/chipoto69/qmd-mlx
branch: main
```

This is a dedicated public lab repo. It is not Rudy's production qmd install and it must not mutate `~/.cache/qmd/index.sqlite`.

## What was tested

Test target:

```text
qmd sandbox: .sandbox/qmd
qmd branch:  rudy/mlx-openai-provider
basis:       qmd PR #619, reference/pr-619-openai-compatible at d6c66e9
related:     qmd PR #689, reference/pr-689-openai-provider
server:      vMLX on http://127.0.0.1:8092/v1
fixture:     tests/fixtures/trace-packets/agent-trace-sample.md
index:       .qmd-test-home/pr619-vmlx/index.sqlite
```

Commands run:

```bash
cd /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx
scripts/verify.sh
QMD_MLX_BASE_URL=http://127.0.0.1:8092/v1 scripts/test-qmd-pr619-vmlx.sh
```

Observed result:

```text
scripts/verify.sh: pass
vMLX /v1/embeddings exact local model path: pass, 1024-dim vectors
vMLX /v1/embeddings qmd-embed alias: fail, 400 alias rejected
vMLX /v1/rerank Qwen3 reranker: fail, 500 'BaseModelOutput' object has no attribute 'shape'
qmd update/embed/vsearch/query --no-rerank through PR #619 provider: pass
qmd query with rerank: fail-soft; qmd logs the rerank 500 and returns fallback retrieval scores
```

Bottom line:

```text
The OpenAI-compatible embedding/vector retrieval path works locally.
The rerank path does not work yet with vMLX + mlx-community/Qwen3-Reranker-0.6B-mxfp8.
```

## Reproduce from a fresh checkout

```bash
git clone https://github.com/chipoto69/qmd-mlx.git
cd qmd-mlx

scripts/setup-dev-env.sh
scripts/download-mlx-models.sh
scripts/clone-qmd-sandbox.sh

/Users/rudlord/.local/bin/vmlx serve \
  "$PWD/models/mlx/mlx-community__Qwen3-Embedding-0.6B-4bit-DWQ" \
  --served-model-name qmd-embed \
  --embedding-model "$PWD/models/mlx/mlx-community__Qwen3-Embedding-0.6B-4bit-DWQ" \
  --host 127.0.0.1 \
  --port 8092 \
  --max-tokens 16 \
  --log-level INFO

# New terminal:
QMD_MLX_BASE_URL=http://127.0.0.1:8092/v1 scripts/test-qmd-pr619-vmlx.sh
```

The diagnostic exits 0 for the current partial state because embedding/vector retrieval passes. To make rerank failure fatal:

```bash
REQUIRE_RERANK=1 QMD_MLX_BASE_URL=http://127.0.0.1:8092/v1 scripts/test-qmd-pr619-vmlx.sh
```

## Current server state on Rudy's M4 Max

A vMLX server was restarted after the repo rename and is listening on:

```text
http://127.0.0.1:8092/v1
```

Its model list includes:

```text
qmd-embed
mlx/mlx-community__Qwen3-Embedding-0.6B-4bit-DWQ
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/models/mlx/mlx-community__Qwen3-Embedding-0.6B-4bit-DWQ
```

Do not trust the alias for embeddings yet. Use the exact local path.

## Next PR-safe steps

1. Add provider contract tests around PR #619 behavior using a fake OpenAI-compatible HTTP server.
2. Decide rerank server path:
   - fix/debug vMLX Qwen3 reranker output handling, or
   - test embed-rerank/Jina-compatible rerank server, or
   - keep qmd `--no-rerank` for the first trace-index pilot.
3. Add a tiny benchmark comparing stock GGUF qmd vs MLX-provider qmd on the same public fixture first.
4. Only after private trace evals show improvement, prepare an upstream qmd branch.
5. Do not open an upstream qmd PR unless Rudy explicitly asks for one.

## Verification snapshot

```text
git status: clean, main tracks origin/main
HEAD: 3d42090 before this handoff file; rerun git log for current commit
remote: PUBLIC https://github.com/chipoto69/qmd-mlx
```
