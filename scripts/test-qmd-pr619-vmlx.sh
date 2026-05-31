#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QMD="$ROOT/.sandbox/qmd"
BASE_URL="${QMD_MLX_BASE_URL:-http://127.0.0.1:8092/v1}"
EMBED_MODEL="${QMD_MLX_EMBED_MODEL:-$ROOT/models/mlx/mlx-community__Qwen3-Embedding-0.6B-4bit-DWQ}"
RERANK_MODEL="${QMD_MLX_RERANK_MODEL:-$ROOT/models/mlx/mlx-community__Qwen3-Reranker-0.6B-mxfp8}"
GENERATE_MODEL="${QMD_MLX_GENERATE_MODEL:-qmd-embed}"
TEST_HOME="${QMD_MLX_TEST_HOME:-$ROOT/.qmd-test-home/pr619-vmlx}"
LOG_DIR="${QMD_MLX_LOG_DIR:-$ROOT/.tmp/pr619-vmlx}"
COLLECTION_NAME="TRACE_FIXTURE"

mkdir -p "$LOG_DIR"

if [ ! -d "$QMD/.git" ]; then
  echo "Missing qmd sandbox: $QMD" >&2
  echo "Run scripts/clone-qmd-sandbox.sh first." >&2
  exit 2
fi

if [ ! -d "$EMBED_MODEL" ]; then
  echo "Missing embedding model directory: $EMBED_MODEL" >&2
  echo "Run scripts/download-mlx-models.sh first, or set QMD_MLX_EMBED_MODEL." >&2
  exit 2
fi

rm -rf "$TEST_HOME"
mkdir -p "$TEST_HOME/config/qmd" "$TEST_HOME/cache"

cat > "$TEST_HOME/config/qmd/index.yml" <<YAML
global_context: "Public smoke-test fixture for qmd OpenAI-compatible MLX provider experiments."
collections:
  $COLLECTION_NAME:
    path: $ROOT/tests/fixtures/trace-packets
    pattern: "**/*.md"
    context:
      "/": "Synthetic agent trace packets and provider smoke-test notes."
models:
  embed: $EMBED_MODEL
  rerank: $RERANK_MODEL
  generate: $GENERATE_MODEL
llm:
  provider: openai-compatible
  baseUrl: $BASE_URL
YAML

export QMD_CONFIG_DIR="$TEST_HOME/config/qmd"
export XDG_CACHE_HOME="$TEST_HOME/cache"
export INDEX_PATH="$TEST_HOME/index.sqlite"
export QMD_OPENAI_BASE_URL="$BASE_URL"
export QMD_LLM_PROVIDER="openai-compatible"
export QMD_EMBED_MODEL="$EMBED_MODEL"
export QMD_RERANK_MODEL="$RERANK_MODEL"
export QMD_GENERATE_MODEL="$GENERATE_MODEL"

run_step() {
  local name="$1"
  shift
  echo
  echo "===== $name ====="
  set +e
  "$@" 2>&1 | tee "$LOG_DIR/$name.log"
  local rc=${PIPESTATUS[0]}
  set -e
  echo "exit=$rc" | tee -a "$LOG_DIR/$name.log"
  return "$rc"
}

probe_endpoints() {
  python3 - <<PY
import json, math, urllib.error, urllib.request
base = "$BASE_URL".rstrip("/")
embed_model = "$EMBED_MODEL"
rerank_model = "$RERANK_MODEL"
generate_model = "$GENERATE_MODEL"

def post(path, payload):
    req = urllib.request.Request(
        base + path,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")[:800]

status, payload = post("/embeddings", {"model": embed_model, "input": ["probe one", "probe two"]})
if status == 200:
    vectors = [item["embedding"] for item in payload.get("data", [])]
    print("embeddings exact-model status", status, "items", len(vectors), "dim", len(vectors[0]) if vectors else 0, "norm0", round(math.sqrt(sum(v*v for v in vectors[0])), 6) if vectors else None)
else:
    print("embeddings exact-model status", status, "body", payload)

status, payload = post("/embeddings", {"model": generate_model, "input": ["alias probe"]})
print("embeddings alias status", status, "body", payload if isinstance(payload, str) else json.dumps(payload)[:400])

status, payload = post("/rerank", {"model": rerank_model, "query": "mlx retrieval", "documents": ["MLX uses Metal", "CUDA uses NVIDIA"], "top_n": 2})
print("rerank exact-model status", status, "body", payload if isinstance(payload, str) else json.dumps(payload)[:800])

status, payload = post("/chat/completions", {"model": generate_model, "messages": [{"role":"user", "content":"Return lex: mlx"}], "max_tokens": 20})
print("chat alias status", status, "body", payload if isinstance(payload, str) else json.dumps(payload)[:800])
PY
}

hard_fail=0
soft_fail=0

echo "ROOT=$ROOT"
echo "QMD=$QMD"
echo "BASE_URL=$BASE_URL"
echo "EMBED_MODEL=$EMBED_MODEL"
echo "RERANK_MODEL=$RERANK_MODEL"
echo "TEST_HOME=$TEST_HOME"
echo "LOG_DIR=$LOG_DIR"

run_step endpoint-probes probe_endpoints || hard_fail=1
cd "$QMD"
run_step status-before bun src/cli/qmd.ts status || hard_fail=1
run_step update bun src/cli/qmd.ts update || hard_fail=1
run_step embed bun src/cli/qmd.ts embed --chunk-strategy regex --max-docs-per-batch 2 --max-batch-mb 1 || hard_fail=1
run_step status-after bun src/cli/qmd.ts status || hard_fail=1
run_step search-bm25 bun src/cli/qmd.ts search "provider embeddings" -c "$COLLECTION_NAME" --json || hard_fail=1
run_step vsearch bun src/cli/qmd.ts vsearch "external provider embeddings" -c "$COLLECTION_NAME" --json || hard_fail=1
run_step query-no-rerank bun src/cli/qmd.ts query $'lex: provider embeddings\nvec: external provider embeddings' -c "$COLLECTION_NAME" --no-rerank --json || hard_fail=1
run_step query-rerank bun src/cli/qmd.ts query $'lex: provider embeddings\nvec: external provider embeddings' -c "$COLLECTION_NAME" --json || soft_fail=1
if grep -q 'Rerank error\|OpenAI-compatible request failed' "$LOG_DIR/query-rerank.log"; then
  soft_fail=1
fi

echo
python3 - <<PY
import pathlib, sqlite3
p = pathlib.Path("$TEST_HOME/index.sqlite")
print("index_exists", p.exists())
print("index_size", p.stat().st_size if p.exists() else 0)
if p.exists():
    con = sqlite3.connect(p)
    for (name,) in con.execute("select name from sqlite_master where type='table' order by name"):
        if name.startswith("sqlite_"):
            continue
        try:
            n = con.execute(f'select count(*) from "{name}"').fetchone()[0]
        except Exception as e:
            n = f"ERR {type(e).__name__}: {e}"
        print(f"{name}: {n}")
PY

if [ "$hard_fail" -ne 0 ]; then
  echo "RESULT=FAIL: embedding/vector qmd path did not pass." >&2
  exit 1
fi

if [ "$soft_fail" -ne 0 ]; then
  echo "RESULT=PARTIAL: embedding/vector qmd path passed, rerank path failed. Set REQUIRE_RERANK=1 to make rerank failure fatal."
  [ "${REQUIRE_RERANK:-0}" = "1" ] && exit 1
  exit 0
fi

echo "RESULT=PASS: qmd OpenAI-compatible MLX provider path passed including rerank."
