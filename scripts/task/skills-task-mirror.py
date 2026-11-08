#!/usr/bin/env python3
"""skills-task-mirror.py — a skill table row that restates a task's `desc`.

`task --list-all --json` serves one `desc` per task. A skill table row that
restates that desc is a second copy of the same fact, and it goes stale the first
time the task changes. Three such rows in one skill is a task index wearing a
skill's name.

This lived in `flake/checks.nix` until the task plane left Nix: the rule needs
`desc` per task, and the honest source of `desc` is go-task itself, which is what
this reads (through `taskfile-list.sh`, the same 120 ms warm cache `task help`
uses).

A row is a mirror when BOTH hold, measured over alnum word tokens:
  * >= 70 % of the desc's significant words (length > 3, not part of the task
    name) appear in the row's non-name cells, and
  * those cells are no longer than 1.5x the desc — a row that adds a caveat is
    longer, which is the only reason to have the table.

Exit: 0 no offenders (warnings are printed) · 1 a skill mirrors the surface · 2 unreadable.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SKILLS = os.path.join(ROOT, ".agents", "skills")


def words(text: str) -> list[str]:
    return [w for w in re.split(r"[^A-Za-z0-9]+", text.lower()) if w]


def row_task_name(cell: str) -> str:
    bare = cell.replace("`", "").strip()
    parts = bare.split()
    if not parts:
        return ""
    if parts[0] == "task" and len(parts) > 1:
        return parts[1]
    return parts[0]


def body_of(path: str) -> list[str]:
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                return lines[i + 1 :]
    return lines


def descs() -> dict[str, str]:
    proc = subprocess.run(
        ["bash", os.path.join(ROOT, "scripts", "task", "taskfile-list.sh")],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        print(f"skills-task-mirror: task --list-all --json failed: {proc.stderr.strip()}", file=sys.stderr)
        raise SystemExit(2)
    return {t["name"]: (t.get("desc") or "") for t in json.loads(proc.stdout)["tasks"]}


def mirrors(lines: list[str], table: dict[str, str]) -> list[str]:
    out = []
    for line in lines:
        cells = [c.strip() for c in line.strip().split("|") if c.strip()]
        if not cells:
            continue
        name = row_task_name(cells[0])
        desc = table.get(name, "")
        rest = " ".join(cells[1:])
        name_tokens = words(name)
        desc_tokens = [w for w in words(desc) if len(w) > 3 and w not in name_tokens]
        rest_tokens = words(rest)
        if not desc_tokens or not rest_tokens:
            continue
        hits = len([w for w in desc_tokens if w in rest_tokens])
        desc_norm = " ".join(words(desc))
        rest_norm = " ".join(rest_tokens)
        if hits * 10 >= len(desc_tokens) * 7 and 2 * len(rest_norm) <= 3 * len(desc_norm):
            out.append(f"{name}: {rest.strip()}")
    return out


def main() -> int:
    table = descs()
    try:
        names = sorted(
            n for n in os.listdir(SKILLS) if os.path.isdir(os.path.join(SKILLS, n))
        )
    except OSError as exc:
        print(f"skills-task-mirror: cannot read {SKILLS}: {exc}", file=sys.stderr)
        return 2

    offenders, warnings = [], []
    for name in names:
        path = os.path.join(SKILLS, name, "SKILL.md")
        if not os.path.exists(path):
            continue
        rows = mirrors(body_of(path), table)
        if len(rows) >= 3:
            offenders.append((name, rows))
        elif rows:
            warnings.append((name, len(rows)))

    if offenders:
        print(
            "agent skill(s) mirror `task --list-all --json` — the task surface already\n"
            "carries these `desc` lines, so the table is a second copy that goes stale:"
        )
        for name, rows in offenders:
            print(f"  {name}: {len(rows)} row(s)")
            for row in rows:
                print(f"    {row}")
        print(
            "Keep the row only when it says something the `desc` does not (a caveat, a\n"
            'cost, a "does not prove"); otherwise name the task and drop the cell.'
        )
        return 1

    print(f"agent skills OK: {len(names)} skills, {len(names)} tables read")
    print("  task rows mirroring a desc: 0")
    for name, count in warnings:
        print(f"WARN {name}: {count} task row(s) restate a `desc`")
    return 0


if __name__ == "__main__":
    sys.exit(main())
