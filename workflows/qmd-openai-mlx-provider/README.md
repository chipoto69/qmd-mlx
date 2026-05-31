# qmd OpenAI-Compatible MLX Provider Workflow

## Objective

Build a qmd development sandbox that can validate an external provider backend against MLX servers.

The first provider target is OpenAI-compatible HTTP because oMLX, vMLX, vllm-mlx, and embed-rerank all expose some combination of:

```text
/v1/embeddings
/v1/rerank
/v1/chat/completions
```

## Current stance

Use qmd PR #619 as the primary reference implementation. Do not blindly copy it. Treat it as architecture prior art and test-contract inspiration.

## Workflow shape

```text
1. Clone upstream qmd into .sandbox/qmd
2. Fetch PR #619 and PR #689 as local reference branches
3. Download small MLX embedding/rerank models into models/mlx
4. Smoke-test an MLX HTTP server endpoint
5. Add provider-contract tests against a fake OpenAI-compatible server
6. Implement qmd provider adapter in the sandbox branch
7. Run qmd tests and trace-packet retrieval smoke tests
8. Only then consider an upstream-ready patch
```

## Acceptance criteria

- A clean checkout can run `scripts/verify.sh`.
- qmd upstream sandbox can be recreated with `scripts/clone-qmd-sandbox.sh`.
- MLX models can be downloaded with `scripts/download-mlx-models.sh`.
- No generated model/index data is committed.
- Provider contract tests prove embeddings/rerank/chat request and response normalization.
- A tiny trace-packet collection can be embedded and queried without touching Rudy's production qmd index.

## Public PR rule

A branch in Rudy's repo is fine. An upstream qmd PR is not allowed unless Rudy explicitly asks for one.
