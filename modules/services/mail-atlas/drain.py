"""Drain the mail-atlas decision queue into the mailbox.

The page writes decisions, never effects: `mail_action` rows say "archive this"
or "queue this for deletion" and stop there. This is the other end — a oneshot
unit on a timer that reads the pending rows, finds the message in the source
mailbox through himalaya, and does the one reversible thing the decision means:

  archive  move Inbox -> the archive mailbox (Gmail: `[Gmail]/All Mail`)
  delete   `himalaya message delete`, i.e. trash first, never expunge

`hermes` rows are left pending on purpose: an instruction is a sentence for an
agent (Hermes, `task agents:mail:atlas`), and a timer has no business
interpreting one. The run reports how many it left behind.

Resolution never guesses. himalaya's query language is textual and cannot match
a Message-ID, and a real inbox holds subjects that are not valid queries
(`[shaoyanji/nixconfig] Run failed: nixcachix - main (047f44a)` — brackets,
colons, parens). So the header always decides, and each query is only a way to
narrow the page it is found on: the message's own sent date first (`date` is a
plain date, no free text to parse), then one alphanumeric token of the subject.
A message none of those find is closed as dismissed with "not in inbox": the
archive stored the same `Date:` header the query reads, so three neighbouring
days are the whole answer, and whatever already moved the message satisfied the
person's decision. (`--deep-scan` adds a paged walk of the mailbox for a manual
investigation; on a 6000-envelope inbox that walk is a minute per run, which is
not what a five-minute timer should spend.) Any himalaya failure leaves its row
pending and fails the unit, so the timer retries; one bad row never stops the
others.
"""

import argparse
import datetime
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request

ARCHIVE = "archive"
DELETE = "delete"
HERMES = "hermes"


def log(**fields):
    print(json.dumps(fields, ensure_ascii=False), flush=True)


def call(argv, timeout=300):
    proc = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    if proc.returncode != 0:
        # himalaya writes some failures to stdout and nothing to stderr; report
        # whichever stream carries the reason, so the journal is diagnosable.
        detail = (proc.stderr.strip() or proc.stdout.strip())[:300]
        raise RuntimeError(
            f"{' '.join(argv[:4])} exited {proc.returncode}: {detail}"
        )
    return proc.stdout


def search_token(subject):
    """One token a text query can carry: the longest alphanumeric run.

    himalaya matches a text clause as a case-insensitive substring, so the
    token only has to narrow the page; the Message-ID header picks the row.
    """
    tokens = re.findall(r"[A-Za-z0-9]{4,}", subject or "")
    return max(tokens, key=len)[:60] if tokens else None


def date_queries(sent_at):
    """The days a message could be dated on, most likely first.

    The archive stores an ISO timestamp; Imap `Date:` headers carry the
    sender's offset, so a message sent near midnight lands on the neighbouring
    day. The header still decides, so a wrong day costs one empty page.
    """
    if not sent_at:
        return []
    try:
        day = datetime.date.fromisoformat(str(sent_at)[:10])
    except ValueError:
        return []
    return [
        f"date {day.isoformat()}",
        f"date {(day - datetime.timedelta(days=1)).isoformat()}",
        f"date {(day + datetime.timedelta(days=1)).isoformat()}",
    ]


