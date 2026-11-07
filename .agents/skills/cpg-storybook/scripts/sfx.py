#!/usr/bin/env python3
"""Real sound for a book: CC0 clips, one per cue, with the credits kept.

    sfx.py fetch --project DIR      # download the cue shelf into audio/sfx/
    sfx.py cues  --project DIR      # write sfx.json: which clip sits on which page

Nothing here is synthesised. The clips come from Freesound through the Openverse
API filtered to `cc0`, so a published book needs no licence argument — but the
credits are written anyway, because "CC0" is a claim about a file and a credit
line is what a reader can check.

Traps, measured 2026-11-07:

- Openverse answers **403** without a `User-Agent`, and rate-limits anonymous
  callers, so the requests are spaced and the UA says who is asking.
- The URL it returns for a Freesound hit is the **preview** mp3, not the original
  upload. That is fine for a CC0 sound (the dedication covers the derivative),
  and it is what makes the fetch keyless: no Freesound token, no login.
- Durations are milliseconds in the API and the beds are minutes long, so every
  clip is trimmed on download: a 282 s river is not a sound effect, it is a file
  transfer.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

UA = {"User-Agent": "nixconfig-storybook/0.1 (+fleet agent; storybook sfx)"}

# cue -> the search that finds it, and what to keep. `want` is a substring of the
# title, which is how the pick survives the API reordering results; `seconds` is
# the trim, `bed` keeps the clip long because it loops under the whole page.
SHELF = {
    # `avoid` is the difference between a river and a riverside cafe: Freesound's
    # top CC0 river hit is "City river ambience 2 (chatter)", which is people.
    "river":      {"q": "river ambience", "want": "river ambience", "seconds": 14.0, "bed": True,
                   "avoid": ["chatter", "city", "angeles", "summer", "traffic"]},
    "crickets":   {"q": "night crickets", "want": "crickets", "seconds": 12.0, "bed": True},
    "wind":       {"q": "soft wind ambience", "want": "soft wind ambience", "seconds": 10.0, "bed": True},
    "owl":        {"q": "owl hoot", "want": "owl hoot", "seconds": 6.0},
    "birds":      {"q": "robin song", "want": "robin", "seconds": 7.0,
                   "avoid": ["owl", "dawn chorus", "garden soundscape"]},
    "page":       {"q": "page turn", "want": "page turn", "seconds": 2.0},
    "chime":      {"q": "glass chime", "want": "glass chimes", "seconds": 5.0},
    "snowsteps":  {"q": "footsteps snow", "want": "footsteps snow", "seconds": 6.0},
    "creak":      {"q": "wood creak", "want": "wood creak single", "seconds": 2.0},
    "fire":       {"q": "fireplace crackle", "want": "fireplace crackling", "seconds": 10.0, "bed": True,
                   "avoid": ["burning", "aachen", "stove", "bonfire"]},
    # There is no CC0 "oars" clip worth having: the river recordings with a
    # paddle in them are kayaks, and a kayak stroke is the same sound as an oar.
    "oars":       {"q": "rowing oars water", "want": "kayaking in calm", "seconds": 12.0, "bed": True},
    "bell":       {"q": "small bell ring", "want": "small bell ringing", "seconds": 4.0},
}

# The bed under everything, once per book. A music box is chosen over a piano
# recording because its spectrum sits above a voice: the melody survives at a
# level low enough that no word is fought.
MUSIC = {"q": "music box lullaby", "want": "music box lullaby", "seconds": 60.0,
         "avoid": ["clip", "christmas", "brahms", "field recording"]}

# Page -> cues. `at` is seconds into the spread, `gain` is a linear multiplier on
# a clip already normalised to -20 LUFS. The narration sits at -16, so a bed at
# 0.10 is roughly 20 dB down and never fights a word.
CUES = {
    "s01": [("river", 0.0, 0.09), ("owl", 2.6, 0.30)],
    "s02": [("river", 0.0, 0.10), ("creak", 1.1, 0.26)],
    "s03": [("river", 0.0, 0.10), ("creak", 2.0, 0.20)],
    "s04": [("wind", 0.0, 0.10), ("birds", 1.6, 0.24)],
    "s05": [("river", 0.0, 0.08), ("snowsteps", 1.2, 0.26)],
    "s06": [("wind", 0.0, 0.12), ("river", 0.0, 0.06)],
    "s07": [("wind", 0.0, 0.09), ("chime", 1.4, 0.20)],
    "s08": [("wind", 0.0, 0.12), ("snowsteps", 2.2, 0.18)],
    "s09": [("crickets", 0.0, 0.09), ("owl", 3.0, 0.26)],
    "s10": [("crickets", 0.0, 0.08), ("river", 0.0, 0.07)],
}

# A page turn closes every spread except the first, where the book is already
# open. A negative `at` counts back from the end of the spread: the recorded
# page turn peaks on its plop 1.7 s in and that is what should land on the cut,
# not the soft rustle that precedes it.
PAGE_TURN_AT = -1.6
PAGE_TURN_GAIN = 0.50


def api(query: str) -> dict:
    q = urllib.parse.urlencode({"q": query, "license": "cc0", "page_size": 8})
    req = urllib.request.Request(f"https://api.openverse.org/v1/audio/?{q}", headers=UA)
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)


def download(url: str, dst: Path) -> None:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        dst.write_bytes(r.read())


def shape(src: Path, dst: Path, seconds: float, bed: bool) -> None:
    """Trim, loop-if-bed, one channel at 44.1 kHz, -20 LUFS.

    A bed shorter than its page is looped here rather than in the mix: an
    `aloop` in the filter graph is the same audio, but a pre-shaped bed keeps the
    per-spread filter readable and its length known.
    """
    target = seconds * 3 if bed else seconds
    # One-shots get their leading silence removed: a Freesound one-shot can open
    # with a second of room tone, so a cue placed at 0.12 s measured -27.9 dB at
    # the head of the spread — the sound arrived late, not quiet.
    lead = "" if bed else "silenceremove=start_periods=1:start_duration=0:start_threshold=-45dB,"
    af = (lead + f"atrim=0:{seconds},asetpts=N/SR/TB"
          + (f",aloop=loop=-1:size={int(seconds * 44100)}" if bed else "")
          + (f",atrim=0:{target}" if bed else "")
          + ",loudnorm=I=-20:TP=-3:LRA=9,aresample=44100")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(src), "-af", af,
                    "-ar", "44100", "-ac", "1", "-c:a", "pcm_s16le", str(dst)], check=True)


def cmd_fetch(args) -> int:
    root = Path(args.project).resolve()
    out = root / "audio" / "sfx"
    out.mkdir(parents=True, exist_ok=True)
    # A rerun fetches only what is missing, so the credits have to start from the
    # file on disk: rebuilding them from this run alone silently dropped every
    # clip that was already there (6 rows for 9 clips).
    cfile = out / "credits.json"
    credits = json.loads(cfile.read_text()) if cfile.exists() else {}
    for cue, spec in SHELF.items():
        wav = out / f"{cue}.wav"
        if wav.exists() and not args.force:
            print(f"sfx: {cue} already there", file=sys.stderr)
            continue
        try:
            data = api(spec["q"])
        except Exception as exc:                      # 403, 429, timeout
            print(f"sfx: {cue}: query failed: {exc}", file=sys.stderr)
            continue
        hits = [h for h in data.get("results", [])
                if spec["want"] in h["title"].lower()
                and not any(bad in h["title"].lower() for bad in spec.get("avoid", []))]
        if not hits:
            print(f"sfx: {cue}: no CC0 hit matching '{spec['want']}'", file=sys.stderr)
            time.sleep(1.2)
            continue
        hit = hits[0]
        raw = out / f"{cue}.src"
        try:
            download(hit["url"], raw)
            shape(raw, wav, spec["seconds"], spec.get("bed", False))
        except Exception as exc:
            print(f"sfx: {cue}: download/shape failed: {exc}", file=sys.stderr)
            raw.unlink(missing_ok=True)
            time.sleep(1.2)
            continue
        raw.unlink(missing_ok=True)
        dur = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                              "-of", "csv=p=0", str(wav)], capture_output=True, text=True).stdout.strip()
        # Freesound titles often carry the container extension; a credits table
        # reading "Soft Wind Ambience.wav" looks like a filename, not a work.
        title = re.sub(r"\.(wav|mp3|flac|ogg|aiff?)$", "", hit["title"].strip(), flags=re.I)
        credits[cue] = {"title": title, "creator": hit.get("creator", "unknown"),
                        "license": hit.get("license", "cc0"), "provider": hit.get("provider", ""),
                        "source": hit.get("foreign_landing_url") or hit.get("url", ""),
                        "seconds": round(float(dur), 2), "file": f"audio/sfx/{cue}.wav"}
        print(f"sfx: {cue} <- {hit['title'][:40]} ({hit.get('creator','?')}) {dur}s", file=sys.stderr)
        time.sleep(1.2)

    cfile.write_text(json.dumps(credits, indent=1, ensure_ascii=False))
    write_credits_page(root, credits)
    print(json.dumps({"cues": list(credits), "dir": str(out)}, indent=1))
    return 0 if credits else 1


def write_credits_page(root: Path, credits: dict) -> None:
    site = root / "site"
    if not site.exists():
        return
    rows = "\n".join(
        f'<tr><td>{display_name(c)}</td><td>{c["title"]}</td><td>{c["creator"]}</td>'
        f'<td>{c["license"]}</td><td><a href="{c["source"]}">{c["provider"] or c["source"]}</a></td></tr>'
        for c in credits.values())
    (site / "sfx.html").write_text(f"""<!doctype html><meta charset="utf-8">
