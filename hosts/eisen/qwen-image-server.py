#!/usr/bin/env python3
"""Qwen-Image-2.1-Turbo image server — OpenAI-compatible /v1/images/generations.

Front-end on :8282 (systemd socket-activated, like Laya). The heavy work is
done by a persistent `sd-server` child on :8283, which keeps the weights
loaded across generations (the HDD cold load is paid once per session, not
once per image). The wrapper:

- forwards OpenAI-style requests (prompt, size, response_format) to
  sd-server, whose CLI defaults carry the fixed Turbo schedule
  (--steps 8 --cfg-scale 1.0 --sampling-method euler
  --sigmas 1.0,0.978453,0.95418,0.926626,0.89508,0.845148,0.704534,0.414568,0.0).
- claims the GPU before starting sd-server: it unloads llama-swap
  (POST /api/models/unload). If the unload fails (a generation is running),
  it returns 429 instead of fighting over the 8 GB VRAM.
- writes the active lock file (RUNTIME_DIRECTORY/active) while sd-server
  holds the GPU. The LLM router checks it and 429s chat generations
  (LLM wins by not starting, not by killing).
- touches RUNTIME_DIRECTORY/last-request on every request. The idle timer
  stops this service after 900 s with no request, killing sd-server and
  freeing the GPU. The socket stays listening, so the next request wakes it.

Stdlib only. One generation at a time (a lock) — the GPU budget is one
image at a time.

Env: PORT (8282), SD_SERVER, SD_PORT (8283), DIT, ENCODER, VAE,
LLAMA_SWAP (http://127.0.0.1:8080). RUNTIME_DIRECTORY is set by systemd.
"""
import json
import os
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

PORT = int(os.environ.get("PORT", "8282"))
SD_SERVER = os.environ.get("SD_SERVER", "sd-server")
SD_PORT = int(os.environ.get("SD_PORT", "8283"))
DIT = os.environ.get("DIT", "")
ENCODER = os.environ.get("ENCODER", "")
VAE = os.environ.get("VAE", "")
LLAMA_SWAP = os.environ.get("LLAMA_SWAP", "http://127.0.0.1:8080")
RUNTIME_DIR = os.environ.get("RUNTIME_DIRECTORY", "/run/qwen-image")
ACTIVE_FILE = os.path.join(RUNTIME_DIR, "active")
LAST_REQUEST_FILE = os.path.join(RUNTIME_DIR, "last-request")
GEN_TIMEOUT = 900  # s; a warm Turbo gen is ~1-2 min, cold load is separate
SD_START_TIMEOUT = 900  # s; the HDD cold load (12 GB) is ~10-12 min

# Turbo sigma schedule (9 values = 8 steps), from the sd.cpp docs.
TURBO_SIGMAS = "1.0,0.978453,0.95418,0.926626,0.89508,0.845148,0.704534,0.414568,0.0"

LOCK = threading.Lock()
_sd_proc = None  # the sd-server child, once started


def _touch_last_request():
    try:
        os.makedirs(RUNTIME_DIR, exist_ok=True)
        with open(LAST_REQUEST_FILE, "a"):
            os.utime(LAST_REQUEST_FILE, None)
    except OSError:
        pass


def _write_active():
    try:
        os.makedirs(RUNTIME_DIR, exist_ok=True)
        with open(ACTIVE_FILE, "w") as fh:
            fh.write(str(os.getpid()))
    except OSError:
        pass


def _clear_active():
    try:
        os.unlink(ACTIVE_FILE)
    except OSError:
        pass


def _http_json(method, url, body=None, timeout=30):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.status, resp.read()


def _sd_healthy():
    try:
        status, _ = _http_json("GET", f"http://127.0.0.1:{SD_PORT}/health", timeout=5)
        return status == 200
    except Exception:
        return False


def _unload_llama_swap():
    """Claim the GPU: unload llama-swap's models.

    Returns True if the GPU is free (unload ok, or nothing loaded).
    Returns False if the unload failed (a generation is likely running) —
    the caller must 429, not fight for VRAM.
    """
    try:
        status, _ = _http_json("POST", f"{LLAMA_SWAP}/api/models/unload", body={}, timeout=30)
        return 200 <= status < 300
    except Exception:
        return False


