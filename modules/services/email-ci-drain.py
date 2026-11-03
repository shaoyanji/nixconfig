#!/usr/bin/env python3
"""Close CI notices nobody will act on.

`agent:ci` is a queue, and until something reads it, it is a mailbox with a nicer
name: 237 open and zero resolved on delphi, while the runs themselves live in
GitHub. Two rules close the ones that cannot need a person:

  * staleness — a notice older than `--days` is resolved; a two-week-old run
    notice is a historical record, and the CI system already told GitHub.
  * supersession — when several notices name the same repo and workflow, only
    the newest stays; the earlier ones describe a state that has been replaced.

Anything that does not fit a rule is left alone: this drains, it does not judge.
Writes go through the archive API (`POST /api/triage-resolve`), so the mail stays
archived and only its verdict is closed.

The report is for an agent: counts plus a five-row sample, not 237 message ids.
`--full` adds every closed id when something needs to inspect them.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

OWNER = "agent:ci"
SUBJECT = re.compile(r"^(?:\[(?P<repo>[^\]]{1,80})\]\s*)?(?P<rest>.+)$")


def get(url: str, timeout: float = 30.0) -> object:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode() or "null")


def post(url: str, payload: dict, timeout: float = 30.0) -> None:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        response.read()


def key_of(subject: str) -> tuple[str, str]:
    """The repo and workflow a notice is about, as far as the subject says.

    A notice that names no repo groups under "" — it is only ever superseded by
    another notice without one, which keeps the rule conservative.
    """
    match = SUBJECT.match(subject or "")
    if not match:
        return "", ""
    repo = (match.group("repo") or "").strip().lower()
    rest = re.split(r"[\(\-–|:]", match.group("rest"))[0].strip().lower()
    workflow = " ".join(rest.split()[:6])
    return repo, workflow


def resolve(api: str, message_id: str) -> None:
    post(f"{api}/api/triage-resolve", {"messageId": message_id})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default="http://127.0.0.1:8080")
    parser.add_argument("--limit", type=int, default=1000)
    parser.add_argument("--days", type=int, default=14, help="age after which a notice is stale")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true", help="structured output (pipe through toon -e)")
    parser.add_argument("--full", action="store_true", help="list every closed message, not a sample")
    parser.add_argument("--sample", type=int, default=5, help="rows in the report when not --full")
    args = parser.parse_args()

    api = args.api.rstrip("/")
    rows = get(f"{api}/api/agent-queue?owner={OWNER}&lim={args.limit}") or []
    if not rows:
        print(json.dumps({"open": 0, "resolved": 0}) if args.json else "ci drain: nothing in the queue")
        return 0

    cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)
    groups: dict[tuple[str, str], list[dict]] = {}
    for row in rows:
        groups.setdefault(key_of(row.get("subject") or ""), []).append(row)

    resolved: list[dict] = []
    for group in groups.values():
        group.sort(key=lambda row: row.get("sentAt") or "", reverse=True)
        for index, row in enumerate(group):
            sent = (row.get("sentAt") or "")[:19]
            try:
                age_ok = datetime.fromisoformat(sent).replace(tzinfo=timezone.utc) < cutoff
            except ValueError:
                age_ok = False
            superseded = index > 0
            if not (age_ok or superseded):
                continue
            reason = "stale" if age_ok else "superseded"
            if not args.dry_run:
                resolve(api, row["messageId"])
            resolved.append(
                {
                    "messageId": row["messageId"],
                    "sentAt": sent,
                    "subject": (row.get("subject") or "")[:80],
                    "reason": reason,
                }
            )

    payload = {
        "open": len(rows),
        "resolved": len(resolved),
        "by_reason": {},
        "closed": resolved if args.full else resolved[: args.sample],
    }
    for item in resolved:
        payload["by_reason"][item["reason"]] = payload["by_reason"].get(item["reason"], 0) + 1

    if args.json:
        print(json.dumps(payload, ensure_ascii=False))
    else:
        state = "would close" if args.dry_run else "closed"
        reasons = ", ".join(f"{k} {v}" for k, v in sorted(payload["by_reason"].items())) or "none"
        print(f"ci drain: {len(rows)} open, {state} {len(resolved)} ({reasons})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
