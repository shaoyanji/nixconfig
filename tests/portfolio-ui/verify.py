#!/usr/bin/env python3
"""Assertions for the job-db-scraper and private-deals pages.

The browser half is a probe that reads the rendered page and reports what it
saw; this file is what decides whether that counts as working. Keeping them
apart is what lets `browser-stub/run.sh` check the assertions with no Chrome and
no clanker — and lets a failure name the control that broke instead of a page
that "looked wrong".

Input is one JSON document:

    {"jobs": {...probe...}, "deals": {...probe...},
     "log": {"jobs": [...writes...], "deals": [...writes...]}}

Exit: 0 every assertion holds, 1 one does not, 2 the input is not usable.
"""

from __future__ import annotations

import json
import sys

JOBS_EXPORTS = (
    "/api/postings/export?format=csv",
    "/api/postings/export?format=json",
    "/api/postings/export?format=markdown",
)
DEALS_EXPORTS = (
    "/api/export.csv",
    "/api/deals/export",
    "/api/deals/feed.rss",
    "/api/deals/feed.atom",
)


def check_jobs(page: dict, writes: list) -> list:
    fails = []

    def want(condition, message):
        if not condition:
            fails.append(message)

    want(page.get("loaded") == 2, f"expected 2 postings, saw {page.get('loaded')}")
    metrics = page.get("metrics") or {}
    want(
        metrics == {"metric-jobs": "12", "metric-companies": "5", "metric-remote": "7", "metric-fresh": "9"},
        f"the metric cards read {metrics}",
    )
    hrefs = page.get("exports") or []
    for href in JOBS_EXPORTS:
        want(href in hrefs, f"no {href} link in the export row: {hrefs}")
    want(
        (page.get("firstTitle") or "").startswith("Platform Engineer"),
        f"first posting is {(page.get('firstTitle') or '')!r}",
    )
    want(
        page.get("stageBadges") == ["applied", "saved"],
        f"stage badges read {page.get('stageBadges')}",
    )
    want(page.get("detailOpen") is True, "the detail dialog did not open")
    options = page.get("stageOptions") or []
    want(
        options == ["saved", "applied", "interview", "offer", "rejected", "archived"],
        f"the stage selector offers {options}",
    )
    want(page.get("noteForm") is True, "the note form is missing from the detail panel")
    want(
        page.get("packetExport") == "/api/postings/export?format=markdown&id=1",
        f"the packet export links to {page.get('packetExport')!r}",
    )
    journal = " ".join(page.get("journal") or [])
    want("saved → applied" in journal, f"the stage history is not rendered: {journal!r}")
    want("recruiter call" in journal, f"the earlier note is not rendered: {journal!r}")
    want(
        page.get("afterStage") == "interview",
        f"after saving the stage the row reads {page.get('afterStage')!r}",
    )
    after = " ".join(page.get("journalAfterNote") or [])
    want("spoke to the hiring manager" in after, f"the new note is not in the journal: {after!r}")
    want(
        page.get("filteredRows") == 1,
        f"the interview filter kept {page.get('filteredRows')} rows",
    )
    staged = [w for w in writes if w.get("method") == "PATCH" and str(w.get("path", "")).endswith("/stage")]
    want(bool(staged), f"no PATCH to the stage route; writes were {writes}")
    if staged:
        body = staged[-1].get("body") or {}
        want(body.get("stage") == "interview", f"the stage PATCH sent {body}")
    noted = [w for w in writes if w.get("method") == "POST" and str(w.get("path", "")).endswith("/notes")]
    want(bool(noted), f"no POST to the notes route; writes were {writes}")
    if noted:
        note = (noted[-1].get("body") or {}).get("note", "")
        want("spoke to the hiring manager" in note, f"the note POST sent {note!r}")
    return fails


def check_deals(page: dict, writes: list) -> list:
    fails = []

    def want(condition, message):
        if not condition:
            fails.append(message)

    want(page.get("loaded") == 2, f"expected 2 deals, saw {page.get('loaded')}")
    want(
        page.get("stats") == ["2", "3", "14", "1"],
        f"the stat cards read {page.get('stats')}",
    )
    hrefs = page.get("exports") or []
    for href in DEALS_EXPORTS:
        want(href in hrefs, f"no {href} link in the header: {hrefs}")
    want(page.get("spark") is True, "the price sparkline did not draw")
    figures = page.get("figures") or ""
    want("price points" in figures, f"the analytics figures read {figures!r}")
    want("−20%" in figures or "-20%" in figures, f"no biggest-drop figure in {figures!r}")
    want(
        "last 30 days" in (page.get("window") or ""),
        f"the analytics window reads {page.get('window')!r}",
    )
    drops = " ".join(page.get("drops") or [])
    want("249" in drops and "199" in drops, f"the price-drop row reads {drops!r}")
    want(page.get("alerts") == 1, f"expected 1 alert, saw {page.get('alerts')}")
    want(
        "Watchlist poll started" in (page.get("toastAll") or ""),
        f"polling every watchlist said {page.get('toastAll')!r}",
    )
    want(
        "already running" in (page.get("toastOne") or ""),
        f"polling one list said {page.get('toastOne')!r}",
    )
    want(page.get("detailOpen") is True, "the deal detail dialog did not open")
    want(page.get("historyBars") == 2, f"the price history drew {page.get('historyBars')} bar(s)")
    global_poll = [w for w in writes if str(w.get("path", "")).endswith("/api/watchlists/poll")]
    one_poll = [w for w in writes if str(w.get("path", "")).endswith("/api/watchlists/1/poll")]
    want(bool(global_poll), f"no POST to /api/watchlists/poll; writes were {writes}")
    want(bool(one_poll), f"no POST to /api/watchlists/1/poll; writes were {writes}")
    want(
        all(w.get("method") == "POST" for w in global_poll + one_poll),
        "a poll route was called with the wrong method",
    )
    return fails


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw)
    except ValueError as exc:
        print(f"portfolio-ui: the probes did not return JSON: {exc}", file=sys.stderr)
        return 2
    if not isinstance(payload, dict):
        print("portfolio-ui: the probes returned something other than an object", file=sys.stderr)
        return 2
    log = payload.get("log") or {}
    fails = check_jobs(payload.get("jobs") or {}, log.get("jobs") or [])
    fails += check_deals(payload.get("deals") or {}, log.get("deals") or [])
    if fails:
        for line in fails:
            print(f"FAIL {line}", file=sys.stderr)
        return 1
    jobs = payload["jobs"]
    deals = payload["deals"]
    print(
        f"PASS jobs: {jobs['loaded']} postings, exports {len(jobs['exports'])}, "
        f"stage {jobs['afterStage']}, note written"
    )
    print(
        f"PASS deals: {deals['loaded']} deals, sparkline drawn, "
        f"{deals['historyBars']} price bars, both polls posted"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
