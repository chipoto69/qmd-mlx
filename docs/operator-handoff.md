# Operator Handoff - qmd-mlx

Date: 2026-05-31

## Repo

```text
local:  /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx
remote: https://github.com/chipoto69/qmd-mlx
branch: main
```

This is a dedicated public lab repo. It is not Rudy's production qmd install and it must not mutate `~/.cache/qmd/index.sqlite`.

## What was tested

Test target:

```text
qmd sandbox: .sandbox/qmd
qmd branch:  rudy/mlx-openai-provider
basis:       qmd PR #619, reference/pr-619-openai-compatible at d6c66e9
related:     qmd PR #689, reference/pr-689-openai-provider
server:      fake provider on http://127.0.0.1:18092/v1 for deterministic contract tests
server:      vMLX on http://127.0.0.1:8092/v1 for live MLX runtime tests
fixture:     tests/fixtures/trace-packets/agent-trace-sample.md
indexes:     .qmd-test-home/pr619-fake-openai/index.sqlite and .qmd-test-home/pr619-vmlx/index.sqlite
```

Commands run:

```bash
cd /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx
scripts/verify.sh
scripts/test-qmd-pr619-fake-openai.sh
QMD_MLX_BASE_URL=http://127.0.0.1:8092/v1 scripts/test-qmd-pr619-vmlx.sh
```

Observed result:

```text
scripts/verify.sh: pass
fake provider contract: pass; qmd hit /v1/models, /v1/embeddings, /v1/rerank, and /v1/chat/completions; Authorization forwarding verified; isolated index writes verified
vMLX /v1/embeddings exact local model path: pass, 1024-dim vectors
vMLX /v1/embeddings qmd-embed alias: fail, 400 alias rejected
vMLX /v1/rerank Qwen3 reranker: pass after local vMLX 1.5.49 patch; endpoint returns bounded relevance_score values
qmd update/embed/vsearch/query/rerank through PR #619 provider: pass with REQUIRE_RERANK=1
```

Bottom line:

```text
The PR #619 OpenAI-compatible provider contract works against a deterministic fake server.
The live MLX embedding/vector/rerank path works locally after applying the vMLX 1.5.49 Qwen3 reranker patch.
The remaining live runtime caveat is vMLX embedding alias rejection for `qmd-embed`.
```

## Reproduce from a fresh checkout

```bash
git clone https://github.com/chipoto69/qmd-mlx.git
cd qmd-mlx

scripts/setup-dev-env.sh
scripts/download-mlx-models.sh
scripts/clone-qmd-sandbox.sh

# Deterministic contract test. No MLX/vMLX runtime required.
scripts/test-qmd-pr619-fake-openai.sh

# Live MLX runtime diagnostic.
scripts/start-vmlx-embedding-server.sh

# New terminal:
QMD_MLX_BASE_URL=http://127.0.0.1:8092/v1 scripts/test-qmd-pr619-vmlx.sh
```

The live diagnostic now passes with rerank when the local vMLX patch is applied:

```bash
REQUIRE_RERANK=1 QMD_MLX_BASE_URL=http://127.0.0.1:8092/v1 scripts/test-qmd-pr619-vmlx.sh
```

Patch file:

```text
patches/vmlx-1.5.49-qwen3-reranker-causal.patch
```

## Current server state on Rudy's M4 Max

A vMLX server was restarted after the repo rename and is listening on:

```text
http://127.0.0.1:8092/v1
```

Its model list includes:

```text
qmd-embed
mlx/mlx-community__Qwen3-Embedding-0.6B-4bit-DWQ
/Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx/models/mlx/mlx-community__Qwen3-Embedding-0.6B-4bit-DWQ
```

Do not trust the alias for embeddings yet. Use the exact local path.

If Hermes reports a fresh startup from another checkout but `/v1/models` still shows this repo path, a stale listener is already holding port 8092. Use `scripts/start-vmlx-embedding-server.sh`; it refuses mismatched listeners instead of silently testing the wrong checkout. Set `QMD_MLX_KILL_STALE=1` only when you deliberately want it to kill the existing port owner.

## Next PR-safe steps

1. Turn `patches/vmlx-1.5.49-qwen3-reranker-causal.patch` into an upstream-ready vMLX branch or a local reapply script with checksum verification.
2. Fix or work around vMLX embedding alias handling so `qmd-embed` works for `/v1/embeddings`, or keep qmd configured to the exact local model path.
3. Add a tiny benchmark comparing stock GGUF qmd vs MLX-provider qmd on the same public fixture first.
4. Only after private trace evals show improvement, prepare an upstream qmd branch.
5. Do not open an upstream qmd PR unless Rudy explicitly asks for one.

## Verification snapshot

```text
git status: clean after committed/pushed; verify with `git status -sb`
required checks: scripts/verify.sh; scripts/test-qmd-pr619-fake-openai.sh; REQUIRE_RERANK=1 QMD_MLX_BASE_URL=http://127.0.0.1:8092/v1 scripts/test-qmd-pr619-vmlx.sh
remote: PUBLIC https://github.com/chipoto69/qmd-mlx
```
