#!/usr/bin/env python3
"""Feed `deals-page-scrape.py` output into private-deals.

The scraper reads a rendered page and returns deals; private-deals owns the
SQLite store and its FTS5 index. This is the pipe between them, so one command
can sweep a board and index it:

    python3 scripts/task/deals-page-scrape.py --json https://shop.example/deals \
      | python3 scripts/task/deals-ingest.py --dry-run

Input is the scrape JSON: an array of pages, a single page object, or one
`{"deals": [...]}` object, on stdin or `--in FILE`. Field names differ by one
important detail — the scraper calls the struck-through price `original_price`,
the API calls it `list_price` — and that mapping is the reason this file exists
rather than a `jq` one-liner that would silently drop the original price.

A run posts in chunks to `POST /api/deals/batch`, which dedupes inside the
chunk and answers with `created`/`updated`/`skipped`/`failed` and per-index
errors. A server that predates that route answers 404 or 405, and the run falls
back to one `POST /api/deals` per deal rather than failing the sweep.

Nothing here writes the database directly: the server stays the only writer, so
the FTS index cannot drift from the rows.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

UA = "nixconfig-deals-ingest/1.0"
# The server refuses a larger batch than this; a chunk size above it would be a
# 400 for every chunk rather than a shorter run.
BATCH_LIMIT = 500


class IngestError(RuntimeError):
    """The server refused a deal; the run reports it and keeps going."""


class BatchUnsupported(IngestError):
    """The route is not there (404/405): post one deal at a time instead."""


def canonical(url: str) -> str:
    """The identity the server also computes: no fragment, no tracking query."""
    parts = urllib.parse.urlsplit((url or "").strip())
    query = [
        (k, v)
        for k, v in urllib.parse.parse_qsl(parts.query, keep_blank_values=False)
        if not k.lower().startswith("utm_") and k.lower() not in {"ref", "gclid", "fbclid"}
    ]
    return urllib.parse.urlunsplit(
        (
            parts.scheme.lower(),
            parts.netloc.lower().removeprefix("www."),
            parts.path.rstrip("/") or "/",
            urllib.parse.urlencode(query),
            "",
        )
    ).rstrip("/")


def source_for(url: str) -> str:
    host = urllib.parse.urlsplit(url).netloc.lower().removeprefix("www.")
    return host or "unknown"


def deal_pairs(document) -> list:
    """Every deal with the board it came from, in any shape the scraper emits.

    The board's host is the source, not the deal link's: a deal points at a
    redirect such as `cc.techbargains.com/otc/...`, which would file the whole
    feed under `cc`.
    """
    if isinstance(document, dict):
        if isinstance(document.get("deals"), list):
            source = source_for(document.get("url") or "") if document.get("url") else ""
            return [(source, deal) for deal in document["deals"]]
        for key in ("items", "pages", "results"):
            if isinstance(document.get(key), list):
                pairs = []
                for page in document[key]:
                    pairs.extend(deal_pairs(page))
                return pairs
        if document.get("title"):
            return [("", document)]
        return []
    if isinstance(document, list):
        pairs = []
        for entry in document:
            pairs.extend(deal_pairs(entry))
        return pairs
    return []


def deal_pages(document) -> list:
    """Just the deals, for callers that do not care which board they came from."""
    return [deal for _source, deal in deal_pairs(document)]


def to_input(deal: dict, source: str = "", merchant: str = "", tags=()) -> dict:
    """A scraped deal in the API's own vocabulary."""
    price = deal.get("price")
    original = deal.get("original_price")
    return {
        "url": (deal.get("url") or "").strip(),
        "source": source or source_for(deal.get("url") or ""),
        "merchant": merchant or (deal.get("merchant") or "").strip(),
        "title": (deal.get("title") or "").strip(),
        "description": "",
        "category": (deal.get("category") or "").strip(),
        "currency": (deal.get("currency") or "EUR").strip(),
        "price": price,
        # The scraper's original price is the API's list price.
        "list_price": original,
        "discount_pct": deal.get("discount_pct"),
        "tags": sorted(
            {tag.strip().lower() for tag in list(tags) + list(deal.get("tags") or []) if tag and tag.strip()}
        ),
    }


def build_inputs(deals, source="", merchant="", tags=(), warnings=None, page_sources=None):
    warnings = warnings if warnings is not None else []
    inputs, seen = [], set()
    for index, deal in enumerate(deals):
        page_source = page_sources[index] if page_sources else ""
        posting = to_input(deal, source=source or page_source, merchant=merchant, tags=tags)
        if not posting["title"] or not posting["url"]:
            warnings.append(f"skipped: no title or url ({deal.get('url') or deal.get('title')})")
            continue
        if posting["price"] is None:
            warnings.append(f"skipped: no price ({posting['url']})")
            continue
        key = canonical(posting["url"])
        if key in seen:
            continue
        seen.add(key)
        posting["url"] = key or posting["url"]
        inputs.append(posting)
    return inputs, warnings


def post_deal(api: str, payload: dict, token: str = "", timeout: int = 30):
    body = json.dumps(payload).encode()
    headers = {"Content-Type": "application/json", "User-Agent": UA}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"{api.rstrip('/')}/api/deals", data=body, headers=headers, method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:300]
        raise IngestError(f"{exc.code} {detail}") from exc
    except urllib.error.URLError as exc:
        raise IngestError(f"api unreachable: {exc.reason}") from exc


