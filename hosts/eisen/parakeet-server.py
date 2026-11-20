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
import os
import socket
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from parakeet_stt.transcribe import OnnxParakeet, read_audio

MAX_BODY_BYTES = 25 * 1024 * 1024
# An upload that stalls holds a request thread forever; two minutes is a
# generous *total* deadline for 25 MB (~218 KB/s floor) and still bounds it.
# A per-recv socket timeout alone is not enough: a drip that keeps bytes
# coming never blocks a syscall long enough to trip it.
READ_TIMEOUT_SECONDS = 120
# sd_listen_fds(3): fd 0,1,2 are stdio; the first passed socket is fd 3.
SD_LISTEN_FDS_START = 3


class Server:
    def __init__(self, model_dir: Path, threads: int | None):
        self.model = OnnxParakeet(model_dir, threads=threads)
        self.lock = threading.Lock()
        self.last_activity = time.monotonic()

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

        def setup(self) -> None:
            super().setup()
            self.request.settimeout(READ_TIMEOUT_SECONDS)

        def log_message(self, *args):  # keep stdout clean; errors go via send_error_json
            pass

        def _read_body(self, length: int) -> bytes:
            deadline = time.monotonic() + READ_TIMEOUT_SECONDS
            parts = []
            remaining = length
            while remaining > 0:
                budget = deadline - time.monotonic()
                if budget <= 0:
                    raise TimeoutError(f"body not complete within {READ_TIMEOUT_SECONDS}s")
                self.request.settimeout(budget)
                chunk = self.rfile.read1(min(remaining, 1 << 16))
                if not chunk:
                    raise OSError("connection closed mid-body")
                parts.append(chunk)
                remaining -= len(chunk)
            return b"".join(parts)

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
            server.last_activity = time.monotonic()
            if self.path in ("/health", "/health/"):
                self._json(200, {"status": "ok", "model": "parakeet-redux-onnx"})
            else:
                self._json(404, {"error": "not found"})

        def do_POST(self) -> None:
            server.last_activity = time.monotonic()
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
                data = self._read_body(length)
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


def _idle_watchdog(httpd, server: Server, idle_seconds: int) -> None:
    """Exit the process after idle_seconds without a request.

    With the socket unit holding :8091, a clean exit drops the ~1 GB resident
    model and the next connection cold-starts the service again. `shutdown`
    must run off the serve thread, which is why this is a watchdog, not a
    request hook.
    """
    while True:
        time.sleep(min(30, max(1, idle_seconds // 4)))
        if time.monotonic() - server.last_activity >= idle_seconds:
            print(f"parakeet-stt idle for {idle_seconds}s; exiting", file=sys.stderr, flush=True)
            httpd.shutdown()
            return


def _listen_socket(args):
    """The listening socket systemd passed, if this start was socket-activated.

    sd_listen_fds passes the accept() socket itself (Accept=no), so the service
    binds nothing: `ThreadingHTTPServer` is constructed unbound and handed the
    inherited fd. Without activation this returns None and the normal bind
    happens.
    """
    listen_fds = int(os.environ.get("LISTEN_FDS") or 0)
    listen_pid = int(os.environ.get("LISTEN_PID") or 0)
    if listen_fds >= 1 and listen_pid == os.getpid():
        return socket.fromfd(SD_LISTEN_FDS_START, socket.AF_INET, socket.SOCK_STREAM)
    return None


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="parakeet-server")
    parser.add_argument("--model-dir", required=True, help="directory with the ONNX files")
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8091)
    parser.add_argument("--threads", type=int, default=8,
                        help="onnxruntime intra-op threads (default 8; leaves headroom beside the LLM)")
    parser.add_argument("--idle-timeout", type=int, default=0,
                        help="exit after this many seconds without a request (0 = never; the socket unit re-starts the service on the next connection)")
    args = parser.parse_args(argv)

    model_dir = Path(args.model_dir).expanduser().resolve()
    if not (model_dir / "encoder-model.onnx").exists():
        print(f"error: no ONNX export in {model_dir}", file=sys.stderr)
        return 1
    print(f"loading Parakeet Redux from {model_dir} ...", file=sys.stderr, flush=True)
    server = Server(model_dir, threads=args.threads)
    inherited = _listen_socket(args)
    if inherited is not None:
        httpd = ThreadingHTTPServer((args.bind, args.port), make_handler(server), bind_and_activate=False)
        httpd.socket = inherited
        httpd.server_address = inherited.getsockname()
        httpd.server_activate()
        print(f"parakeet-stt serving on inherited socket {inherited.getsockname()}", file=sys.stderr, flush=True)
    else:
        httpd = ThreadingHTTPServer((args.bind, args.port), make_handler(server))
        print(f"parakeet-stt listening on {args.bind}:{args.port}", file=sys.stderr, flush=True)
    if args.idle_timeout > 0:
        threading.Thread(target=_idle_watchdog, args=(httpd, server, args.idle_timeout), daemon=True).start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
