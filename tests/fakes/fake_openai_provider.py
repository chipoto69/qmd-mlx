#!/usr/bin/env python3
"""Tiny OpenAI-compatible fake provider for qmd PR #619 contract tests.

Implements only the surfaces qmd's OpenAICompatibleLLM uses:
- GET  /v1/models
- POST /v1/embeddings
- POST /v1/rerank
- POST /v1/chat/completions

No external dependencies. Deterministic vectors keep this usable in CI and on
machines without MLX/vMLX installed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

EMBED_MODEL = "fake-embed-8d"
RERANK_MODEL = "fake-rerank"
GENERATE_MODEL = "fake-generate"
VECTOR_DIMS = 8


def deterministic_embedding(text: str) -> list[float]:
    digest = hashlib.sha256(text.encode("utf-8", errors="replace")).digest()
    values = []
    for idx in range(VECTOR_DIMS):
        raw = int.from_bytes(digest[idx * 2 : idx * 2 + 2], "big")
        values.append((raw / 65535.0) * 2.0 - 1.0)
    norm = math.sqrt(sum(value * value for value in values)) or 1.0
    return [round(value / norm, 8) for value in values]


def score_document(query: str, document: str) -> float:
    query_terms = {term.lower().strip(".,:;!?()[]{}") for term in query.split() if len(term) > 2}
    doc_lower = document.lower()
    overlap = sum(1 for term in query_terms if term and term in doc_lower)
    bonus = 0.25 if "provider" in doc_lower else 0.0
    score = min(0.99, 0.15 + overlap * 0.12 + bonus)
    return round(score, 6)


class FakeOpenAIHandler(BaseHTTPRequestHandler):
    server_version = "qmd-fake-openai/1.0"

    def log_message(self, format: str, *args: Any) -> None:  # keep stdout clean
        return

    @property
    def request_log_path(self) -> Path:
        return self.server.request_log_path  # type: ignore[attr-defined]

    def read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("content-length") or 0)
        if length <= 0:
            return {}
        raw = self.rfile.read(length).decode("utf-8", errors="replace")
        return json.loads(raw or "{}")

    def write_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def append_log(self, payload: dict[str, Any] | None = None) -> None:
        row = {
            "ts": time.time(),
            "method": self.command,
            "path": self.path,
            "authorization": self.headers.get("authorization"),
        }
        if payload is not None:
            row["json"] = payload
        with self.request_log_path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(row, sort_keys=True) + "\n")

    def do_GET(self) -> None:  # noqa: N802 - stdlib handler API
        if self.path != "/v1/models":
            self.append_log()
            self.write_json(404, {"error": {"message": f"unknown path: {self.path}"}})
            return
        self.append_log()
        self.write_json(
            200,
            {
                "object": "list",
                "data": [
                    {"id": EMBED_MODEL, "object": "model"},
                    {"id": RERANK_MODEL, "object": "model"},
                    {"id": GENERATE_MODEL, "object": "model"},
                ],
            },
        )

    def do_POST(self) -> None:  # noqa: N802 - stdlib handler API
        try:
            payload = self.read_json()
        except Exception as exc:  # intentionally broad: fake server should report bad contracts
            self.append_log({"_decode_error": str(exc)})
            self.write_json(400, {"error": {"message": f"invalid json: {exc}"}})
            return

        self.append_log(payload)

        if self.path == "/v1/embeddings":
            self.handle_embeddings(payload)
            return
        if self.path == "/v1/rerank":
            self.handle_rerank(payload)
            return
        if self.path == "/v1/chat/completions":
            self.handle_chat_completions(payload)
            return

        self.write_json(404, {"error": {"message": f"unknown path: {self.path}"}})

    def handle_embeddings(self, payload: dict[str, Any]) -> None:
        model = payload.get("model")
        if model != EMBED_MODEL:
            self.write_json(400, {"error": {"message": f"unexpected embedding model: {model}"}})
            return

        raw_input = payload.get("input", [])
        inputs = raw_input if isinstance(raw_input, list) else [raw_input]
        texts = [str(item) for item in inputs]
        self.write_json(
            200,
            {
                "object": "list",
                "model": model,
                "data": [
                    {
                        "object": "embedding",
                        "index": index,
                        "embedding": deterministic_embedding(text),
                    }
                    for index, text in enumerate(texts)
                ],
                "usage": {"prompt_tokens": sum(len(text.split()) for text in texts), "total_tokens": sum(len(text.split()) for text in texts)},
            },
        )

    def handle_rerank(self, payload: dict[str, Any]) -> None:
        model = payload.get("model")
        if model != RERANK_MODEL:
            self.write_json(400, {"error": {"message": f"unexpected rerank model: {model}"}})
            return

        query = str(payload.get("query") or "")
        documents = payload.get("documents") or []
        if not isinstance(documents, list):
            self.write_json(400, {"error": {"message": "documents must be a list"}})
            return

        top_n = int(payload.get("top_n") or len(documents))
        ranked = sorted(
            (
                {"index": index, "relevance_score": score_document(query, str(document))}
                for index, document in enumerate(documents)
            ),
            key=lambda item: item["relevance_score"],
            reverse=True,
        )[:top_n]
        self.write_json(200, {"model": model, "results": ranked})

    def handle_chat_completions(self, payload: dict[str, Any]) -> None:
        model = payload.get("model")
        if model != GENERATE_MODEL:
            self.write_json(400, {"error": {"message": f"unexpected generation model: {model}"}})
            return

        content = "\n".join(
            [
                "lex: provider embeddings",
                "vec: external provider embeddings",
                "hyde: Synthetic agent trace packet about qmd OpenAI-compatible provider support.",
            ]
        )
        self.write_json(
            200,
            {
                "id": "chatcmpl-fake-qmd-contract",
                "object": "chat.completion",
                "created": int(time.time()),
                "model": model,
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": content},
                        "finish_reason": "stop",
                    }
                ],
                "usage": {"prompt_tokens": 1, "completion_tokens": len(content.split()), "total_tokens": len(content.split()) + 1},
            },
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run qmd fake OpenAI-compatible provider")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=18092)
    parser.add_argument("--log-jsonl", required=True)
    args = parser.parse_args()

    request_log_path = Path(args.log_jsonl)
    request_log_path.parent.mkdir(parents=True, exist_ok=True)
    request_log_path.write_text("", encoding="utf-8")

    server = ThreadingHTTPServer((args.host, args.port), FakeOpenAIHandler)
    server.request_log_path = request_log_path  # type: ignore[attr-defined]
    print(f"fake OpenAI-compatible provider listening on http://{args.host}:{args.port}/v1", flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
