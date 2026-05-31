# qmd MLX Provider Lab

Isolated public lab for enhancing qmd with an OpenAI-compatible provider path that can use MLX-backed servers for embeddings, reranking, and query expansion.

This repo is deliberately not the production qmd install. It is the clean lane for development, testing, and eventual upstream-ready patches.

## References

- qmd upstream: https://github.com/tobi/qmd
- qmd PR #619 - OpenAI-compatible backend: https://github.com/tobi/qmd/pull/619
- qmd PR #689 - OpenAI embeddings/query-expansion/rerank path: https://github.com/tobi/qmd/pull/689
- vMLX: https://github.com/jjang-ai/vmlx
- oMLX: https://github.com/jundot/omlx
- embed-rerank: https://github.com/joonsoo-me/embed-rerank

## Why

Current qmd is strong, but its shipped backend is GGUF/node-llama-cpp. For Rudy's Apple Silicon trace-search lane, a warm MLX server may be better for:

- persistent model residency
- shared local inference across tools
- faster iteration over embedding/rerank model choices
- clean separation between qmd retrieval logic and model runtime

## First workflow

```text
workflows/qmd-openai-mlx-provider/
```

Goal: create and validate a qmd provider path where:

```text
qmd embedBatch()  -> POST /v1/embeddings
qmd rerank()      -> POST /v1/rerank
qmd expandQuery() -> POST /v1/chat/completions
```

## Quick start

```bash
cd /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx-provider-lab

# Prepare Python tooling and download small MLX models
scripts/setup-dev-env.sh
scripts/download-mlx-models.sh

# Clone upstream qmd into an ignored sandbox and fetch PR references
scripts/clone-qmd-sandbox.sh

# Run repo-level verification
scripts/verify.sh
```

## Default MLX models for the first experiment

Small enough to validate the path before wasting time on giant re-embeds:

```text
Embedding: mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ
Reranker:  mlx-community/Qwen3-Reranker-0.6B-mxfp8
```

Quality-mode candidates after the path works:

```text
Embedding: mlx-community/Qwen3-Embedding-4B-4bit-DWQ
Reranker:  Qwen3-Reranker-4B via an MLX-compatible server, if available and validated
```

## Public repo hygiene

No private traces. No model weights. No qmd indexes. No secrets.

The committed repo contains reproducible scripts and plans only. Generated work lives in ignored folders.
