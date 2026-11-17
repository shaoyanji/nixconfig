#!/usr/bin/env python3
"""Budget-aware picture-book printer.

The manifest is the author's work (text, prompts, size); this script only spends
image generations on it: paced, resumable, and refusing to run past the
account's lifetime image allowance.

    storybook.py budget
    storybook.py run [--limit N] [--candidates N] [--dry-run]
    storybook.py gen --spread s01
    storybook.py status
    storybook.py choose --spread s01 --candidate 2
    storybook.py finalize

State is a ledger, not a memory: every generation is one JSONL row, so a run
killed at image 60 resumes at 61 and never re-spends a spent generation.
"""
from __future__ import annotations

import argparse
import fcntl
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# The book is a directory of content, not part of the skill: run it from there,
# or point STORYBOOK_DIR at it.
PROJECT = Path(os.environ.get("STORYBOOK_DIR", Path.cwd())).resolve()
MANIFEST = PROJECT / "manifest.json"
LEDGER = PROJECT / "state" / "ledger.jsonl"
STATE = PROJECT / "state" / "state.json"
CANDIDATES = PROJECT / "candidates"
FINALS = PROJECT / "finals"

MIN_INTERVAL = 145.0  # 25 images/hour => 144 s; one second of slack.
RETRY_SLEEP = 90.0


def now() -> float:
    return time.time()


def stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load(path: Path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return default


def save(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(obj, indent=2) + "\n")
    tmp.replace(path)


def manifest() -> dict:
    m = load(MANIFEST, None)
    if not m:
        sys.exit(f"storybook: no manifest at {MANIFEST}")
    return m


def ledger_rows() -> list[dict]:
    if not LEDGER.exists():
        return []
    rows = []
    for line in LEDGER.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def append_ledger(row: dict) -> None:
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    with LEDGER.open("a") as fh:
        fh.write(json.dumps(row) + "\n")


def cpg(*args: str, timeout: float = 300.0) -> subprocess.CompletedProcess:
    # A timeout is a failed request, not an exception that ends a print run.
    try:
        return subprocess.run(
            ["cpg", *args], capture_output=True, text=True, timeout=timeout
        )
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(["cpg", *args], 124, "", "timeout")


def budget() -> dict:
    """The allowance is the account's, so it is asked, never remembered."""
    proc = cpg("usage", "--json", timeout=60)
    for _ in range(3):
        if proc.returncode == 0:
            break
        # The usage endpoint is a separate request; one timeout must not kill a
        # two-hour print run at image 83.
        time.sleep(15)
        proc = cpg("usage", "--json", timeout=60)
    if proc.returncode != 0:
        sys.exit(f"storybook: cpg usage failed: {proc.stderr.strip()[:300]}")
    usage = json.loads(proc.stdout)
    images = usage["usage"]["images"]
    return {
        "total": images["limit"],
        "used": images["used"],
        "remaining": images["remaining"],
        "period_end": images.get("periodEnd"),
        "plan": usage["entitlement"]["name"],
    }


def pace(min_interval: float) -> None:
    """The window belongs to the server; the local gap keeps a burst honest."""
    state = load(STATE, {})
    wait = state.get("next_ok_ts", 0.0) - now()
    if wait > 0:
        print(f"storybook: pacing {wait:.0f}s", file=sys.stderr)
        time.sleep(wait)
    state["next_ok_ts"] = now() + min_interval
    save(STATE, state)


def prompt_for(m: dict, spread: dict) -> str:
    """The book's style block is authoritative; a spread only adds its scene."""
    if spread.get("prompt"):
        return spread["prompt"]
    return f"{m.get('style', '')} {spread.get('scene', spread.get('beat', ''))}".strip()


def spend(spread: dict, index: int, model: str, size: str) -> dict:
    out = CANDIDATES / spread["id"] / f"c{index}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists() and out.stat().st_size > 0:
        return {"ok": True, "path": str(out), "skipped": True}
    prompt = spread["prompt"]
    proc = cpg(
        "image", "--json", "--model", model, "--size", size, "-o", str(out),
        prompt, timeout=420,
    )
    if proc.returncode != 0 and any(k in (proc.stderr + proc.stdout) for k in ("429", "500", "502", "503", "504")):
        time.sleep(RETRY_SLEEP)
        proc = cpg(
            "image", "--json", "--model", model, "--size", size, "-o", str(out),
            prompt, timeout=420,
        )
    if proc.returncode != 0:
        return {"ok": False, "error": (proc.stderr or proc.stdout).strip()[:400]}
    try:
        payload = json.loads(proc.stdout.strip().splitlines()[-1])
    except (json.JSONDecodeError, IndexError):
        payload = {}
    return {"ok": True, "path": str(out), "model": payload.get("model", model)}


def cmd_budget(_: argparse.Namespace) -> int:
    print(json.dumps(budget(), indent=2))
    return 0


def cmd_status(_: argparse.Namespace) -> int:
    m = manifest()
    rows = ledger_rows()
    print(f"book     {m.get('title', '?')}")
    print(f"spreads  {len(m['spreads'])}")
    print(f"spent    {len(rows)} attempts, {sum(1 for r in rows if r.get('ok'))} images this project")
    print(f"states   {sum(1 for s in m['spreads'] if s.get('chosen'))} chosen")
    for s in m["spreads"]:
        got = len(list((CANDIDATES / s["id"]).glob("*.png")))
        mark = f"chosen c{s['chosen']}" if s.get("chosen") else f"{got}/{s.get('candidates', m.get('candidates', 3))}"
        print(f"  {s['id']:>4}  {mark}")
    b = budget()
    print(f"account  {b['remaining']} of {b['total']} generations left ({b['plan']})")
    return 0


def cmd_gen(args: argparse.Namespace) -> int:
    m = manifest()
    spread = next((s for s in m["spreads"] if s["id"] == args.spread), None)
    if not spread:
        sys.exit(f"storybook: no spread {args.spread}")
    spread = {**spread, "prompt": prompt_for(m, spread)}
    count = args.candidates or spread.get("candidates") or m.get("candidates", 3)
    model = spread.get("model") or m.get("model")
    size = spread.get("size") or m.get("size", "1536x1024")
    made = 0
    for i in range(1, count + 1):
        if args.limit is not None and made >= args.limit:
            break
        b = budget()
        if b["remaining"] <= 0:
            print("storybook: allowance exhausted", file=sys.stderr)
            break
        if args.dry_run:
            print(f"would generate {spread['id']} c{i} ({model} {size})")
            made += 1
            continue
        pace(args.min_interval)
        result = spend(spread, i, model, size)
        append_ledger(
            {"ts": stamp(), "spread": spread["id"], "candidate": i,
             "model": model, "size": size, **result}
        )
        if result.get("ok"):
            made += 1
            print(f"{spread['id']} c{i} -> {result['path']}", file=sys.stderr)
        else:
            print(f"{spread['id']} c{i} FAILED {result.get('error')}", file=sys.stderr)
    return 0 if made else 1


def cmd_run(args: argparse.Namespace) -> int:
    m = manifest()
    # A ledger row can outlive its plate (an archived style, a deleted file), so
    # what counts as done is the file on disk, not the record of spending.
    want = args.candidates or m.get("candidates", 3)
    # A spread is finished when it has its candidates, not when it has one: a run
    # that stopped at plate 2 of 3 must be resumable.
    have = {s["id"]: len(list((CANDIDATES / s["id"]).glob("*.png"))) for s in m["spreads"]}
    pending = [s for s in m["spreads"] if have[s["id"]] < want]
    if not pending:
        print("storybook: every spread already has candidates")
        return 0
    if args.limit is not None:
        pending = pending[: args.limit]
    for idx, spread in enumerate(pending):
        left = len(pending) - idx
        # Every spread gets a plate even if the allowance runs short: share what
        # is left across the spreads still to come instead of front-loading.
        share = max(1, budget()["remaining"] // left)
        cmd_gen(argparse.Namespace(
            spread=spread["id"], candidates=min(want, share),
            limit=None, min_interval=args.min_interval, dry_run=args.dry_run,
        ))
    return 0


def cmd_choose(args: argparse.Namespace) -> int:
    m = manifest()
    spread = next((s for s in m["spreads"] if s["id"] == args.spread), None)
    if not spread:
        sys.exit(f"storybook: no spread {args.spread}")
    src = CANDIDATES / spread["id"] / f"c{args.candidate}.png"
    if not src.exists():
        sys.exit(f"storybook: {src} does not exist")
    spread["chosen"] = args.candidate
    save(MANIFEST, m)
    print(f"{spread['id']}: c{args.candidate}")
    return 0


def cmd_finalize(_: argparse.Namespace) -> int:
    m = manifest()
    FINALS.mkdir(parents=True, exist_ok=True)
    lines = [f"# {m.get('title', 'Untitled')}", ""]
    if m.get("subtitle"):
        lines += [f"*{m['subtitle']}*", ""]
    missing = []
    for spread in m["spreads"]:
        pick = spread.get("chosen") or 1
        src = CANDIDATES / spread["id"] / f"c{pick}.png"
        if not src.exists():
            missing.append(spread["id"])
            continue
        dst = FINALS / f"{spread['id']}.png"
        if not dst.exists() or dst.stat().st_size != src.stat().st_size:
            shutil.copyfile(src, dst)
        lines += [f"## {spread.get('page', spread['id'])}", ""]
        if spread.get("text"):
            lines += [spread["text"], ""]
        lines += [f"![{spread['id']}](../finals/{spread['id']}.png)", ""]
    (PROJECT / "book.md").write_text("\n".join(lines))
    if missing:
        print(f"storybook: {len(missing)} spreads have no image: {', '.join(missing)}", file=sys.stderr)
        return 1
    print(f"storybook: book.md + {len(m['spreads'])} plates")
    return 0


def take_lock():
    """Two printers would each think they own the hourly window."""
    STATE.parent.mkdir(parents=True, exist_ok=True)
    handle = (STATE.parent / "printer.lock").open("w")
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit("storybook: another printer holds the lock; stop it first")
    return handle


def main() -> int:
    parser = argparse.ArgumentParser(prog="storybook")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("budget").set_defaults(fn=cmd_budget)
    sub.add_parser("status").set_defaults(fn=cmd_status)
    sub.add_parser("finalize").set_defaults(fn=cmd_finalize)

    gen = sub.add_parser("gen")
    gen.add_argument("--spread", required=True)
    gen.add_argument("--candidates", type=int)
    gen.add_argument("--limit", type=int)
    gen.add_argument("--min-interval", type=float, default=MIN_INTERVAL)
    gen.add_argument("--dry-run", action="store_true")
    gen.set_defaults(fn=cmd_gen)

    run = sub.add_parser("run")
    run.add_argument("--candidates", type=int)
    run.add_argument("--limit", type=int, help="spreads to touch this pass")
    run.add_argument("--min-interval", type=float, default=MIN_INTERVAL)
    run.add_argument("--dry-run", action="store_true")
    run.set_defaults(fn=cmd_run)

    choose = sub.add_parser("choose")
    choose.add_argument("--spread", required=True)
    choose.add_argument("--candidate", type=int, required=True)
    choose.set_defaults(fn=cmd_choose)

    args = parser.parse_args()
    if args.cmd in ("gen", "run"):  # read-only commands report on a live printer
        lock = take_lock()  # noqa: F841 — held for the life of the process
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