def _start_sd_server():
    """Start the sd-server child (if not running) and wait for readiness.

    A child that is alive but not yet healthy is still in its cold load —
    NEVER terminate it (a previous bug killed the nearly-loaded child on
    every request, so no request ever saw a healthy sd-server). Only
    spawn a new child if there is none or the old one died. If the wait
    times out, the child keeps loading; the next request will find it
    ready (or wait for the remainder).
    """
    global _sd_proc
    if _sd_proc is not None and _sd_proc.poll() is None and _sd_healthy():
        return True
    if _sd_proc is None or _sd_proc.poll() is not None:
        # No child, or the old one died — start a fresh one.
        _sd_proc = subprocess.Popen(
            [
                SD_SERVER,
                "--listen-ip", "127.0.0.1",
                "--listen-port", str(SD_PORT),
                "--diffusion-model", DIT,
                "--vae", VAE,
                "--llm", ENCODER,
                "--sigmas", TURBO_SIGMAS,
                "--steps", "8",
                "--cfg-scale", "1.0",
                "--sampling-method", "euler",
                "--offload-to-cpu",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    deadline = time.time() + SD_START_TIMEOUT
    while time.time() < deadline:
        if _sd_proc.poll() is not None:
            return False  # sd-server exited during the cold load
        if _sd_healthy():
            _write_active()
            return True
        time.sleep(5)
    # Timed out waiting, but the child is still loading — leave it alone.
    return False


def _stop_sd_server():
    global _sd_proc
    if _sd_proc is not None and _sd_proc.poll() is None:
        _sd_proc.terminate()
        try:
            _sd_proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            _sd_proc.kill()
    _sd_proc = None
    _clear_active()


def parse_size(size):
    """'1024x1024' -> (1024, 1024). sd.cpp needs dims divisible by 32."""
    try:
        w, h = size.lower().split("x")
        w, h = int(w), int(h)
    except Exception:
        return 1024, 1024
    w = max(32, (w // 32) * 32)
    h = max(32, (h // 32) * 32)
    return w, h


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if urlparse(self.path).path == "/health":
            self._json(200, {"status": "ok", "model": "qwen-image-2.1-turbo"})
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        if urlparse(self.path).path != "/v1/images/generations":
            self._json(404, {"error": "not found"})
            return
        try:
            n = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(n) or b"{}")
        except Exception as e:
            self._json(400, {"error": f"bad json: {e}"})
            return
        prompt = (body.get("prompt") or "").strip()
        if not prompt:
            self._json(400, {"error": "prompt is required"})
            return
        width, height = parse_size(str(body.get("size") or "1024x1024"))
        fmt = str(body.get("response_format") or "b64_json")
        _touch_last_request()
        with LOCK:
            # Claim the GPU (unload llama-swap) before starting sd-server.
            if not _unload_llama_swap():
                self._json(429, {"error": "LLM generation in progress; GPU busy, retry later"})
                return
            if not _start_sd_server():
                self._json(504, {"error": "image server failed to start (cold load)"})
                return
            _touch_last_request()
            try:
                status, raw = _http_json(
                    "POST",
                    f"http://127.0.0.1:{SD_PORT}/v1/images/generations",
                    body={"prompt": prompt, "size": f"{width}x{height}", "output_format": "png"},
                    timeout=GEN_TIMEOUT,
                )
            except urllib.error.HTTPError as e:
                self._json(e.code, {"error": f"sd-server: {e.read().decode(errors='replace')[:500]}"})
                return
            except Exception as e:
                self._json(502, {"error": f"sd-server unreachable: {e}"})
                return
            _touch_last_request()
            if status != 200:
                self._json(status, {"error": f"sd-server: {raw.decode(errors='replace')[:500]}"})
                return
            try:
                resp = json.loads(raw)
                b64 = resp["data"][0]["b64_json"]
            except Exception as e:
                self._json(502, {"error": f"bad sd-server response: {e}"})
                return
        if fmt == "url":
            data = [{"url": f"data:image/png;base64,{b64}"}]
        else:
            data = [{"b64_json": b64}]
        self._json(200, {"created": 0, "data": data})


def _shutdown(signum, frame):
    _stop_sd_server()
    sys.exit(0)


def main():
    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)
    # systemd socket activation: the socket unit passes its listening FD as
    # FD 3 (LISTEN_FDS=1). Use it instead of binding (the port is already
    # held by systemd). Fall back to a normal bind when run standalone.
    listen_fds = int(os.environ.get("LISTEN_FDS", "0"))
    if listen_fds >= 1:
        sock = socket.fromfd(3, socket.AF_INET, socket.SOCK_STREAM)
        server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler, bind_and_activate=False)
        server.socket = sock
        server.server_bind = lambda: None  # already bound by systemd
        server.server_activate()
    else:
        server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    try:
        server.serve_forever()
    finally:
        _stop_sd_server()


if __name__ == "__main__":
    main()
