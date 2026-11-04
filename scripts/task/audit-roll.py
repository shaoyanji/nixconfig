#!/usr/bin/env python3
"""Roll ledger entries older than N days into the agent turn log.

AUDIT.md is the current state plus the recent ledger, not a history file: what
happened is a turn (xs), the full text of anything rolled stays in the commit
that wrote it, and the fleet turn log is where an agent looks for who did what
and when. This moves the entries and leaves the pointer.

Each entry becomes one event: the heading is the action, the first paragraph is
the rationale, and the subject carries the date so a `subject=` filter finds it.
One event per entry rather than one batch, so two agents can read them apart.

Usage: audit-roll.py [--days 7] [--max 20] [--dry-run] [--json] [--cutoff DATE]
Exit 0 = rolled (or nothing to roll), 1 = the turn log refused a post.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
import uuid
from datetime import date, datetime, timedelta, timezone

AUDIT = "AUDIT.md"
ENTRY = re.compile(r"^### (?P<date>\d{4}-\d{2}-\d{2}) — (?P<title>.+)$")
DEFAULT_ENDPOINT = "https://delphi.cloudforest-kardashev.ts.net:8449"


def repo_root() -> str:
    """The working directory is not guaranteed; the ledger lives at the root."""
    here = os.path.dirname(os.path.abspath(__file__))
    result = subprocess.run(
        ["git", "-C", here, "rev-parse", "--show-toplevel"], capture_output=True, text=True
    )
    return result.stdout.strip() if result.returncode == 0 else os.path.abspath(f"{here}/../..")


def head() -> str | None:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], capture_output=True, text=True, cwd=repo_root()
    )
    return result.stdout.strip() or None if result.returncode == 0 else None


def token() -> str:
    existing = os.environ.get("AGENT_TURNS_TOKEN", "").strip()
    if existing:
        return existing
    try:
        raw = subprocess.run(
            ["sops", "-d", "modules/secrets.yaml"], capture_output=True, text=True, check=True
        ).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"audit-roll: no AGENT_TURNS_TOKEN and sops failed ({error})")
    match = re.search(r"^agent-turns-token:\s*(\S+)$", raw, re.MULTILINE)
    if not match:
        raise SystemExit("audit-roll: agent-turns-token is not in modules/secrets.yaml")
    return match.group(1)


def post(endpoint: str, bearer: str, event: dict) -> None:
    request = urllib.request.Request(
        f"{endpoint.rstrip('/')}/v1/events",
        data=json.dumps(event).encode(),
        headers={"content-type": "application/json", "authorization": f"Bearer {bearer}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            response.read()
    except urllib.error.HTTPError as error:
        # The shim says why it refused (a credential-shaped body, an unknown
        # field); a bare status code sends the next reader to the wrong place.
        detail = error.read().decode("utf-8", "replace").strip()[:400]
        raise SystemExit(
            f"audit-roll: the turn log refused {event['subject']} ({error.code})"
            + (f": {detail}" if detail else "")
        )


def blocks(lines: list[str]) -> list[tuple[int, int, str, str]]:
    """(start, end, date, title) for every `### <date> — <title>` block."""
    found: list[tuple[int, int, str, str]] = []
    start: int | None = None
    for index, line in enumerate(lines):
        match = ENTRY.match(line)
        if match:
            if start is not None:
                found.append((start, index, prev_date, prev_title))
            start, prev_date, prev_title = index, match.group("date"), match.group("title")
        elif start is not None and line.startswith("## "):
            found.append((start, index, prev_date, prev_title))
            start = None
    if start is not None:
        found.append((start, len(lines), prev_date, prev_title))
    return found


def event_subject(day: str, slug: str) -> str:
    return f"nixconfig:ledger-{day}-{slug}"


def summary(text: str) -> str:
    """The whole block flattened into one string.

    Every bullet is a fact the entry carried, and the entry is about to leave the
    file: keeping only the first paragraph dropped three of four bullets on the
    first real roll, so the cap is the only limit now.
    """
    body: list[str] = []
    for line in text.splitlines()[1:]:
        stripped = line.strip()
        if not stripped:
            continue
        body.append(stripped.lstrip("- ").replace("**", ""))
    flat = " · ".join(body)
    # 1000 is the shim's cap on `rationale` (docs/agent-turns.md); this function
    # used to cut at 2000 and the turn log refused every entry over 1000 with a
    # 400, which is why the ledger roll stopped working.
    limit = 1000
    return (flat[: limit - 1].rstrip() + "…") if len(flat) > limit else flat


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=7, help="age at which an entry rolls")
    parser.add_argument("--max", type=int, default=20, help="entries per run, oldest first")
    parser.add_argument("--cutoff", default="", help="date YYYY-MM-DD; overrides --days (for a dry run)")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--source", default="freebuff-buffy")
    parser.add_argument("--endpoint", default=os.environ.get("AGENT_TURNS_URL", DEFAULT_ENDPOINT))
    args = parser.parse_args()

    cutoff = date.fromisoformat(args.cutoff) if args.cutoff else date.today() - timedelta(days=args.days)

    root = repo_root()
    ledger = os.path.join(root, AUDIT)
    with open(ledger, encoding="utf-8") as handle:
        lines = handle.read().splitlines()

    # The ledger is newest first, so within one date the later block is older.
    found = [entry for entry in blocks(lines) if date.fromisoformat(entry[2]) < cutoff]
    found.sort(key=lambda entry: (entry[2], -entry[0]))
    selected = found[: args.max]
    if not selected:
        print(json.dumps({"rolled": 0, "cutoff": cutoff.isoformat()}) if args.json else f"audit-roll: nothing older than {cutoff}")
        return 0

    bearer = "" if args.dry_run else token()
    rolled = []
    for start, end, day, title in selected:
        text = "\n".join(lines[start:end]).rstrip()
        slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:40] or "entry"
        event = {
            # Deterministic: the subject identifies the entry, so a re-run after a
            # timeout is the same event (the shim's id is the dedup key) instead
            # of a second copy of the same history.
            "id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"nixconfig:ledger:{event_subject(day, slug)}")),
            "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "source": args.source,
            "kind": "turn",
            "subject": event_subject(day, slug),
            "action": title[:200],
            "rationale": summary(text) or None,
            "base_commit": head(),
            "branch": "main",
            "files_changed": [AUDIT],
            "commits": [],
            "claims": [],
            "outcome": "done",
        }
        if not args.dry_run:
            post(args.endpoint, bearer, event)
        rolled.append({"date": day, "title": title[:120], "subject": event["subject"]})

    if not args.dry_run:
        drop = set()
        for start, end, _day, _title in selected:
            drop.update(range(start, end))
        kept = [line for index, line in enumerate(lines) if index not in drop]
        while "\n\n\n" in "\n".join(kept):
            kept = "\n".join(kept).replace("\n\n\n", "\n\n").splitlines()
        with open(ledger, "w", encoding="utf-8") as handle:
            handle.write("\n".join(kept).rstrip("\n") + "\n")

    payload = {"rolled": len(rolled), "cutoff": cutoff.isoformat(), "dry_run": args.dry_run, "entries": rolled}
    if args.json:
        print(json.dumps(payload, ensure_ascii=False))
    else:
        state = "would roll" if args.dry_run else "rolled"
        print(f"audit-roll: {state} {len(rolled)} entr{'y' if len(rolled) == 1 else 'ies'} before {cutoff}")
        for item in rolled:
            print(f"  {item['date']}  {item['subject']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
