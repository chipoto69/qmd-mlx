#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
from huggingface_hub import snapshot_download

DEFAULT_MODELS = [
    "mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ",
    "mlx-community/Qwen3-Reranker-0.6B-mxfp8",
]
QUALITY_MODELS = [
    "mlx-community/Qwen3-Embedding-4B-4bit-DWQ",
]


def safe_name(model_id: str) -> str:
    return model_id.replace("/", "__")


def main() -> None:
    parser = argparse.ArgumentParser(description="Download MLX models for qmd provider experiments.")
    parser.add_argument("--model-dir", default="models/mlx", help="Target model directory")
    parser.add_argument("--quality", action="store_true", help="Also download quality-mode model candidates")
    parser.add_argument("models", nargs="*", help="Explicit Hugging Face model IDs")
    args = parser.parse_args()

    root = Path.cwd()
    model_dir = (root / args.model_dir).resolve()
    model_dir.mkdir(parents=True, exist_ok=True)

    models = args.models or DEFAULT_MODELS + (QUALITY_MODELS if args.quality else [])
    for model_id in models:
        target = model_dir / safe_name(model_id)
        print(f"==> downloading {model_id}")
        print(f"    target: {target}")
        snapshot_download(
            repo_id=model_id,
            local_dir=str(target),
            local_dir_use_symlinks=False,
            resume_download=True,
        )
        print(f"    done: {target}")


if __name__ == "__main__":
    main()
