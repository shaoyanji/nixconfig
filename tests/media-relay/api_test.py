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

# One `rclone lsjson` answer: the video, its poster (metadata, never a row) and a
# `.txt` the extension set leaves out. ModTime carries rclone's nanoseconds.
REMOTE_OBJECTS = [
    {
        "Path": "vidA/Big Buck Bunny [vidA].mp4",
        "Name": "Big Buck Bunny [vidA].mp4",
        "Size": 5000,
        "ModTime": "2026-11-19T00:00:00.123456789Z",
        "IsDir": False,
    },
    {"Path": "vidA/poster.jpg", "Size": 1200, "ModTime": "2026-11-19T00:00:00Z", "IsDir": False},
    {"Path": "vidA/notes.txt", "Size": 10, "ModTime": "2026-11-19T00:00:00Z", "IsDir": False},
]
STORE_URL = "https://edge.example/media/vidA/Big%20Buck%20Bunny%20%5BvidA%5D.mp4"


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


class Remote(unittest.TestCase):
    """The bucket listing, mapped to the rows the cloud section draws."""

    def setUp(self):
        self.saved = api.R2_PUBLIC
        api.R2_PUBLIC = "https://edge.example/media"

    def tearDown(self):
        api.R2_PUBLIC = self.saved

    def test_the_indexs_three_rules_hold_for_a_bucket(self):
        items = api.remote_items(REMOTE_OBJECTS)
        self.assertEqual([item["name"] for item in items], ["Big Buck Bunny [vidA].mp4"])
        item = items[0]
        self.assertEqual(item["kind"], "video")
        self.assertEqual(item["size"], 5000)
        self.assertEqual(item["poster"], "https://edge.example/media/vidA/poster.jpg")
        # The poster is not a row and is not counted: the same rule as the local
        # manifest, so a stored video and a fetched one look alike.
        self.assertEqual(sum(i["size"] for i in items), 5000)

    def test_the_link_is_the_edge_and_it_is_quoted(self):
        self.assertEqual(api.remote_items(REMOTE_OBJECTS)[0]["url"], STORE_URL)

    def test_a_folder_without_a_poster_has_no_poster_field(self):
        items = api.remote_items([REMOTE_OBJECTS[0]])
        self.assertIsNone(items[0]["poster"])

    def test_nanosecond_modtimes_parse(self):
        self.assertEqual(api.epoch("2026-11-19T00:00:00.123456789Z"), api.epoch("2026-11-19T00:00:00Z"))
        self.assertEqual(api.epoch("nonsense"), 0)
        self.assertEqual(api.epoch(None), 0)

    def test_junk_entries_are_dropped_rather_than_crashing(self):
        self.assertEqual(api.remote_items([None, {}, {"Path": ""}, {"Path": ".hidden/"}]), [])


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
        store = root / "yt-store"
        store.write_text(f"#!/bin/sh\necho {STORE_URL!r}\n".replace("'", '"'))
        listing = root / "r2-list"
        listing.write_text("#!/bin/sh\ncat <<'JSON'\n" + json.dumps(REMOTE_OBJECTS) + "\nJSON\n")
        for script in (search, fetch, store, listing):
            script.chmod(0o755)

        cls.port = free_port()
        env = dict(os.environ)
        env.update(
            {
                "PORT": str(cls.port),
                "BIND_ADDR": "127.0.0.1",
                "YT_SEARCH": str(search),
                "YT_GET": str(fetch),
                "YT_STORE": str(store),
                "R2_LIST": str(listing),
                "R2_PUBLIC": "https://edge.example/media",
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

    def test_health_says_the_bucket_is_configured(self):
        status, body = call(self.port, "/api/health")
        self.assertEqual(status, 200)
        self.assertTrue(body["r2"])

    def test_store_queues_a_job_that_reaches_done(self):
        status, job = call(self.port, "/api/store", {"url": "https://youtu.be/dQw4w9WgXcQ", "title": "remote"})
        self.assertEqual(status, 202)
        self.assertEqual(job["mode"], "r2")

        deadline = time.time() + 15
        done = None
        while time.time() < deadline:
            _, listing = call(self.port, "/api/jobs")
            done = next(
                (r for r in listing["jobs"] if r["id"] == job["id"] and r["state"] not in ("queued", "running")),
                None,
            )
            if done:
                break
            time.sleep(0.1)
        self.assertIsNotNone(done, "the queued store never finished")
        self.assertEqual(done["state"], "done")
        # A store's output is a URL at the edge, not a path on this host.
        self.assertEqual(done["out"], STORE_URL)

    def test_a_plain_fetch_is_not_a_store(self):
        status, job = call(self.port, "/api/fetch", {"url": "https://youtu.be/dQw4w9WgXcQ"})
        self.assertEqual(status, 202)
        self.assertEqual(job["mode"], "local")

    def test_cloud_listing_carries_absolute_links(self):
        status, body = call(self.port, "/api/r2?refresh=1")
        self.assertEqual(status, 200)
        self.assertEqual(body["count"], 1)
        self.assertEqual(body["bytes"], 5000)
        self.assertEqual(body["items"][0]["url"], STORE_URL)

    def test_unknown_route_is_404(self):
        self.assertEqual(call(self.port, "/api/nope")[0], 404)
        self.assertEqual(call(self.port, "/api/jobs/../fetch")[0], 404)


if __name__ == "__main__":
    unittest.main(verbosity=2)
