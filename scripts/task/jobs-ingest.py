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
    parser.add_argument("--dry-run", action="store_true", help="print payloads, POST nothing")
    args = parser.parse_args()

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

    created = updated = 0
    failed = []
    for posting in postings:
        if args.dry_run:
            print(json.dumps({"would_post": posting}, sort_keys=True), file=sys.stderr)
            continue
        try:
            answer = post_posting(args.api, posting, token=token, timeout=args.timeout)
            if answer.get("created"):
                created += 1
            else:
                updated += 1
        except IngestError as exc:
            failed.append({"url": posting["url"], "error": str(exc)[:300]})

    summary = {
        "run": "jobs-ingest",
        "dry_run": args.dry_run,
        "api": args.api,
        "jobs_seen": len(jobs),
        "postings": len(postings),
        "created": created,
        "updated": updated,
        "failed": failed,
        "warnings": warnings,
        "at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    print(json.dumps(summary, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
