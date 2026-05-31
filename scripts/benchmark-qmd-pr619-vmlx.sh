#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QMD="$ROOT/.sandbox/qmd"
BASE_URL="${QMD_MLX_BASE_URL:-http://127.0.0.1:8092/v1}"
EMBED_MODEL="${QMD_MLX_EMBED_MODEL:-$ROOT/models/mlx/mlx-community__Qwen3-Embedding-0.6B-4bit-DWQ}"
RERANK_MODEL="${QMD_MLX_RERANK_MODEL:-$ROOT/models/mlx/mlx-community__Qwen3-Reranker-0.6B-mxfp8}"
GENERATE_MODEL="${QMD_MLX_GENERATE_MODEL:-qmd-embed}"
TEST_HOME="${QMD_MLX_BENCH_HOME:-$ROOT/.qmd-test-home/pr619-vmlx-bench}"
LOG_DIR="${QMD_MLX_BENCH_LOG_DIR:-$ROOT/.tmp/bench-pr619-vmlx}"
COLLECTION_NAME="eval-docs"
FIXTURE_PATH="$QMD/src/bench/fixtures/example.json"
EVAL_DOCS_PATH="$QMD/test/eval-docs"
ITERATIONS="${QMD_MLX_BENCH_ITERATIONS:-10}"

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

if [ ! -f "$FIXTURE_PATH" ]; then
  echo "Missing qmd bench fixture: $FIXTURE_PATH" >&2
  exit 2
fi

if [ ! -d "$EVAL_DOCS_PATH" ]; then
  echo "Missing qmd eval docs: $EVAL_DOCS_PATH" >&2
  exit 2
fi

mkdir -p "$LOG_DIR"
rm -rf "$TEST_HOME"
mkdir -p "$TEST_HOME/config/qmd" "$TEST_HOME/cache"

cat > "$TEST_HOME/config/qmd/index.yml" <<YAML
global_context: "Public qmd eval-docs benchmark corpus for OpenAI-compatible MLX provider experiments."
collections:
  $COLLECTION_NAME:
    path: $EVAL_DOCS_PATH
    pattern: "**/*.md"
    context:
      "/": "Small public benchmark corpus covering API design, startup fundraising, distributed systems, ML, product retrospectives, and remote work."
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

echo "ROOT=$ROOT"
echo "QMD=$QMD"
echo "BASE_URL=$BASE_URL"
echo "EMBED_MODEL=$EMBED_MODEL"
echo "RERANK_MODEL=$RERANK_MODEL"
echo "GENERATE_MODEL=$GENERATE_MODEL"
echo "TEST_HOME=$TEST_HOME"
echo "LOG_DIR=$LOG_DIR"
echo "FIXTURE_PATH=$FIXTURE_PATH"
echo "ITERATIONS=$ITERATIONS"

python3 - <<PY | tee "$LOG_DIR/endpoint-bench.json"
import json, math, statistics, time, urllib.request
base = "$BASE_URL".rstrip("/")
embed_model = "$EMBED_MODEL"
rerank_model = "$RERANK_MODEL"
generate_model = "$GENERATE_MODEL"
iterations = int("$ITERATIONS")

def post(path, payload, timeout=120):
    body = json.dumps(payload).encode()
    req = urllib.request.Request(base + path, data=body, headers={"Content-Type": "application/json"}, method="POST")
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        text = resp.read().decode()
    elapsed_ms = (time.perf_counter() - start) * 1000
    return elapsed_ms, json.loads(text)

def get(path, timeout=30):
    start = time.perf_counter()
    with urllib.request.urlopen(base + path, timeout=timeout) as resp:
        text = resp.read().decode()
    elapsed_ms = (time.perf_counter() - start) * 1000
    return elapsed_ms, json.loads(text)

def pct(values, q):
    if not values:
        return None
    values = sorted(values)
    idx = min(len(values) - 1, max(0, math.ceil((q / 100) * len(values)) - 1))
    return values[idx]

def summarize(values):
    return {
        "count": len(values),
        "mean_ms": round(statistics.mean(values), 2),
        "p50_ms": round(statistics.median(values), 2),
        "p95_ms": round(pct(values, 95), 2),
        "min_ms": round(min(values), 2),
        "max_ms": round(max(values), 2),
    }

