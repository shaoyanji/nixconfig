#!/usr/bin/env python3
"""Fill the email archive from the live mailbox.

Envelopes come from himalaya — the same account and IMAP path the mail agent on
this host already uses — and every new message is posted to the loopback
NpgsqlRest API, which owns the schema. The endpoint upserts on message_id, so a
re-run is safe: a second pass updates rows instead of duplicating them.

Nothing here reads the database directly, so the importer needs no database
credential. It does need himalaya's config (which carries the account password
as a command) and write access to the attachment tree.

Backfill is bounded per run rather than by a watermark: the newest `--limit`
messages not yet in the archive are imported, then the run stops. Successive
runs therefore walk further back through the mailbox until it is exhausted,
without a state file to drift or a timestamp to trust.
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.request

LOG_PREFIX = "email-archive-import"


def log(message):
    print(f"{LOG_PREFIX}: {message}", flush=True)


class Importer:
    def __init__(self, args):
        self.args = args
        # message_id -> archived body length, so a run can both skip what is
        # already there and find the rows an older run stored without text.
        self.known = {}
        self.imported = 0
        self.refilled = 0
        self.converted = 0
        self.skipped = 0
        self.failed = 0

    # -- himalaya ---------------------------------------------------------

    def himalaya(self, argv, timeout):
        cmd = ["himalaya", "-c", self.args.himalaya_config, "--json"]
        if self.args.account:
            cmd += ["-a", self.args.account]
        # `--json` is a global flag; the subcommand and its arguments follow.
        proc = subprocess.run(
            cmd + argv, capture_output=True, text=True, timeout=timeout
        )
        if proc.returncode != 0:
            raise RuntimeError(
                f"himalaya {' '.join(argv[:2])} exited {proc.returncode}: "
                f"{proc.stderr.strip()[:300]}"
            )
        try:
            return json.loads(proc.stdout)
        except json.JSONDecodeError as exc:
            raise RuntimeError(
                f"himalaya {' '.join(argv[:2])} returned non-JSON output: {exc}"
            )

    def envelopes(self, page):
        doc = self.himalaya(
            [
                "envelope",
                "list",
                "-m",
                self.args.mailbox,
                "-p",
                str(page),
                "-s",
                str(self.args.page_size),
            ],
            timeout=300,
        )
        return doc.get("envelopes") or []

    def message(self, message_id):
        return self.himalaya(
            ["message", "read", "-m", self.args.mailbox, message_id], timeout=300
        )

    # -- api --------------------------------------------------------------

    def api_get(self, path):
        url = f"{self.args.api}{path}"
        with urllib.request.urlopen(url, timeout=60) as response:
            return json.load(response)

    def api_post(self, payload):
        body = json.dumps(payload).encode()
        request = urllib.request.Request(
            f"{self.args.api}/api/add-email",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.load(response)

    def load_known(self):
        # The archive answers with the newest rows; asking for as many as the
        # scan can reach is enough to skip the ones a run would otherwise re-read.
        limit = max(self.args.page_size * self.args.max_pages, self.args.limit)
        try:
            rows = self.api_get(f"/api/list-emails?lim={limit}")
        except (urllib.error.URLError, json.JSONDecodeError) as exc:
            raise RuntimeError(f"list-emails failed ({exc}); is the API up?")
        self.known = {
            row.get("messageId"): (row.get("bodyLength") or 0)
            for row in rows
            if row.get("messageId")
        }
        empty = sum(1 for length in self.known.values() if not length)
        log(f"archive holds {len(self.known)} known message ids ({empty} with no text)")

    # -- mapping ----------------------------------------------------------

    @staticmethod
    def address(entry):
        if not entry:
            return ""
        name, email = (entry.get("name") or "").strip(), (entry.get("email") or "").strip()
        if name and email:
            return f"{name} <{email}>"
        return email or name

    @staticmethod
    def part_body(parts, index, key):
        if not isinstance(index, int) or not 0 <= index < len(parts):
            return ""
        value = (parts[index].get("body") or {}).get(key)
        return value.strip() if isinstance(value, str) else ""

    def convert_html(self, html):
        """HTML to text through the html2markdown binary.

        A message whose only body part is text/html is the majority of bulk
        mail, and dropping it is what left an archive that could not find the
        message it had just stored.
        """
        try:
            proc = subprocess.run(
                [self.args.html2markdown],
                input=html,
                capture_output=True,
                text=True,
                timeout=120,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            log(f"html2markdown failed: {exc}")
            return ""
        if proc.returncode != 0:
            log(f"html2markdown exited {proc.returncode}: {proc.stderr.strip()[:200]}")
            return ""
        return proc.stdout.strip()

    def body(self, message):
        """The message text, converted from HTML when there is no text part."""
        parts = message.get("parts") or []
        texts = [
            text
            for text in (
                self.part_body(parts, index, "Text")
                for index in message.get("text_body") or []
            )
            if text
        ]
        if texts:
            return "\n\n".join(texts)
        htmls = [
            html
            for html in (
                self.part_body(parts, index, "Html")
                for index in message.get("html_body") or []
            )
            if html
        ]
        if not htmls:
            return ""
        converted = self.convert_html("\n".join(htmls))
        if converted:
            self.converted += 1
        return converted

    def attachments_dir(self, message_id):
        digest = hashlib.sha256(message_id.encode()).hexdigest()[:16]
        return os.path.join(self.args.attachments, digest)

    def fetch_attachments(self, envelope_id, message_id):
        target = self.attachments_dir(message_id)
        if os.path.isdir(target) and os.listdir(target):
            # Content-addressed by message id, and himalaya suffixes a name
            # collision instead of overwriting, so a re-download would duplicate
            # files. The directory existing is the record that it is done.
            return target
        os.makedirs(target, mode=0o750, exist_ok=True)
        try:
            proc = subprocess.run(
                [
                    "himalaya",
                    "-c",
                    self.args.himalaya_config,
                    "attachment",
                    "download",
                    # himalaya's own id, not the RFC Message-ID: the CLI answers
                    # a Message-ID with "no such message" and an empty stderr.
                    envelope_id,
                    "-m",
                    self.args.mailbox,
                    "-d",
                    target,
                ],
                capture_output=True,
                text=True,
                timeout=600,
            )
        except subprocess.TimeoutExpired:
            proc = None
        if proc is None or proc.returncode != 0 or not os.listdir(target):
            detail = "timed out" if proc is None else (proc.stderr.strip()[:200] or "no files")
            log(f"attachments for {message_id} not fetched ({detail})")
            shutil.rmtree(target, ignore_errors=True)
            return ""
        # The API runs as its own user and mirrors this tree, so hand the files
        # over in the same shape the upload handler would have left them.
        if os.geteuid() == 0:
            parent = os.stat(self.args.attachments)
            for root, dirs, files in os.walk(target):
                for name in dirs + files:
                    os.chown(os.path.join(root, name), parent.st_uid, parent.st_gid)
            os.chown(target, parent.st_uid, parent.st_gid)
        return target

    def row(self, envelope, message):
        message_id = envelope.get("message-id")
        body = self.body(message)
        # `message read` reports attachment part ids, but `attachment download`
        # rejects them ("No attachment with id 3") — asking for every attachment
        # is both what the archive wants and the shape the CLI actually accepts.
        attachment_path = (
            self.fetch_attachments(envelope.get("id"), message_id)
            if message.get("attachments")
            else ""
        )
        reply_to = envelope.get("in-reply-to") or []
        return {
            "messageId": message_id,
            # The parent message id is the nearest thing the archive has to a
            # thread: Gmail's own thread id is not an IMAP header.
            "threadId": reply_to[0] if reply_to else "",
            "sender": self.address((envelope.get("from") or [{}])[0]),
            "recipients": ",".join(
                entry.get("email") or ""
                for entry in (envelope.get("to") or [])
                if entry.get("email")
            ),
            "subject": envelope.get("subject") or "",
            "sentAt": envelope.get("date") or "",
            # The source folder is a real Gmail label; IMAP flags are not.
            "labels": self.args.mailbox,
            "bodyPlain": body,
            "attachmentPath": attachment_path,
        }

    # -- run --------------------------------------------------------------

    def run(self):
        self.load_known()
        scanned = 0
        for page in range(1, self.args.max_pages + 1):
            envelopes = self.envelopes(page)
            if not envelopes:
                break
            for envelope in envelopes:
                if self.imported >= self.args.limit:
                    break
                message_id = envelope.get("message-id")
                if not message_id:
                    self.skipped += 1
                    continue
                archived = self.known.get(message_id)
                refilling = archived == 0 and message_id in self.known
                if message_id in self.known and not (self.args.refill and refilling):
                    self.skipped += 1
                    continue
                scanned += 1
                if self.args.dry_run:
                    log(f"would import {message_id}")
                    self.imported += 1
                    continue
                try:
                    payload = self.row(envelope, self.message(envelope.get("id")))
                    self.api_post(payload)
                except (RuntimeError, urllib.error.URLError, subprocess.TimeoutExpired) as exc:
                    self.failed += 1
                    log(f"failed {message_id}: {exc}")
                    continue
                self.known[message_id] = len(payload.get("bodyPlain") or "") or 1
                if refilling:
                    self.refilled += 1
                else:
                    self.imported += 1
            if self.imported >= self.args.limit:
                break
        log(
            f"imported {self.imported}, refilled {self.refilled}, "
            f"html-converted {self.converted}, already archived {self.skipped}, "
            f"failed {self.failed}, newly seen {scanned}"
        )
        return 1 if self.failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", required=True, help="loopback NpgsqlRest base URL")
    parser.add_argument("--himalaya-config", required=True)
    parser.add_argument("--account", default="", help="himalaya account; empty = default")
    parser.add_argument("--mailbox", default="inbox")
    parser.add_argument("--attachments", required=True)
    parser.add_argument("--html2markdown", default="html2markdown")
    parser.add_argument(
        "--refill",
        action="store_true",
        help="also revisit archived messages whose stored body is empty",
    )
    parser.add_argument("--limit", type=int, default=100, help="new messages per run")
    parser.add_argument("--max-pages", type=int, default=20)
    parser.add_argument("--page-size", type=int, default=100)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        return Importer(args).run()
    except RuntimeError as exc:
        log(str(exc))
        return 2


if __name__ == "__main__":
    sys.exit(main())
