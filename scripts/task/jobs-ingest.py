#!/usr/bin/env python3
"""Feed `job-page-scrape.py` output into job-db-scraper.

Two halves existed without a pipe between them: reading a JS-rendered career
page (`job-page-scrape.py`, Tavily/Firecrawl/Context/agent-browser) and storing
a posting (`POST /api/postings` on job-db-scraper, which owns the SQLite FTS5
index). This is the pipe, so one command can sweep a board and index it:

    task apps:page -- --json https://jobs.lever.co/acme \
      | python3 scripts/task/jobs-ingest.py --dry-run

Input is the scrape JSON: an array of pages, a single page object, or one
`{"jobs": [...]}` object, on stdin or `--in FILE`. Each posting keeps the
scrape's URL as its identity — the server dedupes on canonical URL and
fingerprint — and the company is read from the ATS URL (`jobs.lever.co/<co>/…`),
because the scrape lists a board, not a brand. A page whose company cannot be
read is skipped and reported: a posting filed under the wrong employer is worse
than one not filed.

Nothing here writes the database directly, so the server stays the only writer
and the ingest cannot desynchronise the FTS index from the rows.

A run posts in chunks to `POST /api/postings/batch`, which dedupes inside the
chunk, stores the deterministic role-match score and lane per posting, and
answers with `created`/`updated`/`skipped`/`failed` plus per-index errors. A
server that predates that route answers 404 or 405, and the run falls back to
one `POST /api/postings` per posting rather than failing the sweep.
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

UA = "nixconfig-jobs-ingest/1.0"
# The server refuses a larger batch than this; a chunk size above it would be a
# 400 for every chunk rather than a shorter run.
BATCH_LIMIT = 500

# The board API behind a host is the useful source label: `lever` says more than
# `jobs.lever.co`, and the server stores it as a column the UI groups on.
ATS_HOSTS = {
    "jobs.lever.co": "lever",
    "jobs.ashbyhq.com": "ashby",
    "boards.greenhouse.io": "greenhouse",
    "job-boards.greenhouse.io": "greenhouse",
    "boards.eu.greenhouse.io": "greenhouse",
    "jobs.personio.de": "personio",
    "jobs.personio.com": "personio",
    "apply.workable.com": "workable",
    "jobs.smartrecruiters.com": "smartrecruiters",
    "careers.smartrecruiters.com": "smartrecruiters",
    "myworkdayjobs.com": "workday",
    "jobs.ashbyhq.com": "ashby",
}
# Segments that are never an employer name, so a URL without a company slug is
# skipped instead of being filed under "careers" or "jobs".
STOP_SEGMENTS = {
    "careers",
    "career",
    "jobs",
    "job",
    "en",
    "de",
    "search",
    "apply",
    "home",
    "index.html",
}


class IngestError(RuntimeError):
    """The server refused a posting; the run reports it and keeps going."""


class BatchUnsupported(IngestError):
    """The route is not there (404/405): post one posting at a time instead."""


def canonical(url: str) -> str:
    """The identity the server also computes: no fragment, no tracking query."""
    try:
        parts = urllib.parse.urlsplit((url or "").strip())
    except ValueError:
        return ""
    query = [
        (k, v)
        for k, v in urllib.parse.parse_qsl(parts.query, keep_blank_values=False)
        if not k.lower().startswith("utm_") and k.lower() not in {"ref", "gclid", "fbclid"}
    ]
    path = parts.path.rstrip("/") or "/"
    return urllib.parse.urlunsplit(
        (parts.scheme.lower(), parts.netloc.lower().removeprefix("www."), path,
         urllib.parse.urlencode(query), "")
    ).rstrip("/")


def source_for(url: str) -> str:
    host = urllib.parse.urlsplit(url).netloc.lower().removeprefix("www.")
    if host in ATS_HOSTS:
        return ATS_HOSTS[host]
    if host.endswith(".myworkdayjobs.com"):
        return "workday"
    return host or "unknown"


def company_from_url(url: str) -> str:
    """The employer slug a board URL carries, or empty when it carries none."""
    parts = urllib.parse.urlsplit(url)
    host = parts.netloc.lower().removeprefix("www.")
    segments = [s for s in parts.path.split("/") if s]
    if host in ATS_HOSTS or host.endswith(".myworkdayjobs.com"):
        for segment in segments:
            candidate = urllib.parse.unquote(segment)
            if candidate.lower() in STOP_SEGMENTS:
                continue
            if candidate.isdigit() or len(candidate) < 2:
                continue
            return candidate
        return ""
    # A company's own careers page: `careers.acme.example` names the employer
    # in its second label, and `acme.example` in its first.
    labels = host.split(".")
    label = labels[0]
    if label in STOP_SEGMENTS and len(labels) > 1:
        label = labels[1]
    return "" if not label or label in STOP_SEGMENTS else label


def page_jobs(document) -> list:
    """Every job in any of the shapes job-page-scrape can emit."""
    if isinstance(document, dict):
        if isinstance(document.get("jobs"), list):
            return document["jobs"]
        for key in ("items", "pages", "results"):
            if isinstance(document.get(key), list):
                return [job for page in document[key] for job in page_jobs(page)]
        return []
    if isinstance(document, list):
        jobs = []
        for entry in document:
            if isinstance(entry, dict) and isinstance(entry.get("jobs"), list):
                jobs.extend(entry["jobs"])
            elif isinstance(entry, dict) and entry.get("url") and entry.get("title"):
                jobs.append(entry)
        return jobs
    return []


def to_posting(job: dict, source: str = "", company: str = "", tags=()) -> dict:
    url = (job.get("url") or "").strip()
    title = (job.get("title") or "").strip()
    location = (job.get("location") or "").strip()
    return {
        "url": url,
        "source": source or source_for(url),
        "company": company or company_from_url(url),
        "title": title,
        "location": location,
        "remote": "remote" in f"{location} {title}".lower(),
        "employment": "",
        # The board listing carries no description; the detail page does, and
        # fetching it here would turn a cheap sweep into one request per job.
        "description": "",
        "tags": sorted({tag.strip().lower() for tag in tags if tag and tag.strip()}),
        "posted_at": "",
        "salary": "",
    }


def build_postings(jobs, source="", company="", tags=(), warnings=None):
    """Postings from a scrape, deduped by canonical URL, with skip reasons."""
    warnings = warnings if warnings is not None else []
    postings, seen = [], set()
    for job in jobs:
        posting = to_posting(job, source=source, company=company, tags=tags)
        if not posting["title"] or not posting["url"]:
            warnings.append(f"skipped: no title or url ({job.get('url') or job.get('title')})")
            continue
        if not posting["company"]:
            warnings.append(f"skipped: no company in {posting['url']}")
            continue
        key = canonical(posting["url"])
        if key in seen:
            continue
        seen.add(key)
        postings.append(posting)
    return postings, warnings


def post_posting(api: str, posting: dict, token: str = "", timeout: int = 30):
    body = json.dumps(posting).encode()
    headers = {"Content-Type": "application/json", "User-Agent": UA}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"{api.rstrip('/')}/api/postings", data=body, headers=headers, method="POST"
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
    """One request for a chunk of postings, so a sweep is not one round trip each."""
    body = json.dumps({"postings": list(payloads)}).encode()
    headers = {"Content-Type": "application/json", "User-Agent": UA}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"{api.rstrip('/')}/api/postings/batch", data=body, headers=headers, method="POST"
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
    for posting in payloads:
        try:
            answer = post_posting(api, posting, token=token, timeout=timeout)
            if answer.get("created"):
                created += 1
            else:
                updated += 1
        except IngestError as exc:
            failed.append({"url": posting["url"], "error": str(exc)[:300]})
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
        description="Feed job-page-scrape JSON into job-db-scraper's /api/postings."
    )
    parser.add_argument("--api", default="http://127.0.0.1:8101", help="job-db-scraper base URL")
    parser.add_argument("--in", dest="input_path", help="scrape JSON file; default stdin")
    parser.add_argument("--source", default="", help="override the source label")
    parser.add_argument("--company", default="", help="override the company")
    parser.add_argument("--tag", action="append", default=[], help="extra tag per posting")
    parser.add_argument(
        "--token-env",
        default="JOB_DB_ADMIN_TOKEN",
        help="environment variable holding the write bearer token",
    )
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument(
        "--batch-size",
        type=int,
        default=100,
        help=f"postings per /api/postings/batch request (1-{BATCH_LIMIT}); a 404/405 falls back to single POSTs",
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

    jobs = page_jobs(document)
    postings, warnings = build_postings(
        jobs, source=args.source, company=args.company, tags=args.tag
    )
    token = os.environ.get(args.token_env, "").strip()

    if args.dry_run:
        for posting in postings:
            print(json.dumps({"would_post": posting}, sort_keys=True), file=sys.stderr)
        created = updated = skipped = 0
        failed = []
        batched = False
    else:
        created, updated, skipped, failed, batched = post_chunks(
            args.api, postings, args.batch_size, token=token, timeout=args.timeout
        )

    summary = {
        "run": "jobs-ingest",
        "dry_run": args.dry_run,
        "api": args.api,
        "jobs_seen": len(jobs),
        "postings": len(postings),
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
