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
import pathlib
import shlex
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
            ok, detail = smoke.check_dom(BASE, "#stats", attempts=1, run=run)
        self.assertFalse(ok)
        self.assertIn("missing or empty", detail)

    def test_a_container_the_js_fills_a_beat_late_is_waited_for(self):
        answers = iter(["", '"1 machine"'])

        def run(argv, **_kw):
            if "open" in argv:
                return SimpleNamespace(returncode=0, stdout="opened", stderr="")
            return SimpleNamespace(returncode=0, stdout=next(answers), stderr="")

        with mock.patch.object(smoke.shutil, "which", return_value="/bin/agent-browser"):
            ok, detail = smoke.check_dom(BASE, "#machines", run=run, sleep=lambda _s: None)
        self.assertTrue(ok)
        self.assertIn("1 machine", detail)

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


class AnalyticsTest(unittest.TestCase):
    def test_a_real_report_passes_and_counts_its_buckets(self):
        fetch = responder({"/api/analytics": (200, "application/json", body(
            {"generated_at": "2026-11-26T00:00:00Z", "window_days": 30,
             "categories": [{"name": "computing"}], "locations": []}))})
        ok, detail = smoke.check_analytics(BASE, fetch=fetch)
        self.assertTrue(ok)
        self.assertIn("1 bucket row(s)", detail)

    def test_an_empty_object_fails(self):
        fetch = responder({"/api/analytics": (200, "application/json", "{}")})
        self.assertFalse(smoke.check_analytics(BASE, fetch=fetch)[0])

    def test_a_report_without_a_window_fails(self):
        fetch = responder({"/api/analytics": (200, "application/json", body({"items": []}))})
        ok, detail = smoke.check_analytics(BASE, fetch=fetch)
        self.assertFalse(ok)
        self.assertIn("names no window", detail)

    def test_a_500_is_reported_with_its_path(self):
        fetch = responder({"/api/analytics": (500, "application/json", body({"error": "boom"}))})
        ok, detail = smoke.check_analytics(BASE, fetch=fetch)
        self.assertFalse(ok)
        self.assertIn("/api/analytics answered 500", detail)


class EndpointTest(unittest.TestCase):
    def test_an_items_wrapper_passes(self):
        fetch = responder({"/api/presets": (200, "application/json", body({"items": [1, 2], "total": 2}))})
        ok, detail = smoke.check_endpoint(BASE, "/api/presets", fetch=fetch)
        self.assertTrue(ok)
        self.assertIn("2 row(s)", detail)

    def test_an_object_without_items_passes(self):
        fetch = responder({"/api/schedules": (200, "application/json", body({"total": 0}))})
        self.assertTrue(smoke.check_endpoint(BASE, "/api/schedules", fetch=fetch)[0])

    def test_an_html_answer_fails(self):
        fetch = responder({"/api/machines": (200, "text/html", "<html>")})
        self.assertFalse(smoke.check_endpoint(BASE, "/api/machines", fetch=fetch)[0])


class ExportTest(unittest.TestCase):
    def test_a_csv_packet_passes_with_its_header(self):
        fetch = responder({"format=csv": (200, "text/csv; charset=utf-8", "id,company\n1,ACME\n")})
        ok, detail = smoke.check_export(BASE, "/api/postings/export?format=csv", "text/csv", fetch=fetch)
        self.assertTrue(ok)
        self.assertIn("bytes of text/csv", detail)

    def test_a_markdown_packet_passes(self):
        fetch = responder({"format=markdown": (200, "text/markdown; charset=utf-8", "# Job posting packet\n")})
        self.assertTrue(
            smoke.check_export(BASE, "/api/postings/export?format=markdown", "text/markdown", fetch=fetch)[0]
        )

    def test_an_rss_feed_is_a_document(self):
        fetch = responder({"feed.rss": (200, "application/rss+xml", "<rss><channel/></rss>")})
        ok, detail = smoke.check_export(BASE, "/api/deals/feed.rss", "xml", fetch=fetch)
        self.assertTrue(ok)
        self.assertIn("application/rss+xml", detail)

    def test_a_json_export_has_to_parse(self):
        fetch = responder({"/api/deals/export": (200, "application/json", body({"items": [{"id": 1}]}))})
        ok, detail = smoke.check_export(BASE, "/api/deals/export", "json", fetch=fetch)
        self.assertTrue(ok)
        self.assertIn("1 row(s)", detail)
        broken = responder({"/api/deals/export": (200, "application/json", "<html>")})
        self.assertFalse(smoke.check_export(BASE, "/api/deals/export", "json", fetch=broken)[0])

    def test_json_served_where_csv_was_asked_for_fails(self):
        fetch = responder({"format=csv": (200, "application/json", "{}")})
        ok, detail = smoke.check_export(BASE, "/api/postings/export?format=csv", "text/csv", fetch=fetch)
        self.assertFalse(ok)
        self.assertIn("served application/json", detail)

    def test_an_empty_document_fails(self):
        fetch = responder({"format=csv": (200, "text/csv", "  \n")})
        ok, detail = smoke.check_export(BASE, "/api/postings/export?format=csv", "text/csv", fetch=fetch)
        self.assertFalse(ok)
        self.assertIn("empty", detail)

    def test_a_500_is_reported_with_its_path(self):
        fetch = responder({"export.csv": (500, "application/json", body({"error": "boom"}))})
        ok, detail = smoke.check_export(BASE, "/api/export.csv", "text/csv", fetch=fetch)
        self.assertFalse(ok)
        self.assertIn("/api/export.csv answered 500", detail)


