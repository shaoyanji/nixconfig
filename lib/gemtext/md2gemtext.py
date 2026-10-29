#!/usr/bin/env python3
"""Markdown -> gemtext for the fleet capsule.

Not a general converter. It covers what this repo's docs actually contain:
headings, fenced code, bullet and numbered lists, tables, blockquotes, inline
links and images. Everything else falls through as plain text.

A link to another `.md` page is rewritten to the `.gmi` page this same run
writes, so the capsule has no dead internal links. External URLs (http, gemini,
mailto, gopher) are kept verbatim. Anchors are preserved.

Usage: md2gemtext.py <src-dir> <out-dir> <title> <description>
"""

import os
import re
import sys

INLINE_IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
INLINE_LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HTML_TAG = re.compile(r"</?[A-Za-z][^>]*>")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
BULLET = re.compile(r"^\s*[-*+]\s+(.*)$")
ORDERED = re.compile(r"^\s*\d+[.)]\s+(.*)$")
QUOTE = re.compile(r"^\s*>\s?(.*)$")
RULE = re.compile(r"^\s*(?:-{3,}|\*{3,}|_{3,})\s*$")
TABLE_SEP = re.compile(r"^\s*\|?[\s:|-]{3,}\|?\s*$")
FENCE = re.compile(r"^\s*```")

EXTERNAL = ("http://", "https://", "gemini://", "gopher://", "mailto:")


def target(url, page, existing):
    """Resolve an internal link to an absolute capsule path.

    The docs write relative links against two different roots — the page's own
    directory (`./ci-pipeline.md`) and the repo root (`docs/ci-pipeline.md`) —
    so a candidate is accepted when it names a page this run emits, whichever
    root it lands on.
    """
    if url.startswith(EXTERNAL):
        return url
    path, sep, anchor = url.partition("#")
    suffix = sep + anchor if sep else ""
    if path.endswith(".md"):
        path = path[:-3] + ".gmi"
    if not path or path.startswith("/"):
        return path + suffix

    for candidate in (
        os.path.normpath(os.path.join(os.path.dirname(page), path)),
        os.path.normpath(path),
    ):
        if candidate in existing:
            return "/" + candidate + suffix
    return path + suffix


def plain(text):
    text = HTML_TAG.sub("", text)
    text = text.replace("**", "").replace("__", "")
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"\1", text)
    text = re.sub(r"(?<![\w_])_([^_\n]+)_(?![\w_])", r"\1", text)
    return text


def convert(text, links, page, existing):
    """Render one line of markdown, appending (url, label) pairs to `links`."""

    def label_for(text, resolved):
        # A label that is just the path reads as stale once the target is a
        # .gmi page; keep the two in step.
        text = plain(text)
        if text.endswith(".md") and resolved.endswith(".gmi"):
            return text[:-3] + ".gmi"
        return text

    def image(match):
        resolved = target(match.group(2), page, existing)
        label = label_for(match.group(1), resolved) or "image"
        links.append((resolved, label))
        return label

    def link(match):
        resolved = target(match.group(2), page, existing)
        links.append((resolved, label_for(match.group(1), resolved) or match.group(2)))
        return match.group(1)

    text = INLINE_IMAGE.sub(image, text)
    text = INLINE_LINK.sub(link, text)
    return plain(text).rstrip()


def convert_file(source, destination, page, existing):
    out = []
    links = []
    fence = False

    with open(source, encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            line = raw.rstrip("\n")

            if FENCE.match(line):
                fence = not fence
                out.append("```")
                continue
            if fence:
                out.append(line)
                continue

            if not line.strip():
                if links:
                    out.append("")
                    out.extend(f"=> {url} {label}" for url, label in links)
                    links = []
                out.append("")
                continue

            heading = HEADING.match(line)
            if heading:
                depth = min(len(heading.group(1)), 3)
                out.append("#" * depth + " " + convert(heading.group(2), links, page, existing))
            elif RULE.match(line) or TABLE_SEP.match(line):
                continue
            elif QUOTE.match(line):
                out.append("> " + convert(QUOTE.match(line).group(1), links, page, existing))
            elif BULLET.match(line):
                out.append("* " + convert(BULLET.match(line).group(1), links, page, existing))
            elif ORDERED.match(line):
                out.append("* " + convert(ORDERED.match(line).group(1), links, page, existing))
            elif line.count("|") >= 2 and line.strip().startswith("|"):
                cells = [convert(c, links, page, existing) for c in line.strip().strip("|").split("|")]
                out.append(" · ".join(c.strip() for c in cells))
            else:
                out.append(convert(line, links, page, existing))

            if links:
                out.append("")
                out.extend(f"=> {url} {label}" for url, label in links)
                links = []

    while out and not out[-1].strip():
        out.pop()

    os.makedirs(os.path.dirname(destination), exist_ok=True)
    with open(destination, "w", encoding="utf-8") as handle:
        handle.write("\n".join(out) + "\n")


def collect(src, out, title, description):
    pages = []
    for root, _dirs, files in os.walk(src):
        for name in sorted(files):
            if name.endswith(".md"):
                pages.append(os.path.relpath(os.path.join(root, name), src))
    existing = {p[:-3] + ".gmi" for p in pages}
    for relative in sorted(pages):
        page = relative[:-3] + ".gmi"
        convert_file(
            os.path.join(src, relative),
            os.path.join(out, page),
            page,
            existing,
        )

    def section(page):
        if page.startswith("docs/generated/"):
            return (1, "Fleet registry")
        if page.startswith("docs/"):
            return (2, "Documentation")
        return (0, "Project")

    sections = {}
    for page in sorted(p[:-3] + ".gmi" for p in pages):
        sections.setdefault(section(page), []).append(page)

    lines = [f"# {title}", "", description, ""]
    for _rank, heading in sorted(sections):
        lines.append(f"## {heading}")
        lines.append("")
        for page in sections[(_rank, heading)]:
            label = page.rsplit("/", 1)[-1][:-4]
            lines.append(f"=> /{page} {label}")
        lines.append("")

    with open(os.path.join(out, "index.gmi"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines[:-1]) + "\n")


def main():
    src, out, title, description = sys.argv[1:5]
    os.makedirs(out, exist_ok=True)
    collect(src, out, title, description)


if __name__ == "__main__":
    main()
