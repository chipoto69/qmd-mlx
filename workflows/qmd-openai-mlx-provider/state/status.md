# Status

## 2026-05-30

Bootstrapped isolated qmd MLX provider lab.

Known facts:

- Rudy's active qmd install is 2.1.0 via `/Users/rudlord/.bun/bin/qmd`.
- Current upstream qmd has open external-provider work, especially PR #619.
- vMLX/oMLX can expose `/v1/embeddings` and `/v1/rerank`.
- Current qmd config/env alone cannot use vMLX/oMLX. It needs provider code.

Next checkpoint:

- Recreate qmd sandbox.
- Fetch PR #619 and PR #689.
- Download small MLX models.
- Run endpoint smoke tests against an MLX server.

## 2026-05-31

Local diagnostic completed against qmd PR #619 and vMLX.

What passed:

- qmd sandbox is on `rudy/mlx-openai-provider` at PR #619 commit `d6c66e9`.
- PR refs are present locally: `reference/pr-619-openai-compatible`, `reference/pr-689-openai-provider`.
- Repo verification passed: `scripts/verify.sh`.
- vMLX `/v1/embeddings` works when qmd sends the exact local embedding-model path.
- qmd `update`, `embed`, `vsearch`, and structured `query --no-rerank` work against the public `TRACE_FIXTURE` collection with isolated `INDEX_PATH`.

What failed:

- vMLX advertises `qmd-embed` from `/v1/models`, but `/v1/embeddings` rejects `model=qmd-embed`. qmd must use the exact local embedding-model path unless vMLX alias handling is fixed.
- vMLX `/v1/rerank` fails with the tested Qwen3 reranker: `500 'BaseModelOutput' object has no attribute 'shape'`.
- qmd full `query` with rerank reaches `/v1/rerank`, gets the same vMLX 500, then falls back to retrieval scores instead of crashing.

Current verdict:

```text
provider contract path: works against deterministic fake OpenAI-compatible server
embedding/vector/rerank path: works against live vMLX after local vMLX 1.5.49 Qwen3 reranker patch
rerank root cause: vMLX misclassified Qwen3ForCausalLM reranker as encoder through mlx_embeddings, then returned raw causal logit margins instead of bounded relevance scores
upstream PR readiness: not yet; vMLX patch needs upstream-ready packaging or reapply automation, alias handling and benchmark still needed
```

Additional 2026-05-31 checkpoint:

- Added `tests/fakes/fake_openai_provider.py`, a dependency-free fake OpenAI-compatible server.
- Added `scripts/test-qmd-pr619-fake-openai.sh` to verify qmd PR #619 hits `/v1/models`, `/v1/embeddings`, `/v1/rerank`, and `/v1/chat/completions` with expected model IDs.
- The fake-provider test verifies `Authorization` forwarding, qmd embedding/vector/rerank/query-expansion behavior, fixture retrieval, and isolated SQLite index writes.
- Measured fake-provider request counts: `/v1/chat/completions`: 2, `/v1/embeddings`: 6, `/v1/models`: 2, `/v1/rerank`: 2.

Rerank root-cause checkpoint:

- Backed up local vMLX 1.5.49 `vmlx_engine/reranker.py` before patching.
- Captured the local fix as `patches/vmlx-1.5.49-qwen3-reranker-causal.patch`.
- Added `docs/vmlx-qwen3-rerank-root-cause.md` with the causal chain and verification output.
- Verified direct local vMLX reranker path: backend `causal`, bounded scores `0.418697` vs `0.148047` for relevant vs irrelevant docs.
- Verified live `/v1/rerank`: HTTP 200 with bounded `relevance_score` values.
- Verified qmd PR #619 live path with `REQUIRE_RERANK=1`: `RESULT=PASS: qmd OpenAI-compatible MLX provider path passed including rerank` and returned `qmd://TRACE_FIXTURE/agent-trace-sample.md` with score `0.76`.

Public benchmark checkpoint:

- Added `scripts/benchmark-qmd-pr619-vmlx.sh` and `scripts/benchmark-qmd-pr619-gguf.sh`.
- Saved committed benchmark summary at `docs/benchmarks/qmd-pr619-public-benchmark-2026-05-31.md`.
- vMLX endpoint microbench: embeddings mean 12.77 ms / p95 38.67 ms; rerank mean 166.79 ms / p95 373.68 ms.
- qmd bench on tiny public `eval-docs` fixture: MLX full pipeline P@k/Recall/MRR/F1 all 1.000, avg 3049 ms; stock GGUF full pipeline P@k/Recall/MRR/F1 all 1.000, avg 6651 ms.
- This is smoke evidence only. Next quality gate is private 30-50 trace-query eval with recall@20, MRR/nDCG, and citation quality.
