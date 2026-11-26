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
        ), mock.patch.object(ingest, "post_posting", half_fail), contextlib.redirect_stdout(out):
            code = ingest.main()
        summary = json.loads(out.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(len(summary["failed"]), 1)
        self.assertEqual(summary["created"], 1)


if __name__ == "__main__":
    unittest.main()
