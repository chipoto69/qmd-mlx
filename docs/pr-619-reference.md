# qmd PR #619 Reference

Primary reference:

- https://github.com/tobi/qmd/pull/619

Why it matters:

PR #619 is the closest known upstream-direction implementation for qmd external model providers. It targets OpenAI-compatible generation, embeddings, and reranking.

Expected endpoint contract:

```text
POST /v1/chat/completions
POST /v1/embeddings
POST /v1/rerank
```

Provider mapping needed for qmd:

```text
embedBatch(texts)
  -> POST /v1/embeddings
  -> normalize data[].embedding

rerank(query, docs)
  -> POST /v1/rerank
  -> normalize results[].index + results[].relevance_score

expandQuery(prompt)
  -> POST /v1/chat/completions
  -> parse response.choices[0].message.content
```

Implementation warnings:

- `/v1/rerank` is not an OpenAI standard. Treat it as Cohere/Jina-compatible.
- Embedding dimensions are model/server-dependent. The index metadata must make dimension explicit.
- Chunking currently depends on local tokenizer behavior in stock qmd. External-provider mode needs a conservative strategy until tokenizer parity is solved.
- Secrets must never appear in errors or logs.

Related PR:

- https://github.com/tobi/qmd/pull/689

Local prior art:

- `/Users/rudlord/qmd-mlx`

Use it as a sketch, not gospel. Rebase ideas onto current upstream qmd before implementation.
