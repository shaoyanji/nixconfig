#!/usr/bin/env python3
"""Fixture for scripts/task/job-page-scrape.py.

The CLI's only claim worth asserting is precision: a posting link comes back
once with a title, and a filter, a nav link and a social link do not come back
at all. The extraction is pure, so the fixture feeds it the three shapes a
browser, Firecrawl and a plain GET actually return instead of a live network.
"""

from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
import urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "job_page_scrape", ROOT / "scripts" / "task" / "job-page-scrape.py"
)
scrape = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scrape)

LEVER = "https://jobs.lever.co/leverdemo"
LEVER_JOB = LEVER + "/8a1f0e42-7d4c-4a41-9b52-3b3c1b8c1b21"
ASHBY = "https://jobs.ashbyhq.com/acme/3f2a9b1c-2e4d-4c5b-8a6f-1d2c3b4a5e6f"
GREENHOUSE = "https://boards.greenhouse.io/acme/jobs/4567890"
WORKDAY = "https://acme.wd5.myworkdayjobs.com/External/job/Berlin/Senior-SRE_R-12345"


class TitleCleanTest(unittest.TestCase):
    def test_work_type_marker_ends_the_title(self):
        self.assertEqual(
            scrape.clean_title(
                "Sr. Customer Success Manager ST HYBRID — REGULAR FULL TIME (SALARY)ATLANTA, GEORGIA"
            ),
            "Sr. Customer Success Manager ST",
        )

    def test_greenhouse_city_list_becomes_the_location(self):
        self.assertEqual(
            scrape.split_title_location("Applied Scientist, Engineering San Francisco, CA"),
            ("Applied Scientist, Engineering", "San Francisco, CA"),
        )
        self.assertEqual(
            scrape.split_title_location(
                "Fellows Program, The Institute (Economics & Policy) London, UK; "
                "Ontario, CAN; Remote-Friendly, United States"
            ),
            (
                "Fellows Program, The Institute (Economics & Policy)",
                "London, UK; Ontario, CAN; Remote-Friendly, United States",
            ),
        )

    def test_ashby_bullet_meta_is_split_off(self):
        self.assertEqual(
            scrape.split_title_location(
                "Account Executive, Enterprise GTM • Singapore • Full time • Hybrid"
            ),
            ("Account Executive, Enterprise GTM", "Singapore"),
        )
        self.assertEqual(
            scrape.split_title_location("Staff Engineer • Remote • Full time"),
            ("Staff Engineer", "Remote"),
        )

    def test_card_line_breaks_are_not_part_of_the_title(self):
        self.assertEqual(
            scrape.split_title_location(
                "Anthropic Fellows Program, AI Safety & Security <br> <br>"
                "London, UK; Ontario, CAN; Remote-Friendly, United States"
            ),
            (
                "Anthropic Fellows Program, AI Safety & Security",
                "London, UK; Ontario, CAN; Remote-Friendly, United States",
            ),
        )

    def test_a_title_without_a_city_is_left_alone(self):
        self.assertEqual(
            scrape.split_title_location("Staff Platform Engineer"),
            ("Staff Platform Engineer", None),
        )

    def test_an_ordinary_dash_is_part_of_the_title(self):
        self.assertEqual(
            scrape.clean_title("Backend Engineer - Payments"),
            "Backend Engineer - Payments",
        )


class PostingShapeTest(unittest.TestCase):
    def test_board_shapes_are_postings(self):
        for url in (LEVER_JOB, ASHBY, GREENHOUSE, WORKDAY):
            self.assertTrue(scrape.is_posting(url), url)

    def test_embedded_greenhouse_query_is_a_posting(self):
        self.assertTrue(
            scrape.is_posting("https://acme.example/careers?gh_jid=4567890")
        )

    def test_filter_links_are_not_postings(self):
        self.assertFalse(scrape.is_posting(LEVER + "?location=Berlin"))
        self.assertFalse(scrape.is_posting(LEVER + "?workplaceType=remote"))

    def test_nav_and_policy_paths_are_not_postings(self):
        for url in (
            "https://acme.example/privacy",
            "https://acme.example/login",
            "https://acme.example/cookies",
        ):
            self.assertFalse(scrape.is_posting(url), url)

    def test_third_party_links_are_not_postings(self):
        self.assertFalse(scrape.is_posting("https://www.linkedin.com/jobs/view/123"))
        self.assertFalse(scrape.is_posting("mailto:jobs@acme.example"))


class AnchorExtractionTest(unittest.TestCase):
    def test_same_posting_twice_is_one_job(self):
        jobs = scrape.from_anchors(
            [
                (LEVER_JOB, "Senior Site Reliability Engineer"),
                (LEVER_JOB + "?utm_source=x", "Senior Site Reliability Engineer"),
                (LEVER_JOB + "/", "Senior Site Reliability Engineer"),
            ],
            LEVER,
        )
        self.assertEqual(len(jobs), 1)
        self.assertEqual(jobs[0]["url"], LEVER_JOB)

    def test_nav_label_falls_back_to_the_slug(self):
        jobs = scrape.from_anchors([(GREENHOUSE, "Apply")], LEVER)
        self.assertEqual(len(jobs), 1)
        self.assertEqual(jobs[0]["title"], "4567890")

    def test_relative_href_is_resolved(self):
        jobs = scrape.from_anchors([("/jobs/4567890", "Platform Engineer")], LEVER)
        self.assertEqual(jobs[0]["url"], "https://jobs.lever.co/jobs/4567890")

    def test_filter_anchor_is_dropped(self):
        jobs = scrape.from_anchors([(LEVER + "?location=Berlin", "Berlin")], LEVER)
        self.assertEqual(jobs, [])


