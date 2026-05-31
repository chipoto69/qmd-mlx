# Development Handoff

## Local sandbox paths

```text
repo:          /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx-provider-lab
qmd sandbox:   /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx-provider-lab/.sandbox/qmd
model cache:   /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx-provider-lab/models/mlx
qmd test home: /Users/rudlord/ORGANIZED/ACTIVE_PROJECTS/qmd-mlx-provider-lab/.qmd-test-home
```

## Branch policy

Use implementation branches in this repo or inside `.sandbox/qmd`:

```bash
git checkout -b feat/openai-mlx-provider
```

Do not open upstream qmd PRs without Rudy explicitly asking.

## Verification commands

```bash
scripts/verify.sh
scripts/clone-qmd-sandbox.sh
scripts/download-mlx-models.sh
```

For qmd sandbox work:

```bash
cd .sandbox/qmd
bun install || npm install
git branch --all | grep 'reference/pr-619\|reference/pr-689'
```
