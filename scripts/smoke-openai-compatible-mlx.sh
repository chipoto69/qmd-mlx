#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${QMD_MLX_BASE_URL:-http://127.0.0.1:8000/v1}"
EMBED_MODEL="${QMD_MLX_EMBED_MODEL:-mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ}"
RERANK_MODEL="${QMD_MLX_RERANK_MODEL:-mlx-community/Qwen3-Reranker-0.6B-mxfp8}"

python3 - <<PY
import json
import urllib.request

base = "$BASE_URL".rstrip('/')
embed_model = "$EMBED_MODEL"
rerank_model = "$RERANK_MODEL"

def post(path, payload):
    req = urllib.request.Request(
        base + path,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())

print('smoke embeddings:', base + '/embeddings')
emb = post('/embeddings', {"model": embed_model, "input": ["MLX runs on Apple Silicon", "qmd does hybrid retrieval"]})
print(json.dumps({"embedding_items": len(emb.get('data', [])), "first_dim": len(emb.get('data', [{}])[0].get('embedding', []))}, indent=2))

print('smoke rerank:', base + '/rerank')
rer = post('/rerank', {"model": rerank_model, "query": "Apple Silicon MLX retrieval", "documents": ["MLX uses Metal on Apple Silicon", "CUDA is for NVIDIA GPUs"], "top_n": 2})
print(json.dumps(rer, indent=2)[:2000])
PY