def prober(allows: dict, status=405):
    """A fake OPTIONS probe: path tail -> the Allow header the server sends."""

    def fake(url, timeout=10.0):
        for tail, allow in allows.items():
            if url.endswith(tail):
                return status, allow, ""
        return 405, "GET, HEAD", ""

    return fake


class RouteTest(unittest.TestCase):
    def test_an_advertised_method_proves_the_route_is_deployed(self):
        probe = prober({"/api/postings/1/stage": "GET, HEAD, PATCH"})
        ok, detail = smoke.check_route(BASE, "/api/postings/1/stage", "PATCH", probe=probe)
        self.assertTrue(ok)
        self.assertIn("GET, HEAD, PATCH", detail)

    def test_a_404_is_reported_as_not_deployed(self):
        probe = prober({"/api/postings/1/notes": ""}, status=404)
        ok, detail = smoke.check_route(BASE, "/api/postings/1/notes", "POST", probe=probe)
        self.assertFalse(ok)
        self.assertIn("not deployed", detail)

    def test_a_path_that_only_advertises_get_is_named_as_missing_its_method(self):
        probe = prober({"/api/watchlists/1/poll": "GET, HEAD"})
        ok, detail = smoke.check_route(BASE, "/api/watchlists/1/poll", "POST", probe=probe)
        self.assertFalse(ok)
        self.assertIn("POST is missing", detail)

    def test_an_answers_allow_list_is_read_case_insensitively(self):
        probe = prober({"/api/watchlists/1/poll": "get,head,post"}, status=200)
        self.assertTrue(smoke.check_route(BASE, "/api/watchlists/1/poll", "POST", probe=probe)[0])

    def test_the_real_probe_reads_allow_from_a_405(self):
        class Answer:
            status = 405
            headers = {"Allow": "GET, HEAD, PATCH"}

            def read(self):
                return b"Method Not Allowed"

        def opener(_request, timeout=10.0):
            raise urllib.error.HTTPError(BASE, 405, "no", Answer.headers, io.BytesIO(b"no body"))

        status, allow, _body = smoke.probe_method(f"{BASE}/api/postings/1/stage", opener=opener)
        self.assertEqual((status, allow), (405, "GET, HEAD, PATCH"))


class QrTest(unittest.TestCase):
    def test_an_svg_label_passes(self):
        fetch = responder({"/api/items/7/qr.svg": (200, "image/svg+xml; charset=utf-8",
                                                         '<svg xmlns="http://www.w3.org/2000/svg"></svg>')})
        ok, detail = smoke.check_qr(BASE, 7, fetch=fetch)
        self.assertTrue(ok)
        self.assertIn("item 7", detail)

    def test_json_with_200_is_not_a_label(self):
        fetch = responder({"/api/items/7/qr.svg": (200, "application/json", "{}")})
        ok, detail = smoke.check_qr(BASE, 7, fetch=fetch)
        self.assertFalse(ok)
        self.assertIn("served application/json", detail)

    def test_html_that_is_not_svg_fails(self):
        fetch = responder({"/api/items/7/qr.svg": (200, "image/svg+xml", "<html>")})
        self.assertFalse(smoke.check_qr(BASE, 7, fetch=fetch)[0])

    def test_the_first_item_is_read_from_the_register(self):
        fetch = responder({"/api/items?limit=1": (200, "application/json", body({"items": [{"id": 12}]}))})
        self.assertEqual(smoke.first_item_id(BASE, fetch=fetch), 12)

    def test_an_empty_register_has_no_item_to_label(self):
        fetch = responder({"/api/items?limit=1": (200, "application/json", body({"items": []}))})
        self.assertIsNone(smoke.first_item_id(BASE, fetch=fetch))


