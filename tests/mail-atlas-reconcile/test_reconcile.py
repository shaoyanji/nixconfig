#!/usr/bin/env python3
"""Fixture for modules/services/mail-atlas/reconcile.py.

The reconcile rewrites boxes for every archived letter, so the cases that matter
are the ones where a read is not a fact: a document with no `envelopes`, an
Inbox that reads empty while the archive still holds letters, a page cap, a head
that moves mid-walk, and a mailbox read that fails outright. Each of those must
abort before a single write. The happy paths below pin the verdict itself.
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
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "mail_atlas_reconcile", ROOT / "modules" / "services" / "mail-atlas" / "reconcile.py"
)
reconcile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reconcile)


def page(*ids):
    return {"envelopes": [{"message-id": f"<{i}>"} for i in ids]}


class EnvelopeDocumentTest(unittest.TestCase):
    def test_a_document_without_envelopes_is_a_failed_read(self):
        for doc in ({}, {"error": "boom"}, [], None):
            with self.assertRaises(reconcile.WalkError):
                reconcile.envelopes_of(doc)

    def test_a_null_envelope_list_is_an_empty_page(self):
        self.assertEqual(reconcile.envelopes_of({"envelopes": None}), [])

    def test_head_skips_blank_ids(self):
        doc = {"envelopes": [{"message-id": ""}, {"message-id": "<a@b>"}]}
        self.assertEqual(reconcile.head_of(reconcile.envelopes_of(doc)), "a@b")


class WalkTest(unittest.TestCase):
    def walk(self, docs, page_size=2, max_pages=10, verify_head=True):
        calls = []

        def fake(argv, config, account, **_kw):
            calls.append(argv)
            return docs[len(calls) - 1]

        with mock.patch.object(reconcile, "himalaya", fake):
            result = reconcile.mailbox_ids(
                "/etc/himalaya.toml", "", "inbox", page_size, max_pages, verify_head=verify_head
            )
        return result, calls

    def test_a_short_first_page_is_the_whole_mailbox(self):
        (present, complete, pages), calls = self.walk([page("a", "b")], page_size=10)
        self.assertEqual((present, complete, pages), ({"a", "b"}, True, 1))
        self.assertEqual(len(calls), 1)

    def test_full_pages_then_a_short_one_are_every_letter(self):
        docs = [page("a", "b"), page("c", "d"), page("e"), page("a", "b")]
        (present, complete, pages), calls = self.walk(docs)
        self.assertEqual(present, {"a", "b", "c", "d", "e"})
        self.assertTrue(complete)
        self.assertEqual(pages, 3)
        # The fourth call is the head re-read the multi-page walk owes.
        self.assertEqual(len(calls), 4)
        self.assertEqual(calls[-1][-1], "1")

    def test_a_page_cap_is_incomplete_not_a_verdict(self):
        docs = [page("a", "b"), page("c", "d")]
        (present, complete, pages), calls = self.walk(docs, max_pages=2)
        self.assertFalse(complete)
        self.assertEqual(pages, 2)
        self.assertEqual(len(calls), 2)

    def test_a_head_that_moved_mid_walk_aborts(self):
        docs = [page("a", "b"), page("c"), page("new", "a")]
        with self.assertRaises(reconcile.WalkError) as caught:
            self.walk(docs)
        self.assertIn("head moved", str(caught.exception))

    def test_the_head_check_can_be_skipped_for_a_single_page(self):
        (present, _complete, _pages), calls = self.walk(
            [page("a", "b")], page_size=10, verify_head=False
        )
        self.assertEqual(len(calls), 1)
        self.assertEqual(present, {"a", "b"})


class PlanTest(unittest.TestCase):
    def test_the_three_moves(self):
        boxes = [("<back@x>", "archived"), ("<left@x>", "inbox"), ("<queued@x>", "queued")]
        changes = reconcile.plan(boxes, {"back@x"})
        self.assertEqual(
            changes,
            [
                ("<back@x>", "inbox", "back in the inbox"),
                ("<left@x>", "archived", "left the inbox"),
                ("<queued@x>", "gone", "left the inbox before the drain"),
            ],
        )

    def test_a_letter_that_agrees_is_not_a_change(self):
        self.assertEqual(reconcile.plan([("<a@x>", "inbox")], {"a@x"}), [])
        self.assertEqual(reconcile.plan([("<b@x>", "archived")], set()), [])

    def test_a_row_without_a_message_id_is_ignored(self):
        self.assertEqual(reconcile.plan([("", "inbox")], set()), [])


class HimalayaFailureTest(unittest.TestCase):
    def test_a_nonzero_exit_is_raised(self):
        proc = mock.Mock(returncode=1, stderr="no such mailbox", stdout="")
        with mock.patch.object(reconcile.subprocess, "run", return_value=proc):
            with self.assertRaises(RuntimeError) as caught:
                reconcile.himalaya(["envelope", "list"], "/etc/h.toml", "")
        self.assertIn("exited 1", str(caught.exception))

    def test_non_json_is_raised(self):
        proc = mock.Mock(returncode=0, stderr="", stdout="not json")
        with mock.patch.object(reconcile.subprocess, "run", return_value=proc):
            with self.assertRaises(RuntimeError) as caught:
                reconcile.himalaya(["envelope", "list"], "/etc/h.toml", "")
        self.assertIn("non-JSON", str(caught.exception))

    def test_a_timeout_is_a_plain_error_not_a_traceback(self):
        with mock.patch.object(
            reconcile.subprocess, "run", side_effect=subprocess.TimeoutExpired("himalaya", 300)
        ):
            with self.assertRaises(RuntimeError) as caught:
                reconcile.himalaya(["envelope", "list"], "/etc/h.toml", "")
        self.assertIn("timed out", str(caught.exception))


class MainTest(unittest.TestCase):
    def run_main(self, argv, boxes, walk, writes=None):
        writes = writes if writes is not None else []
        out = io.StringIO()

        def fake_api(base, path, payload=None):
            if path == "/api/atlas-boxes":
                return [{"messageId": mid, "box": box} for mid, box in boxes]
            writes.append(payload)
            return {"changed": 1}

        with mock.patch.object(sys, "argv", ["reconcile", "--himalaya-config", "/etc/h.toml"] + argv), \
            mock.patch.object(reconcile, "api", fake_api), \
            mock.patch.object(reconcile, "mailbox_ids", return_value=walk), \
            contextlib.redirect_stdout(out):
            code = reconcile.main()
        return code, json.loads(out.getvalue()), writes

    ARGS = ["--himalaya-config", "/etc/h.toml"]

    def test_a_normal_pass_writes_the_plan(self):
        code, summary, writes = self.run_main(
            [], [("<a@x>", "inbox"), ("<b@x>", "archived")], ({"b@x"}, True, 1)
        )
        self.assertEqual(code, 0)
        self.assertEqual((summary["archived"], summary["restored"]), (1, 1))
        self.assertEqual(len(writes), 2)
        self.assertEqual({w["box"] for w in writes}, {"archived", "inbox"})

    def test_dry_run_writes_nothing_but_reports_the_plan(self):
        code, summary, writes = self.run_main(
            ["--dry-run"], [("<a@x>", "inbox")], ({"stay@x"}, True, 1)
        )
        self.assertEqual(code, 0)
        self.assertEqual(writes, [])
        self.assertEqual(summary["archived"], 1)
        self.assertTrue(summary["dry_run"])

    def test_an_empty_walk_over_a_full_archive_aborts(self):
        code, summary, writes = self.run_main([], [("<a@x>", "inbox"), ("<b@x>", "inbox")], (set(), True, 1))
        self.assertEqual(code, 2)
        self.assertFalse(summary["ok"])
        self.assertIn("unread mailbox", summary["error"])
        self.assertEqual(writes, [])

    def test_allow_empty_is_the_deliberate_override(self):
        code, summary, writes = self.run_main(
            ["--allow-empty"], [("<a@x>", "inbox")], (set(), True, 1)
        )
        self.assertEqual(code, 0)
        self.assertEqual(summary["archived"], 1)
        self.assertEqual(len(writes), 1)

    def test_an_empty_walk_with_an_empty_archive_is_fine(self):
        code, summary, writes = self.run_main([], [], (set(), True, 1))
        self.assertEqual(code, 0)
        self.assertEqual(writes, [])

    def test_an_incomplete_walk_aborts(self):
        code, summary, writes = self.run_main([], [("<a@x>", "inbox")], ({"a@x"}, False, 40))
        self.assertEqual(code, 2)
        self.assertIn("page cap", summary["error"])
        self.assertEqual(writes, [])

    def test_a_walk_error_is_a_verdict_not_a_traceback(self):
        out = io.StringIO()

        def boom(*_a, **_k):
            raise reconcile.WalkError("head moved during the walk")

        with mock.patch.object(sys, "argv", ["reconcile", "--himalaya-config", "/etc/h.toml"]), \
            mock.patch.object(reconcile, "api", lambda *_a, **_k: [{"messageId": "<a@x>", "box": "inbox"}]), \
            mock.patch.object(reconcile, "mailbox_ids", boom), \
            contextlib.redirect_stdout(out):
            code = reconcile.main()
        summary = json.loads(out.getvalue())
        self.assertEqual(code, 2)
        self.assertIn("head moved", summary["error"])

    def test_an_unreadable_box_list_aborts_before_the_walk(self):
        out = io.StringIO()

        def refuse(*_a, **_k):
            raise urllib.error.URLError("connection refused")

        with mock.patch.object(sys, "argv", ["reconcile", "--himalaya-config", "/etc/h.toml"]), \
            mock.patch.object(reconcile, "api", refuse), \
            mock.patch.object(reconcile, "mailbox_ids", side_effect=AssertionError("walked")), \
            contextlib.redirect_stdout(out):
            code = reconcile.main()
        summary = json.loads(out.getvalue())
        self.assertEqual(code, 2)
        self.assertIn("cannot read the archive's boxes", summary["error"])

    def test_a_refused_write_is_reported_and_the_rest_continue(self):
        present = {"stay@x"}
        out = io.StringIO()
        writes = []

        def fake_api(base, path, payload=None):
            if path == "/api/atlas-boxes":
                return [{"messageId": "<a@x>", "box": "inbox"}, {"messageId": "<b@x>", "box": "inbox"}]
            if payload["messageId"] == "<a@x>":
                raise urllib.error.HTTPError(base, 404, "no", {}, io.BytesIO(b""))
            writes.append(payload)
            return {"changed": 1}

        with mock.patch.object(sys, "argv", ["reconcile", "--himalaya-config", "/etc/h.toml"]), \
            mock.patch.object(reconcile, "api", fake_api), \
            mock.patch.object(reconcile, "mailbox_ids", return_value=(present, True, 1)), \
            contextlib.redirect_stdout(out):
            code = reconcile.main()
        summary = json.loads(out.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(len(summary["failed"]), 1)
        self.assertEqual(len(writes), 1)

    def test_the_limit_truncates_the_plan_and_says_so(self):
        boxes = [(f"<{i}@x>", "inbox") for i in range(5)]
        code, summary, writes = self.run_main(["--limit", "2"], boxes, ({"stay@x"}, True, 1))
        self.assertEqual(code, 0)
        self.assertEqual(summary["planned"], 5)
        self.assertTrue(summary["truncated"])
        self.assertEqual(len(writes), 2)

    def test_a_second_pass_over_the_written_boxes_plans_nothing(self):
        boxes = [("<a@x>", "inbox"), ("<b@x>", "archived")]
        _code, _summary, writes = self.run_main([], boxes, ({"b@x"}, True, 1))
        applied = {(w["messageId"], w["box"]) for w in writes}
        after = [(mid, dict(applied)[mid]) if mid in dict(applied) else (mid, box) for mid, box in boxes]
        code, summary, writes = self.run_main([], after, ({"b@x"}, True, 1))
        self.assertEqual(code, 0)
        self.assertEqual(summary["planned"], 0)
        self.assertEqual(writes, [])


if __name__ == "__main__":
    unittest.main()
