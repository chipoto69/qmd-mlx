#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QMD="$ROOT/.sandbox/qmd"
FAKE_SERVER="$ROOT/tests/fakes/fake_openai_provider.py"
HOST="${QMD_FAKE_OPENAI_HOST:-127.0.0.1}"
PORT="${QMD_FAKE_OPENAI_PORT:-18092}"
BASE_URL="${QMD_FAKE_OPENAI_BASE_URL:-http://$HOST:$PORT/v1}"
EMBED_MODEL="${QMD_FAKE_EMBED_MODEL:-fake-embed-8d}"
RERANK_MODEL="${QMD_FAKE_RERANK_MODEL:-fake-rerank}"
GENERATE_MODEL="${QMD_FAKE_GENERATE_MODEL:-fake-generate}"
TEST_HOME="${QMD_FAKE_TEST_HOME:-$ROOT/.qmd-test-home/pr619-fake-openai}"
LOG_DIR="${QMD_FAKE_LOG_DIR:-$ROOT/.tmp/pr619-fake-openai}"
COLLECTION_NAME="TRACE_FIXTURE"
SERVER_LOG="$LOG_DIR/server.log"
REQUEST_LOG="$LOG_DIR/server-requests.jsonl"

mkdir -p "$LOG_DIR"

if [ ! -d "$QMD/.git" ]; then
  echo "Missing qmd sandbox: $QMD" >&2
  echo "Run scripts/clone-qmd-sandbox.sh first." >&2
  exit 2
fi

if [ ! -f "$FAKE_SERVER" ]; then
  echo "Missing fake OpenAI-compatible server: $FAKE_SERVER" >&2
  exit 2
fi

listener_pid="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true)"
if [ -n "$listener_pid" ]; then
  listener_cmd="$(ps -p "$listener_pid" -o command= 2>/dev/null || true)"
  echo "Port $HOST:$PORT already has listener pid=$listener_pid" >&2
  echo "$listener_cmd" >&2
  if [ "${QMD_FAKE_OPENAI_KILL_STALE:-0}" = "1" ]; then
    kill "$listener_pid"
    sleep 1
  else
    echo "Refusing to start fake provider on occupied port $PORT. Set QMD_FAKE_OPENAI_KILL_STALE=1 only if safe." >&2
    exit 1
  fi
fi

rm -rf "$TEST_HOME"
rm -f "$SERVER_LOG" "$REQUEST_LOG"
mkdir -p "$TEST_HOME/config/qmd" "$TEST_HOME/cache" "$LOG_DIR"

python3 "$FAKE_SERVER" --host "$HOST" --port "$PORT" --log-jsonl "$REQUEST_LOG" >"$SERVER_LOG" 2>&1 &
server_pid=$!
cleanup() {
  if kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

for _ in $(seq 1 80); do
  if curl -fsS "$BASE_URL/models" >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    echo "Fake provider exited early. Log:" >&2
    sed -n '1,200p' "$SERVER_LOG" >&2 || true
    exit 1
  fi
  sleep 0.1
done
curl -fsS "$BASE_URL/models" >/dev/null

cat > "$TEST_HOME/config/qmd/index.yml" <<YAML
global_context: "Public smoke-test fixture for qmd OpenAI-compatible provider contract tests."
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
export QMD_OPENAI_API_KEY="fake-contract-token"

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

hard_fail=0

echo "ROOT=$ROOT"
echo "QMD=$QMD"
echo "BASE_URL=$BASE_URL"
echo "EMBED_MODEL=$EMBED_MODEL"
echo "RERANK_MODEL=$RERANK_MODEL"
echo "GENERATE_MODEL=$GENERATE_MODEL"
echo "TEST_HOME=$TEST_HOME"
echo "LOG_DIR=$LOG_DIR"
echo "REQUEST_LOG=$REQUEST_LOG"

cd "$QMD"
run_step status-before bun src/cli/qmd.ts status || hard_fail=1
run_step update bun src/cli/qmd.ts update || hard_fail=1
run_step embed bun src/cli/qmd.ts embed --chunk-strategy regex --max-docs-per-batch 2 --max-batch-mb 1 || hard_fail=1
run_step status-after bun src/cli/qmd.ts status || hard_fail=1
run_step search-bm25 bun src/cli/qmd.ts search "provider embeddings" -c "$COLLECTION_NAME" --json || hard_fail=1
run_step vsearch bun src/cli/qmd.ts vsearch "external provider embeddings" -c "$COLLECTION_NAME" --json || hard_fail=1
run_step query-rerank bun src/cli/qmd.ts query $'lex: provider embeddings\nvec: external provider embeddings' -c "$COLLECTION_NAME" --json || hard_fail=1
run_step query-expanded bun src/cli/qmd.ts query "find the qmd external provider investigation" -c "$COLLECTION_NAME" --json || hard_fail=1

if [ "$hard_fail" -ne 0 ]; then
  echo "RESULT=FAIL: qmd fake OpenAI-compatible contract path failed." >&2
  exit 1
fi

python3 - <<PY
import json, pathlib, sqlite3, sys
root = pathlib.Path("$ROOT")
log_path = pathlib.Path("$REQUEST_LOG")
log_rows = []
for line in log_path.read_text().splitlines():
    if line.strip():
        log_rows.append(json.loads(line))
paths = {}
for row in log_rows:
    paths[row["path"]] = paths.get(row["path"], 0) + 1
print("request_counts", json.dumps(paths, sort_keys=True))
required = ["/v1/models", "/v1/embeddings", "/v1/rerank", "/v1/chat/completions"]
missing = [path for path in required if paths.get(path, 0) < 1]
if missing:
    raise SystemExit(f"missing required endpoint calls: {missing}")

models = {row.get("json", {}).get("model") for row in log_rows if isinstance(row.get("json"), dict) and row.get("json", {}).get("model")}
expected = {"$EMBED_MODEL", "$RERANK_MODEL", "$GENERATE_MODEL"}
if not expected.issubset(models):
    raise SystemExit(f"missing expected model IDs: {sorted(expected - models)} from {sorted(models)}")

if not any(row.get("authorization") == "Bearer fake-contract-token" for row in log_rows if row.get("path") != "/v1/models"):
    raise SystemExit("authorization header was not forwarded to fake provider")

for name in ["vsearch", "query-rerank", "query-expanded"]:
    text = pathlib.Path("$LOG_DIR", f"{name}.log").read_text()
    if "qmd://TRACE_FIXTURE/agent-trace-sample.md" not in text:
        raise SystemExit(f"expected fixture missing from {name}.log")

index = pathlib.Path("$TEST_HOME/index.sqlite")
print("index_exists", index.exists())
print("index_size", index.stat().st_size if index.exists() else 0)
con = sqlite3.connect(index)
for table in ["documents", "content", "content_vectors", "vectors_vec_chunks"]:
    count = con.execute(f'select count(*) from "{table}"').fetchone()[0]
    print(f"{table}: {count}")
    if count < 1:
        raise SystemExit(f"expected rows in {table}")
PY

echo "RESULT=PASS: qmd PR #619 OpenAI-compatible provider contract passed with fake embeddings, rerank, generation, and isolated index."