class ServiceTest(unittest.TestCase):
    ARGS = SimpleNamespace(
        jobs=BASE,
        deals=BASE,
        inventory=BASE,
        clanker=BASE,
        link_vault=BASE,
        timeout=5.0,
        query="",
        expect_hit=False,
        browser=False,
        browser_cmd="agent-browser",
    )

    def test_every_check_runs_and_passes(self):
        fetch = responder({
            "/api/health": (200, "application/json", body({"ok": True, "service": "job-db-scraper"})),
            "/api/stats": (200, "application/json", body({"postings": 1})),
            "/api/analytics": (200, "application/json", body({"generated_at": "now", "companies": []})),
            # The export and writing-route keys come before `/api/postings`,
            # which is a prefix of both of them.
            "format=csv": (200, "text/csv; charset=utf-8", "id,company\n"),
            "format=markdown": (200, "text/markdown; charset=utf-8", "# Job posting packet\n"),
            "/api/postings/1/stage": (405, "text/plain", "Method Not Allowed"),
            "/api/postings/1/notes": (405, "text/plain", "Method Not Allowed"),
            "/api/postings": (200, "application/json", body({"items": []})),
            "/": (200, "text/html", '<html><div id="metric-jobs"></div>'),
        })
        probe = prober({"/stage": "GET, HEAD, PATCH", "/notes": "GET, HEAD, POST"})
        result = smoke.smoke_service("jobs", smoke.SERVICES["jobs"], self.ARGS, fetch=fetch, probe=probe)
        self.assertTrue(result["ok"])
        self.assertEqual(
            [c["check"] for c in result["checks"]],
            ["health", "stats", "analytics", "page", "search", "export-csv", "export-markdown", "patch stage", "post notes"],
        )
        self.assertEqual(result["base"], BASE)

    def test_clanker_runs_its_endpoints_and_no_search(self):
        fetch = responder({
            "/api/health": (200, "application/json", body({"ok": True, "service": "clanker-runner"})),
            "/api/stats": (200, "application/json", body({"jobs": 0})),
            "/api/machines": (200, "application/json", body({"items": []})),
            "/api/presets": (200, "application/json", body({"items": []})),
            "/api/schedules": (200, "application/json", body({"items": []})),
            "/": (200, "text/html", '<html><div id="machines"></div>'),
        })
        result = smoke.smoke_service("clanker", smoke.SERVICES["clanker"], self.ARGS, fetch=fetch)
        self.assertTrue(result["ok"])
        self.assertEqual(
            [c["check"] for c in result["checks"]],
            ["health", "stats", "page", "machines", "presets", "schedules"],
        )

    def test_link_vault_searches_links_and_tags(self):
        fetch = responder({
            "/api/health": (200, "application/json", body({"ok": True, "service": "link-vault"})),
            "/api/stats": (200, "application/json", body({"bookmarks": 0})),
            "/api/links": (200, "application/json", body({"links": [{"id": 1}], "count": 1})),
            "/api/tags": (200, "application/json", body({"tags": ["nix"], "count": 1})),
            "/api/feeds": (200, "application/json", body({"items": [], "total": 0})),
            "/api/analytics": (200, "application/json", body({"generated_at": "now", "tags": []})),
            "/": (200, "text/html", '<html><section id="metrics"></section>'),
        })
        result = smoke.smoke_service("link_vault", smoke.SERVICES["link_vault"], self.ARGS, fetch=fetch)
        self.assertTrue(result["ok"])
        self.assertEqual(
            [c["check"] for c in result["checks"]],
            ["health", "stats", "analytics", "page", "search", "tags", "feeds"],
        )
        self.assertIn("1 row(s)", [c["detail"] for c in result["checks"] if c["check"] == "tags"][0])

    def test_deals_runs_its_exports_and_the_watchlist_poll_route(self):
        fetch = responder({
            "/api/health": (200, "application/json", body({"ok": True, "service": "private-deals"})),
            "/api/stats": (200, "application/json", body({"deals": 0})),
            "/api/analytics": (200, "application/json", body({"generated_at": "now", "sources": []})),
            "/api/deals/feed.rss": (200, "application/rss+xml", "<rss><channel/></rss>"),
            "/api/deals/export": (200, "application/json", body({"items": []})),
            "/api/export.csv": (200, "text/csv; charset=utf-8", "id,title\n"),
            "/api/watchlists/1/poll": (405, "text/plain", "Method Not Allowed"),
            "/api/deals": (200, "application/json", body({"items": []})),
            "/": (200, "text/html", '<html><div id="stats"></div>'),
        })
        probe = prober({"/api/watchlists/1/poll": "GET, HEAD, POST"})
        result = smoke.smoke_service("deals", smoke.SERVICES["deals"], self.ARGS, fetch=fetch, probe=probe)
        self.assertTrue(result["ok"])
        self.assertEqual(
            [c["check"] for c in result["checks"]],
            ["health", "stats", "analytics", "page", "search", "export-json", "feed-rss", "export-csv", "post watchlist-poll"],
        )

    def test_a_missing_writing_route_fails_the_service(self):
        fetch = responder({
            "/api/health": (200, "application/json", body({"ok": True, "service": "private-deals"})),
            "/api/stats": (200, "application/json", body({"deals": 0})),
            "/api/analytics": (200, "application/json", body({"generated_at": "now"})),
            "/api/deals/feed.rss": (200, "application/rss+xml", "<rss/>"),
            "/api/deals/export": (200, "application/json", body({"items": []})),
            "/api/export.csv": (200, "text/csv", "id\n"),
            "/api/watchlists/1/poll": (404, "text/plain", "404 page not found"),
            "/api/deals": (200, "application/json", body({"items": []})),
            "/": (200, "text/html", '<html><div id="stats"></div>'),
        })
        probe = prober({"/api/watchlists/1/poll": ""}, status=404)
        result = smoke.smoke_service("deals", smoke.SERVICES["deals"], self.ARGS, fetch=fetch, probe=probe)
        self.assertFalse(result["ok"])
        failed = [c for c in result["checks"] if not c["ok"]]
        self.assertEqual([c["check"] for c in failed], ["post watchlist-poll"])
        self.assertIn("not deployed", failed[0]["detail"])

    def test_a_links_wrapper_is_rows(self):
        self.assertEqual(smoke.rows_of({"links": [{"id": 1}], "count": 1}), [{"id": 1}])
        self.assertEqual(smoke.rows_of({"tags": ["nix"], "count": 1}), ["nix"])

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
            "/api/analytics": (200, "application/json", body(
                {"generated_at": "now", "window_days": 30, "categories": [], "warranty": []})),
            "/api/items": (200, "application/json", body({"items": []})),
            "/": (200, "text/html", '<html><div id="stats"></div>'),
        })

    def test_without_the_flag_no_browser_is_started(self):
        run = mock.Mock(side_effect=AssertionError("browser used without the flag"))
        result = smoke.smoke_service(
            "inventory", smoke.SERVICES["inventory"], self.ARGS, self.inventory_routes(), run
        )
        self.assertTrue(result["ok"])
        self.assertEqual(
            [c["check"] for c in result["checks"]],
            ["health", "stats", "analytics", "page", "search", "qr"],
        )
        run.assert_not_called()

    def test_an_empty_register_marks_the_qr_check_skipped_not_silent(self):
        result = smoke.smoke_service(
            "inventory", smoke.SERVICES["inventory"], self.ARGS, self.inventory_routes()
        )
        qr = [c for c in result["checks"] if c["check"] == "qr"][0]
        self.assertTrue(qr["ok"])
        self.assertTrue(qr.get("skipped"))
        self.assertIn("no item to label", qr["detail"])

    def test_a_real_item_is_labelled(self):
        routes = {
            "/api/items/12/qr.svg": (200, "image/svg+xml", '<svg xmlns="http://www.w3.org/2000/svg"/>'),
            "/api/items?limit=1": (200, "application/json", body({"items": [{"id": 12}]})),
            "/api/items": (200, "application/json", body({"items": [{"id": 12}], "total": 1})),
            "/api/health": (200, "application/json", body({"ok": True, "service": "inventory-site"})),
            "/api/stats": (200, "application/json", body({"items": 1})),
            "/api/analytics": (200, "application/json", body({"generated_at": "now", "items": 1})),
            "/": (200, "text/html", '<html><div id="stats"></div>'),
        }
        result = smoke.smoke_service(
            "inventory", smoke.SERVICES["inventory"], self.ARGS, responder(routes)
        )
        self.assertTrue(result["ok"])
        qr = [c for c in result["checks"] if c["check"] == "qr"][0]
        self.assertNotIn("skipped", qr)
        self.assertIn("item 12", qr["detail"])

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


