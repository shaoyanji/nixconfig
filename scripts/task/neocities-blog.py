#!/usr/bin/env python3
"""neocities-blog.py — write, edit, publish, delete and render the dragon court log.

Source of truth is one HTML file per post, in one of two places:

    site/blog/<slug>.html   published — deployed by neocities-push.sh
    drafts/<slug>.html      draft — never uploaded (the push only walks site/)

Each file starts with a single-line JSON comment that carries what the listings need:

    <!--post {"title": "...", "date": "2026-10-30", "tags": ["court"],
              "status": "published", "summary": "..."}-->

`render` reads those comments and regenerates the three surfaces that would otherwise
drift by hand: the rows in site/blog/index.html, the three cards on site/index.html,
site/feed.xml, and the entry count. Everything else on the site stays hand-written.

The interactive paths use gum (the TUI the task plane is built around) and fall back to
plain prompts when gum is not on PATH.

Usage: neocities-blog.py <list|new|edit|publish|draft|delete|render|menu> [--project DIR]
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

BASE = "https://dragoncourt.neocities.org"
META_RE = re.compile(r"^<!--post (\{.*\})-->\s*$", re.M)
SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")

PROJECT = Path(__file__).resolve().parents[2] / "projects" / "neocities-dragoncourt"
SITE = PROJECT / "site"
BLOG = SITE / "blog"
DRAFTS = PROJECT / "drafts"


# ---- gum ---------------------------------------------------------------------


def have_gum() -> bool:
    return shutil.which("gum") is not None


def gum(*args: str, input_text: str | None = None, optional: bool = False) -> str | None:
    """Run gum; abort on cancel unless optional (then return None)."""
    if not have_gum():
        raise RuntimeError("gum is not installed")
    proc = subprocess.run(
        ["gum", *args], input=input_text, text=True, capture_output=True
    )
    if proc.returncode != 0:
        if optional:
            return None
        sys.exit(130)
    return proc.stdout.rstrip("\n")


def banner(text: str) -> None:
    if have_gum():
        print(gum("style", "--foreground", "51", "--border", "rounded", "--padding", "0 1", text))
    else:
        print(f"== {text} ==")


def ask(header: str, value: str = "", placeholder: str = "") -> str:
    if have_gum():
        args = ["input", "--header", header, "--value", value, "--placeholder", placeholder]
        out = gum(*args)
        return (out or "").strip()
    return input(f"{header} [{value}]: ").strip() or value


def ask_block(header: str, value: str = "") -> str:
    if have_gum():
        out = gum("write", "--header", header, "--width", "78", "--height", "10",
                  "--placeholder", "HTML is fine; a blank line starts a new paragraph.",
                  input_text=value)
        return (out or "").rstrip()
    print(f"{header} (end with a line containing only a dot):")
    lines = []
    for line in sys.stdin:
        if line.strip() == ".":
            break
        lines.append(line.rstrip("\n"))
    return "\n".join(lines).strip()


def confirm(prompt: str) -> bool:
    if have_gum():
        return gum("confirm", prompt, optional=True) is not None
    return input(f"{prompt} [y/N]: ").strip().lower().startswith("y")


# ---- post files -------------------------------------------------------------


def read_post(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    match = META_RE.search(text)
    if not match:
        raise SystemExit(f"{path}: no <!--post {...}--> metadata header")
    meta = json.loads(match.group(1))
    meta.setdefault("tags", [])
    # a post lives where it lives: the directory decides, so a stale "status" in the
    # comment can never claim a draft is deployed (or the reverse)
    meta["status"] = "published" if path.parent == BLOG else "draft"
    return meta


def write_meta(path: Path, meta: dict) -> None:
    text = path.read_text(encoding="utf-8")
    line = "<!--post " + json.dumps(meta, ensure_ascii=False) + "-->"
    if META_RE.search(text):
        text = META_RE.sub(line, text, count=1)
    else:
        text = line + "\n" + text
    path.write_text(text, encoding="utf-8")


def all_posts() -> list[tuple[Path, dict]]:
    found = []
    for directory in (BLOG, DRAFTS):
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.html")):
            if path.name == "index.html":
                continue
            found.append((path, read_post(path)))
    return found


def published() -> list[tuple[Path, dict]]:
    rows = [(p, m) for p, m in all_posts() if m.get("status") == "published"]
    rows.sort(key=lambda row: row[1].get("date", ""), reverse=True)
    return rows


def dotted(date: str) -> str:
    return date.replace("-", ".")


def words_of(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    article = re.search(r"<article[^>]*>(.*?)</article>", text, re.S)
    body = article.group(1) if article else text
    return len(HTML_TAG_RE.sub(" ", body).split())


HTML_TAG_RE = re.compile(r"<[^>]+>")


def slugify(title: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return slug or "entry"


# ---- page template ----------------------------------------------------------

PAGE = """<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title} — 龍庭 dragon court</title>
    <meta name="description" content="{summary}" />
    <link rel="canonical" href="{url}" />
    <link rel="alternate" type="application/rss+xml" title="dragon court log" href="/feed.xml" />
    <meta name="theme-color" content="#05060a" />
    <meta property="og:type" content="article" />
    <meta property="og:title" content="{title}" />
    <meta property="og:url" content="{url}" />
    <link rel="stylesheet" href="/style.css" />
  </head>
  <body>
    <a class="skip" href="#main">skip to content</a>

    <header class="site-header">
      <div class="wrap">
        <a class="brand" href="/">
          <span class="glyph" lang="zh-Hant" aria-hidden="true">龍</span>
          <span class="mark">dragon court</span>
        </a>
        <nav aria-label="main">
          <a href="/">index</a>
          <a href="/blog/" aria-current="page">log</a>
          <a href="/about">about</a>
          <a href="/feed.xml">rss</a>
        </nav>
      </div>
    </header>

    <div class="statusbar">
      <div class="wrap">
        <span><b>filed</b> {date}</span>
        <span><b>clock</b> <time id="clock" datetime="">--:--:--</time></span>
        <span><b>trackers</b> <span class="dot">none</span></span>
      </div>
    </div>

    <main id="main">
      <div class="wrap">
        <article class="post">
          <header>
            <h1>{title}</h1>
            <p class="meta">{meta_line}</p>
          </header>

