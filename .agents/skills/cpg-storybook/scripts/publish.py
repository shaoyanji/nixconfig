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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=os.environ.get("STORYBOOK_DIR", "."))
    parser.add_argument("--out", default="site")
    args = parser.parse_args()

    root = Path(args.project).resolve()
    manifest = json.loads((root / "manifest.json").read_text())
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
        "<!doctype html>", '<html lang="en"><head><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        f"<title>{title}</title>", f"<style>{CSS}</style></head><body>",
        '<header class="title">', f"<h1>{title}</h1>",
        f'<p class="sub">{subtitle}</p>' if subtitle else "",
        f'<p class="dedication">{dedication}</p>' if dedication else "",
        '<p class="hint">scroll to read</p>', "</header>", "<main>",
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
    parts += [
        "</main>", "<footer>",
        f"<p>The End</p>",
        f'<p class="meta">{printed} of {len(manifest["spreads"])} plates · '
        f'{title} · a Riverbank tale after Kenneth Grahame</p>',
        "</footer></body></html>",
    ]
    (site / "index.html").write_text("\n".join(p for p in parts if p))

    if missing:
        print(f"publish: {len(missing)} spreads without a plate: {', '.join(missing)}", file=sys.stderr)
        return 1
    (site / "READY").write_text("complete\n")
    print(f"publish: {printed} plates -> {site / 'index.html'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