def post_batch(api: str, payloads: list, token: str = "", timeout: int = 30) -> dict:
    """One request for a chunk of deals, so a sweep is not one round trip each."""
    body = json.dumps({"deals": list(payloads)}).encode()
    headers = {"Content-Type": "application/json", "User-Agent": UA}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"{api.rstrip('/')}/api/deals/batch", data=body, headers=headers, method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:300]
        if exc.code in (404, 405):
            raise BatchUnsupported(f"{exc.code} {detail}") from exc
        raise IngestError(f"{exc.code} {detail}") from exc
    except urllib.error.URLError as exc:
        raise IngestError(f"api unreachable: {exc.reason}") from exc


def post_singles(api: str, payloads, token: str = "", timeout: int = 30):
    """The pre-batch path: one request each, so one refusal cannot lose the rest."""
    created = updated = 0
    failed = []
    for payload in payloads:
        try:
            answer = post_deal(api, payload, token=token, timeout=timeout)
            if answer.get("created"):
                created += 1
            else:
                updated += 1
        except IngestError as exc:
            failed.append({"url": payload["url"], "error": str(exc)[:300]})
    return created, updated, failed


def post_chunks(api: str, payloads, batch_size: int, token: str = "", timeout: int = 30):
    """Send in chunks, fall back to singles on the first 404/405, count the answer."""
    created = updated = skipped = 0
    failed = []
    batched = True
    start = 0
    while start < len(payloads):
        chunk = payloads[start : start + batch_size]
        start += len(chunk)
        if batched:
            try:
                answer = post_batch(api, chunk, token=token, timeout=timeout)
            except BatchUnsupported:
                batched = False
            except IngestError as exc:
                failed.extend({"url": p["url"], "error": str(exc)[:300]} for p in chunk)
                continue
            else:
                created += int(answer.get("created") or 0)
                updated += int(answer.get("updated") or 0)
                skipped += int(answer.get("skipped") or 0)
                errors = answer.get("errors") or []
                for error in errors:
                    index = error.get("index")
                    url = (
                        chunk[index]["url"]
                        if isinstance(index, int) and 0 <= index < len(chunk)
                        else chunk[0]["url"]
                    )
                    failed.append({"url": url, "error": str(error.get("error", ""))[:300]})
                undetailed = int(answer.get("failed") or 0) - len(errors)
                if undetailed > 0:
                    failed.append({"url": "", "error": f"{undetailed} more refused without detail"})
                continue
        one_created, one_updated, one_failed = post_singles(
            api, chunk, token=token, timeout=timeout
        )
        created += one_created
        updated += one_updated
        failed.extend(one_failed)
    return created, updated, skipped, failed, batched


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Feed deals-page-scrape JSON into private-deals /api/deals."
    )
    parser.add_argument("--api", default="http://127.0.0.1:8102", help="private-deals base URL")
    parser.add_argument("--in", dest="input_path", help="scrape JSON file; default stdin")
    parser.add_argument("--source", default="", help="override the source label")
    parser.add_argument("--merchant", default="", help="override the merchant")
    parser.add_argument("--tag", action="append", default=[], help="extra tag per deal")
    parser.add_argument("--min-discount", type=int, default=0, help="drop deals below this %% off")
    parser.add_argument(
        "--token-env",
        default="PRIVATE_DEALS_ADMIN_TOKEN",
        help="environment variable holding the write bearer token",
    )
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument(
        "--batch-size",
        type=int,
        default=100,
        help=f"deals per /api/deals/batch request (1-{BATCH_LIMIT}); a 404/405 falls back to single POSTs",
    )
    parser.add_argument("--dry-run", action="store_true", help="print payloads, POST nothing")
    args = parser.parse_args()
    if not 1 <= args.batch_size <= BATCH_LIMIT:
        parser.error(f"--batch-size must be between 1 and {BATCH_LIMIT}")

    try:
        raw = open(args.input_path, encoding="utf-8").read() if args.input_path else sys.stdin.read()
        document = json.loads(raw or "[]")
    except OSError as exc:
        print(json.dumps({"error": f"cannot read input: {exc}"}))
        return 2
    except json.JSONDecodeError as exc:
        print(json.dumps({"error": f"input is not JSON: {exc}"}))
        return 2

    pairs = deal_pairs(document)
    deals = [deal for _source, deal in pairs]
    inputs, warnings = build_inputs(
        deals,
        source=args.source,
        merchant=args.merchant,
        tags=args.tag,
        page_sources=[source for source, _deal in pairs],
    )
    if args.min_discount:
        kept = [d for d in inputs if (d.get("discount_pct") or 0) >= args.min_discount]
        dropped = len(inputs) - len(kept)
        if dropped:
            warnings.append(f"dropped {dropped} deals under {args.min_discount}% off")
        inputs = kept
    token = os.environ.get(args.token_env, "").strip()

    if args.dry_run:
        for payload in inputs:
            print(json.dumps({"would_post": payload}, sort_keys=True), file=sys.stderr)
        created = updated = skipped = 0
        failed = []
        batched = False
    else:
        created, updated, skipped, failed, batched = post_chunks(
            args.api, inputs, args.batch_size, token=token, timeout=args.timeout
        )

    summary = {
        "run": "deals-ingest",
        "dry_run": args.dry_run,
        "api": args.api,
        "deals_seen": len(deals),
        "deals": len(inputs),
        "batch": batched,
        "batch_size": args.batch_size,
        "created": created,
        "updated": updated,
        "skipped": skipped,
        "failed": failed,
        "warnings": warnings,
        "at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    print(json.dumps(summary, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
