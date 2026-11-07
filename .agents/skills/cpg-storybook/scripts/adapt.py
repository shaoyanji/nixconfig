#!/usr/bin/env python3
"""Adapt a finished book into another language: one speculate round per chunk.

    adapt.py --project DIR --lang de [--chunk 7] [--title … --subtitle …]

`media.py say` needs `script.<lang>.json`, and the adaptation is a graded round
of cheap drafts rather than one model's first answer. A 28-spread book does not
fit one round: `speculate.sh` grades the first 2000 characters of each lane, so a
whole-book prompt would be judged on its opening and accepted on faith after
that. Chunks of seven keep the whole candidate inside the grader's window, and
the previous chunk is carried into the next prompt so the voice does not restart
every seven pages.

Nothing here talks to a model directly: it builds the prompt, calls the skill's
own `speculate.sh --json`, and keeps the winner's text.

Resumable by design — a failed chunk leaves `state/adapt-<lang>.json` holding
the chunks already won, and a rerun redoes only the missing ones.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# The round runner lives in the sibling skill, not here: `speculate.sh` is
# cpg-speculate's contract and adapting must not fork it.
SPECULATE = HERE.parents[1] / "cpg-speculate" / "scripts" / "speculate.sh"

# The words the pictures and the count already fixed. A translator that
# re-decides "Mole" or "wish-lantern" produces a book that disagrees with its own
# art, so the glossary is in every prompt, not only the first.
GLOSSARY = {
    "de": {
        "The Riverbank": "das Flussufer",
        "Mole": "der Maulwurf (Maulwurf)",
        "Ratty": "die Ratte (Wasserratte)",
        "Toad": "die Kröte",
        "Badger": "der Dachs",
        "Pip": "Pip (kleiner Fischotter)",
        "the holt": "der Otterbau",
        "the Lantern Festival": "das Laternenfest",
        "wish-lantern / paper sail": "die Wunschlaterne mit dem Papiersegel",
        "the old stone bridge": "die alte Steinbrücke",
        "bolt/candles": "Kerzen",
        "willow island": "die Weideninsel",
    },
}

RULES = """You are translating ONE chunk of a children's picture book into {lang}.
The illustrations are already printed: the count on each page, who is present \
and what happens are fixed. Translate the page text; do not summarise, explain, \
add a moral, or move a scene.

Voice: warm, unhurried, concrete — a bedtime read-aloud for ages 5-9. German \
sentences a parent can say in one breath. Keep 2-4 sentences per page, about \
the length of the English. Past tense throughout, as the English is.

Names and objects, exactly these (never invent a synonym for a character):
{glossary}

Read-aloud constraints: no digits (spell numbers out), no abbreviations, no \
em dash at the end of a line, no stage directions. Umlauts and ß as real \
characters, never \\u escapes.

Answer with ONE JSON array and nothing else: no prose, no code fence.
[{{"id": "s01", "text": "…"}}, …] — the same ids, in the same order.
"""


def chunk(list_, n):
    for i in range(0, len(list_), n):
        yield list_[i:i + n]


def parse_spreads(text: str) -> list[dict]:
    """Pull the JSON array out of whatever the model wrapped it in."""
    stripped = re.sub(r"^```(?:json)?|```$", "", text.strip(), flags=re.M).strip()
    starts = [i for i, c in enumerate(stripped) if c in "[{"]
    dec = json.JSONDecoder()
    for pos in starts:
        try:
            value, _ = dec.raw_decode(stripped[pos:])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            value = [value]
        rows = [r for r in value if isinstance(r, dict) and "id" in r and "text" in r]
        if rows:
            return [{"id": r["id"], "text": str(r["text"]).strip()} for r in rows]
    return []


def main() -> int:
    ap = argparse.ArgumentParser(prog="adapt")
    ap.add_argument("--project", required=True)
    ap.add_argument("--lang", default="de")
    ap.add_argument("--chunk", type=int, default=7)
    ap.add_argument("--title", default="")
    ap.add_argument("--subtitle", default="")
    ap.add_argument("--dedication", default="")
    ap.add_argument("--models", nargs="*", default=[])
    args = ap.parse_args()

    root = Path(args.project).resolve()
    manifest = json.loads((root / "manifest.json").read_text())
    spreads = manifest["spreads"]
    (root / "state").mkdir(exist_ok=True)
    state_file = root / "state" / f"adapt-{args.lang}.json"
    state = json.loads(state_file.read_text()) if state_file.exists() else {}
    glossary = json.dumps(GLOSSARY.get(args.lang, {}), indent=1, ensure_ascii=False)

    previous = ""
    for idx, group in enumerate(chunk(spreads, args.chunk)):
        ids = [s["id"] for s in group]
        key = f"{idx:02d}-{ids[0]}-{ids[-1]}"
        if key in state:
            previous = " ".join(s["text"] for s in state[key]["spreads"])[-1200:]
            continue
        english = "\n".join(f'id {s["id"]}: {s["text"]}' for s in group)
        prompt = (
            RULES.format(lang=args.lang, glossary=glossary)
            + (f"\nThe previous chunk, already translated — match its voice and keep "
               f"recurring words identical:\n{previous}\n" if previous else "")
            + f"\nTranslate these {len(group)} pages:\n{english}\n")
        cmd = ["bash", str(SPECULATE), "--json", prompt, *args.models]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            sys.exit(f"adapt: speculate failed for {key}: {proc.stderr.strip()[-600:]}")
        result = json.loads(proc.stdout)
        rows = parse_spreads(result["winner"]["text"])
        got = {r["id"] for r in rows}
        if got != set(ids):
            sys.exit(f"adapt: chunk {key} returned {sorted(got)}; expected {ids}")
        state[key] = {"spreads": rows, "model": result["winner"]["model"],
                      "decision": result.get("decision")}
        state_file.write_text(json.dumps(state, indent=1, ensure_ascii=False))
        previous = " ".join(r["text"] for r in rows)[-1200:]
        print(f"adapt: {key} <- {result['winner']['model']} "
              f"({len(rows)} pages)", file=sys.stderr)

    ordered = [r for k in sorted(state) for r in state[k]["spreads"]]
    by_id = {r["id"]: r["text"] for r in ordered}
    missing = [s["id"] for s in spreads if s["id"] not in by_id]
    if missing:
        sys.exit(f"adapt: no translation for {', '.join(missing)}")

    script = {
        "language": args.lang,
        "title": args.title or manifest.get("title", ""),
        "subtitle": args.subtitle or manifest.get("subtitle", ""),
        "dedication": args.dedication or manifest.get("dedication", ""),
        "source": f"manifest.json ({len(spreads)} spreads, en)",
        "adapted_by": "cpg-speculate rounds of "
                      f"{args.chunk} pages, Jev-chosen per chunk: "
                      + ", ".join(f"{k}={v['model']}" for k, v in sorted(state.items())),
        "spreads": [{"id": s["id"], "text": by_id[s["id"]]} for s in spreads],
    }
    (root / f"script.{args.lang}.json").write_text(
        json.dumps(script, indent=1, ensure_ascii=False))
    lengths = [len(s["text"]) for s in script["spreads"]]
    print(json.dumps({"out": f"script.{args.lang}.json", "spreads": len(by_id),
                      "chars_min": min(lengths), "chars_max": max(lengths)}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
