#!/usr/bin/env python3
"""Compare two adaptations of the same book, page by page.

    compare.py --project DIR --lang de [--hand FILE] [--round FILE] [--html PATH]

`adapt.py` writes `script.<lang>.json`; a hand-written edition is usually the
same file. So one of them has to move: this reads `--hand` (default
`script.<lang>.hand.json`) against `--round` (default `script.<lang>.json`) and
reports where they disagree, without rewriting either.

The point is not "which is better" — that is a reading, and the flags only say
where a reading is needed. What a chunked model round loses first is measurable:

- **length drift**, a page that grew or shrank by more than a third
- **digits**, which a read-aloud voice says in the wrong language
- **names**, the character words the glossary pins (Maulwurf, Ratte, Kröte …)
- **scene facts that are numbers**: a counting book's page count is the page
"""
from __future__ import annotations

import argparse
import html
import json
import re
import sys
from pathlib import Path

NAMES = {
    "de": ["Maulwurf", "Ratte", "Kröte", "Dachs", "Pip", "Otter", "Laterne", "Fluss"],
    "en": ["Mole", "Ratty", "Toad", "Badger", "Pip", "otter", "lantern", "river"],
}


def sentences(text: str) -> int:
    return len([s for s in re.split(r"[.!?]+", text) if s.strip()])


def compare(hand: dict, round_: dict, lang: str) -> list[dict]:
    right = {s["id"]: s["text"] for s in round_["spreads"]}
    rows = []
    for page in hand["spreads"]:
        sid, left = page["id"], page["text"]
        right_text = right.get(sid, "")
        flags = []
        if not right_text:
            flags.append("missing")
        elif not left:
            flags.append("empty")
        else:
            ratio = len(right_text) / max(len(left), 1)
            if ratio > 1.35:
                flags.append(f"longer ×{ratio:.2f}")
            elif ratio < 0.74:
                flags.append(f"shorter ×{ratio:.2f}")
            if re.search(r"\d", right_text) and not re.search(r"\d", left):
                flags.append("digits")
            for name in NAMES.get(lang, []):
                if (name.lower() in left.lower()) != (name.lower() in right_text.lower()):
                    flags.append(f"name:{name}")
        rows.append({"id": sid, "hand": left, "round": right_text,
                     "chars": (len(left), len(right_text)),
                     "sentences": (sentences(left), sentences(right_text)),
                     "flags": flags})
    return rows


def table(rows: list[dict]) -> str:
    out = [f"{'page':5} {'hand':>5} {'round':>6} {'Δ':>5} {'sent':>8}  flags"]
    for r in rows:
        a, b = r["chars"]
        sa, sb = r["sentences"]
        out.append(f"{r['id']:5} {a:5d} {b:6d} {b - a:+5d} {sa:3d}/{sb:<3d}  "
                   + (", ".join(r["flags"]) or "-"))
    changed = [r for r in rows if r["hand"] != r["round"]]
    out.append("")
    out.append(f"{len(rows)} pages, {len(changed)} differ, "
               f"{sum(len(r['flags']) for r in rows)} flags")
    return "\n".join(out)


def page(rows: list[dict], title: str) -> str:
    cards = []
    for r in rows:
        flags = (f'<p class="flags">{html.escape(", ".join(r["flags"]))}</p>'
                 if r["flags"] else "")
        cards.append(
            f'<section><h2>{html.escape(r["id"])} '
            f'<small>{r["chars"][0]} → {r["chars"][1]} Zeichen</small></h2>'
            f'<div class="cols"><p><b>von Hand</b>{html.escape(r["hand"])}</p>'
            f'<p><b>Runde</b>{html.escape(r["round"])}</p></div>{flags}</section>')
    return f"""<!doctype html><meta charset="utf-8"><title>{html.escape(title)}</title>
<style>body{{background:#f4ecd8;color:#2c2620;font-family:Georgia,serif;margin:0;padding:5vh 6vw;line-height:1.55}}
h1{{font-size:1.5rem}} section{{border-top:1px solid #e2d6bb;padding:1rem 0}}
h2{{font-size:.95rem;letter-spacing:.06em}} h2 small{{opacity:.5;font-weight:400;margin-left:.6rem;letter-spacing:0}}
.cols{{display:grid;grid-template-columns:1fr 1fr;gap:2rem}} p{{margin:0}}
.cols p b{{display:block;font-size:.7rem;letter-spacing:.16em;text-transform:uppercase;opacity:.45;margin-bottom:.3rem}}
.flags{{margin-top:.6rem;font-size:.8rem;color:#8a3b2b}}</style>
<h1>{html.escape(title)}</h1>{''.join(cards)}"""


def main() -> int:
    ap = argparse.ArgumentParser(prog="compare")
    ap.add_argument("--project", default=".")
    ap.add_argument("--lang", default="de")
    ap.add_argument("--hand", default="", help="default script.<lang>.hand.json")
    ap.add_argument("--round", default="", help="default script.<lang>.json")
    ap.add_argument("--html", default="", help="write the side-by-side page here")
    args = ap.parse_args()
    root = Path(args.project).resolve()
    hand_file = Path(args.hand) if args.hand else root / f"script.{args.lang}.hand.json"
    round_file = Path(args.round) if args.round else root / f"script.{args.lang}.json"
    for p in (hand_file, round_file):
        if not p.exists():
            sys.exit(f"compare: no {p}")
    hand = json.loads(hand_file.read_text())
    round_ = json.loads(round_file.read_text())
    rows = compare(hand, round_, args.lang)
    print(table(rows))
    if args.html:
        out = Path(args.html)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(page(rows, f"{hand.get('title', '')} — von Hand gegen Runde"))
        print(f"compare: {out}")
    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())