<title>Sound credits</title>
<style>body{{background:#f4ecd8;color:#2c2620;font-family:Georgia,serif;margin:0;padding:6vh 8vw}}
table{{border-collapse:collapse;width:100%;font-size:.9rem}}
td,th{{text-align:left;padding:.4rem .6rem;border-bottom:1px solid #e2d6bb}}
th{{font-size:.75rem;letter-spacing:.14em;text-transform:uppercase;opacity:.5}}
a{{color:#6b4f2a}}</style>
<h1>Sound credits</h1>
<p>Every sound in the narrated edition is CC0 (public domain dedication) and was
fetched with <code>sfx.py</code>. They are credited here anyway.</p>
<table><tr><th>clip</th><th>title</th><th>creator</th><th>licence</th><th>source</th></tr>
{rows}</table>""")


def display_name(cue: dict) -> str:
    """`bed.wav` says nothing; the credits table names the thing, not its file."""
    if cue.get("kind") == "music":
        return "music bed"
    return cue["file"].split("/")[-1]


def load_plan(root: Path, explicit: str) -> dict:
    """A book's own cue plan, else the built-in one for the counting book.

    The built-in plan numbers pages s01-s10 with one book's scenes, so a second
    book must not inherit it: `sfx.plan.json` in the project is read first, and
    its shape is `{sid: [[cue, at, gain], ...]}` — same as CUES, hand-editable.
    """
    path = Path(explicit) if explicit else root / "sfx.plan.json"
    if not path.exists():
        return CUES
    return json.loads(path.read_text())


def cmd_cues(args) -> int:
    root = Path(args.project).resolve()
    have = {p.stem for p in (root / "audio" / "sfx").glob("*.wav")}
    book = json.loads((root / f"script.{args.lang}.json").read_text())
    ids = [s["id"] for s in book["spreads"]]
    source = load_plan(root, args.plan)
    plan = {}
    for i, sid in enumerate(ids):
        cues = [{"cue": c, "at": at, "gain": g} for c, at, g in source.get(sid, []) if c in have]
        if i and "page" in have:
            cues.append({"cue": "page", "at": PAGE_TURN_AT, "gain": PAGE_TURN_GAIN})
        plan[sid] = cues
    (root / "sfx.json").write_text(json.dumps(plan, indent=1))
    print(json.dumps({"pages": len(plan),
                      "cues_used": sorted({c["cue"] for v in plan.values() for c in v})}))
    return 0


def cmd_music(args) -> int:
    """One CC0 track, shaped to a 60 s loop at -20 LUFS.

    The mix loops it per spread and ducks it under the narration, so only the
    first minute is needed; a 3-minute track would be a download and a licence
    line for audio that is never heard.
    """
    root = Path(args.project).resolve()
    out = root / "audio" / "music"
    out.mkdir(parents=True, exist_ok=True)
    dst = out / "bed.wav"
    cfile = root / "audio" / "sfx" / "credits.json"
    credits = json.loads(cfile.read_text()) if cfile.exists() else {}
    if args.source:
        # A series should sound like a series: the second book reuses the first
        # book's bed, credit line included, instead of gambling on the top hit
        # of the same query being the same recording.
        src = Path(args.source).resolve()
        if not src.exists():
            sys.exit(f"music: no bed at {src}")
        if not dst.exists() or args.force:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
        try:
            entry = json.loads((src.parents[2] / "audio" / "sfx" / "credits.json").read_text()).get("music")
        except (OSError, json.JSONDecodeError):
            entry = None
        if entry:
            credits["music"] = entry
        print(f"music: reused {src}", file=sys.stderr)
    elif dst.exists() and not args.force:
        print(f"music: bed already there ({dst})", file=sys.stderr)
    else:
        data = api(MUSIC["q"])
        hits = [h for h in data.get("results", [])
                if MUSIC["want"] in h["title"].lower()
                and not any(bad in h["title"].lower() for bad in MUSIC["avoid"])]
        if not hits:
            sys.exit("music: no CC0 hit matching 'music box lullaby'")
        hit = hits[0]
        raw = out / "bed.src"
        download(hit["url"], raw)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(raw),
                        "-af", f"atrim=0:{MUSIC['seconds']},asetpts=N/SR/TB,"
                               "loudnorm=I=-20:TP=-3:LRA=9,aresample=44100",
                        "-ar", "44100", "-ac", "1", "-c:a", "pcm_s16le", str(dst)], check=True)
        raw.unlink(missing_ok=True)
        dur = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                              "-of", "csv=p=0", str(dst)], capture_output=True, text=True).stdout.strip()
        title = re.sub(r"\.(wav|mp3|flac|ogg|aiff?)$", "", hit["title"].strip(), flags=re.I)
        credits["music"] = {"title": title, "creator": hit.get("creator", "unknown"),
                            "license": hit.get("license", "cc0"), "provider": hit.get("provider", ""),
                            "source": hit.get("foreign_landing_url") or hit.get("url", ""),
                            "seconds": round(float(dur), 2), "file": "audio/music/bed.wav",
                            "kind": "music"}
        print(f"music: <- {hit['title'][:40]} ({hit.get('creator','?')}) {dur}s", file=sys.stderr)
    # Written outside the fetch branch: a reused bed adds a credit too, and the
    # page is rendered from this file, so a missing write is a missing row.
    if credits:
        cfile.parent.mkdir(parents=True, exist_ok=True)
        cfile.write_text(json.dumps(credits, indent=1, ensure_ascii=False))
    write_credits_page(root, credits)
    print(json.dumps({"bed": str(dst), "credits": display_name(credits.get("music", {"file": "", "kind": "music"}))}))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="sfx")
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fetch")
    f.add_argument("--project", default=".")
    f.add_argument("--force", action="store_true")
    f.set_defaults(fn=cmd_fetch)
    c = sub.add_parser("cues")
    c.add_argument("--project", default=".")
    c.add_argument("--lang", default="de")
    c.add_argument("--plan", default="", help="cue plan JSON (default: <project>/sfx.plan.json)")
    c.set_defaults(fn=cmd_cues)
    m = sub.add_parser("music")
    m.add_argument("--project", default=".")
    m.add_argument("--force", action="store_true")
    m.add_argument("--source", default="",
                   help="reuse another book's bed (audio/music/bed.wav) and its credit")
    m.set_defaults(fn=cmd_music)
    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
