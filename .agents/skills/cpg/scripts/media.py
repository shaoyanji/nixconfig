#!/usr/bin/env python3
"""Turn a finished picture book into a narrated one: German first.

    media.py voices
    media.py bakeoff  --project DIR --lang de [--line "…"] [--port 8897]
    media.py say      --project DIR --lang de --voice de_DE-thorsten-high
    media.py mix      --project DIR --lang de --voice de_DE-thorsten-high

The narration is offline VITS (piper) on `clanker`, because it is minutes of
CPU work with a file as the result and it spends no model quota. This box keeps
the plates, the mixing and the publish: `ffmpeg` is local, `piper` is not.

Two things here are not obvious and cost a run each:

- piper reads the text from stdin, and every voice has its own sample rate
  (16 kHz low, 22.05 kHz high), so the mix normalises to 44.1 kHz rather than
  trusting the file.
- clanker's run clock is 120 minutes and the box suspends after 30 idle. The
  whole batch is one job: a per-spread ssh call would be ten round trips and
  ten chances to lose the clock.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
STORYBOOK = Path(os.environ.get("STORYBOOK_DIR", Path.cwd())).resolve()
CLANKER_VOICES = "/data/tts/voices"
CLANKER_RUN = "/data/tts/run"

# The German shelf, measured 2026-11-07. `low`/`x_low` are 16 kHz; `high` is
# 22.05 kHz and about twice the download. Every one of them is a download from
# rhasspy/piper-voices, not a package: the .onnx is the model.
VOICES = {
    "de_DE-thorsten-high": {"lang": "de", "sex": "m", "rate": 22050, "note": "clearest male, best prosody"},
    "de_DE-kerstin-low": {"lang": "de", "sex": "f", "rate": 16000, "note": "warm female, slightly flat"},
    "de_DE-eva_k-x_low": {"lang": "de", "sex": "f", "rate": 16000, "note": "bright female, fastest"},
    "de_DE-ramona-low": {"lang": "de", "sex": "f", "rate": 16000, "note": "storyteller female, faster read"},
    "de_DE-karlsson-low": {"lang": "de", "sex": "m", "rate": 16000, "note": "older male, avuncular"},
}


def clanker(cmd: str) -> str:
    p = subprocess.run(["bash", str(REPO / "scripts/task/clanker.sh"), "ssh", cmd],
                       capture_output=True, text=True)
    if p.returncode != 0:
        sys.exit(f"media: clanker ssh failed: {p.stderr.strip()[:300]}")
    return p.stdout


def job(script: str, tag: str) -> str:
    """Push one shell script to clanker and run it as a detached job."""
    b64 = base64.b64encode(script.encode()).decode()
    path = f"{CLANKER_RUN}/{tag}.sh"
    clanker(f"mkdir -p {CLANKER_RUN} && echo {b64} | base64 -d > {path} && chmod +x {path}")
    out = subprocess.run(["bash", str(REPO / "scripts/task/clanker.sh"), "job", path],
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f"media: job start failed: {out.stderr.strip()[:300]}")
    jid = out.stdout.strip().splitlines()[-1].strip()
    wait = subprocess.run(["bash", str(REPO / "scripts/task/clanker.sh"), "wait", jid, "1800"],
                          capture_output=True, text=True)
    logs = subprocess.run(["bash", str(REPO / "scripts/task/clanker.sh"), "logs", jid, "200"],
                          capture_output=True, text=True).stdout
    if wait.returncode != 0:
        sys.exit(f"media: job {jid} failed:\n{logs[-1500:]}")
    return logs


def fetch(remote: str, local: Path) -> None:
    """One file back over ssh as base64. No rsync on that image."""
    data = clanker(f"base64 -w0 {remote}")
    payload = "".join(m for m in re.findall(r"^[A-Za-z0-9+/=]{40,}$", data, re.M))
    if not payload:
        sys.exit(f"media: no bytes came back for {remote}")
    local.parent.mkdir(parents=True, exist_ok=True)
    local.write_bytes(base64.b64decode(payload))


def speak_script(lines: list[tuple[str, str]], voices: list[str], outdir: str, pace: float) -> str:
    """One piper call per line. `pace` is piper's length_scale.

    1.0 is the model's own speed and reads a German spread at ~200 words a
    minute, which is a news bulletin, not a bedtime story: measured on s04,
    4.8 s at 1.0 and 6.5 s at 1.55 (146 wpm).

    shlex.quote, never json.dumps: a JSON string escapes umlauts as \u00fc and
    piper then reads the escape out loud — that bug cost a whole narration run
    where every word with an umlaut was spelled letter by letter.
    """
    body = "\n".join(f'printf %s {shlex.quote(text)} | piper --model "$V"/{v}.onnx '
                     f'--length_scale {pace} --sentence_silence 0.4 '
                     f'--output_file {outdir}/{v}__{sid}.wav' for v in voices for sid, text in lines)
    return f"""set -uo pipefail
