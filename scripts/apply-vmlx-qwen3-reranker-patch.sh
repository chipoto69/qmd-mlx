#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$ROOT/patches/vmlx-1.5.49-qwen3-reranker-causal.patch"
V_MLX_PYTHON="${V_MLX_PYTHON:-/Users/rudlord/.local/share/uv/tools/vmlx/bin/python}"
EXPECTED_VERSION="${EXPECTED_VERSION:-1.5.49}"

if [ ! -x "$V_MLX_PYTHON" ]; then
  echo "vMLX Python not executable: $V_MLX_PYTHON" >&2
  echo "Set V_MLX_PYTHON=/path/to/vmlx/tool/python" >&2
  exit 2
fi

if [ ! -f "$PATCH_FILE" ]; then
  echo "Missing patch file: $PATCH_FILE" >&2
  exit 2
fi

read -r V_MLX_VERSION RERANKER_FILE <<EOF_INFO
$($V_MLX_PYTHON - <<'PY'
import importlib.metadata as md
import vmlx_engine.reranker as reranker
print(md.version('vmlx'), reranker.__file__)
PY
)
EOF_INFO

echo "vmlx_version=$V_MLX_VERSION"
echo "reranker_file=$RERANKER_FILE"

if [ "$V_MLX_VERSION" != "$EXPECTED_VERSION" ]; then
  echo "Expected vmlx $EXPECTED_VERSION, got $V_MLX_VERSION. Refusing blind patch." >&2
  exit 1
fi

if grep -q '_is_causal_reranker_model' "$RERANKER_FILE"; then
  echo "Patch already appears applied. Verifying syntax only."
  "$V_MLX_PYTHON" -m py_compile "$RERANKER_FILE"
  exit 0
fi

BACKUP_DIR="$ROOT/.tmp/backups/vmlx-$V_MLX_VERSION"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/reranker.py.$(date +%Y%m%d-%H%M%S).pre-qwen3-causal-fix"
cp "$RERANKER_FILE" "$BACKUP_FILE"
echo "backup=$BACKUP_FILE"

PATCH_TMP="$ROOT/.tmp/vmlx-qwen3-reranker-causal.patch"
mkdir -p "$(dirname "$PATCH_TMP")"
# Strip labels so the patch applies from the package root.
sed 's#^--- a/vmlx_engine/reranker.py#--- vmlx_engine/reranker.py#; s#^+++ b/vmlx_engine/reranker.py#+++ vmlx_engine/reranker.py#' "$PATCH_FILE" > "$PATCH_TMP"

SITE_ROOT="$($V_MLX_PYTHON - <<'PY'
import pathlib, vmlx_engine
print(pathlib.Path(vmlx_engine.__file__).resolve().parent.parent)
PY
)"

(
  cd "$SITE_ROOT"
  patch --forward -p0 < "$PATCH_TMP"
)

"$V_MLX_PYTHON" -m py_compile "$RERANKER_FILE"
echo "RESULT=PASS applied vMLX Qwen3 reranker causal patch"
