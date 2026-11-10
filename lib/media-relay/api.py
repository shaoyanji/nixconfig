#!/usr/bin/env python3
"""Search YouTube and queue fetches for the media library page.

The page is static and nginx serves it; this process is the only part of it that
writes. Everything is loopback, reached through the vhost's `/api/` proxy, so
the tailnet mount stays the whole exposure:

    GET  /api/search?q=...   one `yt-dlp -J ytsearch`, cached briefly
    POST /api/fetch          queue a `yt-get` run, one at a time
    GET  /api/jobs           the queue's recent records
    GET  /api/health         liveness, and whether a cookie jar is readable

Why not Invidious: it is a Crystal service with Postgres and a companion, and
its product is a public API-compatible front end. `yt-dlp -J ytsearch` returns
the same list — title, channel, duration, thumbnail — in one request, which is
all the page draws. The fetch already exists as `yt-get`, so this adds a form,
not a second YouTube client.
"""
import collections
import json
import os
import queue
import subprocess
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

YT_GET = os.environ.get("YT_GET", "yt-get")
YT_SEARCH = os.environ.get("YT_SEARCH", "yt-search")
COOKIE_FILE = os.environ.get("COOKIE_FILE", "")
REQUIRE_COOKIES = os.environ.get("REQUIRE_COOKIES", "0") == "1"

# Only the URLs a fetch can act on. `yt-get` accepts any URL and would happily
# pull an arbitrary host, so the allow-list lives here rather than in the page:
# a tailnet client is trusted, a page field that turns into a server-side fetch
# is not.
ALLOWED_HOSTS = {
    "youtube.com",
    "www.youtube.com",
    "m.youtube.com",
    "music.youtube.com",
    "youtu.be",
    "www.youtu.be",
}

SEARCH_TTL = 600
SEARCH_CACHE_MAX = 64
SEARCH_TIMEOUT = 60
# A one-hour video fetches in minutes at line rate, so 15 minutes is generous for
# a VOD and still a bound on anything that keeps producing bytes. `yt-get`
# refuses a live stream on its own; this is the belt under that.
FETCH_TIMEOUT = 900
MAX_ACTIVE = 4
HISTORY = 40
MAX_BODY = 8192

_search_lock = threading.Lock()
_search_cache = collections.OrderedDict()
_search_sem = threading.BoundedSemaphore(2)


class RequestError(Exception):
    """A request the caller can fix, mapped onto a 4xx/5xx by the handler."""

    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


def clean_url(value):
    """Return the URL if it is a YouTube watch URL, else None."""
    if not isinstance(value, str):
        return None
    value = value.strip()
    if not value or len(value) > 2048:
        return None
    if any(ord(c) < 0x20 or c == " " for c in value):
        return None
    try:
        parsed = urlparse(value)
        port = parsed.port
    except ValueError:
        return None
    if parsed.scheme not in ("http", "https"):
        return None
    # A userinfo or an explicit port is how `youtube.com@evil.example` gets in.
    if parsed.username or parsed.password or port is not None:
        return None
    host = (parsed.hostname or "").lower().rstrip(".")
    if host not in ALLOWED_HOSTS:
        return None
    return value


def clean_title(value):
    """A display-only label: no control characters, no unbounded length."""
    if not isinstance(value, str):
        return ""
    value = "".join(c for c in value if ord(c) >= 0x20).strip()
    return value[:200]


def clamp_limit(value, default=15, low=1, high=20):
    try:
        number = int(str(value).strip())
    except (TypeError, ValueError):
        return default
    return max(low, min(high, number))


def last_line(text):
    for line in reversed((text or "").splitlines()):
        line = line.strip()
        if line:
            return line
    return ""


def tail(text, limit=400):
    text = " ".join((text or "").split())
    if not text:
        return ""
    return text[-limit:]


def search(query, limit=15):
    """Run one `yt-search`, remembering the answer for a few minutes."""
    key = (query.strip().lower(), limit)
    now = time.time()
    with _search_lock:
        hit = _search_cache.get(key)
        if hit and hit[0] > now:
            _search_cache.move_to_end(key)
            return hit[1]

    # Two concurrent yt-dlp searches already cost this 2-vCPU host more than the
    # page is worth; a third waits, and a queue that never drains is an error
    # rather than a hang.
    if not _search_sem.acquire(timeout=20):
        raise RequestError(429, "another search is still running")
    try:
        try:
            proc = subprocess.run(
                [YT_SEARCH, "--limit", str(limit), query],
                capture_output=True,
                text=True,
                timeout=SEARCH_TIMEOUT,
            )
        except subprocess.TimeoutExpired:
            raise RequestError(504, f"the search took longer than {SEARCH_TIMEOUT} s")
    finally:
        _search_sem.release()

    if proc.returncode != 0:
        raise RequestError(502, tail(proc.stderr) or f"yt-search exited {proc.returncode}")
    try:
        items = json.loads(proc.stdout or "[]")
    except json.JSONDecodeError:
        raise RequestError(502, "yt-search printed something that is not JSON")
    if not isinstance(items, list):
        raise RequestError(502, "yt-search printed JSON that is not a list")

    payload = {"query": query, "count": len(items), "items": items}
    with _search_lock:
        _search_cache[key] = (now + SEARCH_TTL, payload)
        while len(_search_cache) > SEARCH_CACHE_MAX:
            _search_cache.popitem(last=False)
    return payload


ACTIVE = ("queued", "running")


