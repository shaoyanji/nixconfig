#!/usr/bin/env python3
"""Seed the portfolio indexes in one pass: scrape, batch-ingest, sync.

Three services hold the portfolio's data and three verbs fill them, one lane at a
time. Doing that by hand means knowing which scraper feeds which ingester, which
API port each one defaults to, and that a scrape with no hits still has to reach
the batch route to be counted. This runs the three lanes and says what landed.

    task agents:portfolio:seed -- --jobs https://boards.greenhouse.io/acme
    task agents:portfolio:seed -- --deals-from deals.json --only deals
    task agents:portfolio:seed -- --jobs-from jobs.json --only jobs --dry-run

A page with no postings is an answer, not a failure: the lane reports zero and
the run stays green. An ingest refusal is a failure, and the run exits 1 with the
first refusal in the summary.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
LANE_ORDER = ("jobs", "deals", "inventory")

LANES = {
    "jobs": {
        "label": "job-db-scraper",
        "scrape": "job-page-scrape.py",
        "ingest": "jobs-ingest.py",
        "api": "api_jobs",
        "pages": "jobs_pages",
        "from": "jobs_from",
        "unit": "postings",
    },
    "deals": {
        "label": "private-deals",
        "scrape": "deals-page-scrape.py",
        "ingest": "deals-ingest.py",
        "api": "api_deals",
        "pages": "deals_pages",
        "from": "deals_from",
        "unit": "deals",
    },
    "inventory": {"label": "inventory-site"},
}


def invoke(argv, run=None, timeout=600):
    """Run one child; a missing binary or a hang is an answer, not a traceback."""
    runner = run or subprocess.run
    try:
        result = runner(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 1, "", str(exc)
    return result.returncode, result.stdout or "", result.stderr or ""


def to_toon(document) -> str:
    binary = shutil.which("toon")
    if binary:
        try:
            result = subprocess.run(
                [binary],
                input=json.dumps(document),
                capture_output=True,
                text=True,
                timeout=30,
                check=True,
            )
            if result.stdout.strip():
                return result.stdout.rstrip("\n")
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            pass
    return json.dumps(document, indent=2)


def emit(document, fmt: str) -> None:
    print(to_toon(document) if fmt == "toon" else json.dumps(document, indent=2))


def scrape(spec, args, run):
    """Every page as the scraper's own JSON, merged into one document.

    The scraper exits 1 when every page came back empty. That is a real answer,
    so success here is "the JSON parsed", not "the exit code was zero".
    """
    pages, problems = [], []
    for url in getattr(args, spec["pages"]) or []:
        argv = [args.python, str(SCRIPTS / spec["scrape"]), "--json"]
        if args.backend:
            argv += ["--backend", args.backend]
        if args.max:
            argv += ["--max", str(args.max)]
        argv.append(url)
        code, out, err = invoke(argv, run, max(120, args.timeout * 4))
        try:
            document = json.loads(out)
        except json.JSONDecodeError:
            detail = (err.strip() or out.strip() or f"exit {code}")[:160]
            problems.append(f"{url}: {detail}")
            continue
        pages.extend(document if isinstance(document, list) else [document])
    return pages, problems


def counts_of(summary, unit):
    failed = summary.get("failed") or []
    return {
        unit: int(summary.get(unit) or 0),
        "created": int(summary.get("created") or 0),
        "updated": int(summary.get("updated") or 0),
        "skipped": int(summary.get("skipped") or 0),
        "failed": len(failed) if isinstance(failed, list) else int(failed or 0),
        "batch": bool(summary.get("batch", False)),
        "warnings": len(summary.get("warnings") or []),
        "first_error": str((failed[0] or {}).get("error", ""))[:160] if failed else "",
        "error": str(summary.get("error") or "")[:160],
    }


def explain(lane, code, err):
    """Why a lane is red: the per-item refusal, the child's own error, or its exit."""
    if not lane["ok"] and not lane.get("detail"):
        lane["detail"] = lane["first_error"] or lane["error"] or (err.strip() or f"exit {code}")[:160]
    return lane


