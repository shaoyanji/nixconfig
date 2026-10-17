#!/usr/bin/env python3
"""Qwen-Image-2.1-Turbo image server — OpenAI-compatible /v1/images/generations.

Translates an OpenAI-style request into a stable-diffusion.cpp `sd-cli`
invocation (Turbo: fixed 8-step sigma schedule, CFG 1.0, euler) and returns
the PNG as b64_json (or a data: URL for response_format=url).

Stdlib only (like parakeet-server.py). One generation at a time (a lock) —
sd-cli is a one-shot process and the GPU/CPU budget is one image at a time.

Env: PORT (default 8282), SD_CLI, DIT, ENCODER, VAE, MMPROJ (editing only),
OUT_DIR (default /tmp/qwen-image-out).
"""
import base64
import json
import os
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

PORT = int(os.environ.get("PORT", "8282"))
SD_CLI = os.environ.get("SD_CLI", "sd-cli")
DIT = os.environ.get("DIT", "")
ENCODER = os.environ.get("ENCODER", "")
VAE = os.environ.get("VAE", "")
MMPROJ = os.environ.get("MMPROJ", "")
OUT_DIR = os.environ.get("OUT_DIR", "/tmp/qwen-image-out")
GEN_TIMEOUT = 900  # s; a 1024x1024 Turbo gen should be well under this

LOCK = threading.Lock()


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


def generate(prompt, width, height, ref_paths):
    """Run sd-cli once. Returns the PNG bytes."""
    os.makedirs(OUT_DIR, exist_ok=True)
    fd, out_path = tempfile.mkstemp(prefix="qwen-img-", suffix=".png", dir=OUT_DIR)
    os.close(fd)
    try:
        cmd = [
            SD_CLI,
            "--diffusion-model", DIT,
            "--vae", VAE,
            "--llm", ENCODER,
            "-p", prompt,
            "--width", str(width),
            "--height", str(height),
            "--sigmas", "qwen-image-2.1-turbo",
            "--steps", "8",
            "--cfg-scale", "1.0",
            "--sampling-method", "euler",
            "--offload-to-cpu",
            "-o", out_path,
        ]
        if ref_paths:
            # Editing: vision weights + reference images.
            cmd += ["--llm_vision", MMPROJ]
            for rp in ref_paths:
                cmd += ["-r", rp]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=GEN_TIMEOUT)
        if r.returncode != 0:
            raise RuntimeError(f"sd-cli exit {r.returncode}: {(r.stderr or '').strip()[-2000:]}")
        with open(out_path, "rb") as fh:
            return fh.read()
    finally:
        try:
            os.unlink(out_path)
        except OSError:
            pass


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
        # Editing (image inputs) is not part of the OpenAI images API surface
        # this wrapper exposes yet — text-to-image only. (sd-cli takes -r +
        # --llm_vision; wire it when the editing endpoint is needed.)
        with LOCK:
            try:
                png = generate(prompt, width, height, ref_paths=[])
            except subprocess.TimeoutExpired:
                self._json(504, {"error": "generation timed out"})
                return
            except Exception as e:
                self._json(500, {"error": str(e)})
                return
        b64 = base64.b64encode(png).decode()
        if fmt == "url":
            data = [{"url": f"data:image/png;base64,{b64}"}]
        else:
            data = [{"b64_json": b64}]
        self._json(200, {"created": 0, "data": data})


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
