#!/usr/bin/env python3
import argparse
import html
import json
import re
from pathlib import Path

from markdown import Markdown

NAV_PATH = Path(__file__).with_name("nav.json")
STYLE_PATH = Path(__file__).with_name("assets") / "style.css"

def load_nav():
    with open(NAV_PATH, encoding="utf-8") as f:
        return json.load(f)

def normalize_base_url(base_url):
    base = base_url.strip()
    if not base.startswith("/"):
        base = "/" + base
    if not base.endswith("/"):
        base = base + "/"
    return base

TEMPLATE = """<!doctype html>
<html lang=\"en\">
  <head>
    <meta charset=\"utf-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
    <title>{page_title} · nixconfig docs</title>
    <style>{style}</style>
  </head>
  <body>
    <div class=\"layout\">
      <nav class=\"nav\">
{nav}
      </nav>
      <main>
        <article>
          <header>
            <div class=\"breadcrumb\">{breadcrumb}</div>
            <h1>{page_title}</h1>
          </header>
{content}
        </article>
      </main>
    </div>
  </body>
</html>
"""

LINK_RE = re.compile(r"\[(?P<text>[^\]]+)\]\((?P<link>[^)]+)\)")


def normalize_path(path_str):
    return str(Path(path_str).as_posix()).lstrip("./")


def default_slug(path_str):
    parts = []
    for segment in Path(path_str).with_suffix("").parts:
        if segment.startswith("."):
            parts.append(segment.lstrip("."))
        else:
            parts.append(segment)
    return "/" + "/".join(filter(None, parts)) + "/"


def with_base(slug, base_url):
    if base_url == "/":
        return slug
    return base_url.rstrip("/") + slug


def build_slug_map(nav):
    return {page["src"]: page["slug"] for section in nav for page in section["pages"]}


def rewrite_links(text, slug_map, base_url):
    def repl(match):
        text = match.group("text")
        href = match.group("link").strip()
        if href.startswith(("http://", "https://", "mailto:", "#")):
            return match.group(0)
        anchor = ""
        if "#" in href:
            href, anchor = href.split("#", 1)
        normalized = normalize_path(href)
        if not normalized:
            return match.group(0)
        target_slug = slug_map.get(normalized)
        if not target_slug and normalized.endswith(".md"):
            target_slug = default_slug(normalized)
        if not target_slug:
            return match.group(0)
        if anchor:
            target_slug = target_slug + "#" + anchor
        return f"[{text}]({with_base(target_slug, base_url)})"
    return LINK_RE.sub(repl, text)


def render_nav(nav, active_slug, base_url):
    lines = []
    for section in nav:
        lines.append(f"        <h2>{html.escape(section['title'])}</h2>")
        for page in section["pages"]:
            slug = page["slug"]
            cls = "nav-link"
            if slug == active_slug:
                cls += " active"
            href = with_base(slug, base_url)
            lines.append(f"        <a class=\"{cls}\" href=\"{href}\">{html.escape(page['label'])}</a>")
    return "\n".join(lines)


def guess_title(text, fallback):
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            return stripped.lstrip("#").strip()
    return fallback


def write_page(output_root, slug, html_content):
    if slug == "/":
        target = output_root / "index.html"
    else:
        target_dir = output_root / slug.lstrip("/").rstrip("/")
        target_dir.mkdir(parents=True, exist_ok=True)
        target = target_dir / "index.html"
    target.write_text(html_content, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--base-url", default="/", help="Base URL for generated links")
    args = parser.parse_args()

    repo_root = Path(args.repo_root)
    output_root = Path(args.out)
    output_root.mkdir(parents=True, exist_ok=True)
    base_url = normalize_base_url(args.base_url)

    nav = load_nav()
    slug_map = build_slug_map(nav)
    style = STYLE_PATH.read_text(encoding="utf-8")

    for section in nav:
        for page in section["pages"]:
            source = repo_root / page["src"]
            if not source.exists():
                raise SystemExit(f"Missing source document: {source}")
            raw = source.read_text(encoding="utf-8")
            safe_raw = rewrite_links(raw, slug_map, base_url)
            md = Markdown(extensions=["fenced_code", "attr_list", "tables"], output_format="html5")
            body = md.convert(safe_raw)
            page_title = guess_title(raw, page["label"])
            nav_html = render_nav(nav, page["slug"], base_url)
            breadcrumb = f"{html.escape(section['title'])} / {html.escape(page['label'])}"
            final = TEMPLATE.format(
                page_title=html.escape(page_title),
                style=style,
                nav=nav_html,
                breadcrumb=breadcrumb,
                content=body,
            )
            write_page(output_root, page["slug"], final)


if __name__ == "__main__":
    main()
