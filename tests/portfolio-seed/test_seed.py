"""Unit tests for portfolio-seed: the orchestration, not the network.

Both halves of a lane are child processes, so the test replaces `run` with a
table of answers keyed by script name. What is left to prove is what the seed
decides: which script gets which arguments, what a zero-page scrape means, what a
refusal does to the run, and that the scrape file it hands over is gone after.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("portfolio_seed", ROOT / "scripts" / "task" / "portfolio-seed.py")
seed = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(seed)

BASE = "http://seed.test"

PAGES = [{"url": "https://boards.example/acme", "count": 1, "jobs": [{"title": "Platform", "url": "u"}]}]
INGEST = {"run": "jobs-ingest", "postings": 1, "batch": True, "created": 1, "updated": 0, "skipped": 0, "failed": []}
INVENTORY = {"run": "inventory-sync", "hosts": 3, "items": 3, "created": 2, "updated": 1, "failed": []}


def answer(payload, code=0, stderr=""):
    return SimpleNamespace(returncode=code, stdout=json.dumps(payload), stderr=stderr)


def responder(table, calls):
    def run(argv, **_kwargs):
        calls.append(argv)
        joined = " ".join(argv)
        for needle, reply in table.items():
            if needle in joined:
                return reply(argv) if callable(reply) else reply
        return SimpleNamespace(returncode=127, stdout="", stderr=f"not in the table: {joined}")

    return run


def args(**overrides):
    base = dict(
        jobs_pages=[],
        deals_pages=[],
        jobs_from="",
        deals_from="",
        api_jobs=BASE,
        api_deals=BASE,
        api_inventory=BASE,
        only=seed.LANE_ORDER,
        inventory_hosts="",
        inventory_from="",
        backend="auto",
        max=0,
        batch_size=100,
        timeout=30,
        dry_run=False,
        format="json",
        python="/usr/bin/python3",
    )
    base.update(overrides)
    return SimpleNamespace(**base)


class ScrapeLaneTest(unittest.TestCase):
    def run_lane(self, table, **overrides):
        calls = []
        lane = seed.seed_lane("jobs", seed.LANES["jobs"], args(jobs_pages=["https://boards.example/acme"], **overrides),
                              responder(table, calls))
        return lane, calls

    def test_a_page_is_scraped_and_posted_in_one_batch(self):
        lane, calls = self.run_lane({"job-page-scrape.py": answer(PAGES), "jobs-ingest.py": answer(INGEST)})
        self.assertTrue(lane["ok"])
        self.assertEqual(lane["created"], 1)
        self.assertEqual(lane["scraped"], 1)
        self.assertTrue(lane["batch"])
        ingest = [c for c in calls if "jobs-ingest.py" in " ".join(c)][0]
        self.assertIn("--batch-size", ingest)
        self.assertIn("--api", ingest)
        self.assertIn(BASE, ingest)
        scrape = [c for c in calls if "job-page-scrape.py" in " ".join(c)][0]
        self.assertIn("--json", scrape)
        self.assertIn("https://boards.example/acme", scrape)

    def test_the_scrape_file_is_gone_after_the_run(self):
        seen = {}

        def ingest(argv, **_kwargs):
            seen["path"] = argv[argv.index("--in") + 1]
            return answer(INGEST)

        lane = seed.seed_lane(
            "jobs",
            seed.LANES["jobs"],
            args(jobs_pages=["https://boards.example/acme"]),
            responder({"job-page-scrape.py": answer(PAGES), "jobs-ingest.py": ingest}, []),
        )
        self.assertTrue(lane["ok"])
        self.assertFalse(os.path.exists(seen["path"]))

    def test_a_page_with_nothing_on_it_is_a_zero_not_a_failure(self):
        empty = [{"url": "https://boards.example/acme", "count": 0, "jobs": []}]
        zero = dict(INGEST, postings=0, created=0)
        lane, _ = self.run_lane(
            {"job-page-scrape.py": answer(empty, code=1), "jobs-ingest.py": answer(zero)}
        )
        self.assertTrue(lane["ok"])
        self.assertEqual(lane["scraped"], 0)

    def test_a_scraper_that_answers_no_json_fails_the_lane(self):
        lane, _ = self.run_lane(
            {"job-page-scrape.py": SimpleNamespace(returncode=2, stdout="no backend", stderr="")}
        )
        self.assertFalse(lane["ok"])
        self.assertIn("https://boards.example/acme", lane["detail"])

    def test_an_ingest_refusal_is_named_and_fails_the_lane(self):
        refused = dict(INGEST, created=0, failed=[{"url": "u", "error": "400 bad salary"}])
        lane, _ = self.run_lane(
            {"job-page-scrape.py": answer(PAGES), "jobs-ingest.py": answer(refused, code=1)}
        )
        self.assertFalse(lane["ok"])
        self.assertEqual(lane["failed"], 1)
        self.assertIn("400 bad salary", lane["detail"])

    def test_a_dry_run_tells_the_ingester_not_to_post(self):
        lane, calls = self.run_lane(
            {"job-page-scrape.py": answer(PAGES), "jobs-ingest.py": answer(dict(INGEST, created=0))},
            dry_run=True,
        )
        ingest = [c for c in calls if "jobs-ingest.py" in " ".join(c)][0]
        self.assertIn("--dry-run", ingest)
        self.assertTrue(lane["ok"])
        self.assertEqual(lane["created"], 0)

    def test_a_saved_scrape_skips_the_scraper(self):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(PAGES, handle)
            path = handle.name
        try:
            calls = []
            lane = seed.seed_lane(
                "jobs",
                seed.LANES["jobs"],
                args(jobs_from=path),
                responder({"jobs-ingest.py": answer(INGEST)}, calls),
            )
        finally:
            os.unlink(path)
        self.assertTrue(lane["ok"])
        self.assertEqual(len(calls), 1)
        self.assertIn("jobs-ingest.py", " ".join(calls[0]))
        self.assertIn("from", lane["source"])

    def test_a_lane_with_no_page_is_a_skip_not_a_red(self):
        calls = []
        lane = seed.seed_lane("deals", seed.LANES["deals"], args(), responder({}, calls))
        self.assertTrue(lane["ok"])
        self.assertTrue(lane["skipped"])
        self.assertIn("--deals", lane["detail"])
        self.assertEqual(calls, [])

    def test_an_unreadable_saved_scrape_fails_the_lane(self):
        lane = seed.seed_lane("jobs", seed.LANES["jobs"], args(jobs_from="/nope/jobs.json"), responder({}, []))
        self.assertFalse(lane["ok"])
        self.assertIn("cannot read", lane["detail"])


class InventoryLaneTest(unittest.TestCase):
    def run_lane(self, table, **overrides):
        calls = []
        lane = seed.sync_lane(args(**overrides), responder(table, calls))
        return lane, calls

    def test_eval_is_the_default_source(self):
        lane, calls = self.run_lane({"inventory-sync.py": answer(INVENTORY)})
        self.assertTrue(lane["ok"])
        self.assertEqual(lane["hosts"], 3)
        self.assertIn("--eval", calls[0])
        self.assertIn("json", calls[0])

    def test_hosts_are_narrowed_by_only(self):
        lane, calls = self.run_lane({"inventory-sync.py": answer(INVENTORY)}, inventory_hosts="delphi,frieren")
        self.assertTrue(lane["ok"])
        self.assertIn("--only", calls[0])
        self.assertIn("delphi,frieren", calls[0])

    def test_a_dry_run_reaches_the_sync(self):
        _, calls = self.run_lane({"inventory-sync.py": answer(dict(INVENTORY, created=0))}, dry_run=True)
        self.assertIn("--dry-run", calls[0])

    def test_an_unreachable_service_fails_the_lane(self):
        lane, _ = self.run_lane({"inventory-sync.py": answer({"error": "api unreachable"}, code=2)})
        self.assertFalse(lane["ok"])
        self.assertIn("api unreachable", lane["detail"])


class SeedRunTest(unittest.TestCase):
    def test_only_limits_the_lanes(self):
        calls = []
        summary = seed.seed(
            args(only=("inventory",)),
            responder({"inventory-sync.py": answer(INVENTORY)}, calls),
        )
        self.assertTrue(summary["ok"])
        self.assertEqual(list(summary["lanes"]), ["inventory"])
        self.assertEqual(len(calls), 1)

    def test_one_refusal_fails_the_run_without_stopping_the_other_lane(self):
        calls = []
        refused = dict(INGEST, created=0, failed=[{"url": "u", "error": "boom"}])
        summary = seed.seed(
            args(
                jobs_pages=["https://boards.example/acme"],
                deals_pages=["https://deals.example/x"],
            ),
            responder(
                {
                    "job-page-scrape.py": answer(PAGES),
                    "jobs-ingest.py": answer(refused, code=1),
                    "deals-page-scrape.py": answer(PAGES),
                    "deals-ingest.py": answer({"deals": 1, "batch": True, "created": 1, "updated": 0, "failed": []}),
                    "inventory-sync.py": answer(INVENTORY),
                },
                calls,
            ),
        )
        self.assertFalse(summary["ok"])
        self.assertEqual(summary["failed"], ["jobs"])
        self.assertTrue(summary["lanes"]["deals"]["ok"])
        self.assertTrue(summary["lanes"]["inventory"]["ok"])

    def test_skipped_lanes_are_listed_separately_from_failed_ones(self):
        summary = seed.seed(
            args(only=("jobs", "inventory")),
            responder({"inventory-sync.py": answer(INVENTORY)}, []),
        )
        self.assertTrue(summary["ok"])
        self.assertEqual(summary["skipped"], ["jobs"])
        self.assertEqual(summary["failed"], [])

    def test_an_unknown_lane_is_refused(self):
        with self.assertRaises(Exception) as caught:
            seed.parse_only("jobs,shoes")
        self.assertIn("shoes", str(caught.exception))

    def test_the_lane_list_is_ordered(self):
        self.assertEqual(seed.parse_only("inventory,jobs"), ("inventory", "jobs"))


class CliTest(unittest.TestCase):
    def run_main(self, argv, table):
        calls = []
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["portfolio-seed", *argv]), \
            mock.patch.object(seed.subprocess, "run", side_effect=responder(table, calls)), \
            contextlib.redirect_stdout(out):
            code = seed.main()
        return code, out.getvalue(), calls

    def test_a_green_run_exits_zero_with_json(self):
        code, out, _ = self.run_main(
            ["--only", "inventory", "--api-inventory", BASE],
            {"inventory-sync.py": answer(INVENTORY)},
        )
        summary = json.loads(out)
        self.assertEqual(code, 0)
        self.assertTrue(summary["ok"])
        self.assertEqual(summary["run"], "portfolio-seed")

    def test_a_red_run_exits_one(self):
        code, out, _ = self.run_main(
            ["--only", "inventory"],
            {"inventory-sync.py": answer({"error": "api unreachable"}, code=2)},
        )
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["failed"], ["inventory"])

    def test_toon_is_read_back_as_toon(self):
        code, out, _ = self.run_main(
            ["--only", "inventory", "--format", "toon"],
            {"inventory-sync.py": answer(INVENTORY)},
        )
        self.assertEqual(code, 0)
        self.assertIn("portfolio-seed", out)

    def test_a_batch_size_above_the_server_limit_is_refused(self):
        with mock.patch.object(sys, "argv", ["portfolio-seed", "--batch-size", "900"]), \
            contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as caught:
                seed.main()
        self.assertEqual(caught.exception.code, 2)


class ToonTest(unittest.TestCase):
    def test_the_json_fallback_still_answers(self):
        with mock.patch.object(seed.shutil, "which", return_value=None):
            rendered = seed.to_toon({"ok": True})
        self.assertEqual(json.loads(rendered), {"ok": True})


if __name__ == "__main__":
    unittest.main()
