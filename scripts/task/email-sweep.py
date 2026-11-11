#!/usr/bin/env python3
"""Resolve a block of the human queue by selector, not one message at a time.

`agents:mail:resolve` is right for a single message. A queue of 511 is not 511
decisions, it is ~60 sender decisions: the same feed writes ten times, the same
bank alerts monthly. This applies one decision to every row a selector names and
prints what it matched before it writes anything.

Selectors combine with AND: `--sender gumball --older 30` is the rows from that
sender older than 30 days. At least one selector is required, so a mistyped
command cannot empty the queue.

  --sender S    substring of the sender address
  --domain D    exact domain of the sender address
  --subject S   substring of the subject
  --tier T      comma-separated tiers (person, action, review)
  --older N     rows older than N days
  --newer N     rows newer than N days
  --limit N     stop after N matches

Exit 0 = resolved (or would, with --dry-run); 2 = no selector or bad input;
1 = the API refused a resolve.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from email.utils import parseaddr

# Same default as the taskfile's other mail calls: the API is loopback on delphi,
# so any other tailnet host has to name it. Without this the sweep silently
# answered whatever else listens on 8080 (a 404, read as "no rows").
DEFAULT_API = os.environ.get("EMAIL_ARCHIVE_API", "http://127.0.0.1:8080")


def get(url: str, timeout: float = 60.0) -> object:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode() or "null")


def post(url: str, payload: dict, timeout: float = 30.0) -> object:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read().decode() or "null"
    return json.loads(body)


# NpgsqlRest answers camelCase; the rest of this script reads snake_case.
ALIASES = {"messageId": "message_id", "sentAt": "sent_at", "bodyLength": "body_length"}


def normalize(row: dict) -> dict:
    return {ALIASES.get(key, key): value for key, value in row.items()}


def address(sender: str | None) -> str:
    return parseaddr(sender or "")[1].strip().lower()


def when(value: str | None) -> datetime | None:
    try:
        return datetime.fromisoformat((value or "")[:19]).replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--api", default=DEFAULT_API)
    parser.add_argument("--sender", default="")
    parser.add_argument("--domain", default="")
    parser.add_argument("--subject", default="")
    parser.add_argument("--tier", default="")
    parser.add_argument("--older", type=float, default=None, help="days")
    parser.add_argument("--newer", type=float, default=None, help="days")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--apply", action="store_true", help="resolve; without it nothing is written")
    parser.add_argument("--json", action="store_true", help="structured output (pipe through toon -e)")
    args = parser.parse_args()

    if not any(
        [args.sender, args.domain, args.subject, args.tier, args.older, args.newer]
    ):
        print(
            "email-sweep: a selector is required (--sender, --domain, --subject, "
            "--tier, --older, --newer)",
            file=sys.stderr,
        )
        return 2

    api = args.api.rstrip("/")
    rows = [normalize(row) for row in (get(f"{api}/api/attention?lim=100000") or [])]
    tiers = {tier.strip().lower() for tier in args.tier.split(",") if tier.strip()}
    now = datetime.now(timezone.utc)
    sender = args.sender.lower()
    subject = args.subject.lower()

    matched = []
    for row in rows:
        addr = address(row.get("sender"))
        domain = addr.split("@")[-1] if "@" in addr else ""
        if sender and sender not in addr:
            continue
        if args.domain and args.domain.lower() != domain:
            continue
        if subject and subject not in (row.get("subject") or "").lower():
            continue
        if tiers and (row.get("tier") or "").lower() not in tiers:
            continue
        sent = when(row.get("sent_at"))
        if args.older is not None:
            if sent is None or sent >= now - timedelta(days=args.older):
                continue
        if args.newer is not None:
            if sent is None or sent <= now - timedelta(days=args.newer):
                continue
        matched.append(row)

    matched.sort(key=lambda row: row.get("sent_at") or "")
    if args.limit:
        matched = matched[: args.limit]

    by_tier: dict[str, int] = {}
    by_sender: dict[str, int] = {}
    for row in matched:
        by_tier[row.get("tier") or "?"] = by_tier.get(row.get("tier") or "?", 0) + 1
        addr = address(row.get("sender"))
        by_sender[addr] = by_sender.get(addr, 0) + 1

    resolved = 0
    failed = 0
    if args.apply:
        for row in matched:
            try:
                post(f"{api}/api/triage-resolve", {"messageId": row["message_id"]})
                resolved += 1
            except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, KeyError) as error:
                failed += 1
                print(f"email-sweep: {row.get('message_id')}: {error}", file=sys.stderr)

    payload = {
        "matched": len(matched),
        "resolved": resolved,
        "failed": failed,
        "applied": bool(args.apply),
        "by_tier": by_tier,
        "by_sender": dict(sorted(by_sender.items(), key=lambda item: -item[1])[:15]),
        "rows": [
            {
                "messageId": row.get("message_id"),
                "sentAt": (row.get("sent_at") or "")[:10],
                "tier": row.get("tier"),
                "sender": address(row.get("sender")),
                "subject": (row.get("subject") or "")[:80],
            }
            for row in matched[:20]
        ],
    }

    if args.json:
        print(json.dumps(payload, ensure_ascii=False))
    else:
        state = "resolved" if args.apply else "would resolve"
        print(f"email-sweep: {len(matched)} matched, {state} {resolved if args.apply else len(matched)}")
        if failed:
            print(f"  failed {failed}", file=sys.stderr)
        print("  by tier:   " + " ".join(f"{tier}={n}" for tier, n in sorted(by_tier.items())))
        print("  by sender: " + " ".join(f"{addr}={n}" for addr, n in payload["by_sender"].items()))
        for row in payload["rows"]:
            print(f"  {row['sentAt']}  {row['tier']:<7} {row['sender'][:34]:<34} {row['subject']}")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
