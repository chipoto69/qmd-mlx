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
embedding/vector path: works against live vMLX when qmd uses exact local embedding model path
rerank path: blocked by vMLX/Qwen3 reranker compatibility
upstream PR readiness: not yet; contract test exists, rerank-server decision and benchmark still needed
```

Additional 2026-05-31 checkpoint:

- Added `tests/fakes/fake_openai_provider.py`, a dependency-free fake OpenAI-compatible server.
- Added `scripts/test-qmd-pr619-fake-openai.sh` to verify qmd PR #619 hits `/v1/models`, `/v1/embeddings`, `/v1/rerank`, and `/v1/chat/completions` with expected model IDs.
- The fake-provider test verifies `Authorization` forwarding, qmd embedding/vector/rerank/query-expansion behavior, fixture retrieval, and isolated SQLite index writes.
- Measured fake-provider request counts: `/v1/chat/completions`: 2, `/v1/embeddings`: 6, `/v1/models`: 2, `/v1/rerank`: 2.
