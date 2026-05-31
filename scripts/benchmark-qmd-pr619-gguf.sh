#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QMD="$ROOT/.sandbox/qmd"
TEST_HOME="${QMD_GGUF_BENCH_HOME:-$ROOT/.qmd-test-home/pr619-gguf-bench}"
LOG_DIR="${QMD_GGUF_BENCH_LOG_DIR:-$ROOT/.tmp/bench-pr619-gguf}"
COLLECTION_NAME="eval-docs"
FIXTURE_PATH="$QMD/src/bench/fixtures/example.json"
EVAL_DOCS_PATH="$QMD/test/eval-docs"

if [ ! -d "$QMD/.git" ]; then
  echo "Missing qmd sandbox: $QMD" >&2
  echo "Run scripts/clone-qmd-sandbox.sh first." >&2
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
mkdir -p "$TEST_HOME/config/qmd"

cat > "$TEST_HOME/config/qmd/index.yml" <<YAML
global_context: "Public qmd eval-docs benchmark corpus for stock GGUF baseline experiments."
collections:
  $COLLECTION_NAME:
    path: $EVAL_DOCS_PATH
    pattern: "**/*.md"
    context:
      "/": "Small public benchmark corpus covering API design, startup fundraising, distributed systems, ML, product retrospectives, and remote work."
YAML

export QMD_CONFIG_DIR="$TEST_HOME/config/qmd"
export INDEX_PATH="$TEST_HOME/index.sqlite"
# Reuse the normal qmd model cache for GGUF weights, but keep the index isolated.
# This avoids accidental reuse of XDG_CACHE_HOME from another benchmark shell.
unset XDG_CACHE_HOME QMD_OPENAI_BASE_URL QMD_LLM_PROVIDER QMD_EMBED_MODEL QMD_RERANK_MODEL QMD_GENERATE_MODEL

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
echo "TEST_HOME=$TEST_HOME"
echo "LOG_DIR=$LOG_DIR"
echo "FIXTURE_PATH=$FIXTURE_PATH"

cd "$QMD"
run_step status-before bun src/cli/qmd.ts status
run_step update bun src/cli/qmd.ts update
run_step embed bun src/cli/qmd.ts embed --chunk-strategy regex --max-docs-per-batch 4 --max-batch-mb 1
run_step status-after bun src/cli/qmd.ts status
run_step qmd-bench-text bash -c "bun src/cli/qmd.ts bench '$FIXTURE_PATH' -c '$COLLECTION_NAME' > '$LOG_DIR/qmd-bench-result.txt'"

python3 - <<PY | tee "$LOG_DIR/summary.txt"
import json, pathlib, re, sqlite3
log_dir = pathlib.Path("$LOG_DIR")
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
print("qmd stock GGUF bench summary:")
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

echo "RESULT=PASS qmd PR #619 stock GGUF benchmark complete"
