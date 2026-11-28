#!/usr/bin/env python3
"""Fixture for the email-archive importer's scan window.

The failure this pins is silent: an archive that outgrew a fixed window made
every run re-read the same known envelopes, import nothing, and exit 0 with a
warning. Measured on delphi 2026-11-26 — `--max-pages 20` over 3,516 archived
messages read the same 2,000 envelopes hourly while the INBOX held 7,555.

The mailbox is synthetic and ordered newest-first, exactly as an IMAP folder is,
so the assertions are about pages read and messages imported rather than about
himalaya.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "email_archive_import", ROOT / "modules" / "services" / "email-archive-import.py"
)
archive = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(archive)

PAGE = 100


def args(**overrides):
    base = dict(
        api="http://127.0.0.1:1",
        himalaya_config="/dev/null",
        account="",
        mailbox="inbox",
        attachments="/tmp",
        html2markdown="cat",
        refill=False,
        limit=100,
        max_pages=0,
        page_size=PAGE,
        known_limit=50000,
        start_page=1,
        dry_run=False,
    )
    base.update(overrides)
    return SimpleNamespace(**base)


class FakeImporter(archive.Importer):
    """An importer whose mailbox is a list of Message-IDs, newest first."""

    def __init__(self, argv, mailbox_ids, archived_ids=()):
        super().__init__(argv)
        self.mailbox_ids = list(mailbox_ids)
        self.archived = set(archived_ids)
        self.pages_read = []
        self.posted = []

    def load_known(self):
        self.known = {message_id: 100 for message_id in self.archived}

    def envelopes(self, page):
        self.pages_read.append(page)
        start = (page - 1) * self.args.page_size
        window = self.mailbox_ids[start : start + self.args.page_size]
        return [
            {"id": str(index), "message-id": message_id}
            for index, message_id in enumerate(window, start=start)
        ]

    def message(self, _uid):
        return {"parts": [], "text_body": [], "html_body": [], "attachments": []}

    def api_post(self, payload):
        self.posted.append(payload["messageId"])
        return {"ok": True}


def mailbox(new, old, fresh_prefix="new", old_prefix="old"):
    return [f"{fresh_prefix}{i}" for i in range(new)] + [
        f"{old_prefix}{i}" for i in range(old)
    ]


def run(importer):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = importer.run()
    return code, out.getvalue()


class WindowMathTest(unittest.TestCase):
    def test_derived_window_reaches_past_the_archive(self):
        importer = FakeImporter(args(limit=100, page_size=PAGE), [])
        # 3,516 archived: 3,616 messages plus two pages of slack at 100 a page.
        self.assertEqual(importer.pages_for(3516), 39)

    def test_zero_pages_stays_derived(self):
        importer = FakeImporter(args(max_pages=0, limit=100), [])
        self.assertEqual(importer.pages_for(0), 3)


class WideningTest(unittest.TestCase):
    def test_fixed_window_shorter_than_the_archive_is_widened(self):
        ids = mailbox(new=7555 - 3516, old=3516)
        importer = FakeImporter(
            args(max_pages=20, limit=5), ids, archived_ids=ids[:3516]
        )
        code, out = run(importer)
        self.assertEqual(code, 0)
        # limit 5 over 3,516 archived: ceil(3521/100) + 2 = 38 pages.
        self.assertIn("widening to 38 pages", out)
        self.assertEqual(importer.imported, 5)
        # The unseen run starts at envelope 3,517, which is on page 36.
        self.assertEqual(importer.pages_read[-1], 36)
        self.assertGreaterEqual(len(importer.pages_read), 20)

    def test_a_window_that_already_reaches_is_left_alone(self):
        ids = mailbox(new=50, old=0)
        importer = FakeImporter(args(max_pages=20, limit=100), ids)
        code, out = run(importer)
        self.assertEqual(code, 0)
        self.assertNotIn("widening", out)
        self.assertEqual(importer.imported, 50)

    def test_derived_window_is_not_widened(self):
        ids = mailbox(new=7555 - 3516, old=3516)
        importer = FakeImporter(args(max_pages=0, limit=5), ids, archived_ids=ids[:3516])
        _code, out = run(importer)
        self.assertNotIn("widening", out)
        self.assertEqual(importer.imported, 5)


class LimitTest(unittest.TestCase):
    def test_a_run_stops_at_the_limit_and_names_where_to_resume(self):
        ids = mailbox(new=3000, old=0)
        importer = FakeImporter(args(limit=100), ids)
        _code, out = run(importer)
        self.assertEqual(importer.imported, 100)
        self.assertEqual(importer.pages_read, [1])
        self.assertIn("resume with --start-page 1", out)

    def test_deep_backfill_resumes_from_the_logged_page(self):
        ids = mailbox(new=7555 - 3516, old=3516)
        importer = FakeImporter(
            args(max_pages=0, limit=5, start_page=30), ids, archived_ids=ids[:3516]
        )
        _code, out = run(importer)
        self.assertEqual(importer.pages_read[0], 30)
        self.assertEqual(importer.imported, 5)
        self.assertIn("from 30", out)

    def test_start_page_past_the_archive_imports_everything_it_reads(self):
        ids = mailbox(new=0, old=300)
        importer = FakeImporter(args(start_page=2, limit=100), ids)
        _code, _out = run(importer)
        self.assertEqual(importer.pages_read, [2])
        self.assertEqual(importer.imported, 100)


class DryRunTest(unittest.TestCase):
    def test_dry_run_counts_without_posting(self):
        ids = mailbox(new=20, old=0)
        importer = FakeImporter(args(dry_run=True, limit=100), ids)
        code, _out = run(importer)
        self.assertEqual(code, 0)
        self.assertEqual(importer.imported, 20)
        self.assertEqual(importer.posted, [])


if __name__ == "__main__":
    unittest.main()
