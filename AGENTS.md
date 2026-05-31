# qmd-mlx - Agent Contract

## Purpose

This repository is the isolated build lane for making qmd usable with Apple Silicon MLX model servers for embeddings, reranking, and query expansion.

It exists to turn the current qmd MLX/OpenAI-compatible provider idea into a runnable, inspectable, testable workflow without polluting Rudy's global qmd install, the noisy parent ACTIVE_PROJECTS tree, or upstream qmd.

## Core Goals

- Keep the work sandboxed: upstream qmd clones, model downloads, virtualenvs, and generated indexes stay out of git.
- Reference and learn from qmd PR #619: https://github.com/tobi/qmd/pull/619
- Track related qmd PR #689: https://github.com/tobi/qmd/pull/689
- Preserve local qmd-mlx fork learnings from `/Users/rudlord/qmd-mlx` without treating that fork as canonical.
- Build an OpenAI-compatible provider path that can talk to oMLX, vMLX, vllm-mlx, or embed-rerank.
- Test with real trace-packet retrieval flows before touching Rudy's production qmd index.

## Ambition

The end state is a local-first qmd branch where:

```text
qmd embedBatch()  -> POST /v1/embeddings
qmd rerank()      -> POST /v1/rerank
qmd expandQuery() -> POST /v1/chat/completions
```

qmd should keep its strong hybrid retrieval shape while delegating model execution to a warm MLX service on Apple Silicon.

## Non-Goals

- Do not modify Rudy's global qmd install directly.
- Do not mutate `~/.cache/qmd/index.sqlite` during experiments.
- Do not create upstream qmd pull requests unless Rudy explicitly asks for an upstream PR.
- Do not turn this into idea storage. Every workflow must leave runnable artifacts.
- Do not index raw private traces in this public repo.

## Repository Rules

- One workflow per folder under `workflows/`.
- Keep operator artifacts file-backed: plans, state, logs, fixtures, scripts, and outputs.
- Autonomy without logs and review paths is failure.
- Root-cause fixes only: no papering over native module, tokenizer, or schema mismatches.
- Human checkpoints are required before public upstream PRs, publishing packages, or touching production qmd config.
- Anything generated, downloaded, or private goes under ignored folders: `.sandbox/`, `models/`, `output/`, `.venv/`, `.qmd-test-home/`.

## Git and Versioning Policy

- This directory owns its own git repo. Do not rely on the parent ACTIVE_PROJECTS repo.
- Use conventional commits.
- Keep `main` clean and pushable.
- Use branches for implementation work: `feat/openai-mlx-provider`, `test/provider-contract`, etc.
- Commit docs, scripts, fixtures, and reproducible config. Never commit model weights, qmd indexes, secrets, or trace dumps.

## Quality Bar for a Real Workflow

A workflow counts only if it has:

- a README explaining purpose and current state
- a plan with acceptance criteria
- scripts that can be re-run from a clean checkout
- a state file or log trail
- small public fixtures, not private data
- verification commands and expected results

## Current First Workflow

```text
workflows/qmd-openai-mlx-provider/
  README.md
  plan.md
  state/status.md
  config/qmd-openai-compatible.example.yml
```

## Safety

This repo can be public. Keep it boringly clean: no credentials, no private traces, no full local paths in generated model logs unless intentionally documented as operator paths.
