#!/usr/bin/env python3
"""One smoke run over the three portfolio services.

`job-db-scraper` (:8464), `private-deals` (:8465) and `inventory-site` (:8466)
each serve a Go HTML reader and a JSON API from the same binary over SQLite with
an FTS5 index. They fail in ways a `systemctl is-active` cannot see: the process
answers, the page renders, and the query behind it is broken — an index that
never got built, a stats query against a renamed column, a shell whose JS throws
before it draws. This runs the four things a person actually does — health,
stats, the page, one search — and says which one broke.

    task portfolio:smoke                       # local loopback defaults
    task portfolio:smoke -- --deals http://127.0.0.1:8502 --format toon

An empty database is a pass: "nothing matched" is an answer, and a smoke that
needs data only works on the machine that has it. `--expect-hit` turns the
search into a check with content. `--browser` adds the DOM half — it opens each
page in agent-browser and asserts the element the JS fills is really there,
which is the difference between an HTML file and a page that works.
"""

from __future__ import annotations

import argparse
import datetime
import json
import shutil
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
        "id": "metric-jobs",
        "query": "engineer",
    },
    "deals": {
        "label": "private-deals",
        "api": "http://127.0.0.1:8102",
        "search": "/api/deals",
        "id": "stats",
        "query": "deals",
    },
    "inventory": {
        "label": "inventory-site",
        "api": "http://127.0.0.1:8103",
        "search": "/api/items",
        "id": "stats",
        "query": "fleet",
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
        for key in ("items", "rows", "results"):
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


def check_dom(base, marker, browser="agent-browser", timeout=45.0, run=subprocess.run):
    """The rendered page, not the HTML string: the element the JS fills exists."""
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
        evaluated = run(
            [browser, "eval", script], capture_output=True, text=True, timeout=timeout
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, f"{browser} did not finish: {exc}"
    if evaluated.returncode != 0:
        return False, f"eval failed: {(evaluated.stderr or evaluated.stdout).strip()[:120]}"
    answer = (evaluated.stdout or "").strip().strip('"')
    if not answer:
        return False, f"{marker} is missing or empty in the rendered page"
    return True, f"{marker} = {answer!r}"


def smoke_service(key, spec, args, fetch=fetch, run=subprocess.run):
    base = getattr(args, key) or spec["api"]
    name = spec["label"]
    checks = []

    def record(check, outcome):
        ok, detail = outcome
        checks.append({"check": check, "ok": ok is True, "detail": detail})
        return ok is True

    try:
        record("health", check_health(base, name, args.timeout, fetch))
        record("stats", check_stats(base, args.timeout, fetch))
        record("page", check_page(base, f'id="{spec["id"]}"', args.timeout, fetch))
        record(
            "search",
            check_search(
                base, spec["search"], args.query or spec["query"], args.expect_hit, args.timeout, fetch
            ),
        )
        if args.browser:
            record("dom", check_dom(base, f'#{spec["id"]}', args.browser_cmd, run=run))
    except FetchError as exc:
        checks.append({"check": "reachable", "ok": False, "detail": str(exc)})

    return {
        "service": name,
        "base": base,
        "ok": all(check["ok"] for check in checks) and bool(checks),
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Smoke the three portfolio services end to end.")
    for key, spec in SERVICES.items():
        parser.add_argument(f"--{key}", default=spec["api"], help=f"{spec['label']} base URL")
    parser.add_argument("--timeout", type=float, default=10.0, help="seconds per HTTP request")
    parser.add_argument("--query", default="", help="search term for all three (default: per service)")
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
