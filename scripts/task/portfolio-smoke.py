#!/usr/bin/env python3
"""One smoke run over the five portfolio services.

`job-db-scraper` (:8464), `private-deals` (:8465), `inventory-site` (:8466),
`clanker-runner` (:8467) and `link-vault` (:8468) each serve a Go HTML reader and
a JSON API from the same binary over SQLite with an FTS5 index. They fail in ways a `systemctl is-active`
cannot see: the process answers, the page renders, and the query behind it is
broken — an index that never got built, a stats query against a renamed column, a
shell whose JS throws before it draws. This runs the things a person actually
does — health, stats, the analytics report, the page, one search, a printable
label — and says which one broke.

    task agents:portfolio:smoke                # local loopback defaults
    task agents:portfolio:smoke -- --deals http://127.0.0.1:8502 --format toon

An empty database is a pass: "nothing matched" is an answer, and a smoke that
needs data only works on the machine that has it. `--expect-hit` turns the
search into a check with content. The QR label is the one check that cannot run
against an empty register; it says so in its detail rather than pretending it
looked. `--browser` adds the DOM half — it opens each page in agent-browser and
asserts the element the JS fills is really there, which is the difference between
an HTML file and a page that works.
"""

from __future__ import annotations

import argparse
import datetime
import json
import shutil
import time
import subprocess
import sys
import urllib.error
import urllib.request

UA = "nixconfig-portfolio-smoke/1.0"

SERVICES = {
    "jobs": {
        "label": "job-db-scraper",
        "api": "http://127.0.0.1:8101",
        "search": "/api/postings",
        "analytics": "/api/analytics",
        "id": "metric-jobs",
        "query": "engineer",
    },
    "deals": {
        "label": "private-deals",
        "api": "http://127.0.0.1:8102",
        "search": "/api/deals",
        "analytics": "/api/analytics",
        "id": "stats",
        "query": "deals",
    },
    "inventory": {
        "label": "inventory-site",
        "api": "http://127.0.0.1:8103",
        "search": "/api/items",
        "analytics": "/api/analytics",
        "qr": True,
        "id": "stats",
        "query": "fleet",
    },
    "clanker": {
        "label": "clanker-runner",
        "api": "http://127.0.0.1:8104",
        "id": "machines",
        "endpoints": ("/api/machines", "/api/presets", "/api/schedules"),
        "query": "",
    },
    # The key stays a Python name; the flag is the service's own spelling.
    "link_vault": {
        "label": "link-vault",
        "flag": "link-vault",
        "api": "http://127.0.0.1:8106",
        "search": "/api/links",
        "id": "metrics",
        "endpoints": ("/api/tags",),
        "query": "nix",
    },
}


class FetchError(RuntimeError):
    """The endpoint did not answer; the check reports it and the run continues."""


def to_toon(document) -> str:
    binary = shutil.which("toon")
    if binary:
        try:
            result = subprocess.run(
                [binary], input=json.dumps(document), capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.rstrip("\n")
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            pass
    return json.dumps(document, indent=2)


def fetch(url: str, timeout: float = 10.0):
    """Status, content type and body of one GET. Raises FetchError, never silently."""
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.headers.get("content-type", ""), response.read().decode(
                "utf-8", "replace"
            )
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:200]
        raise FetchError(f"{exc.code} {detail}") from exc
    except urllib.error.URLError as exc:
        raise FetchError(f"unreachable: {exc.reason}") from exc
    except OSError as exc:
        raise FetchError(f"unreachable: {exc}") from exc


def rows_of(payload):
    """The list a search answers with: bare, or under `items`."""
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        for key in ("items", "rows", "results", "links", "tags"):
            if isinstance(payload.get(key), list):
                return payload[key]
    return None


def check_health(base, name, timeout=10.0, fetch=fetch):
    status, _ctype, body = fetch(f"{base}/api/health", timeout)
    try:
        payload = json.loads(body)
    except json.JSONDecodeError as exc:
        return False, f"health is not JSON: {exc}"
    if status != 200:
        return False, f"health answered {status}"
    if payload.get("ok") is not True:
        return False, f"health says ok={payload.get('ok')!r}"
    if payload.get("service") != name:
        return False, f"health names service {payload.get('service')!r}, expected {name!r}"
    return True, f"ok, up {payload.get('uptime_seconds', '?')}s"


