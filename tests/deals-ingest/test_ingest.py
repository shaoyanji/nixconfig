#!/usr/bin/env python3
"""Fixture for scripts/task/deals-ingest.py.

The mapping is the whole point: the scraper's `original_price` has to arrive as
the API's `list_price`, and a deal with no price is not a deal. Both are cases,
along with the shapes the scraper emits and a refusal that must not stop the
run.
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
    "deals_ingest", ROOT / "scripts" / "task" / "deals-ingest.py"
)
ingest = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ingest)

SHOP = "https://shop.example/knife?utm_source=feed"


def page(*deals):
    return {"url": "https://www.techbargains.com/", "backend": "firecrawl", "deals": list(deals)}


def deal(**overrides):
    base = {
        "title": "Shan Zu Fillet Knife",
        "price": 18.99,
        "original_price": 49.99,
        "discount_pct": 62,
        "currency": "EUR",
        "merchant": "amazon",
        "url": SHOP,
        "category": "other",
    }
    base.update(overrides)
    return base


class ShapeTest(unittest.TestCase):
    def test_pages_array(self):
        self.assertEqual(len(ingest.deal_pages([page(deal()), page(deal(title="B"))])), 2)

    def test_single_page(self):
        self.assertEqual(len(ingest.deal_pages(page(deal()))), 1)

    def test_bare_list(self):
        self.assertEqual(len(ingest.deal_pages([deal()])), 1)

    def test_nonsense_is_empty(self):
        self.assertEqual(ingest.deal_pages("nope"), [])
        self.assertEqual(ingest.deal_pages({"deals": "nope"}), [])


class MappingTest(unittest.TestCase):
    def test_original_price_becomes_list_price(self):
        payload, _ = ingest.build_inputs([deal()], merchant="")
        self.assertEqual(payload[0]["list_price"], 49.99)
        self.assertEqual(payload[0]["price"], 18.99)
        self.assertEqual(payload[0]["discount_pct"], 62)

    def test_source_defaults_to_the_host(self):
        payload, _ = ingest.build_inputs([deal()])
        self.assertEqual(payload[0]["source"], "shop.example")

    def test_the_board_host_beats_the_redirect_link(self):
        # The deal link is a redirect on the board's own subdomain.
        pairs = ingest.deal_pairs(page(deal(url="https://cc.techbargains.com/otc/abc")))
        payload, _ = ingest.build_inputs(
            [d for _s, d in pairs], page_sources=[s for s, _d in pairs]
        )
        self.assertEqual(payload[0]["source"], "techbargains.com")

    def test_overrides_win(self):
        payload, _ = ingest.build_inputs([deal()], source="techbargains", merchant="ebay")
        self.assertEqual((payload[0]["source"], payload[0]["merchant"]), ("techbargains", "ebay"))

    def test_tags_merge_and_lowercase(self):
        payload, _ = ingest.build_inputs([deal(tags=["GPU"])], tags=["BlackFriday"])
        self.assertEqual(payload[0]["tags"], ["blackfriday", "gpu"])

    def test_url_is_canonicalised(self):
        payload, _ = ingest.build_inputs([deal()])
        self.assertEqual(payload[0]["url"], "https://shop.example/knife")


class SkipTest(unittest.TestCase):
    def test_same_url_twice_is_one_deal(self):
        payload, warnings = ingest.build_inputs(
            [deal(), deal(url=SHOP + "&ref=x")]
        )
        self.assertEqual(len(payload), 1)
        self.assertEqual(warnings, [])

    def test_a_deal_without_a_price_is_skipped(self):
        payload, warnings = ingest.build_inputs([deal(price=None)])
        self.assertEqual(payload, [])
        self.assertIn("no price", warnings[0])

    def test_a_deal_without_a_title_is_skipped(self):
        payload, warnings = ingest.build_inputs([deal(title="")])
        self.assertEqual(payload, [])
        self.assertIn("no title", warnings[0])


class DiscountFilterTest(unittest.TestCase):
    def run_main(self, argv, payload):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", argv), mock.patch.object(
            sys, "stdin", io.StringIO(json.dumps(payload))
        ), mock.patch.object(
            ingest, "post_deal", side_effect=AssertionError("posted in dry run")
        ), contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = ingest.main()
        return code, json.loads(out.getvalue())

    def test_min_discount_drops_the_rest(self):
        code, summary = self.run_main(
            ["deals-ingest", "--dry-run", "--min-discount", "50"],
            [page(deal(), deal(title="Meh", url="https://shop.example/meh", discount_pct=10))],
        )
        self.assertEqual(code, 0)
        self.assertEqual(summary["deals"], 1)
        self.assertTrue(any("dropped 1 deals" in w for w in summary["warnings"]))

    def test_dry_run_posts_nothing(self):
        code, summary = self.run_main(
            ["deals-ingest", "--dry-run"], [page(deal(), deal(title="B", url="https://shop.example/b"))]
        )
        self.assertEqual(code, 0)
        self.assertTrue(summary["dry_run"])
        self.assertEqual(summary["created"], 0)


class FailureTest(unittest.TestCase):
    def test_http_error_becomes_ingest_error(self):
        def refuse(*_a, **_k):
            raise urllib.error.HTTPError(
                "http://x/api/deals", 400, "bad", {}, io.BytesIO(b'{"error":"nope"}')
            )

        with mock.patch("urllib.request.urlopen", refuse):
            with self.assertRaises(ingest.IngestError) as caught:
                ingest.post_deal("http://x", {"title": "t"})
        self.assertIn("400", str(caught.exception))

    def test_one_refusal_does_not_stop_the_others(self):
        calls = []

        def half_fail(_api, payload, **_kwargs):
            calls.append(payload["url"])
            if len(calls) == 1:
                raise ingest.IngestError("400 bad")
            return {"created": True}

        out = io.StringIO()
        with mock.patch.object(
            sys, "argv", ["deals-ingest", "--api", "http://x"]
        ), mock.patch.object(
            sys, "stdin", io.StringIO(json.dumps([page(deal(), deal(title="B", url="https://shop.example/b"))]))
        ), mock.patch.object(ingest, "post_deal", half_fail), contextlib.redirect_stdout(out):
            code = ingest.main()
        summary = json.loads(out.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(len(summary["failed"]), 1)
        self.assertEqual(summary["created"], 1)


if __name__ == "__main__":
    unittest.main()