class Mailbox:
    def __init__(self, config, account, source, page_size=100, index_pages=60):
        self.config = config
        self.account = account
        self.source = source
        self.page_size = page_size
        self.index_pages = index_pages
        self._by_id = None
        self.pages_read = 0
        self.searches = 0

    def himalaya(self, argv, timeout=300):
        cmd = ["himalaya", "-c", self.config, "--json"]
        if self.account:
            cmd += ["-a", self.account]
        out = call(cmd + argv, timeout=timeout)
        try:
            return json.loads(out or "{}")
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"himalaya returned non-JSON: {exc}") from exc

    def index(self):
        """Every message in the source mailbox, keyed by Message-ID.

        Bounded by `index_pages`; the mailbox is read once per run and shared by
        every row, so a run of fifteen decisions costs one scan, not fifteen.
        """
        if self._by_id is not None:
            return self._by_id
        by_id = {}
        for page in range(1, self.index_pages + 1):
            doc = self.himalaya(
                [
                    "envelope",
                    "list",
                    "-m",
                    self.source,
                    "-s",
                    str(self.page_size),
                    "-p",
                    str(page),
                ]
            )
            self.pages_read += 1
            envelopes = doc.get("envelopes") or []
            for envelope in envelopes:
                key = (envelope.get("message-id") or "").strip("<> ")
                if key:
                    by_id[key] = str(envelope.get("id"))
            if len(envelopes) < self.page_size:
                break
        self._by_id = by_id
        return by_id

    def scan(self, query, message_id, max_pages=2):
        """Pages of one search query, matched by Message-ID. None on a miss.

        A himalaya failure is raised, not swallowed into a miss: "the mailbox
        did not answer" must leave the row pending, while "the mailbox answered
        and it is not here" is the only thing that closes one as dismissed.
        """
        for page in range(1, max_pages + 1):
            self.searches += 1
            doc = self.himalaya(
                [
                    "envelope",
                    "search",
                    "-m",
                    self.source,
                    "-s",
                    str(self.page_size),
                    "-p",
                    str(page),
                    query,
                ]
            )
            envelopes = doc.get("envelopes") or []
            for envelope in envelopes:
                if (envelope.get("message-id") or "").strip("<> ") == message_id:
                    return str(envelope.get("id"))
            if len(envelopes) < self.page_size:
                return None
        return None

    def find(self, message_id, subject, sent_at, deep=False):
        """The mailbox uid for a Message-ID, or None when it is not here."""
        if not message_id:
            return None
        queries = date_queries(sent_at)
        token = search_token(subject)
        if token:
            queries.append(f"subject {token}")
        for query in queries:
            uid = self.scan(query, message_id)
            if uid is not None:
                return uid
        return self.index().get(message_id) if deep else None

    def move(self, uid, target):
        call(
            [
                "himalaya",
                "-c",
                self.config,
                *(["-a", self.account] if self.account else []),
                "message",
                "move",
                "-f",
                self.source,
                "-t",
                target,
                uid,
            ]
        )

    def trash(self, uid):
        # `message delete` moves to the trash and only expunges a message that is
        # already there. Nothing in this file ever expunges.
        call(
            [
                "himalaya",
                "-c",
                self.config,
                *(["-a", self.account] if self.account else []),
                "message",
                "delete",
                "-m",
                self.source,
                uid,
            ]
        )


def api(api_base, path, payload=None):
    url = f"{api_base}{path}"
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"} if data else {},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def close(api_base, action_id, status, result):
    return api(
        api_base,
        "/api/atlas-close",
        {"id": str(action_id), "status": status, "result": result},
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--api", default="http://127.0.0.1:8080")
    parser.add_argument("--himalaya-config", required=True)
    parser.add_argument("--account", default="")
    parser.add_argument("--mailbox", default="inbox")
    parser.add_argument("--archive-mailbox", default="[Gmail]/All Mail")
    parser.add_argument("--limit", type=int, default=50)
    parser.add_argument("--page-size", type=int, default=100)
    parser.add_argument("--index-pages", type=int, default=60)
    parser.add_argument(
        "--deep-scan",
        action="store_true",
        help="walk the whole mailbox when the date and subject queries miss",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    rows = api(args.api, f"/api/atlas-actions?status=pending&lim={args.limit}")
    mailbox = Mailbox(
        args.himalaya_config,
        args.account,
        args.mailbox,
        page_size=args.page_size,
        index_pages=args.index_pages,
    )

    done, dismissed, skipped, failed = [], [], [], []
    for row in rows:
        kind = row.get("kind")
        if kind not in (ARCHIVE, DELETE):
            # `hermes` is an agent's sentence to act on, never the timer's.
            skipped.append(row.get("id"))
            continue

        try:
            uid = mailbox.find(
                row.get("messageId") or "",
                row.get("subject") or "",
                row.get("sentAt"),
                deep=args.deep_scan,
            )
            if uid is None:
                result = f"not in {args.mailbox}"
                if not args.dry_run:
                    close(args.api, row["id"], "dismissed", result)
                dismissed.append({"id": row["id"], "result": result})
                continue

            if args.dry_run:
                result = (
                    f"would {'trash' if kind == DELETE else 'move to ' + args.archive_mailbox}"
                    f" uid {uid}"
                )
            elif kind == DELETE:
                mailbox.trash(uid)
                result = f"trashed uid {uid}"
            else:
                mailbox.move(uid, args.archive_mailbox)
                result = f"moved uid {uid} to {args.archive_mailbox}"
            if not args.dry_run:
                close(args.api, row["id"], "done", result)
            done.append({"id": row["id"], "kind": kind, "result": result})
        except (RuntimeError, subprocess.TimeoutExpired, urllib.error.URLError) as exc:
            failed.append({"id": row.get("id"), "kind": kind, "error": str(exc)[:300]})

    log(
        run="mail-atlas-drain",
        dry_run=args.dry_run,
        pending=len(rows),
        done=done,
        dismissed=dismissed,
        left_for_agent=skipped,
        failed=failed,
        searched=mailbox.searches,
        pages_read=mailbox.pages_read,
    )
    # A failed move is retried by the timer; the row stays pending.
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
