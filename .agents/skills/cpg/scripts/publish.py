#!/usr/bin/env python3
"""Build a static, browsable picture book from a manifest and its plates.

    publish.py [--project DIR] [--out site]

Finals win over candidates: a chosen plate is copied, otherwise the first
candidate. Images are re-encoded to web JPEGs, because a 1536x1024 PNG per
spread is 3 MB and a book of them is a download, not a page.
"""
from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

CSS = """
:root { color-scheme: light; }
* { box-sizing: border-box; }
body {
  margin: 0; background: #f4ecd8; color: #2c2620;
  font-family: "Iowan Old Style", "Palatino Linotype", Palatino, Georgia, serif;
  line-height: 1.55;
}
header.title {
  min-height: 100vh; display: flex; flex-direction: column; align-items: center;
  justify-content: center; text-align: center; padding: 6vh 8vw;
  background: radial-gradient(circle at 50% 30%, #fbf5e4, #ecdfc2 70%, #dccaa6);
}
header.title h1 { font-size: clamp(2rem, 5vw, 3.6rem); margin: 0 0 .4em; letter-spacing: .01em; }
header.title .sub { font-style: italic; opacity: .72; font-size: 1.1rem; }
header.title .dedication { margin-top: 3rem; max-width: 34ch; font-style: italic; opacity: .85; }
header.title .hint { margin-top: 4rem; font-size: .8rem; letter-spacing: .18em;
  text-transform: uppercase; opacity: .45; }
figure.spread { margin: 0 0 12vh; page-break-after: always; }
figure.spread img { display: block; width: 100%; height: auto; }
figure.spread figcaption {
  max-width: 62ch; margin: 1.6rem auto 0; padding: 0 6vw;
  font-size: clamp(1.05rem, 1.5vw, 1.3rem);
}
figure.spread .page { display: block; font-size: .78rem; letter-spacing: .2em;
  text-transform: uppercase; opacity: .38; margin-bottom: .7rem; }
main { max-width: 1200px; margin: 0 auto; padding: 0 0 8vh; }
section.film { max-width: 1200px; margin: 0 auto 6vh; padding: 0 6vw; }
section.film h2 { font-size: .78rem; letter-spacing: .2em; text-transform: uppercase; opacity: .45; }
section.film video { width: 100%; border-radius: 6px; background: #1b1712; }
section.film .meta { font-size: .74rem; opacity: .4; margin: .4rem 0 0; }
footer { text-align: center; padding: 10vh 8vw 16vh; font-style: italic; opacity: .7; }
footer .meta { font-style: normal; font-size: .78rem; opacity: .6; margin-top: 2rem; }
@media print {
  header.title { min-height: auto; padding: 2cm; background: none; }
  figure.spread { margin: 0; page-break-after: always; }
  body { background: #fff; }
}
"""


def plate_for(root: Path, spread: dict) -> Path | None:
    finals = root / "finals" / f"{spread['id']}.jpg"
    final_png = root / "finals" / f"{spread['id']}.png"
    if finals.exists():
        return finals
    if final_png.exists():
        return final_png
    pick = spread.get("chosen") or 1
    cand = root / "candidates" / spread["id"] / f"c{pick}.png"
    if cand.exists():
        return cand
    others = sorted((root / "candidates" / spread["id"]).glob("c*.png"))
    return others[0] if others else None


def web_image(src: Path, dst: Path) -> bool:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
        return True
    proc = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-y", "-i", str(src),
         "-vf", "scale=1400:-2", "-q:v", "4", str(dst)],
        capture_output=True,
    )
    return proc.returncode == 0


def video_lang(stem: str) -> str:
    """`lantern-de-de_DE-thorsten-high` -> `de`; unknown -> `""`."""
    m = re.search(r"-([a-z]{2})-[A-Za-z]", stem)
    return m.group(1) if m else ""


def video_cuts(root: Path) -> dict[tuple[str, bool], Path]:
    """Book stems -> the file to serve, preferring the `.web` cut.

    Sorted order puts `-music` before the plain stem and the full file before
    its `.web` cut, so a later web cut replaces an earlier full one and nothing
    else is overwritten.
    """
    served: dict[tuple[str, bool], Path] = {}
    for v in sorted((root / "video").glob("*.mp4")):
        if re.search(r"-s\d+\.mp4$", v.name):
            continue
        stem = v.stem
        # `.web` is the container suffix and comes off first: "x-music.web" is a
        # music variant, and stripping `-music` before it would key the web cut
        # of one variant as the other variant's full file.
        is_web = stem.endswith(".web")
        if is_web:
            stem = stem[:-len(".web")]
        has_music = stem.endswith("-music")
        if has_music:
            stem = stem[:-len("-music")]
        key = (stem, has_music)
        if key in served and not is_web:
            continue
        served[key] = v
    return served


