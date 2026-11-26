"""Unit tests for drain.py's resolution guards.

The cost of getting these wrong is a person's archive decision being closed as
"gone", so each guard is pinned: a common subject word is not a query, a full
final page is not a miss, a query miss is not absence, and a message already in
the target box is a done row, not a dismissal.
"""

import sys
import unittest
from unittest import mock

import drain


class PagedMailbox(drain.Mailbox):
    """A Mailbox whose himalaya answers from fixed pages instead of IMAP."""

    def __init__(self, pages, page_size=2):
        super().__init__("/dev/null", "", "inbox", page_size=page_size)
        self.pages = pages
        self.queries = []

    def himalaya(self, args):
        if args[1] == "search":
            self.queries.append(args[-1])
        page = int(args[args.index("-p") + 1])
        self.pages_read += 1
        return {"envelopes": self.pages[page - 1] if page <= len(self.pages) else []}


def envelope(message_id, uid):
    return {"id": uid, "message-id": f"<{message_id}>"}


class SearchTokenTest(unittest.TestCase):
    def test_stopword_subject_yields_no_query(self):
        self.assertIsNone(drain.search_token("Update available"))
        self.assertIsNone(drain.search_token("Your weekly newsletter"))

    def test_digit_token_beats_a_longer_word(self):
        token = drain.search_token("Invoice 4471 for the November statement")
        self.assertEqual(token, "4471")

    def test_content_word_survives_when_no_id_is_present(self):
        self.assertEqual(drain.search_token("Update on Kubernetes incident"), "Kubernetes")

    def test_empty_subject_yields_none(self):
        self.assertIsNone(drain.search_token(""))
        self.assertIsNone(drain.search_token(None))


class ScanTest(unittest.TestCase):
    def test_full_final_page_reads_one_more(self):
        # The cap is two pages, both full: the match on page three is still the
        # message, not a dismissal.
        mailbox = PagedMailbox(
            [[envelope("a@x", 1), envelope("b@x", 2)],
             [envelope("c@x", 3), envelope("d@x", 4)],
             [envelope("target@x", 9)]]
        )
        self.assertEqual(mailbox.scan("subject anything", "target@x"), "9")

    def test_short_page_ends_the_search(self):
        mailbox = PagedMailbox([[envelope("a@x", 1)], [envelope("t@x", 9)]])
        self.assertIsNone(mailbox.scan("subject anything", "t@x"))
        self.assertEqual(mailbox.searches, 1)


class FindTest(unittest.TestCase):
    def test_arrival_after_date_is_caught_by_the_recent_window(self):
        # The date queries miss (arrival date differs from the Date: header) and
        # the subject has no narrowing token, so the recent pages must answer.
        mailbox = PagedMailbox([[envelope("late@x", 7)]], page_size=2)
        mailbox.recent_pages = 1
        uid = mailbox.find("late@x", "Update available", None)
        self.assertEqual(uid, "7")
        self.assertFalse([q for q in mailbox.queries if q.startswith("subject")])

    def test_absent_message_is_none_without_deep_scan(self):
        mailbox = PagedMailbox([[]], page_size=2)
        self.assertIsNone(mailbox.find("nope@x", "Kubernetes", None))


class MainVerdictTest(unittest.TestCase):
    def run_main(self, mailbox, rows):
        closed = []

        def fake_api(base, path, body=None):
            if path.startswith("/api/atlas-actions"):
                return rows
            closed.append(body)
            return {}

        argv = ["drain", "--himalaya-config", "/dev/null"]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(
            drain, "Mailbox", lambda *a, **k: mailbox
        ), mock.patch.object(drain, "api", fake_api):
            drain.main()
        return closed

    def test_message_already_in_the_archive_closes_done(self):
        mailbox = mock.Mock()
        mailbox.searches = 0
        mailbox.pages_read = 0
        mailbox.find.return_value = None
        mailbox.in_mailbox.return_value = True
        closed = self.run_main(
            mailbox,
            [{"id": 1, "kind": "archive", "messageId": "moved@x", "subject": "s"}],
        )
        self.assertEqual(closed[0]["status"], "done")
        self.assertIn("already in", closed[0]["result"])

    def test_genuinely_absent_message_closes_dismissed(self):
        mailbox = mock.Mock()
        mailbox.searches = 0
        mailbox.pages_read = 0
        mailbox.find.return_value = None
        mailbox.in_mailbox.return_value = False
        closed = self.run_main(
            mailbox,
            [{"id": 2, "kind": "archive", "messageId": "gone@x", "subject": "s"}],
        )
        self.assertEqual(closed[0]["status"], "dismissed")


if __name__ == "__main__":
    unittest.main()