def check_stats(base, timeout=10.0, fetch=fetch):
    status, _ctype, body = fetch(f"{base}/api/stats", timeout)
    if status != 200:
        return False, f"stats answered {status}"
    try:
        payload = json.loads(body)
    except json.JSONDecodeError as exc:
        return False, f"stats is not JSON: {exc}"
    if not isinstance(payload, dict) or not payload:
        return False, f"stats is not a non-empty object: {body[:80]!r}"
    return True, f"{len(payload)} counters"


def check_page(base, marker, timeout=10.0, fetch=fetch):
    status, ctype, body = fetch(f"{base}/", timeout)
    if status != 200:
        return False, f"/ answered {status}"
    if "text/html" not in ctype:
        return False, f"/ served {ctype or 'no content type'}"
    if "<html" not in body.lower():
        return False, "/ served something that is not HTML"
    if marker not in body:
        return False, f"/ is missing {marker!r}"
    return True, f"{len(body)} bytes of HTML with {marker}"


def check_analytics(base, path="/api/analytics", timeout=10.0, fetch=fetch):
    """The analytics report: a non-empty object that still names its own window.

    Each service shapes its report differently on purpose, so the check is the
    contract they share — JSON, at least one key, and either a window or a
    timestamp — rather than a key list that would rot the moment a bucket is
    renamed.
    """
    status, _ctype, body = fetch(f"{base}{path}", timeout)
    if status != 200:
        return False, f"{path} answered {status}"
    try:
        payload = json.loads(body)
    except json.JSONDecodeError as exc:
        return False, f"{path} is not JSON: {exc}"
    if not isinstance(payload, dict) or not payload:
        return False, f"{path} is not a non-empty object: {body[:80]!r}"
    markers = {"generated_at", "window_days", "days", "at"}
    if not markers & set(payload):
        return False, f"{path} names no window or timestamp: {sorted(payload)[:6]}"
    buckets = sum(len(value) for value in payload.values() if isinstance(value, list))
    return True, f"{len(payload)} keys, {buckets} bucket row(s)"


def check_endpoint(base, path, timeout=10.0, fetch=fetch):
    """A JSON route with no query of its own: it must answer rows or an object."""
    status, _ctype, body = fetch(f"{base}{path}", timeout)
    if status != 200:
        return False, f"{path} answered {status}"
    try:
        payload = json.loads(body)
    except json.JSONDecodeError as exc:
        return False, f"{path} is not JSON: {exc}"
    rows = rows_of(payload)
    if rows is not None:
        return True, f"{path} -> {len(rows)} row(s)"
    if isinstance(payload, dict) and payload:
        return True, f"{path} -> {len(payload)} keys"
    return False, f"{path} answered neither rows nor an object: {body[:80]!r}"


def first_item_id(base, timeout=10.0, fetch=fetch):
    """One asset id, or None when the register is still empty."""
    status, _ctype, body = fetch(f"{base}/api/items?limit=1", timeout)
    if status != 200:
        return None
    try:
        rows = rows_of(json.loads(body)) or []
    except json.JSONDecodeError:
        return None
    if not rows:
        return None
    try:
        return int(rows[0]["id"])
    except (KeyError, TypeError, ValueError):
        return None


def check_qr(base, item_id, timeout=10.0, fetch=fetch):
    """The printable label is a real SVG document, not a JSON error with 200."""
    path = f"/api/items/{item_id}/qr.svg"
    status, ctype, body = fetch(f"{base}{path}", timeout)
    if status != 200:
        return False, f"{path} answered {status}"
    if "svg" not in (ctype or "").lower():
        return False, f"{path} served {ctype or 'no content type'}"
    if "<svg" not in body.lower():
        return False, f"{path} is not an SVG document: {body[:60]!r}"
    return True, f"{len(body)} bytes of SVG for item {item_id}"


def check_search(base, path, query, expect_hit=False, timeout=10.0, fetch=fetch):
    url = f"{base}{path}?q={urllib.request.quote(query)}&limit=5"
    status, _ctype, body = fetch(url, timeout)
    if status != 200:
        return False, f"{path}?q= answered {status}"
    try:
        payload = json.loads(body)
    except json.JSONDecodeError as exc:
        return False, f"{path}?q= is not JSON: {exc}"
    rows = rows_of(payload)
    if rows is None:
        return False, f"{path}?q= is not a list or {{items}}: {body[:80]!r}"
    if expect_hit and not rows:
        return False, f"{path}?q={query!r} found nothing (--expect-hit)"
    return True, f"{len(rows)} row(s) for {query!r}"


