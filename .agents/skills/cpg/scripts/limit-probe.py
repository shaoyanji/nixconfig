#!/usr/bin/env python3
"""Ask the image endpoint where its wall is, and write down the answer.

    limit-probe.py --project DIR --candidates 3 [--attempts 40] [--stop-after 3]

Unlike `storybook.py`, this paces nothing: it issues generations back to back,
using the NEXT missing candidate of each spread so the plates are still usable,
and records every response. The point is the refusal — the status code, the body,
and how many attempts succeeded before it — not the pictures.

Writes `state/probe-<stamp>.jsonl` and prints a one-line JSON summary.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

PROJECT = Path(os.environ.get("STORYBOOK_DIR", Path.cwd())).resolve()


def usage() -> dict:
    proc = subprocess.run(["cpg", "usage", "--json"], capture_output=True, text=True, timeout=90)
    if proc.returncode != 0:
        return {}
    return json.loads(proc.stdout)


def counter(u: dict) -> tuple[int, int]:
    try:
        images = u["usage"]["images"]
        return (images["used"], images["limit"])
    except KeyError:
        return (-1, -1)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", default=str(PROJECT))
    ap.add_argument("--candidates", type=int, default=3, help="target candidates per spread")
    ap.add_argument("--attempts", type=int, default=40)
    ap.add_argument("--stop-after", type=int, default=3, help="consecutive failures that end it")
    args = ap.parse_args()

    root = Path(args.project).resolve()
    manifest = json.loads((root / "manifest.json").read_text())
    ledger = root / "state" / f"probe-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}.jsonl"
    ledger.parent.mkdir(parents=True, exist_ok=True)

    style = manifest.get("style", "")
    model = manifest.get("model", "gpt-image-2.5-sunburst")
    size = manifest.get("size", "1536x1024")

    work = []
    for spread in manifest["spreads"]:
        have = len(list((root / "candidates" / spread["id"]).glob("c*.png")))
        for idx in range(have + 1, args.candidates + 1):
            work.append((spread, idx))

    before, total = counter(usage())
    started = time.time()
    ok = bad = 0
    consec = 0
    first_error = None
    stopped = "attempts-exhausted"

    with ledger.open("a") as fh:
        for spread, idx in work[: args.attempts]:
            out = root / "candidates" / spread["id"] / f"c{idx}.png"
            out.parent.mkdir(parents=True, exist_ok=True)
            prompt = spread.get("prompt") or f"{style} {spread.get('scene', '')}".strip()
            t0 = time.time()
            proc = subprocess.run(
                ["cpg", "image", "--json", "--model", model, "--size", size, "-o", str(out), prompt],
                capture_output=True, text=True, timeout=420,
            )
            took = round(time.time() - t0, 1)
            detail = (proc.stderr or proc.stdout).strip().replace("\n", " ")[:300]
            row = {
                "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "spread": spread["id"], "candidate": idx, "rc": proc.returncode,
                "seconds": took, "ok": proc.returncode == 0, "detail": detail,
            }
            if proc.returncode == 0:
                ok += 1
                consec = 0
            else:
                bad += 1
                consec += 1
                if first_error is None:
                    first_error = row
                if consec >= args.stop_after:
                    fh.write(json.dumps(row) + "\n")
                    stopped = f"{consec}-consecutive-failures"
                    break
            fh.write(json.dumps(row) + "\n")
            fh.flush()

    after, _ = counter(usage())
    summary = {
        "attempted": ok + bad, "ok": ok, "failed": bad,
        "elapsed_s": round(time.time() - started, 1),
        "counter_before": before, "counter_after": after, "allowance": total,
        "stopped": stopped, "first_error": (first_error or {}).get("detail", ""),
        "ledger": str(ledger),
    }
    print(json.dumps(summary))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