def write_mix_page(root: Path, site: Path, manifest: dict,
                   served: dict[tuple[str, bool], Path], lang: str) -> None:
    """The A/B: one book, two mixes, the measured difference between them."""
    esc = html.escape
    plain_label, bed_label = (("ohne Musik", "mit Musik (geduckt)") if lang == "de"
                              else ("cues only", "with the music bed"))
    credits = {}
    cfile = root / "audio" / "sfx" / "credits.json"
    if cfile.exists():
        credits = json.loads(cfile.read_text())
    music = credits.get("music", {})
    stems = [s for s in sorted({k[0] for k in served})
             if (s, True) in served and (s, False) in served
             and video_lang(s) == (lang or "en")]
    cards = []
    notes = []
    for stem in stems:
        plain, withbed = served[(stem, False)], served[(stem, True)]
        for name, label in ((plain, plain_label), (withbed, bed_label)):
            cards.append(
                '<figure class="ab"><figcaption>' + esc(label) + '</figcaption>'
                f'<video controls preload="metadata" src="{esc(name.name)}"></video>'
                f'<small>{esc(name.name)}</small></figure>')
        mix = {}
        for mj in (root / "video").glob("mix-*.json"):
            data = json.loads(mj.read_text())
            if f"{data.get('slug')}-{data.get('lang')}-{data.get('voice')}" == stem:
                mix = data
        duck = (mix.get("variants") or {}).get("duck", {})
        if duck:
            notes.append(
                f"<li>bed gain <b>{mix.get('music_gain')}</b> linear on a −20 LUFS track, "
                f"ducking at threshold {mix.get('duck_threshold')}; measured "
                f"<b>{duck.get('bed_window_delta_db')} dB</b> in the 0.6 s before the "
                f"words and <b>{duck.get('speech_window_delta_db')} dB</b> inside them</li>")
    (site / "mix.html").write_text(
        '<!doctype html><meta charset="utf-8"><title>A/B — music bed</title>'
        '<style>body{background:#f4ecd8;color:#2c2620;font-family:Georgia,serif;margin:0;padding:6vh 6vw}'
        'h1{font-size:1.5rem}p{max-width:70ch}figure.ab{margin:0 0 2rem}'
        'figure.ab video{width:100%;border-radius:6px;background:#1b1712}'
        'figcaption{font-size:.78rem;letter-spacing:.18em;text-transform:uppercase;opacity:.5;margin-bottom:.4rem}'
        'small{opacity:.4;font-size:.74rem}li{margin:.4rem 0}</style>'
        f'<h1>A/B — {esc(manifest.get("title", ""))}</h1>'
        + ('<p>Zwei Schnitte derselben Lesung mit denselben Geräuschen. Der einzige '
           'Unterschied ist die Musik, also ist der Vergleich genau eine Variable breit.</p>'
           if lang == "de" else
           '<p>Two cuts of the same narration and the same cues. The only difference is '
           'the music bed, so the comparison is one variable wide.</p>')
        + "\n".join(cards)
        + (f'<p>Music: <b>{esc(music.get("title", ""))}</b> — {esc(music.get("creator", ""))} '
           f'({esc(music.get("license", ""))}), credited on the <a href="sfx.html">sound page</a>.</p>'
           if music else "")
        + ("<ul>" + "".join(notes) + "</ul>" if notes else "")
        + (('<p><a href="bed.html">Zwei Pegel der Musik zum Vergleich</a> — '
            'die Spieluhr leise und präsent auf denselben zwei Seiten.</p>')
           if (site / "bed.html").exists() else ""))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=os.environ.get("STORYBOOK_DIR", "."))
    parser.add_argument("--out", default="site")
    parser.add_argument("--lang", default="",
                        help="publish the adapted edition from script.<lang>.json as index.<lang>.html")
    args = parser.parse_args()

    root = Path(args.project).resolve()
    manifest = json.loads((root / "manifest.json").read_text())
    lang = args.lang
    if lang:
        adapted = json.loads((root / f"script.{lang}.json").read_text())
        manifest["title"] = adapted.get("title", manifest["title"])
        manifest["subtitle"] = adapted.get("subtitle", manifest.get("subtitle", ""))
        manifest["dedication"] = adapted.get("dedication", manifest.get("dedication", ""))
        captions = {s["id"]: s["text"] for s in adapted["spreads"]}
        for spread in manifest["spreads"]:
            spread["text"] = captions.get(spread["id"], spread.get("text", ""))
    site = root / args.out
    (site / "img").mkdir(parents=True, exist_ok=True)

    missing = []
    plates = {}
    for spread in manifest["spreads"]:
        src = plate_for(root, spread)
        if not src:
            missing.append(spread["id"])
            continue
        dst = site / "img" / f"{spread['id']}.jpg"
        if web_image(src, dst):
            plates[spread["id"]] = dst.name
        else:
            missing.append(spread["id"])

    esc = html.escape
    title = esc(manifest.get("title", "Untitled"))
    subtitle = esc(manifest.get("subtitle", ""))
    dedication = esc(manifest.get("dedication", ""))

    parts = [
        "<!doctype html>", f'<html lang="{lang or "en"}"><head><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        f"<title>{title}</title>", f"<style>{CSS}</style></head><body>",
        '<header class="title">', f"<h1>{title}</h1>",
        f'<p class="sub">{subtitle}</p>' if subtitle else "",
        f'<p class="dedication">{dedication}</p>' if dedication else "",
        '<p class="hint">scroll to read</p>',
        (f'<p class="hint"><a href="index.html">English edition</a></p>' if lang
         else ('<p class="hint"><a href="index.de.html">Deutsche Ausgabe</a></p>'
               if (site / "index.de.html").exists() else "")),
        "</header>", "<main>",
    ]

    for spread in manifest["spreads"]:
        name = plates.get(spread["id"])
        if not name:
            continue
        caption = esc(spread.get("text", ""))
        page = esc(str(spread.get("page", spread["id"])))
        parts += [
            '<figure class="spread">',
            f'<img src="img/{name}" alt="Illustration for page {page}" loading="lazy">',
            f'<figcaption><span class="page">page {page}</span>{caption}</figcaption>',
            "</figure>",
        ]

    printed = len(plates)
    # A narrated cut is optional: when `media.py mix` has produced one, the page
    # opens with it, because a book with sound is a different artifact and the
    # reader should not have to find the file.
    # `-sNN.mp4` is one spread's clip; the book is the file without that suffix.
    # Two variants can exist — the cue-only mix and the one with the music bed —
    # so the page serves the music cut and links the A/B to the other.
    served = video_cuts(root)
    for stem in sorted({k[0] for k in served}):
        # A narration is in one language: the German cut does not belong on the
        # English page, where it would look like the book read itself aloud.
        if video_lang(stem) != (lang or "en"):
            continue
        plain, withbed = served.get((stem, False)), served.get((stem, True))
        vid = (withbed or plain)
        for cut in (plain, withbed):
            if cut is None:
                continue
            dst = site / cut.name
            if not dst.exists() or dst.stat().st_mtime < cut.stat().st_mtime:
                shutil.copy2(cut, dst)
        ab = ((' · <a href="mix.html">A/B die Musik</a>' if lang == "de"
               else ' · <a href="mix.html">A/B the music</a>')
              if withbed and plain else "")
        heading = "Hörbuch" if lang == "de" else "Audiobook"
        parts.insert(parts.index("<main>"), (
            f'<section class="film"><h2>{heading}</h2>'
            f'<video controls preload="metadata" src="{esc(vid.name)}"></video>'
            f'<p class="meta">{esc(vid.stem)}{ab}</p></section>'))

    if any((stem, True) in served and (stem, False) in served
           and video_lang(stem) == (lang or "en") for stem, _ in list(served)):
        write_mix_page(root, site, manifest, served, lang)

    credits = (' · <a href="sfx.html">sound credits</a>'
               if (site / "sfx.html").exists() else "")
    parts += [
        "</main>", "<footer>",
        f"<p>The End</p>",
        f'<p class="meta">{printed} of {len(manifest["spreads"])} plates · '
        f'{title} · a Riverbank tale after Kenneth Grahame{credits}</p>',
        "</footer></body></html>",
    ]
    page = site / (f"index.{lang}.html" if lang else "index.html")
    page.write_text("\n".join(p for p in parts if p))

    if missing:
        print(f"publish: {len(missing)} spreads without a plate: {', '.join(missing)}", file=sys.stderr)
        return 1
    (site / "READY").write_text("complete\n")
    print(f"publish: {printed} plates -> {page}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