models_ms, models = get("/models")
embed_lat = []
embed_dim = None
embed_norm = None
for _ in range(iterations):
    ms, payload = post("/embeddings", {"model": embed_model, "input": ["API design versioning", "remote work policy"]})
    embed_lat.append(ms)
    vec = payload["data"][0]["embedding"]
    embed_dim = len(vec)
    embed_norm = math.sqrt(sum(x*x for x in vec))

rerank_lat = []
rerank_top_index = None
rerank_scores = None
for _ in range(iterations):
    ms, payload = post("/rerank", {
        "model": rerank_model,
        "query": "Apple Silicon MLX retrieval",
        "documents": [
            "MLX uses Metal on Apple Silicon for local inference.",
            "CUDA kernels target NVIDIA GPUs.",
            "Remote work policies describe asynchronous collaboration.",
            "Series A fundraising requires investor pipeline management."
        ],
        "top_n": 4,
    })
    rerank_lat.append(ms)
    rerank_top_index = payload["results"][0]["index"]
    rerank_scores = [r["relevance_score"] for r in payload["results"]]

chat_lat = []
for _ in range(max(1, min(3, iterations))):
    ms, _payload = post("/chat/completions", {
        "model": generate_model,
        "messages": [{"role": "user", "content": "Return exactly: lex: API versioning"}],
        "max_tokens": 20,
        "temperature": 0.0,
    })
    chat_lat.append(ms)

result = {
    "base_url": base,
    "models_get_ms": round(models_ms, 2),
    "advertised_models": [m.get("id") for m in models.get("data", [])],
    "embedding": {
        "model": embed_model,
        "dim": embed_dim,
        "norm_first_vector": round(embed_norm, 6) if embed_norm is not None else None,
        "latency": summarize(embed_lat),
    },
    "rerank": {
        "model": rerank_model,
        "top_index": rerank_top_index,
        "scores": rerank_scores,
        "scores_bounded_0_1": all(0 <= s <= 1 for s in (rerank_scores or [])),
        "latency": summarize(rerank_lat),
    },
    "chat_completion": {
        "model": generate_model,
        "latency": summarize(chat_lat),
        "note": "Current server uses qmd-embed alias for generation smoke only; this is not a quality generation benchmark.",
    }
}
print(json.dumps(result, indent=2))
PY

cd "$QMD"
run_step status-before bun src/cli/qmd.ts status
run_step update bun src/cli/qmd.ts update
run_step embed bun src/cli/qmd.ts embed --chunk-strategy regex --max-docs-per-batch 4 --max-batch-mb 1
run_step status-after bun src/cli/qmd.ts status

# qmd bench currently prints table output even when --json is passed in this sandbox.
# Capture the table and parse the Summary section for stable machine-readable metrics.
run_step qmd-bench-text bash -c "bun src/cli/qmd.ts bench '$FIXTURE_PATH' -c '$COLLECTION_NAME' > '$LOG_DIR/qmd-bench-result.txt'"

python3 - <<PY | tee "$LOG_DIR/summary.txt"
import json, pathlib, re, sqlite3
log_dir = pathlib.Path("$LOG_DIR")
endpoint = json.loads((log_dir / "endpoint-bench.json").read_text())
bench_text = (log_dir / "qmd-bench-result.txt").read_text()
summary_re = re.compile(r"^\s*(bm25|vector|hybrid|full)\s+P@k=\s*([0-9.]+)\s+Recall=\s*([0-9.]+)\s+MRR=\s*([0-9.]+)\s+F1=\s*([0-9.]+)\s+Avg=(\d+)ms$", re.MULTILINE)
bench_summary = {
    m.group(1): {
        "avg_precision": float(m.group(2)),
        "avg_recall": float(m.group(3)),
        "avg_mrr": float(m.group(4)),
        "avg_f1": float(m.group(5)),
        "avg_latency_ms": float(m.group(6)),
    }
    for m in summary_re.finditer(bench_text)
}
if set(bench_summary) != {"bm25", "vector", "hybrid", "full"}:
    raise SystemExit(f"Could not parse qmd bench summary from {log_dir / 'qmd-bench-result.txt'}; got {sorted(bench_summary)}")
