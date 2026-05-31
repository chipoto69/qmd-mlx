#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL="${QMD_MLX_EMBED_MODEL:-$ROOT/models/mlx/mlx-community__Qwen3-Embedding-0.6B-4bit-DWQ}"
HOST="${QMD_MLX_HOST:-127.0.0.1}"
PORT="${QMD_MLX_PORT:-8092}"
SERVED_MODEL_NAME="${QMD_MLX_SERVED_MODEL_NAME:-qmd-embed}"
MAX_TOKENS="${QMD_MLX_MAX_TOKENS:-16}"
LOG_LEVEL="${QMD_MLX_LOG_LEVEL:-INFO}"
VMLX_BIN="${VMLX_BIN:-/Users/rudlord/.local/bin/vmlx}"

if [ ! -d "$MODEL" ]; then
  echo "Missing embedding model directory: $MODEL" >&2
  echo "Run scripts/download-mlx-models.sh first, or set QMD_MLX_EMBED_MODEL." >&2
  exit 2
fi

if [ ! -x "$VMLX_BIN" ]; then
  echo "vMLX binary not executable: $VMLX_BIN" >&2
  echo "Install vMLX or set VMLX_BIN=/path/to/vmlx." >&2
  exit 2
fi

listener_pid="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true)"
if [ -n "$listener_pid" ]; then
  listener_cmd="$(ps -p "$listener_pid" -o command= 2>/dev/null || true)"
  echo "Port $HOST:$PORT already has listener pid=$listener_pid" >&2
  echo "$listener_cmd" >&2

  if printf '%s' "$listener_cmd" | grep -Fq "$VMLX_BIN" && printf '%s' "$listener_cmd" | grep -Fq "$MODEL"; then
    if [ "${QMD_MLX_RESTART:-0}" = "1" ]; then
      echo "Stopping compatible existing vMLX listener because QMD_MLX_RESTART=1" >&2
      kill "$listener_pid"
      sleep 1
    else
      echo "Existing vMLX listener already matches this repo/model. Reusing it." >&2
      exit 0
    fi
  elif [ "${QMD_MLX_KILL_STALE:-0}" = "1" ]; then
    echo "Stopping stale listener because QMD_MLX_KILL_STALE=1" >&2
    kill "$listener_pid"
    sleep 1
  else
    echo "Refusing to start: a different process owns port $PORT." >&2
    echo "Kill it yourself, or rerun with QMD_MLX_KILL_STALE=1 if you are sure." >&2
    exit 1
  fi
fi

exec "$VMLX_BIN" serve "$MODEL" \
  --served-model-name "$SERVED_MODEL_NAME" \
  --embedding-model "$MODEL" \
  --host "$HOST" \
  --port "$PORT" \
  --max-tokens "$MAX_TOKENS" \
  --log-level "$LOG_LEVEL"
