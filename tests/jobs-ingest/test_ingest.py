#!/usr/bin/env python3
"""Fixture for scripts/task/jobs-ingest.py.

The pipe's job is to map a board's postings onto job-db-scraper's input without
inventing anything: the URL stays the identity, the company comes from the ATS
path, and a posting whose employer cannot be read is skipped and named rather
than filed under a guess. Each of those is a case below.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import sys
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "jobs_ingest", ROOT / "scripts" / "task" / "jobs-ingest.py"
)
ingest = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ingest)

LEVER = "https://jobs.lever.co/acme/8a1f0e42-7d4c-4a41-9b52-3b3c1b8c1b21"
ASHBY = "https://jobs.ashbyhq.com/linear/3f2a9b1c-2e4d-4c5b-8a6f-1d2c3b4a5e6f"
GREENHOUSE = "https://job-boards.greenhouse.io/anthropic/jobs/5183051008"
WORKDAY = "https://acme.wd5.myworkdayjobs.com/External/job/Berlin/Senior-SRE_R-12345"
OWN_SITE = "https://careers.acme.example/roles/sre"


def page(*jobs):
    return {"url": "https://jobs.lever.co/acme", "backend": "firecrawl", "jobs": list(jobs)}


class InputShapeTest(unittest.TestCase):
    def test_pages_array(self):
        document = [page({"title": "A", "url": LEVER}), page({"title": "B", "url": ASHBY})]
        self.assertEqual(len(ingest.page_jobs(document)), 2)

    def test_single_page_object(self):
        self.assertEqual(len(ingest.page_jobs(page({"title": "A", "url": LEVER}))), 1)

    def test_bare_job_list(self):
        self.assertEqual(
            len(ingest.page_jobs([{"title": "A", "url": LEVER}])), 1
        )

    def test_nonsense_is_empty_not_an_error(self):
        self.assertEqual(ingest.page_jobs("nope"), [])
        self.assertEqual(ingest.page_jobs({"jobs": "nope"}), [])


class EmployerTest(unittest.TestCase):
    def test_ats_slug_is_the_company(self):
        self.assertEqual(ingest.company_from_url(LEVER), "acme")
        self.assertEqual(ingest.company_from_url(ASHBY), "linear")
        self.assertEqual(ingest.company_from_url(GREENHOUSE), "anthropic")
        self.assertEqual(ingest.company_from_url(WORKDAY), "External")

    def test_source_names_the_board(self):
        self.assertEqual(ingest.source_for(LEVER), "lever")
        self.assertEqual(ingest.source_for(ASHBY), "ashby")
        self.assertEqual(ingest.source_for(GREENHOUSE), "greenhouse")
        self.assertEqual(ingest.source_for(WORKDAY), "workday")

    def test_own_careers_page_uses_the_host_label(self):
        self.assertEqual(ingest.company_from_url(OWN_SITE), "acme")
        self.assertEqual(ingest.source_for(OWN_SITE), "careers.acme.example")

    def test_url_without_a_slug_has_no_company(self):
        self.assertEqual(ingest.company_from_url("https://jobs.lever.co/jobs"), "")


class CanonicalTest(unittest.TestCase):
    def test_tracking_and_trailing_slash_are_dropped(self):
        self.assertEqual(
            ingest.canonical(LEVER + "/?utm_source=x&gh_jid=1#apply"),
            LEVER + "?gh_jid=1",
        )


class PostingMappingTest(unittest.TestCase):
    def test_remote_follows_the_location_and_title(self):
        posting = ingest.to_posting(
            {"title": "SRE", "url": LEVER, "location": "Remote — EU"}
        )
        self.assertTrue(posting["remote"])
        self.assertEqual(posting["source"], "lever")
        self.assertEqual(posting["company"], "acme")

    def test_on_site_is_not_remote(self):
        posting = ingest.to_posting({"title": "SRE", "url": LEVER, "location": "Berlin"})
        self.assertFalse(posting["remote"])

    def test_tags_are_lowercased_and_unique(self):
        posting = ingest.to_posting(
            {"title": "SRE", "url": LEVER}, tags=["DevOps", "devops", " Cloud "]
        )
        self.assertEqual(posting["tags"], ["cloud", "devops"])

    def test_overrides_win(self):
        posting = ingest.to_posting(
            {"title": "SRE", "url": LEVER}, source="stepstone", company="Real Co"
        )
        self.assertEqual((posting["source"], posting["company"]), ("stepstone", "Real Co"))


class BuildPostingsTest(unittest.TestCase):
    def test_same_url_twice_is_one_posting(self):
        postings, warnings = ingest.build_postings(
            [
                {"title": "SRE", "url": LEVER},
                {"title": "SRE", "url": LEVER + "?utm_source=rss"},
            ]
        )
        self.assertEqual(len(postings), 1)
        self.assertEqual(warnings, [])

    def test_unreadable_employer_is_skipped_and_named(self):
        postings, warnings = ingest.build_postings(
            [{"title": "SRE", "url": "https://jobs.lever.co/jobs"}]
        )
        self.assertEqual(postings, [])
        self.assertIn("no company", warnings[0])

    def test_missing_title_is_skipped(self):
        postings, warnings = ingest.build_postings([{"url": LEVER}])
        self.assertEqual(postings, [])
        self.assertIn("no title", warnings[0])


class PostFailureTest(unittest.TestCase):
    def test_http_error_becomes_ingest_error(self):
        def refuse(*_a, **_k):
            raise urllib.error.HTTPError(
                "http://x/api/postings", 400, "bad", {}, io.BytesIO(b'{"error":"nope"}')
            )

        with mock.patch("urllib.request.urlopen", refuse):
            with self.assertRaises(ingest.IngestError) as caught:
                ingest.post_posting("http://x", {"title": "t"})
        self.assertIn("400", str(caught.exception))


class DryRunTest(unittest.TestCase):
    def run_main(self, argv, payload):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", argv), mock.patch.object(
            sys, "stdin", io.StringIO(json.dumps(payload))
        ), mock.patch.object(
            ingest, "post_posting", side_effect=AssertionError("posted in dry run")
        ), contextlib.redirect_stdout(out):
            code = ingest.main()
        return code, out.getvalue()

    def test_dry_run_posts_nothing_and_summarises(self):
        code, out = self.run_main(
            ["jobs-ingest", "--dry-run"],
            [page({"title": "SRE", "url": LEVER}, {"title": "SRE2", "url": ASHBY})],
        )
        self.assertEqual(code, 0)
        summary = json.loads(out)
        self.assertTrue(summary["dry_run"])
        self.assertEqual(summary["postings"], 2)
        self.assertEqual(summary["created"], 0)


class FailureReportingTest(unittest.TestCase):
    def test_one_refusal_does_not_stop_the_others(self):
        calls = []

        def half_fail(_api, posting, **_k):
            calls.append(posting["url"])
            if len(calls) == 1:
                raise ingest.IngestError("400 bad")
            return {"created": True}

        out = io.StringIO()
        with mock.patch.object(
            sys, "argv", ["jobs-ingest", "--api", "http://x"]
        ), mock.patch.object(
            sys, "stdin", io.StringIO(json.dumps([page(
                {"title": "A", "url": LEVER}, {"title": "B", "url": ASHBY}
            )]))
        ), mock.patch.object(
            ingest, "post_batch", side_effect=ingest.BatchUnsupported("405 no route")
        ), mock.patch.object(ingest, "post_posting", half_fail), contextlib.redirect_stdout(out):
            code = ingest.main()
        summary = json.loads(out.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(len(summary["failed"]), 1)
        self.assertEqual(summary["created"], 1)
        self.assertFalse(summary["batch"])


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *_exc):
        return False


def http_error(code: int):
    return urllib.error.HTTPError(
        "http://x/api/postings/batch", code, "no", {}, io.BytesIO(b'{"error":"nope"}')
    )


class BatchRequestTest(unittest.TestCase):
    def test_the_batch_route_gets_a_postings_array(self):
        seen = {}

        def fake(request, timeout=30):
            seen["url"] = request.full_url
            seen["body"] = json.loads(request.data.decode())
            return FakeResponse(b'{"created":1,"updated":1,"skipped":0,"failed":0,"total":2}')

        payloads = [{"url": LEVER, "title": "A"}, {"url": ASHBY, "title": "B"}]
        with mock.patch("urllib.request.urlopen", fake):
            answer = ingest.post_batch("http://x", payloads)
        self.assertTrue(seen["url"].endswith("/api/postings/batch"))
        self.assertEqual(seen["body"], {"postings": payloads})
        self.assertEqual(answer["updated"], 1)

    def test_404_and_405_are_unsupported_not_failed(self):
        for code in (404, 405):
            with mock.patch("urllib.request.urlopen", side_effect=http_error(code)):
                with self.assertRaises(ingest.BatchUnsupported):
                    ingest.post_batch("http://x", [{"url": LEVER}])

    def test_a_bad_request_is_a_plain_error(self):
        with mock.patch("urllib.request.urlopen", side_effect=http_error(400)):
            with self.assertRaises(ingest.IngestError) as caught:
                ingest.post_batch("http://x", [{"url": LEVER}])
        self.assertNotIsInstance(caught.exception, ingest.BatchUnsupported)


class ChunkTest(unittest.TestCase):
    def run_chunks(self, payloads, batch_size, batch=None, single=None):
        batch = batch or (lambda api, chunk, **kw: {"created": len(chunk)})
        single = single or (lambda api, payload, **kw: {"created": True})
        with mock.patch.object(ingest, "post_batch", batch), mock.patch.object(
            ingest, "post_posting", single
        ):
            return ingest.post_chunks("http://x", payloads, batch_size)

    def test_chunks_cover_every_posting_once(self):
        payloads = [{"url": f"{LEVER}/{i}"} for i in range(5)]
        sizes = []

        def batch(api, chunk, **kw):
            sizes.append(len(chunk))
            return {"created": len(chunk)}

        created, updated, skipped, failed, batched = self.run_chunks(payloads, 2, batch=batch)
        self.assertEqual(sizes, [2, 2, 1])
        self.assertEqual((created, updated, skipped, failed, batched), (5, 0, 0, [], True))

    def test_the_answer_decides_the_counts_and_names_the_refused_url(self):
        payloads = [{"url": f"{LEVER}/{i}"} for i in range(3)]

        def batch(api, chunk, **kw):
            return {"created": 2, "updated": 0, "skipped": 1, "failed": 0, "errors": []}

        created, updated, skipped, failed, _ = self.run_chunks(payloads, 10, batch=batch)
        self.assertEqual((created, updated, skipped, failed), (2, 0, 1, []))

    def test_an_indexed_error_names_its_posting(self):
        payloads = [{"url": f"{LEVER}/{i}"} for i in range(2)]

        def batch(api, chunk, **kw):
            return {"failed": 1, "errors": [{"index": 1, "error": "company is empty"}]}

        _c, _u, _s, failed, _b = self.run_chunks(payloads, 10, batch=batch)
        self.assertEqual(failed, [{"url": f"{LEVER}/1", "error": "company is empty"}])

    def test_a_404_falls_back_to_one_post_per_posting(self):
        payloads = [{"url": f"{LEVER}/{i}"} for i in range(3)]
        singles = []

        def batch(api, chunk, **kw):
            raise ingest.BatchUnsupported("405 method not allowed")

        def single(api, payload, **kw):
            singles.append(payload["url"])
            return {"created": len(singles) != 2}

        created, updated, _skipped, failed, batched = self.run_chunks(
            payloads, 2, batch=batch, single=single
        )
        self.assertFalse(batched)
        self.assertEqual(singles, [p["url"] for p in payloads])
        self.assertEqual((created, updated, failed), (2, 1, []))

    def test_dry_run_never_reaches_the_batch_route(self):
        out = io.StringIO()
        with mock.patch.object(
            sys, "argv", ["jobs-ingest", "--dry-run"]
        ), mock.patch.object(
            sys, "stdin", io.StringIO(json.dumps([page({"title": "A", "url": LEVER})]))
        ), mock.patch.object(
            ingest, "post_batch", side_effect=AssertionError("batched in dry run")
        ), contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = ingest.main()
        summary = json.loads(out.getvalue())
        self.assertEqual(code, 0)
        self.assertFalse(summary["batch"])
        self.assertEqual(summary["skipped"], 0)

    def test_batch_size_is_validated_against_the_server_limit(self):
        with mock.patch.object(sys, "argv", ["jobs-ingest", "--batch-size", "0"]), mock.patch.object(
            sys, "stdin", io.StringIO("[]")
        ), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
            ingest.main()
        self.assertEqual(caught.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
