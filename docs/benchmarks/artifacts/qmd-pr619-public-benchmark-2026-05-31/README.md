# Raw artifacts for qmd PR #619 public benchmark - 2026-05-31

These are the lightweight raw outputs behind `../../qmd-pr619-public-benchmark-2026-05-31.md`.

Scope caveat: this is still the tiny public `eval-docs` fixture. It is useful as a reproducible smoke benchmark, not enough evidence for an upstream PR.

Committed artifacts:

```text
vmlx/endpoint-bench.json       endpoint microbenchmark against http://127.0.0.1:8092/v1
vmlx/qmd-bench-result.txt      raw qmd bench stdout for MLX provider path
vmlx/qmd-bench-summary.json    parsed qmd bench metrics for MLX provider path
vmlx/summary.txt               compact MLX benchmark summary

gguf/qmd-bench-result.txt      raw qmd bench stdout for stock GGUF path
gguf/qmd-bench-summary.json    parsed qmd bench metrics for stock GGUF path
gguf/summary.txt               compact GGUF benchmark summary
```

Not committed:

```text
.qmd-test-home/*/index.sqlite  regenerated local qmd indexes
.tmp/bench-*                   ignored local working copies of the same artifacts
```

SHA-256 manifest:

```text
5a056416a5e409113d5cca119287fd0c3afd6291a2193bc4f420e8f3eb4b1616  vmlx/endpoint-bench.json
5cf67717127342da8548a32c9231ace0a7419dbf20085dbcf61cb40764b83daf  vmlx/qmd-bench-result.txt
459badaf939928937eb1d634699f018c29de811afc2578fff550fa5043a72ed4  vmlx/qmd-bench-summary.json
8311a9298d12c6b5b3b051a3079b79a401f177437bc3f011c3855391cc93dd52  vmlx/summary.txt
c9221e7e7f3566ce076869d2f78349ff10a86c556f856b3359c54d7be069a7d8  gguf/qmd-bench-result.txt
342e4be7e26ec16f677a28443e0e93d5026cad8d49b139dc9168211f2338867b  gguf/qmd-bench-summary.json
5f09726879da96f3df4ac6442d4ba1b53fd4457e4aecd06669c63251b72c37bd  gguf/summary.txt
```