class AssetAndBoundaryTest(unittest.TestCase):
    def test_logo_with_a_uuid_filename_is_not_a_posting(self):
        logo = (
            "https://lever-client-logos.s3.amazonaws.com/"
            "0f0b0ae7-7dd3-4484-97cf-73a6eb91be08-1486498104340.png"
        )
        self.assertFalse(scrape.is_posting(logo))

    def test_uuid_must_end_the_path(self):
        self.assertFalse(
            scrape.is_posting(LEVER + "/58db3f8e-b108-47d1-9e6e-87a1712497cd.html")
        )
        self.assertTrue(
            scrape.is_posting(LEVER + "/58db3f8e-b108-47d1-9e6e-87a1712497cd")
        )


class LeverCardMarkdownTest(unittest.TestCase):
    """The shape Firecrawl actually returns for a Lever board."""

    BLOCK = "\n".join(
        [
            "[![Lever Demo 2 logo](https://lever-client-logos.s3.amazonaws.com/0f0b0ae7-7dd3-4484-97cf-73a6eb91be08-1486498104340.png)](https://www.lever.co/)",
            "",
            "Sales",
            "",
            f"[Apply]({LEVER_JOB})",
            "",
            f"[**Sales Engineer AH** \\\nRemote — Regular Full Time (Salary)Atlanta, Georgia / Arlington, TX / Boston, MA]({LEVER_JOB}",
        ]
    )

    def test_title_and_location_come_from_the_card_not_the_uuid(self):
        jobs = scrape.from_markdown(self.BLOCK, LEVER)
        self.assertEqual(len(jobs), 1)
        self.assertEqual(jobs[0]["title"], "Sales Engineer AH")
        self.assertEqual(
            jobs[0]["location"], "Atlanta, Georgia / Arlington, TX / Boston, MA"
        )
        self.assertEqual(jobs[0]["url"], LEVER_JOB)


class MarkdownExtractionTest(unittest.TestCase):
    def test_link_plus_next_line_location(self):
        markdown = "\n".join(
            [
                "# Open roles",
                "[](https://jobs.lever.co/acme?workplaceType=remote)",
                f"[Senior SRE]({LEVER_JOB})",
                "Berlin, Germany",
                "[Apply](https://jobs.lever.co/acme/login)",
            ]
        )
        jobs = scrape.from_markdown(markdown, LEVER)
        self.assertEqual(len(jobs), 1)
        self.assertEqual(jobs[0]["title"], "Senior SRE")
        self.assertEqual(jobs[0]["location"], "Berlin, Germany")


class JsonLdTest(unittest.TestCase):
    def test_single_and_list_objects(self):
        one = {
            "@type": "JobPosting",
            "title": "Staff Platform Engineer",
            "url": WORKDAY,
        }
        html = (
            '<script type="application/ld+json">'
            + json.dumps(one)
            + "</script>"
            + '<script type="application/ld+json">'
            + json.dumps([{"@type": "Organization"}, one | {"title": "Second"}])
            + "</script>"
        )
        titles = [job["title"] for job in scrape.from_jsonld(html)]
        self.assertEqual(titles, ["Staff Platform Engineer", "Second"])

    def test_malformed_blob_is_skipped(self):
        html = '<script type="application/ld+json">{not json</script>'
        self.assertEqual(scrape.from_jsonld(html), [])

    def test_html_without_jsonld_falls_back_to_anchors(self):
        html = f'<html><body><a href="{GREENHOUSE}">Data Engineer</a></body></html>'
        jobs = scrape.from_html(html, LEVER)
        self.assertEqual([job["title"] for job in jobs], ["Data Engineer"])


class KeyLoadingTest(unittest.TestCase):
    def test_only_named_keys_are_read(self):
        with tempfile.NamedTemporaryFile("w", suffix=".env", delete=False) as handle:
            handle.write("FIRECRAWL_API_KEY=fc-abc\nOTHER_TOKEN=seq-xyz\n# note\n")
            path = handle.name
        try:
            keys = scrape.load_keys(path, ("FIRECRAWL_API_KEY",))
        finally:
            os.unlink(path)
        self.assertEqual(keys, {"FIRECRAWL_API_KEY": "fc-abc"})


class FallbackTest(unittest.TestCase):
    def test_browser_that_cannot_open_falls_through(self):
        args = type("Args", (), {"timeout": 5, "agent_browser": "agent-browser"})()

        def refused(*_a, **_k):
            raise scrape.Unavailable("the browser could not open the page")

        original_browser, original_http = scrape.fetch_browser, scrape.fetch_http
        scrape.fetch_browser = refused
        scrape.fetch_http = lambda url, timeout: (
            f'<a href="{GREENHOUSE}">Platform Engineer</a>'
        )
        try:
            jobs, used, warnings = scrape.collect(
                "https://acme.example/careers", "auto", args, {}
            )
        finally:
            scrape.fetch_browser, scrape.fetch_http = original_browser, original_http
        self.assertEqual(used, "http")
        self.assertEqual(jobs[0]["title"], "Platform Engineer")
        self.assertTrue(warnings)

    def test_missing_browser_falls_through_to_http(self):
        args = type(
            "Args", (), {"timeout": 5, "agent_browser": "definitely-not-a-binary"}
        )()
        original = scrape.fetch_http
        scrape.fetch_http = lambda url, timeout: (
            f'<a href="{GREENHOUSE}">Site Reliability Engineer</a>'
        )
        try:
            jobs, used, warnings = scrape.collect(LEVER, "auto", args, {})
        finally:
            scrape.fetch_http = original
        self.assertEqual(used, "http")
        self.assertEqual(jobs[0]["title"], "Site Reliability Engineer")
        self.assertTrue(any(w.startswith("browser:") for w in warnings))


if __name__ == "__main__":
    unittest.main()