(log_dir / "qmd-bench-summary.json").write_text(json.dumps({"summary": bench_summary}, indent=2) + "\n")
index_path = pathlib.Path("$TEST_HOME/index.sqlite")
print("Endpoint microbench:")
print(f"  embeddings: dim={endpoint['embedding']['dim']} mean={endpoint['embedding']['latency']['mean_ms']}ms p95={endpoint['embedding']['latency']['p95_ms']}ms n={endpoint['embedding']['latency']['count']}")
print(f"  rerank: top_index={endpoint['rerank']['top_index']} bounded={endpoint['rerank']['scores_bounded_0_1']} mean={endpoint['rerank']['latency']['mean_ms']}ms p95={endpoint['rerank']['latency']['p95_ms']}ms n={endpoint['rerank']['latency']['count']}")
print(f"  chat smoke: mean={endpoint['chat_completion']['latency']['mean_ms']}ms n={endpoint['chat_completion']['latency']['count']}")
print("")
print("qmd bench summary:")
for name, s in bench_summary.items():
    print(f"  {name}: P@k={s['avg_precision']:.3f} Recall={s['avg_recall']:.3f} MRR={s['avg_mrr']:.3f} F1={s['avg_f1']:.3f} Avg={s['avg_latency_ms']:.1f}ms")
print("")
print("Index:")
print(f"  path={index_path}")
print(f"  size_bytes={index_path.stat().st_size if index_path.exists() else 0}")
if index_path.exists():
    con = sqlite3.connect(index_path)
    for table in ["documents", "content", "content_vectors", "vectors_vec_chunks", "llm_cache"]:
        try:
            n = con.execute(f'select count(*) from "{table}"').fetchone()[0]
            print(f"  {table}={n}")
        except Exception as exc:
            print(f"  {table}=ERR {type(exc).__name__}: {exc}")
PY

python3 - <<PY
import json, pathlib
log_dir = pathlib.Path("$LOG_DIR")
endpoint = json.loads((log_dir / "endpoint-bench.json").read_text())
bench = json.loads((log_dir / "qmd-bench-summary.json").read_text())
summary = log_dir / "summary.md"
lines = []
lines.append("# qmd PR #619 vMLX benchmark")
lines.append("")
lines.append(f"Base URL: {endpoint['base_url']}")
lines.append(f"Iterations: {endpoint['embedding']['latency']['count']} endpoint calls for embeddings/rerank")
lines.append("")
lines.append("## Endpoint microbench")
lines.append("")
lines.append("| path | key result | mean ms | p50 ms | p95 ms |")
lines.append("| --- | --- | ---: | ---: | ---: |")
emb = endpoint['embedding']['latency']
rer = endpoint['rerank']['latency']
chat = endpoint['chat_completion']['latency']
lines.append(f"| /v1/embeddings | dim {endpoint['embedding']['dim']} | {emb['mean_ms']} | {emb['p50_ms']} | {emb['p95_ms']} |")
lines.append(f"| /v1/rerank | top index {endpoint['rerank']['top_index']}, bounded {endpoint['rerank']['scores_bounded_0_1']} | {rer['mean_ms']} | {rer['p50_ms']} | {rer['p95_ms']} |")
lines.append(f"| /v1/chat/completions | smoke only | {chat['mean_ms']} | {chat['p50_ms']} | {chat['p95_ms']} |")
lines.append("")
lines.append("## qmd benchmark summary")
lines.append("")
lines.append("| backend | P@k | Recall | MRR | F1 | avg latency ms |")
lines.append("| --- | ---: | ---: | ---: | ---: | ---: |")
for name, s in bench['summary'].items():
    lines.append(f"| {name} | {s['avg_precision']:.3f} | {s['avg_recall']:.3f} | {s['avg_mrr']:.3f} | {s['avg_f1']:.3f} | {s['avg_latency_ms']:.1f} |")
lines.append("")
lines.append("Full artifacts:")
lines.append("")
lines.append(f"- {log_dir / 'endpoint-bench.json'}")
lines.append(f"- {log_dir / 'qmd-bench-result.txt'}")
lines.append(f"- {log_dir / 'qmd-bench-summary.json'}")
lines.append(f"- {log_dir / 'summary.txt'}")
summary.write_text("\n".join(lines) + "\n")
print(summary)
PY

echo "RESULT=PASS qmd PR #619 vMLX benchmark complete"