export PATH=/data/home/.nix-profile/bin:$PATH
V={CLANKER_VOICES}
mkdir -p {outdir}
{body}
ls -l {outdir} | tail -n +2 | wc -l
"""


def normalise(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    # A voice can leave a tail of quiet after the last phoneme, and a spread's
    # length is what the video uses, so trailing silence is trimmed as part of
    # normalising rather than left for the mix to pad over.
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(src),
                    "-af", "silenceremove=stop_periods=-1:stop_duration=0.6:stop_threshold=-45dB,"
                           "loudnorm=I=-16:TP=-1.5:LRA=11,aresample=44100",
                    "-ar", "44100", "-ac", "1", "-c:a", "pcm_s16le", str(dst)], check=True)


def cmd_voices(_args) -> int:
    print(json.dumps({"voices": VOICES, "location": "clanker:" + CLANKER_VOICES}, indent=1))
    return 0


def cmd_bakeoff(args) -> int:
    book = load_script(args.project, args.lang)
    line = args.line or book["spreads"][0]["text"]
    tag = f"bakeoff-{args.lang}-{int(time.time())}"
    outdir = f"{CLANKER_RUN}/{tag}"
    logs = job(speak_script([("probe", line)], list(VOICES), outdir, args.pace), tag)
    site = Path(args.project) / "site"
    audio = site / "audio"
    rows = []
    for v in VOICES:
        raw = Path(args.project) / "audio" / args.lang / v / "_probe_raw.wav"
        try:
            fetch(f"{outdir}/{v}__probe.wav", raw)
        except SystemExit:
            print(f"media: {v} produced nothing", file=sys.stderr)
            continue
        dst = audio / f"{v}.wav"
        normalise(raw, dst)
        dur = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                              "-of", "csv=p=0", str(dst)], capture_output=True, text=True).stdout.strip()
        rows.append({"voice": v, **VOICES[v], "file": f"audio/{v}.wav", "seconds": round(float(dur), 2)})
    write_voice_page(site, book, line, rows)
    print(json.dumps({"bakeoff": f"site/voices.html", "line": line, "rows": rows}, ensure_ascii=False, indent=1))
    return 0


def write_voice_page(site: Path, book: dict, line: str, rows: list[dict]) -> None:
    cards = "\n".join(
        f"""<figure class="v"><figcaption><b>{r['voice']}</b> · {r['sex']} · {r['rate']} Hz
        <span>{r['note']}</span></figcaption>
        <audio controls preload="none" src="{r['file']}"></audio>
        <small>{r['seconds']} s</small></figure>""" for r in rows)
    (site / "voices.html").write_text(f"""<!doctype html><meta charset="utf-8">