class ClankerBrowserTest(unittest.TestCase):
    def test_the_flag_turns_on_the_browser_and_points_at_the_wrapper(self):
        args = smoke.apply_browser_flags(
            SimpleNamespace(browser=False, browser_cmd="agent-browser", clanker_browser=True)
        )
        self.assertTrue(args.browser)
        self.assertTrue(args.browser_cmd.endswith("scripts/task/clanker-browser.sh"))
        self.assertTrue(pathlib.Path(args.browser_cmd).is_file())

    def test_without_the_flag_nothing_moves(self):
        args = smoke.apply_browser_flags(
            SimpleNamespace(browser=False, browser_cmd="agent-browser", clanker_browser=False)
        )
        self.assertEqual((args.browser, args.browser_cmd), (False, "agent-browser"))

    def test_the_wrapper_escapes_an_eval_script_so_it_survives_the_hop(self):
        """`instabox.sh exec` joins its argv, so the script must arrive quoted."""
        wrapper = pathlib.Path(smoke.ROOT) / "scripts/task/clanker-browser.sh"
        script = "(() => { const el = document.querySelector('#metrics'); return el ? el.textContent : ''; })()"
        printed = subprocess.run(
            [str(wrapper), "--print-command", "eval", script],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        self.assertEqual(shlex.split(printed), ["agent-browser", "eval", script])
        self.assertTrue(printed.startswith("agent-browser "))  # named once, not twice
        self.assertNotEqual(printed.split("eval", 1)[1].strip(), script)  # quoting happened


class MainTest(unittest.TestCase):
    PORTS = {
        "8501": "job-db-scraper",
        "8502": "private-deals",
        "8503": "inventory-site",
        "8504": "clanker-runner",
        "8506": "link-vault",
    }

    def fake_fetch(self, stats_status=200):
        def fetch(url, timeout=10.0):
            port = url.split(":")[2].split("/")[0]
            if url.endswith("/api/health"):
                return 200, "application/json", body({"ok": True, "service": self.PORTS[port]})
            if url.endswith("/api/stats"):
                if stats_status != 200:
                    return stats_status, "text/plain", "boom"
                return 200, "application/json", body({"n": 1})
            if "/api/analytics" in url:
                return 200, "application/json", body({"generated_at": "now", "items": []})
            # A writing route answers the smoke's GET with 405, as Go's mux does.
            if any(url.split("?")[0].endswith(tail) for tail in ("/stage", "/notes", "/poll")):
                return 405, "text/plain", "Method Not Allowed"
            if "format=csv" in url or url.endswith("/api/export.csv"):
                return 200, "text/csv; charset=utf-8", "id,company\n"
            if "format=markdown" in url:
                return 200, "text/markdown; charset=utf-8", "# Job posting packet\n"
            if url.endswith("/feed.rss"):
                return 200, "application/rss+xml", "<rss><channel/></rss>"
            if "/api/" in url:
                return 200, "application/json", body({"items": []})
            return 200, "text/html", (
                '<html><div id="stats"></div><div id="metric-jobs"></div>'
                '<div id="machines"></div><section id="metrics"></section>'
            )

        return fetch

    def run_main(self, fetch, argv_extra=()):
        out = io.StringIO()
        argv = [
            "portfolio-smoke",
            "--jobs", "http://127.0.0.1:8501",
            "--deals", "http://127.0.0.1:8502",
            "--inventory", "http://127.0.0.1:8503",
            "--clanker", "http://127.0.0.1:8504",
            "--link-vault", "http://127.0.0.1:8506",
            *argv_extra,
        ]
        probe = prober({"/stage": "GET, HEAD, PATCH", "/notes": "GET, HEAD, POST", "/poll": "GET, HEAD, POST"})
        with mock.patch.object(sys, "argv", argv), \
            mock.patch.object(smoke, "fetch", fetch), \
            mock.patch.object(smoke, "probe_method", probe), \
            contextlib.redirect_stdout(out):
            code = smoke.main()
        return code, out.getvalue()

    def test_a_green_run_exits_zero_with_json(self):
        code, out = self.run_main(self.fake_fetch())
        summary = json.loads(out)
        self.assertEqual(code, 0)
        self.assertTrue(summary["ok"])
        self.assertEqual(
            sorted(summary["services"]), ["clanker", "deals", "inventory", "jobs", "link_vault"]
        )

    def test_a_red_run_exits_one_and_names_the_service(self):
        code, out = self.run_main(self.fake_fetch(stats_status=500))
        summary = json.loads(out)
        self.assertEqual(code, 1)
        self.assertFalse(summary["ok"])
        self.assertEqual(
            sorted(summary["failed"]), ["clanker", "deals", "inventory", "jobs", "link_vault"]
        )
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
