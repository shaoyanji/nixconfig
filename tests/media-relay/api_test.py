#!/usr/bin/env python3
"""The media-relay API, tested against its own process.

Two halves. The pure checks pin the URL allow-list and the limit clamp, because
those are what stand between a page field and a server-side fetch of an
arbitrary host. The live checks start api.py with stub `yt-search` and `yt-get`
scripts and drive it over HTTP: search, a rejected URL, a queued fetch that
finishes, and a 404. Nothing here touches YouTube.

Usage: python3 api_test.py
Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
"""
import importlib.util
import json
import os
import pathlib
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
API = HERE.parent.parent / "lib" / "media-relay" / "api.py"

if not API.is_file():
    print(f"api_test: {API} is missing", file=sys.stderr)
    raise SystemExit(2)

spec = importlib.util.spec_from_file_location("media_relay_api", API)
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)

SEARCH_PAYLOAD = [
    {
        "id": "vidA",
        "title": "Big Buck Bunny",
        "channel": "Blender",
        "duration": 596,
        "live": "not_live",
        "url": "https://www.youtube.com/watch?v=vidA",
        "thumb": "https://i.ytimg.com/vi/vidA/mqdefault.jpg",
    }
]


class Urls(unittest.TestCase):
    def test_accepts_the_shapes_youtube_hands_out(self):
        for url in (
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtube.com/watch?v=dQw4w9WgXcQ&t=42",
            "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://music.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtu.be/dQw4w9WgXcQ",
        ):
            self.assertEqual(api.clean_url(url), url)

    def test_rejects_everything_else(self):
        for url in (
            None,
            "",
            "  ",
            "not a url",
            "javascript:alert(1)",
            "file:///etc/passwd",
            "http://127.0.0.1:8100/api/health",
            "https://www.youtube.com.evil.example/watch?v=x",
            "https://www.youtube.com@evil.example/watch?v=x",
            "https://evil.example/youtube.com",
            "https://www.youtube.com:8443/watch?v=x",
            "https://www.youtube.com/watch?v=" + "x" * 2048,
            "https://www.youtube.com/watch?v=x\nHost: evil",
        ):
            self.assertIsNone(api.clean_url(url), url)

    def test_titles_are_display_only(self):
        self.assertEqual(api.clean_title("  x\x00y  "), "xy")
        self.assertEqual(api.clean_title(None), "")
        self.assertEqual(len(api.clean_title("z" * 500)), 200)


class Limits(unittest.TestCase):
    def test_clamps(self):
        self.assertEqual(api.clamp_limit("7"), 7)
        self.assertEqual(api.clamp_limit("0"), 1)
        self.assertEqual(api.clamp_limit("500"), 20)
        self.assertEqual(api.clamp_limit("abc"), 15)
        self.assertEqual(api.clamp_limit(""), 15)


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def wait_ready(port, deadline):
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/api/health", timeout=1) as response:
                if response.status == 200:
                    return True
        except (urllib.error.URLError, ConnectionError):
            time.sleep(0.05)
    return False


def call(port, path, body=None):
    url = f"http://127.0.0.1:{port}{path}"
    data = None
    headers = {}
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method="POST" if body is not None else "GET")
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status, json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read().decode() or "{}")


class Live(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = pathlib.Path(cls.tmp.name)
        search = root / "yt-search"
        search.write_text("#!/bin/sh\ncat <<'JSON'\n" + json.dumps(SEARCH_PAYLOAD) + "\nJSON\n")
        fetch = root / "yt-get"
        fetch.write_text("#!/bin/sh\necho \"http://delphi:8461/vidA/Big Buck Bunny.mp4\"\n")
        for script in (search, fetch):
            script.chmod(0o755)

        cls.port = free_port()
        env = dict(os.environ)
        env.update(
            {
                "PORT": str(cls.port),
                "BIND_ADDR": "127.0.0.1",
                "YT_SEARCH": str(search),
                "YT_GET": str(fetch),
                "COOKIE_FILE": "",
            }
        )
        cls.proc = subprocess.Popen(
            [sys.executable, str(API)],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if not wait_ready(cls.port, time.time() + 15):
            cls.proc.kill()
            raise RuntimeError("the API never answered /api/health")

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        try:
            cls.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            cls.proc.kill()
        cls.tmp.cleanup()

    def test_health_reports_the_cookie_jar(self):
        status, body = call(self.port, "/api/health")
        self.assertEqual(status, 200)
        self.assertTrue(body["ok"])
        self.assertFalse(body["cookies"])

    def test_search_returns_the_trimmed_list(self):
        status, body = call(self.port, "/api/search?q=big+buck+bunny")
        self.assertEqual(status, 200)
        self.assertEqual(body["count"], 1)
        item = body["items"][0]
        self.assertEqual(item["id"], "vidA")
        self.assertTrue(item["thumb"].startswith("https://i.ytimg.com/"))

    def test_search_needs_a_query(self):
        self.assertEqual(call(self.port, "/api/search?q=a")[0], 400)
        self.assertEqual(call(self.port, "/api/search")[0], 400)

    def test_fetch_refuses_a_non_youtube_url(self):
        status, body = call(self.port, "/api/fetch", {"url": "http://127.0.0.1:8100/"})
        self.assertEqual(status, 400)
        self.assertIn("YouTube", body["error"])

    def test_fetch_runs_and_lands_in_the_jobs_list(self):
        status, job = call(
            self.port,
            "/api/fetch",
            {"url": "https://youtu.be/dQw4w9WgXcQ", "title": "a test"},
        )
        self.assertEqual(status, 202)
        self.assertEqual(job["state"], "queued")

        deadline = time.time() + 15
        done = None
        while time.time() < deadline:
            _, listing = call(self.port, "/api/jobs")
            for record in listing["jobs"]:
                if record["id"] == job["id"] and record["state"] != "queued" and record["state"] != "running":
                    done = record
                    break
            if done:
                break
            time.sleep(0.1)
        self.assertIsNotNone(done, "the queued fetch never finished")
        self.assertEqual(done["state"], "done")
        self.assertEqual(done["title"], "a test")
        self.assertTrue(done["out"].endswith("Big Buck Bunny.mp4"))

    def test_unknown_route_is_404(self):
        self.assertEqual(call(self.port, "/api/nope")[0], 404)
        self.assertEqual(call(self.port, "/api/jobs/../fetch")[0], 404)


if __name__ == "__main__":
    unittest.main(verbosity=2)
