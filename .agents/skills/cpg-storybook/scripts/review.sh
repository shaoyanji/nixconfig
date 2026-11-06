#!/usr/bin/env bash
# review.sh — one review pass over the book: view the unjudged spreads, choose,
# name defects. Meant to run from a timer while the printer works.
set -euo pipefail

project=${STORYBOOK_DIR:-$HOME/Documents/storybook/lantern}
printer=$HOME/Documents/nixconfig/.agents/skills/cpg-storybook/scripts/storybook.py
cd "$project"

unjudged=$(python3 - "$project" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
m = json.loads((root / "manifest.json").read_text())
rows = []
for s in m["spreads"]:
    if s.get("chosen"):
        continue
    plates = sorted((root / "candidates" / s["id"]).glob("c*.png"))
    if plates:
        rows.append(f'{s["id"]}: ' + ", ".join(p.name for p in plates) + f' | text: {s["text"][:160]}')
print("\n".join(rows))
PY
)

if [ -z "$unjudged" ]; then
  echo "review: nothing to judge"
  exit 0
fi

prompt="Read $project/HANDOFF.md, then judge these spreads. For each, view the candidate PNGs (paths under $project/candidates/<id>/) and run:
python3 $printer choose --spread <id> --candidate <n>
Judge in this order: lettering in the art (automatic reject), wrong character or a character the scene does not name, composition (calm lower third), light matching the book's dusk-to-night-to-dawn arc. If your image tool fails with 429, leave that spread unchosen and say so; do not guess. Append one line per rejection to $project/LOG.md naming the defect. Finally run 'python3 $printer status' and reply with a two-line summary: chosen count and any spread you could not judge.

Spreads:
$unjudged"

timeout 1800 hermes chat -q "$prompt" 2>&1 | sed -e 's/\x1b\[[0-9;]*m//g' | tail -20
