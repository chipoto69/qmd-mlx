# Plan - qmd OpenAI-Compatible MLX Provider

## Phase 0 - Sandbox and references

- [x] Dedicated repo with charter and ignores
- [x] Scripts for qmd sandbox clone and PR reference fetch
- [x] Scripts for MLX model download
- [x] Confirm qmd sandbox dependency install
- [x] Capture PR #619 diff notes into implementation checklist

## Phase 1 - Provider contract tests

Write tests before provider code.

Target behaviors:

- [ ] embedBatch sends `POST /v1/embeddings` with `{ model, input: [...] }`
- [ ] embedBatch normalizes OpenAI embedding responses into qmd vector arrays
- [ ] rerank sends `POST /v1/rerank` with `{ model, query, documents, top_n }`
- [ ] rerank normalizes Cohere/Jina-style `{ index, relevance_score }` responses
- [ ] expandQuery sends `POST /v1/chat/completions`
- [ ] provider errors include endpoint/model context but never secrets
- [ ] embedding fingerprint includes provider, base URL identity, model, dimension, and prompt format

## Phase 2 - Minimal provider adapter

- [ ] Introduce provider config/env parsing
- [ ] Add OpenAI-compatible provider implementation
- [ ] Preserve current llama.cpp/GGUF default path
- [ ] Add qmd CLI/status visibility for selected provider
- [ ] Keep chunking conservative until tokenizer semantics are solved

## Phase 3 - MLX server validation

- [x] Smoke-test oMLX or vMLX embeddings endpoint
- [x] Smoke-test rerank endpoint
- [x] Run qmd embed/query against tiny public fixtures
- [x] Compare current GGUF qmd vs MLX server on latency and ranking quality

Phase 3 note, 2026-05-31: embeddings, rerank, qmd vector retrieval, and qmd full query now pass against live vMLX after applying `patches/vmlx-1.5.49-qwen3-reranker-causal.patch`. The tiny public benchmark is saved in `docs/benchmarks/qmd-pr619-public-benchmark-2026-05-31.md`; MLX full pipeline averaged 3049 ms vs stock GGUF 6651 ms on the same fixture. Treat this as smoke evidence only; private trace evals are still required.

## Phase 4 - Trace eval harness

- [ ] Create private local eval set outside this public repo
- [ ] Run 30-50 real trace-query cases
- [ ] Measure recall@20, MRR/nDCG after rerank, and answer citation quality
- [ ] Decide whether MLX is better than GGUF for Rudy's real corpus

## Hard constraints

- No production qmd index mutation.
- No raw private traces in public repo.
- No upstream PR without explicit instruction.
