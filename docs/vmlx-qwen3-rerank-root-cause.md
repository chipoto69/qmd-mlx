# vMLX Qwen3-Reranker root cause

Date: 2026-05-31

## Verdict

The right rerank lane is to patch vMLX's Qwen3-Reranker handling, not to swap qmd or abandon rerank.

The failure was not qmd PR #619. qmd sent the expected OpenAI-compatible `/v1/rerank` request shape. vMLX 1.5.49 loaded the Qwen3 reranker through the wrong backend and then returned scores in the wrong range after the first fix.

## Original symptom

```text
POST /v1/rerank -> 500
'BaseModelOutput' object has no attribute 'shape'
```

This made qmd log `OpenAI-compatible request failed (500 Internal Server Error)` and fall back or return partial results.

## Root cause

File in the local vMLX install:

```text
/Users/rudlord/.local/share/uv/tools/vmlx/lib/python3.13/site-packages/vmlx_engine/reranker.py
```

Relevant version:

```text
vmlx 1.5.49
mlx-lm 0.31.3
mlx-embeddings 0.1.0
```

The Qwen reranker config says:

```json
"architectures": ["Qwen3ForCausalLM"]
```

vMLX's `Reranker._load()` tried `mlx_embeddings.load()` before `mlx_lm.load()`. `mlx_embeddings.load()` accepts this model path, so vMLX classified it as an `encoder` reranker.

That encoder object returns:

```text
mlx_embeddings.models.base.BaseModelOutput
attrs: last_hidden_state, hidden_states
no logits
no shape
```

Then `_score_encoder()` falls through to `logits = output` and tries `logits.shape`, causing:

```text
'BaseModelOutput' object has no attribute 'shape'
```

There was a second bug after forcing the causal path: `_score_causal()` unwrapped `mlx_lm.tokenizer_utils.TokenizerWrapper` to the raw Hugging Face tokenizer. The wrapper's `apply_chat_template()` returns a plain token-id list, but the raw HF tokenizer returns `BatchEncoding`, which `mlx.core.array()` rejects.

There was a third integration bug: the Qwen causal scorer returned raw yes-minus-no logit margins. qmd expects rerank scores to behave like Cohere/Jina `relevance_score` values, i.e. bounded 0..1. Negative margins made qmd's blended score filter drop the result in some cases. Converting the margin through sigmoid fixed it.

## Local patch applied

A backup was saved before touching site-packages:

```text
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/.tmp/backups/vmlx-1.5.49/reranker.py.pre-qwen3-causal-fix
```

Versioned patch:

```text
patches/vmlx-1.5.49-qwen3-reranker-causal.patch
```

The patch does three things:

1. Detects causal rerankers by local model config: architecture ends with `ForCausalLM` and model path contains `reranker`.
2. Routes those models through `mlx_lm.load()` before trying `mlx_embeddings.load()`.
3. Keeps the `mlx_lm` tokenizer wrapper for `apply_chat_template()` and normalizes yes/no logit difference with sigmoid before returning `relevance_score`.

## Measured after patch

Direct local class check:

```text
backend causal
0 0.418697
1 0.148047
RESULT=PASS local vMLX Reranker causal sigmoid path
```

Live vMLX endpoint check:

```text
POST /v1/rerank -> 200
results:
  index 0 relevance_score 0.4186969093556867
  index 1 relevance_score 0.14804719803168948
RESULT=PASS /v1/rerank bounded scores after local vMLX patch
```

qmd PR #619 live MLX diagnostic:

```text
REQUIRE_RERANK=1 QMD_MLX_BASE_URL=http://127.0.0.1:8092/v1 scripts/test-qmd-pr619-vmlx.sh
RESULT=PASS: qmd OpenAI-compatible MLX provider path passed including rerank.
```

The qmd rerank query returned the fixture:

```text
qmd://TRACE_FIXTURE/agent-trace-sample.md
score: 0.76
```

## Remaining caveat

vMLX still advertises `qmd-embed` in `/v1/models`, but `/v1/embeddings` rejects that alias. qmd must keep using the exact local embedding model path until alias handling is fixed.

## Next lane

Make this vMLX patch upstream-ready or carry it as a local patch in the qmd-mlx lab. This is smaller and cleaner than replacing the rerank server.

Fallback order if the patch cannot be upstreamed:

1. Carry local vMLX patch with a checksum and a reapply script.
2. Test an embed-rerank/Jina-compatible rerank server.
3. Run the first private trace pilot with `--no-rerank` only if rerank blocks ingestion throughput.