{body}

          <p class="signoff">— vesper, seat one · stewardship</p>

          <nav class="post-nav" aria-label="entries">
            <a href="/blog/">← all entries</a>
            <a href="/feed.xml">subscribe →</a>
          </nav>
        </article>
      </div>
    </main>

    <footer class="site-footer">
      <div class="wrap">
        <div class="row">
          <span><span class="seal" lang="zh-Hant">龍庭</span> dragon court · est. 2024</span>
          <span><a href="/feed.xml">rss</a> · <a href="/about">colophon</a></span>
        </div>
        <div class="badges">
          <a class="badge" href="https://neocities.org" rel="noopener">
            <img src="/neocities.png" alt="hosted by Neocities" width="105" height="31" />
          </a>
          <span class="badge">hand-coded</span>
          <span class="badge">no trackers</span>
          <span class="badge">utf-8</span>
        </div>
      </div>
    </footer>

    <script src="/app.js" defer></script>
  </body>
</html>
"""


def body_to_html(text: str) -> str:
    """Blank-line separated blocks become paragraphs; anything that starts with a tag is
    passed through so an author can write real markup (blockquote, pre, lists)."""
    blocks = []
    for block in re.split(r"\n\s*\n", text.strip()):
        block = block.strip("\n")
        if not block.strip():
            continue
        if block.lstrip().startswith("<"):
            blocks.append(block)
        else:
            paragraphs = [html.escape(line).strip() for line in block.splitlines() if line.strip()]
            blocks.append("<p>" + "</p>\n          <p>".join(paragraphs) + "</p>")
    return "\n\n".join("          " + block.replace("\n", "\n          ") for block in blocks)


def meta_line(meta: dict, path: Path | None = None) -> str:
    tags = " · ".join(meta.get("tags", []))
    bits = [dotted(meta["date"]), tags]
    if path is not None:
        words = words_of(path)
        bits.append(f"about {max(1, round(words / 200))} min")
    return " · ".join(bit for bit in bits if bit)


def write_page(path: Path, meta: dict, body: str) -> None:
    slug = path.stem
    page = PAGE.format(
        title=html.escape(meta["title"]),
        summary=html.escape(meta["summary"]),
        url=f"{BASE}/blog/{slug}",
        date=dotted(meta["date"]),
        meta_line=meta_line(meta),
        body=body,
    )
    header = "<!--post " + json.dumps(meta, ensure_ascii=False) + "-->\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(header + page, encoding="utf-8")


def sync_page(path: Path, meta: dict) -> None:
    """Keep the head, the h1 and the meta line in step with the metadata comment."""
    text = path.read_text(encoding="utf-8")
    slug = path.stem
    title = html.escape(meta["title"])
    summary = html.escape(meta["summary"])
    url = f"{BASE}/blog/{slug}"

    text = re.sub(r"<title>.*?</title>", f"<title>{title} — 龍庭 dragon court</title>", text, count=1)
    text = re.sub(
        r'<meta\s+name="description"\s+content="[^"]*"\s*/>',
        f'<meta name="description" content="{summary}" />',
        text,
        count=1,
        flags=re.S,
    )
    text = re.sub(
        r'<link rel="canonical" href="[^"]*" />',
        f'<link rel="canonical" href="{url}" />',
        text,
        count=1,
    )
    text = re.sub(
        r'<meta property="og:title" content="[^"]*" />',
        f'<meta property="og:title" content="{title}" />',
        text,
        count=1,
    )
    text = re.sub(
        r'<meta property="og:url" content="[^"]*" />',
        f'<meta property="og:url" content="{url}" />',
        text,
        count=1,
    )
    text = re.sub(r"<h1>.*?</h1>", f"<h1>{title}</h1>", text, count=1)
    text = re.sub(
        r'<p class="meta">.*?</p>',
        f'<p class="meta">{meta_line(meta, path)}</p>',
        text,
        count=1,
        flags=re.S,
    )
    path.write_text(text, encoding="utf-8")


# ---- render -----------------------------------------------------------------


def replace_region(text: str, name: str, payload: str) -> str:
    pattern = re.compile(
        rf"(?P<open>[ \t]*<!-- {name}:start -->).*?(?P<close>[ \t]*<!-- {name}:end -->)",
        re.S,
    )
    if not pattern.search(text):
        raise SystemExit(f"missing <!-- {name}:start --> / <!-- {name}:end --> markers")
    return pattern.sub(
        lambda m: m.group("open") + "\n" + payload + "\n" + m.group("close"),
        text,
        count=1,
    )


def feed_xml(rows: list[tuple[Path, dict]]) -> str:
    items = []
    for path, meta in rows:
        url = f"{BASE}/blog/{path.stem}"
        items.append(
            "    <item>\n"
            f"      <title>{html.escape(meta['title'])}</title>\n"
            f"      <link>{url}</link>\n"
            f"      <guid isPermaLink=\"true\">{url}</guid>\n"
            f"      <pubDate>{rfc822(meta['date'])}</pubDate>\n"
            f"      <category>{html.escape((meta.get('tags') or [''])[0])}</category>\n"
            f"      <description>{html.escape(meta['summary'])}</description>\n"
            "    </item>"
        )
    built = rfc822(rows[0][1]["date"]) if rows else rfc822(dt.date.today().isoformat())
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">\n'
        "  <channel>\n"
        "    <title>龍庭 dragon court — log</title>\n"
        f"    <link>{BASE}/</link>\n"
        f'    <atom:link href="{BASE}/feed.xml" rel="self" type="application/rss+xml" />\n'
        "    <description>A terminal in the dark: machines that check before they claim, "
        "and the eight aspects that keep them honest.</description>\n"
        "    <language>en</language>\n"
        f"    <lastBuildDate>{built}</lastBuildDate>\n"
        "    <generator>neocities-blog.py</generator>\n\n"
        + "\n\n".join(items)
        + "\n  </channel>\n</rss>\n"
    )


def rfc822(date: str) -> str:
    day = dt.date.fromisoformat(date)
    return day.strftime("%a, %d %b %Y 00:00:00 +0000")


def render() -> int:
    rows = published()
    drafts = len(all_posts()) - len(rows)

    cards = []
    for path, meta in rows[:3]:
        slug = path.stem
        cards.append(
            f'            <a class="card" href="/blog/{slug}">\n'
            f'              <time datetime="{meta["date"]}">{dotted(meta["date"])}</time>\n'
            f"              <h3>{html.escape(meta['title'])}</h3>\n"
            f"              <p>\n                {html.escape(meta['summary'])}\n              </p>\n"
            '              <span class="more">read →</span>\n'
            "            </a>"
        )

    entries = []
    for path, meta in rows:
        slug = path.stem
        entries.append(
            "            <li>\n"
            f'              <a href="/blog/{slug}">\n'
            f'                <span class="when">{dotted(meta["date"])}</span>\n'
            f'                <span class="what">{html.escape(meta["title"])}</span>\n'
            f'                <span class="tag">{html.escape(", ".join(meta.get("tags", [])))}</span>\n'
            "              </a>\n"
            "            </li>"
        )

    home = SITE / "index.html"
    home_text = home.read_text(encoding="utf-8")
    home_text = replace_region(home_text, "latest", "\n".join(cards))
    home.write_text(home_text, encoding="utf-8")

    log = BLOG / "index.html"
    log_text = log.read_text(encoding="utf-8")
    log_text = replace_region(log_text, "entries", "\n".join(entries))
    log_text = re.sub(
        r"(<!-- count -->).*?(<!-- /count -->)",
        lambda m: f"{m.group(1)}{len(rows):02d}{m.group(2)}",
        log_text,
        count=1,
    )
    log.write_text(log_text, encoding="utf-8")

    (SITE / "feed.xml").write_text(feed_xml(rows), encoding="utf-8")

    print(f"rendered: {len(rows)} published, {drafts} draft(s)")
    for path, meta in rows:
        print(f"  {dotted(meta['date'])}  {meta['title']}")
    return 0


# ---- interactive commands ---------------------------------------------------


def choose_post(rows: list[tuple[Path, dict]], header: str) -> tuple[Path, dict] | None:
    if not rows:
        print("no posts")
        return None
    labels = [f"{dotted(m['date'])}  {m['title']}" for _p, m in rows]
    if have_gum():
        choice = gum("choose", "--header", header, *labels, optional=True)
        if choice is None:
            return None
        return rows[labels.index(choice)]
    for index, label in enumerate(labels, 1):
        print(f"{index}. {label}")
    raw = input("number: ").strip()
    return rows[int(raw) - 1] if raw.isdigit() and 0 < int(raw) <= len(rows) else None


def form_meta(meta: dict) -> dict:
    title = ask("Title", meta.get("title", ""))
    while not title:
        title = ask("Title (required)", "")
    date = ask("Date (YYYY-MM-DD)", meta.get("date", dt.date.today().isoformat()))
    while True:
        try:
            dt.date.fromisoformat(date)
            break
        except ValueError:
            date = ask("Date must be YYYY-MM-DD", dt.date.today().isoformat())
    tags = ask("Tags (comma separated)", ", ".join(meta.get("tags", [])))
    summary = ask_block("Summary (one or two lines, used by the cards and the feed)",
                        meta.get("summary", ""))
    summary = " ".join(summary.split())
    return {
        "title": title,
        "date": date,
        "tags": [tag.strip() for tag in tags.split(",") if tag.strip()],
        "status": meta.get("status", "draft"),
        "summary": summary,
    }


def cmd_new() -> int:
    banner("dragon court · new entry")
    meta = form_meta({"status": "draft", "date": dt.date.today().isoformat()})
    slug = ask("Slug (URL path)", slugify(meta["title"]))
    while not SLUG_RE.match(slug):
        slug = ask("Slug must be lowercase a-z, 0-9 and dashes", slugify(meta["title"]))
    path = DRAFTS / f"{slug}.html"
    if path.exists() or (BLOG / f"{slug}.html").exists():
        raise SystemExit(f"{slug} already exists")

    body = body_to_html(ask_block("Body"))
    write_page(path, meta, body)
    sync_page(path, meta)
    print(f"draft: {path.relative_to(PROJECT)}")

    if confirm("Publish it now?"):
        path = publish_file(path)
        meta["status"] = "published"
        write_meta(path, meta)
    render()
    return 0


def publish_file(path: Path) -> Path:
    target = BLOG / path.name
    if target.exists() and target != path:
        raise SystemExit(f"{target.name} already exists in site/blog")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(path), str(target))
    meta = read_post(target)
    meta["status"] = "published"
    write_meta(target, meta)
    sync_page(target, meta)
    return target


def unpublish_file(path: Path) -> Path:
    target = DRAFTS / path.name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(path), str(target))
    meta = read_post(target)
    meta["status"] = "draft"
    write_meta(target, meta)
    sync_page(target, meta)
    return target


def cmd_edit() -> int:
    rows = sorted(all_posts(), key=lambda row: row[1].get("date", ""), reverse=True)
    picked = choose_post(rows, "edit which entry?")
    if picked is None:
        return 130
    path, meta = picked
    banner(f"{meta['title']}  [{meta['status']}]")

    action = "metadata, body"
    if have_gum():
        action = gum("choose", "--header", "what do you want to change?",
                     "metadata", "body", "metadata, body", optional=True)
        if action is None:
            return 130

    if "metadata" in action:
        meta = form_meta(meta)
        write_meta(path, meta)
        sync_page(path, meta)
    if "body" in action:
        editor = os.environ.get("EDITOR", "vi")
        subprocess.run([editor, str(path)], check=False)

    render()
    if confirm("Upload to Neocities now?"):
        subprocess.run(["bash", str(Path(__file__).with_name("neocities-push.sh"))], check=False)
    return 0


def cmd_publish() -> int:
    rows = [(p, m) for p, m in all_posts() if m.get("status") != "published"]
    picked = choose_post(rows, "publish which draft?")
    if picked is None:
        return 130
    path = publish_file(picked[0])
    print(f"published: {path.relative_to(PROJECT)}")
    render()
    return 0


def cmd_draft() -> int:
    picked = choose_post(published(), "move which entry back to draft?")
    if picked is None:
        return 130
    path = unpublish_file(picked[0])
    print(f"draft: {path.relative_to(PROJECT)}")
    render()
    return 0


def cmd_delete() -> int:
    rows = sorted(all_posts(), key=lambda row: row[1].get("date", ""), reverse=True)
    picked = choose_post(rows, "delete which entry?")
    if picked is None:
        return 130
    path, meta = picked
    if not confirm(f"delete '{meta['title']}' ({path.relative_to(PROJECT)})? this cannot be undone"):
        print("cancelled")
        return 130
    path.unlink()
    print(f"deleted: {path.relative_to(PROJECT)}")
    render()
    return 0


def cmd_list() -> int:
    rows = all_posts()
    if not rows:
        print("no entries yet")
        return 0
    rows.sort(key=lambda row: row[1].get("date", ""), reverse=True)
    width = max(len(m["title"]) for _p, m in rows)
    for path, meta in rows:
        print(
            f"{dotted(meta['date'])}  {meta['title']:<{width}}  "
            f"{meta['status']:<9}  {', '.join(meta.get('tags', []))}"
        )
    return 0


def cmd_menu() -> int:
    if not have_gum():
        raise SystemExit("the menu needs gum; every command also works on its own")
    actions = {
        "list entries": cmd_list,
        "write a post": cmd_new,
        "edit a post": cmd_edit,
        "publish a draft": cmd_publish,
        "unpublish to draft": cmd_draft,
        "delete a post": cmd_delete,
        "render listings": lambda: render(),
        "deploy to neocities": lambda: subprocess.run(
            ["task", "dev:site:deploy:neocities"], check=False
        ).returncode,
        "quit": lambda: 0,
    }
    while True:
        banner("dragon court · blog control")
        choice = gum("choose", "--header", "what now?", *actions, optional=True)
        if choice is None or choice == "quit":
            return 0
        actions[choice]()
        print()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "command",
        choices=["list", "new", "edit", "publish", "draft", "delete", "render", "menu"],
    )
    parser.add_argument("--project", type=Path, default=None,
                        help="project directory (default: projects/neocities-dragoncourt)")
    args = parser.parse_args()

    global PROJECT, SITE, BLOG, DRAFTS
    if args.project is not None:
        PROJECT = args.project.resolve()
        SITE = PROJECT / "site"
        BLOG = SITE / "blog"
        DRAFTS = PROJECT / "drafts"

    if not SITE.is_dir():
        raise SystemExit(f"{SITE} is not a directory")
    BLOG.mkdir(parents=True, exist_ok=True)
    DRAFTS.mkdir(parents=True, exist_ok=True)

    handlers = {
        "list": cmd_list,
        "new": cmd_new,
        "edit": cmd_edit,
        "publish": cmd_publish,
        "draft": cmd_draft,
        "delete": cmd_delete,
        "render": lambda: render(),
        "menu": cmd_menu,
    }
    return handlers[args.command]()


if __name__ == "__main__":
    raise SystemExit(main())
