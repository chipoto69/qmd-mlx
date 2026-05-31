---
source: synthetic
visibility: public-fixture
kind: agent-trace-packet
---

# Synthetic Agent Trace Packet

Task: investigate whether qmd can delegate embeddings and reranking to an OpenAI-compatible MLX server.

Observed behavior:

- Stock qmd uses GGUF models through node-llama-cpp.
- MLX servers expose HTTP endpoints such as `/v1/embeddings` and `/v1/rerank`.
- Provider support requires tests for request shape, response normalization, dimensions, and error handling.

Expected retrieval query:

```text
find the trace where qmd external provider support was investigated
```

Useful exact terms:

```text
QMD_EMBED_MODEL
/v1/embeddings
/v1/rerank
Qwen3-Embedding
Qwen3-Reranker
```
