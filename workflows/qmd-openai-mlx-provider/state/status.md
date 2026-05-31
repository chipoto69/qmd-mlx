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
