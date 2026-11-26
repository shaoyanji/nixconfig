#!/usr/bin/env python3
"""Fixture for scripts/task/portfolio-smoke.py.

The smoke's value is its verdicts, so each check is pinned on both sides: an
endpoint that answers the wrong thing has to fail, and an empty database has to
pass (a smoke that needs data only works on the machine that has it). The DOM
check is optional by design, so `agent-browser` missing is a skip, not a
failure.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import subprocess
import sys
import unittest
import urllib.error
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "portfolio_smoke", ROOT / "scripts" / "task" / "portfolio-smoke.py"
)
smoke = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(smoke)

BASE = "http://127.0.0.1:8501"


def responder(routes: dict):
    """A fake fetch: path prefix -> (status, ctype, body)."""

    def fake(url, timeout=10.0):
        for prefix, answer in routes.items():
            if prefix in url:
                return answer
        raise AssertionError(f"unexpected request {url}")

    return fake


def body(payload):
    return json.dumps(payload)


class FetchTest(unittest.TestCase):
    def test_an_http_error_is_a_fetch_error_with_its_code(self):
        def refuse(*_a, **_k):
            raise urllib.error.HTTPError(BASE, 500, "boom", {}, io.BytesIO(b'{"error":"no"}'))

        with mock.patch("urllib.request.urlopen", refuse):
            with self.assertRaises(smoke.FetchError) as caught:
                smoke.fetch(f"{BASE}/api/health")
        self.assertIn("500", str(caught.exception))

    def test_a_refused_connection_is_unreachable(self):
        with mock.patch(
            "urllib.request.urlopen", side_effect=urllib.error.URLError("connection refused")
        ):
            with self.assertRaises(smoke.FetchError) as caught:
                smoke.fetch(f"{BASE}/api/health")
        self.assertIn("unreachable", str(caught.exception))

    def test_a_good_answer_is_status_type_and_body(self):
        answer = mock.MagicMock()
        answer.status = 200
        answer.headers.get.return_value = "application/json"
        answer.read.return_value = b'{"ok":true}'
        answer.__enter__.return_value = answer
        with mock.patch("urllib.request.urlopen", return_value=answer):
            status, ctype, payload = smoke.fetch(f"{BASE}/api/health")
        self.assertEqual((status, ctype), (200, "application/json"))
        self.assertEqual(json.loads(payload), {"ok": True})


class HealthTest(unittest.TestCase):
    def test_a_matching_service_passes(self):
        fetch = responder({"/api/health": (200, "application/json", body(
            {"ok": True, "service": "job-db-scraper", "uptime_seconds": 12}))})
        ok, detail = smoke.check_health(BASE, "job-db-scraper", fetch=fetch)
        self.assertTrue(ok)
        self.assertIn("12", detail)

    def test_ok_false_fails(self):
        fetch = responder({"/api/health": (200, "application/json", body({"ok": False}))})
        self.assertFalse(smoke.check_health(BASE, "job-db-scraper", fetch=fetch)[0])

    def test_the_wrong_service_fails(self):
        fetch = responder({"/api/health": (200, "application/json", body(
            {"ok": True, "service": "private-deals"}))})
        ok, detail = smoke.check_health(BASE, "job-db-scraper", fetch=fetch)
        self.assertFalse(ok)
        self.assertIn("private-deals", detail)

    def test_a_non_json_health_fails(self):
        fetch = responder({"/api/health": (200, "text/html", "<html>")})
        self.assertFalse(smoke.check_health(BASE, "job-db-scraper", fetch=fetch)[0])


class StatsTest(unittest.TestCase):
    def test_counters_pass(self):
        fetch = responder({"/api/stats": (200, "application/json", body({"postings": 3, "companies": 2}))})
        ok, detail = smoke.check_stats(BASE, fetch=fetch)
        self.assertTrue(ok)
        self.assertIn("2 counters", detail)

    def test_an_empty_object_fails(self):
        fetch = responder({"/api/stats": (200, "application/json", "{}")})
        self.assertFalse(smoke.check_stats(BASE, fetch=fetch)[0])

    def test_a_list_is_not_stats(self):
        fetch = responder({"/api/stats": (200, "application/json", "[]")})
        self.assertFalse(smoke.check_stats(BASE, fetch=fetch)[0])


class PageTest(unittest.TestCase):
    def test_html_with_the_marker_passes(self):
        fetch = responder({"/": (200, "text/html; charset=utf-8", '<html><div id="stats"></div>')})
        ok, detail = smoke.check_page(BASE, 'id="stats"', fetch=fetch)
        self.assertTrue(ok)
        self.assertIn('id="stats"', detail)

    def test_the_marker_missing_fails(self):
        fetch = responder({"/": (200, "text/html", "<html><body>nothing</body>")})
        ok, detail = smoke.check_page(BASE, 'id="stats"', fetch=fetch)
        self.assertFalse(ok)
        self.assertIn("missing", detail)

    def test_json_at_root_fails(self):
        fetch = responder({"/": (200, "application/json", "{}")})
        self.assertFalse(smoke.check_page(BASE, 'id="stats"', fetch=fetch)[0])


class SearchTest(unittest.TestCase):
    def test_items_wrapper_passes(self):
        fetch = responder({"/api/postings": (200, "application/json", body({"items": [{"id": 1}], "total": 1}))})
        ok, detail = smoke.check_search(BASE, "/api/postings", "sre", fetch=fetch)
        self.assertTrue(ok)
        self.assertIn("1 row", detail)

    def test_a_bare_list_passes(self):
        fetch = responder({"/api/deals": (200, "application/json", "[]")})
        self.assertTrue(smoke.check_search(BASE, "/api/deals", "deals", fetch=fetch)[0])

    def test_an_empty_answer_passes_unless_a_hit_is_required(self):
        fetch = responder({"/api/items": (200, "application/json", body({"items": []}))})
        self.assertTrue(smoke.check_search(BASE, "/api/items", "fleet", fetch=fetch)[0])
        ok, detail = smoke.check_search(BASE, "/api/items", "fleet", expect_hit=True, fetch=fetch)
        self.assertFalse(ok)
        self.assertIn("found nothing", detail)

    def test_a_shape_that_is_not_rows_fails(self):
        fetch = responder({"/api/items": (200, "application/json", body({"total": 0}))})
        self.assertFalse(smoke.check_search(BASE, "/api/items", "fleet", fetch=fetch)[0])

    def test_the_query_is_url_encoded(self):
        seen = {}

        def fetch(url, timeout=10.0):
            seen["url"] = url
            return 200, "application/json", "[]"

        smoke.check_search(BASE, "/api/items", "black forest labs", fetch=fetch)
        self.assertIn("q=black%20forest%20labs", seen["url"])


class DomTest(unittest.TestCase):
    def test_a_missing_browser_is_a_skip(self):
        with mock.patch.object(smoke.shutil, "which", return_value=None):
            ok, detail = smoke.check_dom(BASE, "#stats")
        self.assertIsNone(ok)
        self.assertIn("skipped", detail)

    def test_a_rendered_marker_passes(self):
        def run(argv, **_kw):
            if "open" in argv:
                return SimpleNamespace(returncode=0, stdout="opened", stderr="")
            return SimpleNamespace(returncode=0, stdout='"12 letters"\n', stderr="")

        with mock.patch.object(smoke.shutil, "which", return_value="/bin/agent-browser"):
            ok, detail = smoke.check_dom(BASE, "#stats", run=run)
        self.assertTrue(ok)
        self.assertIn("12 letters", detail)

    def test_an_empty_marker_fails(self):
        def run(argv, **_kw):
            return SimpleNamespace(returncode=0, stdout='""', stderr="")

        with mock.patch.object(smoke.shutil, "which", return_value="/bin/agent-browser"):
            ok, detail = smoke.check_dom(BASE, "#stats", run=run)
        self.assertFalse(ok)

    def test_a_failing_open_fails(self):
        def run(argv, **_kw):
            return SimpleNamespace(returncode=1, stdout="", stderr="chromium died")

        with mock.patch.object(smoke.shutil, "which", return_value="/bin/agent-browser"):
            ok, detail = smoke.check_dom(BASE, "#stats", run=run)
        self.assertFalse(ok)
        self.assertIn("chromium died", detail)

    def test_a_hung_browser_is_a_failure_not_a_traceback(self):
        with mock.patch.object(smoke.shutil, "which", return_value="/bin/agent-browser"), \
            mock.patch.object(
                smoke.subprocess, "run", side_effect=subprocess.TimeoutExpired("agent-browser", 45)
            ):
            ok, detail = smoke.check_dom(BASE, "#stats")
        self.assertFalse(ok)
        self.assertIn("did not finish", detail)


class ServiceTest(unittest.TestCase):
    ARGS = SimpleNamespace(
        jobs=BASE,
        deals=BASE,
        inventory=BASE,
        timeout=5.0,
        query="",
        expect_hit=False,
        browser=False,
        browser_cmd="agent-browser",
    )

    def test_all_four_checks_run_and_pass(self):
        fetch = responder({
            "/api/health": (200, "application/json", body({"ok": True, "service": "job-db-scraper"})),
            "/api/stats": (200, "application/json", body({"postings": 1})),
            "/api/postings": (200, "application/json", body({"items": []})),
            "/": (200, "text/html", '<html><div id="metric-jobs"></div>'),
        })
        result = smoke.smoke_service("jobs", smoke.SERVICES["jobs"], self.ARGS, fetch=fetch)
        self.assertTrue(result["ok"])
        self.assertEqual([c["check"] for c in result["checks"]], ["health", "stats", "page", "search"])
        self.assertEqual(result["base"], BASE)

    def test_an_unreachable_service_fails_once_without_hiding_it(self):
        def fetch(url, timeout=10.0):
            raise smoke.FetchError("unreachable: connection refused")

        result = smoke.smoke_service("deals", smoke.SERVICES["deals"], self.ARGS, fetch=fetch)
        self.assertFalse(result["ok"])
        self.assertEqual([c["check"] for c in result["checks"]], ["reachable"])

    def inventory_routes(self):
        return responder({
            "/api/health": (200, "application/json", body({"ok": True, "service": "inventory-site"})),
            "/api/stats": (200, "application/json", body({"items": 0})),
            "/api/items": (200, "application/json", body({"items": []})),
            "/": (200, "text/html", '<html><div id="stats"></div>'),
        })

    def test_without_the_flag_no_browser_is_started(self):
        run = mock.Mock(side_effect=AssertionError("browser used without the flag"))
        result = smoke.smoke_service(
            "inventory", smoke.SERVICES["inventory"], self.ARGS, self.inventory_routes(), run
        )
        self.assertTrue(result["ok"])
        self.assertEqual([c["check"] for c in result["checks"]], ["health", "stats", "page", "search"])
        run.assert_not_called()

    def test_with_the_flag_a_missing_browser_is_a_skip_not_a_pass(self):
        args = SimpleNamespace(**{**vars(self.ARGS), "browser": True})
        with mock.patch.object(smoke.shutil, "which", return_value=None):
            result = smoke.smoke_service(
                "inventory", smoke.SERVICES["inventory"], args, self.inventory_routes()
            )
        dom = result["checks"][-1]
        self.assertEqual(dom["check"], "dom")
        self.assertFalse(dom["ok"])
        self.assertIn("skipped", dom["detail"])


class MainTest(unittest.TestCase):
    PORTS = {"8501": "job-db-scraper", "8502": "private-deals", "8503": "inventory-site"}

    def fake_fetch(self, stats_status=200):
        def fetch(url, timeout=10.0):
            port = url.split(":")[2].split("/")[0]
            if url.endswith("/api/health"):
                return 200, "application/json", body({"ok": True, "service": self.PORTS[port]})
            if url.endswith("/api/stats"):
                if stats_status != 200:
                    return stats_status, "text/plain", "boom"
                return 200, "application/json", body({"n": 1})
            if "/api/" in url:
                return 200, "application/json", body({"items": []})
            return 200, "text/html", '<html><div id="stats"></div><div id="metric-jobs"></div>'

        return fetch

    def run_main(self, fetch, argv_extra=()):
        out = io.StringIO()
        argv = [
            "portfolio-smoke",
            "--jobs", "http://127.0.0.1:8501",
            "--deals", "http://127.0.0.1:8502",
            "--inventory", "http://127.0.0.1:8503",
            *argv_extra,
        ]
        with mock.patch.object(sys, "argv", argv), \
            mock.patch.object(smoke, "fetch", fetch), \
            contextlib.redirect_stdout(out):
            code = smoke.main()
        return code, out.getvalue()

    def test_a_green_run_exits_zero_with_json(self):
        code, out = self.run_main(self.fake_fetch())
        summary = json.loads(out)
        self.assertEqual(code, 0)
        self.assertTrue(summary["ok"])
        self.assertEqual(sorted(summary["services"]), ["deals", "inventory", "jobs"])

    def test_a_red_run_exits_one_and_names_the_service(self):
        code, out = self.run_main(self.fake_fetch(stats_status=500))
        summary = json.loads(out)
        self.assertEqual(code, 1)
        self.assertFalse(summary["ok"])
        self.assertEqual(sorted(summary["failed"]), ["deals", "inventory", "jobs"])
        self.assertTrue(all(not s["ok"] for s in summary["services"].values()))

    def test_toon_is_read_back_as_toon(self):
        code, out = self.run_main(self.fake_fetch(), ("--format", "toon"))
        self.assertEqual(code, 0)
        self.assertIn("run: portfolio-smoke", out)


class ToonTest(unittest.TestCase):
    def test_the_json_fallback_still_answers(self):
        with mock.patch.object(smoke.shutil, "which", return_value=None):
            rendered = smoke.to_toon({"ok": True})
        self.assertEqual(json.loads(rendered), {"ok": True})


if __name__ == "__main__":
    unittest.main()
