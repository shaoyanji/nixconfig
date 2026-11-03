#!/usr/bin/env python3
"""Stage 1 as a resident process: question -> query object over a unix socket.

The per-call cost this removes is stage 1's own, not the executor's: importing the
interpreter and loading the 1 MB model is ~80 ms of the ~250 ms a cold `ops:q`
costs, and a refusal paid all of it to say nothing. Here the model is loaded once
and reloaded only when the artifact on disk changes, so a retrained model is picked
up at the next question instead of at the next login.

It answers with the SAME JSON `model.py predict` prints, so the caller (`q.sh`)
keeps one execution path and stages 2-4 are untouched: a wrong object is caught by
the same schema check and the same empty-result refusal as a hand-written one. If
this process is not running the caller falls back to the interpreter, which is
why nothing breaks on a host without the unit.

Wire format is HTTP over a unix socket, the pattern kg-sidecar already uses, so a
bash caller reaches it with `curl --unix-socket` and no client of its own.

  POST /predict  {"question": "which notes are blocked"} -> the query object
  GET  /stats    what is loaded: model path, mtime, questions answered, load ms

Exit 0 on SIGTERM/SIGINT. A stale model is a reload, never an answer.
"""
import argparse
import json
import os
import signal
import socketserver
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import model  # noqa: E402  (sibling module, path set above)


class State:
    """The loaded artifact and the counters /stats reports."""

    def __init__(self, path, repo):
        self.path = Path(path)
        self.repo = Path(repo)
        self.lock = threading.Lock()
        self.mtime = -1.0
        self.model = None
        self.load_ms = 0.0
        self.answered = 0
        self.started = time.time()
        self.reload()

    def reload(self):
        mtime = self.path.stat().st_mtime
        began = time.time()
        data = json.loads(self.path.read_text())
        self.model = data
        self.mtime = mtime
        self.load_ms = (time.time() - began) * 1000.0

    def predict(self, question):
        # A retrain rewrites the artifact; serving the previous one is the stale
        # copy that a correct answer is indistinguishable from, so the stat IS the
        # invalidation.
        with self.lock:
            try:
                if self.path.stat().st_mtime != self.mtime:
                    self.reload()
            except FileNotFoundError:
                pass
            began = time.time()
            out = model.query_for(self.model, question, self.model.get("margin", 1.0))
            self.answered += 1
            return out, (time.time() - began) * 1000.0


STATE = None


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("selector: %s\n" % (fmt % args))

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.split("?")[0] != "/stats":
            return self._send(404, {"error": "not found"})
        return self._send(
            200,
            {
                "model": str(STATE.path),
                "model_mtime": STATE.mtime,
                "model_bytes": STATE.path.stat().st_size,
                "load_ms": round(STATE.load_ms, 2),
                "answered": STATE.answered,
                "uptime_s": round(time.time() - STATE.started, 1),
                "margin": STATE.model.get("margin"),
                "pid": os.getpid(),
            },
        )

    def do_POST(self):
        if self.path.split("?")[0] != "/predict":
            return self._send(404, {"error": "not found"})
        try:
            length = int(self.headers.get("Content-Length") or 0)
            request = json.loads(self.rfile.read(length) or b"{}")
            question = request.get("question") or ""
            if not isinstance(question, str) or not question.strip():
                return self._send(400, {"error": "question must be a non-empty string"})
        except (ValueError, TypeError) as exc:
            return self._send(400, {"error": "malformed request: %s" % exc})
        out, ms = STATE.predict(question)
        out = dict(out)
        out["elapsed_ms"] = round(ms, 2)
        return self._send(200, out)


class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    global STATE
    ap = argparse.ArgumentParser()
    ap.add_argument("--socket", required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--repo", default=str(HERE.parent.parent))
    args = ap.parse_args()

    if not Path(args.model).is_file():
        sys.stderr.write(
            "selector: no trained model at %s (task ops:q:train)\n" % args.model
        )
        return 1
    STATE = State(args.model, args.repo)

    sock = Path(args.socket)
    sock.parent.mkdir(parents=True, exist_ok=True)
    if sock.exists() or sock.is_socket():
        sock.unlink()
    server = Server(str(sock), Handler)
    os.chmod(sock, 0o600)

    def stop(_signum, _frame):
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    sys.stderr.write(
        "selector: serving %s on unix:%s (load %.1f ms, margin %s)\n"
        % (args.model, sock, STATE.load_ms, STATE.model.get("margin"))
    )
    sys.stderr.flush()
    try:
        server.serve_forever()
    finally:
        server.server_close()
        try:
            sock.unlink()
        except FileNotFoundError:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
