#!/usr/bin/env python3
"""Minimal HTTP front-end for the vendored Parakeet Redux transcribe pipeline.

Routes:
  GET  /health      -> {"status": "ok", "model": "parakeet-redux-onnx"}
  POST /transcribe  -> audio bytes in the request body (any ffmpeg-decodable
                       format, e.g. wav/mp3/ogg); returns
                       {"text": ..., "duration_seconds": ..., "segments": [...]}

One transcription at a time (a lock serialises requests): the ONNX sessions
are small (~1 GB resident, CPU-only) but serialising keeps latency predictable
beside the LLM workload on the same box. Body cap 25 MB (about 26 minutes of
16 kHz mono wav; longer audio should be chunked by the client).

The model is loaded once at startup; /health answers only after load.
"""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from parakeet_stt.transcribe import OnnxParakeet, read_audio

MAX_BODY_BYTES = 25 * 1024 * 1024


class Server:
    def __init__(self, model_dir: Path, threads: int | None):
        self.model = OnnxParakeet(model_dir, threads=threads)
        self.lock = threading.Lock()

    def transcribe_bytes(self, data: bytes) -> dict:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".audio") as tmp:
            tmp.write(data)
            tmp_path = Path(tmp.name)
        try:
            pcm = read_audio(tmp_path)
            with self.lock:
                return self.model.transcribe(pcm, timestamps="segment")
        finally:
            tmp_path.unlink(missing_ok=True)


def make_handler(server: Server):
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *args):  # keep stdout clean; errors go via send_error_json
            pass

        def _json(self, status: int, payload: dict, close: bool = False) -> None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            if close:
                # The request body was not consumed. Under HTTP/1.1 keep-alive
                # the client may still send it, and those bytes would be parsed
                # as the next request line on this connection. Close instead.
                self.close_connection = True
                self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self) -> None:
            if self.path in ("/health", "/health/"):
                self._json(200, {"status": "ok", "model": "parakeet-redux-onnx"})
            else:
                self._json(404, {"error": "not found"})

        def do_POST(self) -> None:
            if self.path not in ("/transcribe", "/transcribe/"):
                self._json(404, {"error": "not found"}, close=True)
                return
            length = int(self.headers.get("Content-Length") or 0)
            if length <= 0:
                self._json(400, {"error": "empty body"})
                return
            if length > MAX_BODY_BYTES:
                self._json(413, {"error": "body exceeds 25 MB cap"}, close=True)
                return
            try:
                data = self.rfile.read(length)
            except OSError as exc:
                self._json(400, {"error": f"failed to read body: {exc}"})
                return
            try:
                result = server.transcribe_bytes(data)
            except Exception as exc:  # decode failure, too-short audio, inference error
                self._json(422, {"error": str(exc)})
                return
            self._json(200, result)

    return Handler


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="parakeet-server")
    parser.add_argument("--model-dir", required=True, help="directory with the ONNX files")
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8091)
    parser.add_argument("--threads", type=int, default=8,
                        help="onnxruntime intra-op threads (default 8; leaves headroom beside the LLM)")
    args = parser.parse_args(argv)

    model_dir = Path(args.model_dir).expanduser().resolve()
    if not (model_dir / "encoder-model.onnx").exists():
        print(f"error: no ONNX export in {model_dir}", file=sys.stderr)
        return 1
    print(f"loading Parakeet Redux from {model_dir} ...", file=sys.stderr, flush=True)
    server = Server(model_dir, threads=args.threads)
    httpd = ThreadingHTTPServer((args.bind, args.port), make_handler(server))
    print(f"parakeet-stt listening on {args.bind}:{args.port}", file=sys.stderr, flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
