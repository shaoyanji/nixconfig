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
        ), mock.patch.object(
            ingest, "post_batch", side_effect=ingest.BatchUnsupported("404 no route")
        ), mock.patch.object(ingest, "post_deal", half_fail), contextlib.redirect_stdout(out):
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
        "http://x/api/deals/batch", code, "no", {}, io.BytesIO(b'{"error":"nope"}')
    )


class BatchRequestTest(unittest.TestCase):
    def test_the_batch_route_gets_a_deals_array(self):
        seen = {}

        def fake(request, timeout=30):
            seen["url"] = request.full_url
            seen["body"] = json.loads(request.data.decode())
            return FakeResponse(b'{"created":2,"updated":0,"skipped":0,"failed":0,"total":2}')

        payloads = [{"url": "https://a.example/1"}, {"url": "https://a.example/2"}]
        with mock.patch("urllib.request.urlopen", fake):
            answer = ingest.post_batch("http://x", payloads)
        self.assertTrue(seen["url"].endswith("/api/deals/batch"))
        self.assertEqual(seen["body"], {"deals": payloads})
        self.assertEqual(answer["created"], 2)

    def test_404_and_405_are_unsupported_not_failed(self):
        for code in (404, 405):
            with mock.patch("urllib.request.urlopen", side_effect=http_error(code)):
                with self.assertRaises(ingest.BatchUnsupported):
                    ingest.post_batch("http://x", [{"url": "u"}])

    def test_a_bad_request_is_a_plain_error(self):
        with mock.patch("urllib.request.urlopen", side_effect=http_error(400)):
            with self.assertRaises(ingest.IngestError) as caught:
                ingest.post_batch("http://x", [{"url": "u"}])
        self.assertNotIsInstance(caught.exception, ingest.BatchUnsupported)
        self.assertIn("400", str(caught.exception))


class ChunkTest(unittest.TestCase):
    def run_chunks(self, payloads, batch_size, batch=None, single=None):
        batch = batch or (lambda api, chunk, **kw: {"created": len(chunk)})
        single = single or (lambda api, payload, **kw: {"created": True})
        with mock.patch.object(ingest, "post_batch", batch), mock.patch.object(
            ingest, "post_deal", single
        ):
            return ingest.post_chunks("http://x", payloads, batch_size)

    def test_chunks_cover_every_payload_once(self):
        payloads = [{"url": f"https://a.example/{i}"} for i in range(5)]
        sizes = []

        def batch(api, chunk, **kw):
            sizes.append(len(chunk))
            return {"created": len(chunk)}

        created, updated, skipped, failed, batched = self.run_chunks(payloads, 2, batch=batch)
        self.assertEqual(sizes, [2, 2, 1])
        self.assertEqual((created, updated, skipped, failed, batched), (5, 0, 0, [], True))

    def test_the_answer_decides_the_counts_and_names_the_refused_url(self):
        payloads = [{"url": f"https://a.example/{i}"} for i in range(3)]

        def batch(api, chunk, **kw):
            return {"created": 1, "updated": 1, "skipped": 1, "failed": 1,
                    "errors": [{"index": 2, "error": "price is not a number"}]}

        created, updated, skipped, failed, _ = self.run_chunks(payloads, 10, batch=batch)
        self.assertEqual((created, updated, skipped), (1, 1, 1))
        self.assertEqual(failed, [{"url": "https://a.example/2", "error": "price is not a number"}])

    def test_a_404_falls_back_to_one_post_per_deal(self):
        payloads = [{"url": f"https://a.example/{i}"} for i in range(3)]
        singles = []

        def batch(api, chunk, **kw):
            raise ingest.BatchUnsupported("404 no route")

        def single(api, payload, **kw):
            singles.append(payload["url"])
            return {"created": len(singles) != 2}

        created, updated, _skipped, failed, batched = self.run_chunks(
            payloads, 2, batch=batch, single=single
        )
        self.assertFalse(batched)
        self.assertEqual(singles, [p["url"] for p in payloads])
        self.assertEqual((created, updated, failed), (2, 1, []))

    def test_a_refused_chunk_is_reported_without_stopping_the_next(self):
        payloads = [{"url": f"https://a.example/{i}"} for i in range(4)]
        calls = []

        def batch(api, chunk, **kw):
            calls.append(len(chunk))
            if len(calls) == 1:
                raise ingest.IngestError("400 bad")
            return {"created": len(chunk)}

        created, _updated, _skipped, failed, batched = self.run_chunks(payloads, 2, batch=batch)
        self.assertEqual(calls, [2, 2])
        self.assertEqual(created, 2)
        self.assertEqual(len(failed), 2)
        self.assertTrue(batched)

    def test_dry_run_never_reaches_the_batch_route(self):
        out = io.StringIO()
        with mock.patch.object(
            sys, "argv", ["deals-ingest", "--dry-run"]
        ), mock.patch.object(
            sys, "stdin", io.StringIO(json.dumps([page(deal(), deal(title="B", url="https://shop.example/b"))]))
        ), mock.patch.object(
            ingest, "post_batch", side_effect=AssertionError("batched in dry run")
        ), contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = ingest.main()
        summary = json.loads(out.getvalue())
        self.assertEqual(code, 0)
        self.assertFalse(summary["batch"])
        self.assertEqual(summary["skipped"], 0)

    def test_batch_size_is_validated_against_the_server_limit(self):
        with mock.patch.object(sys, "argv", ["deals-ingest", "--batch-size", "501"]), mock.patch.object(
            sys, "stdin", io.StringIO("[]")
        ), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
            ingest.main()
        self.assertEqual(caught.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