<title>{book['title']} — Stimmen</title>
<style>
body{{background:#f4ecd8;color:#2c2620;font-family:"Iowan Old Style",Palatino,Georgia,serif;margin:0;padding:6vh 8vw}}
h1{{font-size:1.6rem}} p.line{{font-style:italic;max-width:60ch}}
figure.v{{margin:0 0 1.4rem;padding:1rem 1.2rem;background:#fbf5e4;border:1px solid #e2d6bb;border-radius:6px}}
figure.v figcaption span{{display:block;opacity:.6;font-size:.85rem}}
audio{{width:100%;margin-top:.5rem}}
small{{opacity:.5}}
</style>
<h1>{book['title']} — {len(rows)} deutsche Stimmen</h1>
<p class="line">{line}</p>
{cards}
""")


def load_script(project: Path, lang: str) -> dict:
    p = Path(project) / f"script.{lang}.json"
    if not p.exists():
        sys.exit(f"media: no {p.name}; adapt the book into {lang} first")
    return json.loads(p.read_text())


def cmd_say(args) -> int:
    book = load_script(args.project, args.lang)
    voice = args.voice
    if voice not in VOICES:
        sys.exit(f"media: unknown voice {voice}; try: {', '.join(VOICES)}")
    if VOICES[voice]["lang"] != args.lang:
        sys.exit(f"media: {voice} is not a {args.lang} voice")
    tag = f"say-{args.lang}-{voice}-{int(time.time())}"
    outdir = f"{CLANKER_RUN}/{tag}"
    lines = [(s["id"], s["text"]) for s in book["spreads"]]
    script = speak_script(lines, [voice], outdir, args.pace)
    # The title card is spoken too, so a player that autoplays starts with the book.
    script += (f'printf %s {shlex.quote(book["title"] + ". " + book.get("subtitle", ""))} | '
               f'piper --model "$V"/{voice}.onnx --length_scale {args.pace} '
               f'--output_file {outdir}/{voice}__title.wav\n')
    job(script, tag)
    dest = Path(args.project) / "audio" / args.lang / voice
    ids = [s["id"] for s in book["spreads"]] + ["title"]
    done = []
    for sid in ids:
        raw = dest / "_raw" / f"{sid}.wav"
        fetch(f"{outdir}/{voice}__{sid}.wav", raw)
        dst = dest / f"{sid}.wav"
        normalise(raw, dst)
        raw.unlink(missing_ok=True)
        done.append(sid)
    (dest / "manifest.json").write_text(json.dumps(
        {"lang": args.lang, "voice": voice, "spreads": done, "rate": 44100,
         "loudness": "-16 LUFS"}, indent=1))
    print(json.dumps({"voice": voice, "spreads": len(done), "dir": str(dest)}, indent=1))
    return 0


# A river bed with no sample to license: brown noise through a lowpass is close
# enough under narration, and it cannot be a copyright claim on a published book.
AMBIENCE = "anoisesrc=color=brown:r=44100:a=0.5"


def cues_for(project: Path) -> dict:
    """`sfx.json` if `sfx.py cues` has written one, else nothing."""
    p = Path(project) / "sfx.json"
    return json.loads(p.read_text()) if p.exists() else {}


def mean_volume(path: Path, start: float, dur: float) -> float | None:
    """Mean level of one window, in dBFS, from ffmpeg's own detector.

    The A/B verdict on a music bed is a difference between two files, and this
    is how the difference gets a number instead of an adjective.
    """
    proc = subprocess.run(["ffmpeg", "-loglevel", "info", "-ss", str(start), "-t", str(dur),
                           "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
                          capture_output=True, text=True)
    m = re.search(r"mean_volume: (-?[0-9.]+) dB", proc.stderr)
    return round(float(m.group(1)), 1) if m else None


def cmd_mix(args) -> int:
    book = load_script(args.project, args.lang)
    voice = args.voice
    project = Path(args.project)
    dest = project / "audio" / args.lang / voice
    if not dest.exists():
        sys.exit(f"media: no narration for {voice}; run `say` first")
    # An audition is two spreads, not a book: `--spreads` with `--out` renders a
    # clip somewhere else, so a level test costs seconds and cannot be mistaken
    # by `publish.py` for another edition of the book.
    if args.spreads:
        wanted = [s.strip() for s in args.spreads.split(",") if s.strip()]
        kept = [s for s in book["spreads"] if s["id"] in wanted]
        if len(kept) != len(wanted):
            sys.exit(f"media: no such spread(s): {args.spreads}")
        book = {**book, "spreads": kept}
    site = project / "site"
    video = (Path(args.out) if args.out else project / "video").resolve()
    video.mkdir(parents=True, exist_ok=True)
    slug = args.slug or project.name
    plan = {} if args.dry_bed else cues_for(project)
    bed = None
    if not args.dry_bed:
        want = Path(args.music) if args.music else project / "audio" / "music" / "bed.wav"
        if want.exists():
            bed = want
        elif args.music:
            sys.exit(f"media: no music bed at {want}; run `sfx.py music` first")

    # Two cuts of one book, from one command: the cue-only mix and the mix with
    # the music bed. Both are the same narration and the same cues, so the only
    # variable a listener hears is the bed — which is what an A/B needs.
    # `--only music` is what a bed tweak costs: the cue-only cut is unchanged,
    # so re-rendering it would be 28 encodes for nothing.
    if args.only == "plain":
        variants = [("", None)]
    elif args.only == "music":
        if not bed:
            sys.exit("media: --only music needs a bed (audio/music/bed.wav or --music)")
        variants = [("-music", bed)]
    else:
        variants = [("", None)]
        if bed:
            variants.append(("-music", bed))
    report: dict = {}
    for suffix, music in variants:
        stem = f"{slug}-{args.lang}-{voice}{suffix}"
        report[suffix or "plain"] = mix_variant(
            book, dest, site, video, plan, args, stem, music)

    # A one-variant run must not erase the other variant's measurements: the
    # A/B page reads both, and `--only music` is the cheap way to retune a bed.
    mixfile = video / f"mix-{args.lang}-{voice}.json"
    prior = json.loads(mixfile.read_text()) if (mixfile.exists() and not args.out) else {}
    merged = {k: v for k, v in (prior.get("variants") or {}).items() if k != "duck"}
    merged.update(report)
    if merged.get("plain") and merged.get("-music"):
        merged["duck"] = {
            "bed_window_delta_db": _delta(merged["plain"], merged["-music"], "bed_window"),
            "speech_window_delta_db": _delta(merged["plain"], merged["-music"], "speech_window"),
        }
    if not args.out:
        mixfile.write_text(json.dumps({
            "slug": slug, "lang": args.lang, "voice": voice,
            "spreads": len(book["spreads"]),
            "music": str(bed) if bed else prior.get("music"),
            "music_gain": args.music_gain, "duck_threshold": args.duck,
            "duck_ratio": args.duck_ratio, "variants": merged,
        }, indent=1))
    print(json.dumps({k: {"book": v.get("book"), "web": v.get("web")}
                      for k, v in report.items() if isinstance(v, dict) and "book" in v}
                     | {"mix": f"video/mix-{args.lang}-{voice}.json"}, indent=1))
    return 0


def _delta(plain: dict | None, withbed: dict | None, key: str) -> float | None:
    if not plain or not withbed or plain.get(key) is None or withbed.get(key) is None:
        return None
    return round(withbed[key] - plain[key], 1)


def mix_variant(book: dict, dest: Path, site: Path, video: Path, plan: dict,
                args, stem: str, music: Path | None) -> dict:
    parts = []
    for spread in book["spreads"]:
        sid = spread["id"]
        narr = dest / f"{sid}.wav"
        plate = site / "img" / f"{sid}.jpg"
        if not narr.exists() or not plate.exists():
            sys.exit(f"media: missing {'narration' if not narr.exists() else 'plate'} for {sid}")
        dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                    "-of", "csv=p=0", str(narr)],
                                   capture_output=True, text=True).stdout.strip())
        total = round(dur + 1.6, 2)
        frames = int(total * 25)
        tail = round(total - 1.1, 2)
        out = video / f"{stem}-{sid}.mp4"

        # Real cues when `sfx.py` has been through, the synthesised bed when it
        # has not: the graph shape is the only thing that changes, so a book
        # without sound files still mixes.
        cues = [c for c in plan.get(sid, [])
                if (Path(args.project) / "audio" / "sfx" / f"{c['cue']}.wav").exists()]
        inputs = ["-loop", "1", "-i", str(plate), "-i", str(narr)]
        # The narration is both a mix input and the sidechain key for the music
        # duck, so it is split once here rather than decoded twice.
        graph = [
            f"[0:v]scale=1600:-2,zoompan=z='min(zoom+0.00035,1.07)':x='iw/2-(iw/zoom/2)':"
            f"y='ih/2-(ih/zoom/2)':d={frames}:s=1280x854:fps=25,setsar=1[v]",
            "[1:a]adelay=700|700,apad,asplit=2[nar][key]" if music
            else "[1:a]adelay=700|700,apad[nar]",
        ]
        mix_in = ["[nar]"]
        n_in = 2
        if cues:
            for k, cue in enumerate(cues):
                path = Path(args.project) / "audio" / "sfx" / f"{cue['cue']}.wav"
                inputs += ["-i", str(path)]
                at = float(cue.get("at", 0))
                delay = int((at if at >= 0 else total + at) * 1000)
                graph.append(
                    f"[{n_in}:a]volume={cue.get('gain', 0.15)},atrim=0:{total},"
                    f"asetpts=N/SR/TB,adelay={delay}|{delay}[s{k}]")
                mix_in.append(f"[s{k}]")
                n_in += 1
        else:
            inputs += ["-f", "lavfi", "-t", str(total), "-i", AMBIENCE]
            graph.append(f"[{n_in}:a]lowpass=f=750,highpass=f=70,volume=0.09[amb]")
            mix_in.append("[amb]")
            n_in += 1
        if music:
            # Ducking is the difference between a bed and a bed that fights the
            # voice: the music is compressed by the narration itself, ~6:1 at a
            # low threshold, so it is present in the gaps and steps back under
            # every word without a hand-drawn volume envelope.
            inputs += ["-stream_loop", "-1", "-i", str(music)]
            graph.append(f"[{n_in}:a]atrim=0:{total},asetpts=N/SR/TB,"
                         f"volume={args.music_gain}[musraw]")
            graph.append(f"[musraw][key]sidechaincompress=threshold={args.duck}:"
                         f"ratio={args.duck_ratio}:attack=15:release=400[mus]")
            mix_in.append("[mus]")
            n_in += 1
        # normalize=0: amix divides by its input count by default, which threw
        # 6 dB away and left the book at -22.7 dB mean against the -16 the
        # narration was normalised to.
        # A 0.6 s fade-in on the mix swallowed the page turn that opens the
        # spread (measured -47.7 dB mean, -31 dB peak across the first 600 ms):
        # the cue is *supposed* to be the first thing heard. 50 ms is enough to
        # stop a click, and the limiter is what keeps a stacked cue off the ceiling.
        graph.append(
            f"{''.join(mix_in)}amix=inputs={len(mix_in)}:duration=longest:"
            f"dropout_transition=0:normalize=0,atrim=0:{total},"
            f"afade=t=in:st=0:d=0.05,afade=t=out:st={tail}:d=1.1,"
            f"alimiter=limit=0.85:level=false[a]")
        filt = ";".join(graph)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *inputs,
                        "-filter_complex", filt, "-map", "[v]", "-map", "[a]",
                        "-t", str(total), "-c:v", "libx264", "-preset", "medium", "-crf", "20",
                        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k",
                        "-movflags", "+faststart", str(out)], check=True)
        parts.append(out)
        print(f"media: {out.name} {total}s", file=sys.stderr)
    listing = video / f"concat-{stem}.txt"
    listing.write_text("".join(f"file '{p.name}'\n" for p in parts))
    final = video / f"{stem}.mp4"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0",
                    "-i", str(listing), "-c", "copy", "-movflags", "+faststart", str(final)], check=True)
    # 28 MB at full quality is a 30 s wait on a phone, so the page points at
    # the web cut. The demo server (.#cli.serve.static-serve) answers Range, so
    # the full master stays seekable for anyone who opens it directly.
    web = video / f"{stem}.web.mp4"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(final),
                    "-vf", "scale=960:-2", "-c:v", "libx264", "-preset", "slow", "-crf", "26",
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "96k",
                    "-movflags", "+faststart", str(web)], check=True)
    seconds = round(sum(float(subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
         str(p)], capture_output=True, text=True).stdout.strip()) for p in parts), 1)
    # Two windows of the first spread: before the words start, and inside them.
    # Their difference between the plain mix and the music mix is the bed's
    # level and the duck's depth, measured rather than asserted.
    first = parts[0]
    return {"book": str(final), "web": str(web), "spreads": len(parts),
            "seconds": seconds, "bed_window": mean_volume(first, 0.0, 0.6),
            "speech_window": mean_volume(first, 1.2, 2.0)}


def main() -> int:
    ap = argparse.ArgumentParser(prog="media")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("voices").set_defaults(fn=cmd_voices)
    for name, fn in (("bakeoff", cmd_bakeoff), ("say", cmd_say), ("mix", cmd_mix)):
        p = sub.add_parser(name)
        p.add_argument("--project", default=str(STORYBOOK))
        p.add_argument("--lang", default="de")
        p.add_argument("--voice", default="de_DE-thorsten-high")
        p.add_argument("--pace", type=float, default=1.5,
                       help="piper length_scale; 1.0 is the model's own, faster than a bedtime read")
        if name == "bakeoff":
            p.add_argument("--line", default="")
        if name == "mix":
            p.add_argument("--synth-bed", action="store_true", dest="dry_bed",
                           help="ignore sfx.json and mix the synthesised noise bed instead")
            p.add_argument("--slug", default="",
                           help="output stem (default: the project directory name)")
            p.add_argument("--music", default="",
                           help="music bed wav (default: <project>/audio/music/bed.wav when it exists)")
            p.add_argument("--music-gain", type=float, default=0.22,
                           help="linear gain on the -20 LUFS bed, before ducking "
                                "(0.22 measures ~21 dB under the voice in the gaps)")
            p.add_argument("--duck", type=float, default=0.05,
                           help="sidechain threshold; lower is a firmer duck")
            p.add_argument("--duck-ratio", type=float, default=3.0,
                           help="sidechain ratio; 6 buries the bed, 3 steps it back")
            p.add_argument("--only", choices=["both", "plain", "music"], default="both",
                           help="render one cut only (a bed tweak does not need both)")
            p.add_argument("--spreads", default="",
                           help="comma-separated spread ids to render as a clip, e.g. s01,s02")
            p.add_argument("--out", default="",
                           help="write the render somewhere other than <project>/video "
                                "(used with --spreads for an audition)")
        p.set_defaults(fn=fn)
    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