def seed_lane(key, spec, args, run):
    """One scrape lane: document in, batch ingest out."""
    from_path = getattr(args, spec["from"]) or ""
    if from_path:
        try:
            document = json.loads(Path(from_path).expanduser().read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            return {"ok": False, "detail": f"cannot read {from_path}: {exc}"}
        pages = document if isinstance(document, list) else [document]
        scrape_note = f"from {from_path}"
    elif getattr(args, spec["pages"]):
        pages, problems = scrape(spec, args, run)
        scrape_note = f"{len(getattr(args, spec['pages']))} page(s)"
        if problems:
            return {"ok": False, "detail": "; ".join(problems), "scraped": 0}
    else:
        return {
            "ok": True,
            "skipped": True,
            "detail": f"no page given (--{key} URL or --{key}-from FILE)",
        }

    handle = tempfile.NamedTemporaryFile(
        "w", suffix=".json", delete=False, encoding="utf-8", prefix=f"portfolio-seed-{key}-"
    )
    try:
        with handle:
            json.dump(pages, handle)
        argv = [
            args.python,
            str(SCRIPTS / spec["ingest"]),
            "--api",
            getattr(args, spec["api"]),
            "--in",
            handle.name,
            "--timeout",
            str(args.timeout),
            "--batch-size",
            str(args.batch_size),
        ]
        if args.dry_run:
            argv.append("--dry-run")
        code, out, err = invoke(argv, run, max(120, args.timeout * 4))
        try:
            summary = json.loads(out)
        except json.JSONDecodeError:
            detail = (err.strip() or out.strip() or f"ingest exit {code}")[:160]
            return {"ok": False, "detail": detail, "scraped": len(pages)}
        lane = counts_of(summary, spec["unit"])
        lane["scraped"] = lane[spec["unit"]]
        lane["ok"] = code == 0 and not lane["failed"]
        lane["source"] = scrape_note
        lane["api"] = getattr(args, spec["api"])
        return explain(lane, code, err)
    finally:
        try:
            os.unlink(handle.name)
        except OSError:
            pass


def sync_lane(args, run):
    argv = [
        args.python,
        str(SCRIPTS / "inventory-sync.py"),
        "--api",
        args.api_inventory,
        "--format",
        "json",
        "--timeout",
        str(args.timeout),
    ]
    if args.inventory_from:
        argv += ["--in", args.inventory_from]
    else:
        argv.append("--eval")
    if args.inventory_hosts:
        argv += ["--only", args.inventory_hosts]
    if args.dry_run:
        argv.append("--dry-run")
    code, out, err = invoke(argv, run, max(180, args.timeout * 6))
    try:
        summary = json.loads(out)
    except json.JSONDecodeError:
        detail = (err.strip() or out.strip() or f"inventory-sync exit {code}")[:160]
        return {"ok": False, "detail": detail}
    lane = counts_of(summary, "items")
    lane["ok"] = code == 0 and not lane["failed"]
    lane["hosts"] = int(summary.get("hosts") or 0)
    lane["api"] = args.api_inventory
    return explain(lane, code, err)


def seed(args, run=None):
    run = run or subprocess.run
    lanes = {}
    for key in LANE_ORDER:
        if key not in args.only:
            continue
        spec = LANES[key]
        lanes[key] = sync_lane(args, run) if key == "inventory" else seed_lane(key, spec, args, run)

    failed = [key for key, lane in lanes.items() if not lane.get("ok")]
    skipped = [key for key, lane in lanes.items() if lane.get("skipped")]
    return {
        "run": "portfolio-seed",
        "dry_run": args.dry_run,
        "only": list(args.only),
        "ok": not failed,
        "failed": failed,
        "skipped": skipped,
        "lanes": lanes,
        "at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    }


def parse_only(value):
    wanted = [part.strip() for part in (value or "").split(",") if part.strip()]
    unknown = [part for part in wanted if part not in LANE_ORDER]
    if unknown:
        raise argparse.ArgumentTypeError(f"unknown lane(s): {', '.join(unknown)}")
    return tuple(LANE_ORDER) if not wanted else tuple(wanted)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Seed job-db-scraper, private-deals and inventory-site in one pass."
    )
    parser.add_argument("--jobs", dest="jobs_pages", action="append", default=[], metavar="URL")
    parser.add_argument("--deals", dest="deals_pages", action="append", default=[], metavar="URL")
    parser.add_argument("--jobs-from", default="", metavar="FILE", help="a saved job scrape")
    parser.add_argument("--deals-from", default="", metavar="FILE", help="a saved deal scrape")
    parser.add_argument("--api-jobs", default="http://127.0.0.1:8101")
    parser.add_argument("--api-deals", default="http://127.0.0.1:8102")
    parser.add_argument("--api-inventory", default="http://127.0.0.1:8103")
    parser.add_argument(
        "--only",
        type=parse_only,
        default=LANE_ORDER,
        help="comma-separated lanes: jobs, deals, inventory",
    )
    parser.add_argument("--inventory-hosts", default="", metavar="KEYS", help="inventory-sync --only")
    parser.add_argument("--inventory-from", default="", metavar="FILE", help="hosts JSON instead of --eval")
    parser.add_argument("--backend", default="auto", help="scraper backend")
    parser.add_argument("--max", type=int, default=0, help="cap entries per page")
    parser.add_argument("--batch-size", type=int, default=100, help="postings or deals per batch")
    parser.add_argument("--timeout", type=int, default=30, help="per-request timeout")
    parser.add_argument("--dry-run", action="store_true", help="scrape and shape, POST nothing")
    parser.add_argument("--format", choices=("json", "toon"), default="json")
    parser.add_argument("--python", default=sys.executable, help="interpreter for the child scripts")
    args = parser.parse_args()
    if not 1 <= args.batch_size <= 500:
        parser.error("--batch-size must be between 1 and 500")

    summary = seed(args)
    emit(summary, args.format)
    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