def run_fetch(job):
    """Execute one fetch. Mutates the record the queue already holds."""
    job["state"] = "running"
    job["started"] = int(time.time())
    try:
        proc = subprocess.run(
            [YT_GET, job["url"]],
            capture_output=True,
            text=True,
            timeout=FETCH_TIMEOUT,
        )
        out = last_line(proc.stdout)
        if proc.returncode == 0 and out:
            job["state"] = "done"
            job["out"] = out
        else:
            job["state"] = "failed"
            job["error"] = tail(proc.stderr) or f"yt-get exited {proc.returncode}"
    except subprocess.TimeoutExpired:
        job["state"] = "failed"
        job["error"] = f"the fetch exceeded {FETCH_TIMEOUT} s"
    except Exception as exc:  # noqa: BLE001 - a crash here has to show on the page
        job["state"] = "failed"
        job["error"] = f"{type(exc).__name__}: {exc}"
    finally:
        job["ended"] = int(time.time())


class Jobs:
    """One worker, so two fetches never fight over the same folder or the line."""

    def __init__(self, runner, max_active=MAX_ACTIVE, history=HISTORY):
        self._runner = runner
        self._max_active = max_active
        self._history = history
        self._lock = threading.Lock()
        self._queue = queue.Queue()
        self._jobs = collections.OrderedDict()
        self._thread = None

    def start(self):
        with self._lock:
            if self._thread is not None:
                return
            self._thread = threading.Thread(target=self._loop, name="media-relay-fetch", daemon=True)
            self._thread.start()

    def _loop(self):
        while True:
            job = self._queue.get()
            try:
                self._runner(job)
            except Exception as exc:  # noqa: BLE001 - the worker must not die
                job["state"] = "failed"
                job["error"] = f"{type(exc).__name__}: {exc}"
                job["ended"] = int(time.time())
            finally:
                self._queue.task_done()

    def submit(self, url, title):
        with self._lock:
            if sum(1 for j in self._jobs.values() if j["state"] in ACTIVE) >= self._max_active:
                return None
            job = {
                "id": uuid.uuid4().hex[:12],
                "url": url,
                "title": title,
                "state": "queued",
                "queued": int(time.time()),
                "started": None,
                "ended": None,
                "out": None,
                "error": None,
            }
            self._jobs[job["id"]] = job
            while len(self._jobs) > self._history:
                oldest = next(iter(self._jobs.values()))
                if oldest["state"] in ACTIVE:
                    break
                self._jobs.popitem(last=False)
            record = dict(job)
        self._queue.put(job)
        return record

    def snapshot(self):
        with self._lock:
            return [dict(j) for j in reversed(self._jobs.values())]

    def active(self):
        with self._lock:
            return sum(1 for j in self._jobs.values() if j["state"] in ACTIVE)


JOBS = Jobs(run_fetch)


class Handler(BaseHTTPRequestHandler):
    server_version = "media-relay-api/1"

    def _send(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _health(self):
        self._send(
            200,
            {
                "ok": True,
                "cookies": bool(COOKIE_FILE) and os.access(COOKIE_FILE, os.R_OK),
                "require_cookies": REQUIRE_COOKIES,
                "active": JOBS.active(),
            },
        )

    def _get(self):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        if parsed.path == "/api/health":
            return self._health()
        if parsed.path == "/api/jobs":
            return self._send(200, {"jobs": JOBS.snapshot()})
        if parsed.path == "/api/search":
            text = (query.get("q") or [""])[0].strip()
            if len(text) < 2:
                return self._send(400, {"error": "q needs at least two characters"})
            if len(text) > 200:
                return self._send(400, {"error": "q is longer than 200 characters"})
            limit = clamp_limit((query.get("limit") or [""])[0])
            return self._send(200, search(text, limit))
        return self._send(404, {"error": "no such route"})

    def _post(self):
        parsed = urlparse(self.path)
        if parsed.path != "/api/fetch":
            return self._send(404, {"error": "no such route"})
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            return self._send(400, {"error": "bad Content-Length"})
        if length <= 0 or length > MAX_BODY:
            return self._send(400, {"error": f"body must be 1..{MAX_BODY} bytes"})
        raw = self.rfile.read(length)
        ctype = (self.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        try:
            if ctype == "application/json":
                data = json.loads(raw.decode("utf-8"))
                if not isinstance(data, dict):
                    raise ValueError
                url, title = data.get("url"), data.get("title")
            else:
                form = parse_qs(raw.decode("utf-8"))
                url = (form.get("url") or [""])[0]
                title = (form.get("title") or [""])[0]
        except (ValueError, UnicodeDecodeError):
            return self._send(400, {"error": "the body is neither JSON nor a form"})

        clean = clean_url(url)
        if clean is None:
            return self._send(400, {"error": "not a YouTube URL"})
        job = JOBS.submit(clean, clean_title(title))
        if job is None:
            return self._send(429, {"error": f"{MAX_ACTIVE} fetches are already queued"})
        return self._send(202, job)

    def do_GET(self):
        try:
            self._get()
        except RequestError as exc:
            self._send(exc.status, {"error": str(exc)})
        except Exception as exc:  # noqa: BLE001 - answer instead of dropping the socket
            self._send(500, {"error": f"{type(exc).__name__}: {exc}"})

    def do_POST(self):
        try:
            self._post()
        except RequestError as exc:
            self._send(exc.status, {"error": str(exc)})
        except Exception as exc:  # noqa: BLE001
            self._send(500, {"error": f"{type(exc).__name__}: {exc}"})

    def log_message(self, fmt, *args):
        print(f"media-relay-api: {self.address_string()} {fmt % args}", flush=True)


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    bind = os.environ.get("BIND_ADDR", "127.0.0.1")
    port = int(os.environ.get("PORT", "8100"))
    JOBS.start()
    server = Server((bind, port), Handler)
    print(f"media-relay-api: listening on http://{bind}:{port}/api/", flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
