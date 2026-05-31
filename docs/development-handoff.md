# Development Handoff

## Local sandbox paths

```text
repo:          /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx
qmd sandbox:   /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/.sandbox/qmd
model cache:   /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/models/mlx
qmd test home: /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/.qmd-test-home
```

## Branch policy

Use implementation branches in this repo or inside `.sandbox/qmd`:

```bash
git checkout -b feat/openai-mlx-provider
```

Do not open upstream qmd PRs without Rudy explicitly asking.

## Verification commands

```bash
scripts/verify.sh
scripts/clone-qmd-sandbox.sh
scripts/download-mlx-models.sh
QMD_MLX_BASE_URL=http://127.0.0.1:8092/v1 scripts/test-qmd-pr619-vmlx.sh
```

## 2026-05-31 local verification

```text
scripts/verify.sh: pass
vMLX /v1/embeddings with exact local model path: pass, 2 vectors, 1024 dims, norm approx 0.997
vMLX /v1/embeddings with qmd-embed alias: fail, 400 alias rejected
vMLX /v1/rerank with mlx-community/Qwen3-Reranker-0.6B-mxfp8 path: fail, 500 'BaseModelOutput' object has no attribute 'shape'
qmd PR #619 update/embed/vsearch/query --no-rerank: pass against public TRACE_FIXTURE using isolated INDEX_PATH
qmd PR #619 query with rerank: partial; qmd catches the rerank 500 and returns retrieval results with fallback scores
```

Bottom line: the external embedding/vector path works locally. The vMLX rerank path is not usable yet with the tested Qwen3 reranker.

For qmd sandbox work:

```bash
cd .sandbox/qmd
bun install || npm install
git branch --all | grep 'reference/pr-619\|reference/pr-689'
```
