#!/usr/bin/env python3
import argparse
import html
import re
from pathlib import Path

from markdown import Markdown

SECTIONS = [
    {
        "title": "Home",
        "pages": [
            {"label": "README", "src": "README.md", "slug": "/"},
        ],
    },
    {
        "title": "Repo routing",
        "pages": [
            {"label": "AGENTS", "src": "AGENTS.md", "slug": "/routing/agents/"},
            {"label": "Agent guidance", "src": ".agents/README.md", "slug": "/routing/agents-index/"},
        ],
    },
    {
        "title": "Deploy",
        "pages": [
            {"label": "Deploy landing", "src": ".agents/deploy/README.md", "slug": "/deploy/"},
            {"label": "AI hosts", "src": ".agents/deploy/ai-hosts.md", "slug": "/deploy/ai-hosts/"},
            {"label": "Rollback", "src": ".agents/deploy/rollback.md", "slug": "/deploy/rollback/"},
            {"label": "Promotion", "src": ".agents/deploy/promotion.md", "slug": "/deploy/promotion/"},
            {"label": "Website guide", "src": ".agents/deploy/website.md", "slug": "/deploy/website/"},
            {"label": "garnixMachine notes", "src": ".agents/deploy/hosts/garnixMachine.md", "slug": "/deploy/hosts/garnixMachine/"},
            {"label": "mtfuji notes", "src": ".agents/deploy/hosts/mtfuji.md", "slug": "/deploy/hosts/mtfuji/"},
            {"label": "thinsandy notes", "src": ".agents/deploy/hosts/thinsandy.md", "slug": "/deploy/hosts/thinsandy/"},
        ],
    },
    {
        "title": "Control plane",
        "pages": [
            {"label": "Task control plane", "src": "docs/task-control-plane.md", "slug": "/control/task-control-plane/"},
            {"label": "Taskfile map", "src": "taskfiles/README.md", "slug": "/control/taskfiles/"},
        ],
    },
    {
        "title": "Supporting docs",
        "pages": [
            {"label": "Nullclaw fleet", "src": "docs/nullclaw-fleet-pattern.md", "slug": "/docs/nullclaw-fleet-pattern/"},
            {"label": "Userland module map", "src": "docs/userland-module-map.md", "slug": "/docs/userland-module-map/"},
            {
                "label": "Userland package ownership",
                "src": "docs/userland-package-ownership.md",
                "slug": "/docs/userland-package-ownership/",
            },
        ],
    },
    {
        "title": "Codex & maintenance",
        "pages": [
            {"label": "Codex handoff", "src": "docs/codex-handoff.md", "slug": "/codex-handoff/"},
            {"label": "TODO", "src": "TODO.md", "slug": "/todo/"},
        ],
    },
]

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


def build_slug_map():
    return {page["src"]: page["slug"] for section in SECTIONS for page in section["pages"]}


def rewrite_links(text, slug_map):
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
        return f"[{text}]({target_slug})"
    return LINK_RE.sub(repl, text)


def render_nav(active_slug):
    lines = []
    for section in SECTIONS:
        lines.append(f"        <h2>{html.escape(section['title'])}</h2>")
        for page in section["pages"]:
            slug = page["slug"]
            cls = "nav-link"
            if slug == active_slug:
                cls += " active"
            lines.append(f"        <a class=\"{cls}\" href=\"{slug}\">{html.escape(page['label'])}</a>")
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


def load_style():
    style_path = Path(__file__).with_name("assets") / "style.css"
    return style_path.read_text(encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    repo_root = Path(args.repo_root)
    output_root = Path(args.out)
    output_root.mkdir(parents=True, exist_ok=True)

    slug_map = build_slug_map()
    style = load_style()

    for section in SECTIONS:
        for page in section["pages"]:
            source = repo_root / page["src"]
            if not source.exists():
                raise SystemExit(f"Missing source document: {source}")
            raw = source.read_text(encoding="utf-8")
            safe_raw = rewrite_links(raw, slug_map)
            md = Markdown(extensions=["fenced_code", "attr_list", "tables"], output_format="html5")
            body = md.convert(safe_raw)
            page_title = guess_title(raw, page["label"])
            nav_html = render_nav(page["slug"])
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
