#!/usr/bin/env python3
"""Quality gate: an HTML-only mail must still become full text.

The archive stores `body_plain`. A message whose only body part is `text/html`
used to store null there, which is the majority of bulk mail — the message was
archived and unsearchable at the same time. The importer now converts HTML with
the `html2markdown` binary; this gate is what proves the conversion actually
produces text, on real mail, rather than trusting that it would.

Two checks, because either alone can lie:

  1. **Conversion.** Take the newest N envelopes, read each message, and run the
     same extraction the importer runs: text parts if any, otherwise the HTML
     parts through html2markdown. A message with a body part that yields no text
     fails the gate.
  2. **Coverage.** Ask the API for the same window and assert every archived
     message in it reports a non-zero body length. This catches a conversion
     that works in this script but never reached the store.

Run it after an importer change and before calling the archive usable:

    task checks:email:bodies
    task checks:email:bodies SAMPLE=50
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.request


class Gate:
    def __init__(self, args):
        self.args = args
        self.failures = []
        self.rows = []

    def fail(self, message):
        self.failures.append(message)

    # -- mailbox ----------------------------------------------------------

    def himalaya(self, argv, timeout=300):
        cmd = ["himalaya", "-c", self.args.himalaya_config, "--json"]
        if self.args.account:
            cmd += ["-a", self.args.account]
        proc = subprocess.run(cmd + argv, capture_output=True, text=True, timeout=timeout)
        if proc.returncode != 0:
            raise RuntimeError(
                f"himalaya {' '.join(argv[:2])} exited {proc.returncode}: "
                f"{proc.stderr.strip()[:200]}"
            )
        return json.loads(proc.stdout)

    def extract(self, message):
        parts = message.get("parts") or []

        def part_body(index, key):
            if not isinstance(index, int) or not 0 <= index < len(parts):
                return ""
            value = (parts[index].get("body") or {}).get(key)
            return value.strip() if isinstance(value, str) else ""

        texts = [
            text
            for text in (
                part_body(index, "Text") for index in message.get("text_body") or []
            )
            if text
        ]
        if texts:
            return "\n\n".join(texts), "text"
        htmls = [
            html
            for html in (
                part_body(index, "Html") for index in message.get("html_body") or []
            )
            if html
        ]
        if not htmls:
            return "", "none"
        try:
            proc = subprocess.run(
                [self.args.html2markdown],
                input="\n".join(htmls),
                capture_output=True,
                text=True,
                timeout=120,
            )
        except OSError as exc:
            self.fail(f"html2markdown not runnable: {exc}")
            return "", "html"
        if proc.returncode != 0:
            self.fail(f"html2markdown exited {proc.returncode}: {proc.stderr.strip()[:120]}")
            return "", "html"
        return proc.stdout.strip(), "html"

    # -- api --------------------------------------------------------------

    def archived_bodies(self):
        try:
            with urllib.request.urlopen(
                f"{self.args.api}/api/list-emails?lim={self.args.sample}", timeout=30
            ) as response:
                rows = json.load(response)
        except Exception as exc:  # noqa: BLE001 - the gate reports, it does not raise
            self.fail(f"list-emails unreachable: {exc}")
            return {}
        return {
            row.get("messageId"): row.get("bodyLength") or 0
            for row in rows
            if isinstance(row, dict)
        }

    # -- run --------------------------------------------------------------

    def run(self):
        envelopes = (
            self.himalaya(
                ["envelope", "list", "-m", self.args.mailbox, "-s", str(self.args.sample)]
            ).get("envelopes")
            or []
        )
        if not envelopes:
            self.fail("no envelopes returned by himalaya")
        archived = self.archived_bodies()

        print(f"{'#':>3}  {'source':<7}{'words':>6}  {'archived':<9}{'bodyLength':>10}")
        for index, envelope in enumerate(envelopes):
            message = self.himalaya(
                ["message", "read", "-m", self.args.mailbox, envelope.get("id")]
            )
            text, source = self.extract(message)
            self.rows.append(source)
            words = len(text.split())
            message_id = envelope.get("message-id")
            body_length = archived.get(message_id)
            state = "absent" if body_length is None else "present"
            print(
                f"{index:>3}  {source:<7}{words:>6}  {state:<9}"
                f"{(body_length if body_length is not None else '-'):>10}"
            )
            if source != "none" and words < self.args.min_words:
                self.fail(
                    f"message {index}: {source} part produced {words} words "
                    f"(< {self.args.min_words})"
                )
            if body_length == 0:
                self.fail(f"message {index}: archived with an empty body")

        converted = sum(1 for row in self.rows if row == "html")
        print()
        print(f"sample      {len(envelopes)} envelopes, {converted} converted from HTML")
        if self.failures:
            print(f"FAILED      {len(self.failures)}")
            for failure in self.failures:
                print(f"  - {failure}")
            return 1
        print("PASSED      every HTML body converted to text and every archived row carries it")
        return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sample", type=int, default=20)
    parser.add_argument("--min-words", type=int, default=3)
    parser.add_argument("--mailbox", default="inbox")
    parser.add_argument("--account", default="")
    parser.add_argument(
        "--himalaya-config", default="/home/devji/.config/himalaya/config.toml"
    )
    # Never resolve through PATH by default: the login profile carries a
    # `html2markdown` wrapper that actually runs html2text, and a gate measuring
    # the wrong converter is worse than no gate.
    parser.add_argument(
        "--html2markdown",
        default=(
            "/run/current-system/sw/bin/html2markdown"
            if os.path.exists("/run/current-system/sw/bin/html2markdown")
            else "html2markdown"
        ),
    )
    parser.add_argument("--api", default="http://127.0.0.1:8080")
    args = parser.parse_args()
    try:
        return Gate(args).run()
    except (RuntimeError, json.JSONDecodeError) as exc:
        print(f"email-body-gate: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
