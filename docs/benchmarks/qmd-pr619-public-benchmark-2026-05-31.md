# qmd PR #619 public benchmark - 2026-05-31

Measured on Rudy's M4 Max against the public qmd `eval-docs` fixture only. This is a tiny smoke/eval harness, not a final quality verdict for Rudy's private trace corpus.

## Scope

```text
repo:          /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx
qmd sandbox:   .sandbox/qmd
qmd branch:    rudy/mlx-openai-provider
fixture:       .sandbox/qmd/src/bench/fixtures/example.json
corpus:        .sandbox/qmd/test/eval-docs/*.md
queries:       10
indexed docs:  6
chunks:        9
```

## Commands

```bash
cd /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx

# Live vMLX benchmark. Requires vMLX on 127.0.0.1:8092 and the local Qwen3 reranker patch.
QMD_MLX_BASE_URL=http://127.0.0.1:8092/v1 scripts/benchmark-qmd-pr619-vmlx.sh

# Stock qmd GGUF baseline, isolated index, normal qmd model cache.
scripts/benchmark-qmd-pr619-gguf.sh
```

## Benchmark sinks

Ignored local artifacts:

```text
MLX logs:       .tmp/bench-pr619-vmlx/
MLX index:      .qmd-test-home/pr619-vmlx-bench/index.sqlite
GGUF logs:      .tmp/bench-pr619-gguf/
GGUF index:     .qmd-test-home/pr619-gguf-bench/index.sqlite
```

Committed summary:

```text
docs/benchmarks/qmd-pr619-public-benchmark-2026-05-31.md
```

## vMLX endpoint microbench

Runtime: `http://127.0.0.1:8092/v1`

Embedding model:

```text
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/models/mlx/mlx-community__Qwen3-Embedding-0.6B-4bit-DWQ
```

Rerank model:

```text
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/models/mlx/mlx-community__Qwen3-Reranker-0.6B-mxfp8
```

| endpoint | result | mean ms | p50 ms | p95 ms | n |
| --- | --- | ---: | ---: | ---: | ---: |
| `/v1/embeddings` | 1024-dim vectors, first-vector norm 0.999567 | 12.77 | 9.00 | 38.67 | 10 |
| `/v1/rerank` | relevant doc ranked first, bounded scores | 166.79 | 151.14 | 373.68 | 10 |
| `/v1/chat/completions` | smoke only through `qmd-embed` alias | 425.83 | 278.01 | 752.04 | 3 |

Note: chat completion here is only a provider-path smoke test. The loaded vMLX server is an embedding/rerank lane, not a serious generation benchmark.

## qmd bench summary

Same fixture, same qmd PR #619 provider branch, isolated indexes.

| backend | MLX P@k | MLX Recall | MLX MRR | MLX F1 | MLX avg ms | GGUF P@k | GGUF Recall | GGUF MRR | GGUF F1 | GGUF avg ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| bm25 | 0.500 | 0.500 | 0.500 | 0.500 | 1 | 0.500 | 0.500 | 0.500 | 0.500 | 2 |
| vector | 1.000 | 1.000 | 1.000 | 1.000 | 43 | 0.900 | 1.000 | 0.867 | 0.900 | 260 |
| hybrid | 1.000 | 1.000 | 1.000 | 1.000 | 7289 | 1.000 | 1.000 | 1.000 | 1.000 | 10787 |
| full | 1.000 | 1.000 | 1.000 | 1.000 | 3049 | 1.000 | 1.000 | 1.000 | 1.000 | 6651 |

## Readout

- MLX vector search beat stock GGUF on this tiny public fixture: perfect top-k metrics and about 6x lower average latency.
- Full qmd pipeline with rerank was about 2.2x faster on MLX than stock GGUF in this run: 3049 ms vs 6651 ms average.
- Hybrid without rerank is still slow because query expansion dominates. This lane needs deeper profiling before declaring a runtime winner.
- The public fixture is too small and too clean. The next useful eval is a private 30-50 trace-query set with recall@20, MRR/nDCG, and citation quality.

## Raw local artifacts from the measured run

```text
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/.tmp/bench-pr619-vmlx/endpoint-bench.json
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/.tmp/bench-pr619-vmlx/qmd-bench-result.txt
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/.tmp/bench-pr619-vmlx/qmd-bench-summary.json
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/.tmp/bench-pr619-vmlx/summary.txt
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/.tmp/bench-pr619-gguf/qmd-bench-result.txt
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/.tmp/bench-pr619-gguf/qmd-bench-summary.json
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/.tmp/bench-pr619-gguf/summary.txt
```