def check_dom(
    base, marker, browser="agent-browser", timeout=45.0, attempts=4, pause=0.5,
    run=subprocess.run, sleep=time.sleep,
):
    """The rendered page, not the HTML string: the element the JS fills exists.

    A container the JS fills starts empty, and `open` returns before the fetch
    that fills it, so an empty answer is re-read a few times before it counts as
    a failure — otherwise a working page reads as broken on a slow first paint.
    """
    if not shutil.which(browser):
        return None, f"{browser} is not installed; DOM check skipped"
    script = (
        "(() => { const el = document.querySelector(" + json.dumps(marker) + ");"
        " return el ? (el.textContent || '').trim().slice(0, 40) : ''; })()"
    )
    try:
        opened = run(
            [browser, "open", f"{base}/"], capture_output=True, text=True, timeout=timeout
        )
        if opened.returncode != 0:
            return False, f"open failed: {(opened.stderr or opened.stdout).strip()[:120]}"
        answer = ""
        for attempt in range(max(1, attempts)):
            if attempt:
                sleep(pause)
            evaluated = run(
                [browser, "eval", script], capture_output=True, text=True, timeout=timeout
            )
            if evaluated.returncode != 0:
                return False, f"eval failed: {(evaluated.stderr or evaluated.stdout).strip()[:120]}"
            answer = (evaluated.stdout or "").strip().strip('"')
            if answer:
                return True, f"{marker} = {answer!r}"
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, f"{browser} did not finish: {exc}"
    return False, f"{marker} is missing or empty in the rendered page"


def smoke_service(key, spec, args, fetch=fetch, run=subprocess.run):
    base = getattr(args, key) or spec["api"]
    name = spec["label"]
    checks = []

    def record(check, outcome, skipped=False):
        ok, detail = outcome
        entry = {"check": check, "ok": ok is True, "detail": detail}
        if skipped:
            entry["skipped"] = True
        checks.append(entry)
        return ok is True

    try:
        record("health", check_health(base, name, args.timeout, fetch))
        record("stats", check_stats(base, args.timeout, fetch))
        if spec.get("analytics"):
            record("analytics", check_analytics(base, spec["analytics"], args.timeout, fetch))
        record("page", check_page(base, f'id="{spec["id"]}"', args.timeout, fetch))
        if spec.get("search"):
            record(
                "search",
                check_search(
                    base, spec["search"], args.query or spec["query"], args.expect_hit, args.timeout, fetch
                ),
            )
        for path in spec.get("endpoints", ()):
            record(path.rsplit("/", 1)[-1], check_endpoint(base, path, args.timeout, fetch))
        if spec.get("qr"):
            item_id = first_item_id(base, args.timeout, fetch)
            if item_id is None:
                # Nothing to label: the endpoint cannot be exercised, and calling
                # that a pass without saying so would be the lie this file avoids.
                record(
                    "qr",
                    (True, "skipped: the register has no item to label"),
                    skipped=True,
                )
            else:
                record("qr", check_qr(base, item_id, args.timeout, fetch))
        if args.browser:
            record("dom", check_dom(base, spec.get("dom") or f'#{spec["id"]}', args.browser_cmd, run=run))
    except FetchError as exc:
        checks.append({"check": "reachable", "ok": False, "detail": str(exc)})

    return {
        "service": name,
        "base": base,
        "ok": all(check["ok"] for check in checks) and bool(checks),
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Smoke the four portfolio services end to end.")
    for key, spec in SERVICES.items():
        parser.add_argument(
            f"--{spec.get('flag', key)}", dest=key, default=spec["api"], help=f"{spec['label']} base URL"
        )
    parser.add_argument("--timeout", type=float, default=10.0, help="seconds per HTTP request")
    parser.add_argument("--query", default="", help="one search term for every service (default: per service)")
    parser.add_argument("--expect-hit", action="store_true", help="a search with no rows fails")
    parser.add_argument("--browser", action="store_true", help="also check the rendered DOM")
    parser.add_argument("--browser-cmd", default="agent-browser")
    parser.add_argument("--format", choices=("json", "toon"), default="json")
    args = parser.parse_args()

    services = {
        key: smoke_service(key, spec, args, fetch, subprocess.run) for key, spec in SERVICES.items()
    }
    failed = [name for name, result in services.items() if not result["ok"]]
    summary = {
        "run": "portfolio-smoke",
        "ok": not failed,
        "services": services,
        "failed": failed,
        "at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    }
    print(to_toon(summary) if args.format == "toon" else json.dumps(summary, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
