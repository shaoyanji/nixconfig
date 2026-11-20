#!/usr/bin/env bash
# scripts/task/site-links.sh — every internal link a built site emits must resolve
# to a file in that site.
#
#   site-links.sh DIR [PDF...]
#
# A named PDF is a required one: the build that ships it passes its own list, so
# "the site ships this CV" and "a page links this CV" are one assertion instead of
# a filename spelled in two places.
#
# Cloudflare Pages serves `work/x.html` at `/work/x` and 308-redirects the `.html`
# form; it has no rewrite that turns `/work/style.css` into `/style.css`. A
# stylesheet href built from the locale's depth instead of the page's depth is
# therefore silent: the page returns 200 and renders unstyled, and no status check
# sees it. This walks the artifact instead — resolve each root-relative or
# relative href/src the way the server will, and fail on one that lands nowhere.
#
# The second rule is orphans. A PDF the site ships but no page links is reachable
# only by guessing its filename — the tailored CVs sat in every build unlinked
# exactly that way. Every *.pdf under the artifact must be the target of a link,
# which also keeps a renamed or dropped CV from leaving a build-only file behind.
#
# The third rule is the `download` attribute on a PDF anchor, and it exists
# because every other check cannot see its absence. Cloudflare Pages serves a PDF
# as `Content-Type: application/pdf` with no `Content-Disposition`, so the browser
# decides from the attribute: with it the link saves a file, without it the link
# navigates and looks identical to a link checker. Drop the attribute and the
# page still returns 200, the href still resolves, the PDF is still linked — and
# the click silently stops downloading. This walks the anchors themselves.
#
# It runs inside the `matt-site` derivation (lib/matt-site.nix) twice — `--gap`
# as a pre-flight, then the full pass last — with that build's `cvFiles` as the
# required list: `matt:build`, `matt:deploy:preview` and `matt:deploy:prod`
# inherit the gate because they build the derivation, and `task site:links` runs
# it over the same artifacts. The procedure and why it
# lives in the build: docs/cv-ats-compliance.md, "The link gate".
#
# `--gap` is the pre-flight form: it asserts only the two structural gaps — a
# built PDF no page links, and a href/src that resolves nowhere — and returns at
# the first broken target instead of finishing the walk, so a build can ask "is
# anything missing?" without paying for the anchor pass. It cannot replace the
# full gate: a lost `download` attribute and a PDF the caller forgot to require
# are both invisible to it.
#
# Exit: 0 every link resolves, every PDF is linked and every required PDF is
# shipped (or, with --gap, nothing is missing), 1 any of those fails, 2 the input
# is not a directory.
set -uo pipefail

gap=""
if [ "${1:-}" = "--gap" ]; then gap="--gap"; shift; fi
input=${1:?usage: site-links.sh [--gap] DIR [PDF...]}
shift
dir=$(cd "$input" 2>/dev/null && pwd) || {
  echo "site-links: no such directory: $input" >&2
  exit 2
}

python3 - "$dir" "$gap" "$@" <<'PY'
import os
import posixpath
import re
import sys

root = sys.argv[1]
gap_only = sys.argv[2] == "--gap"
expected = sys.argv[3:]
HTML = re.compile(r"\.html$", re.I)
LINK = re.compile(r'(?:href|src)\s*=\s*"([^"]*)"', re.I)
ANCHOR = re.compile(r"<a\b[^>]*>", re.I)
ANCHOR_HREF = re.compile(r'\bhref\s*=\s*"([^"]*)"', re.I)
HAS_DOWNLOAD = re.compile(r"(?<![-\w])download(?![\w-])", re.I)


def resolvable(target):
    """Mirror what Pages serves for a path: a file, or `x` as `x.html`."""
    path = target.lstrip("/")
    if path == "" or path.endswith("/"):
        return os.path.isfile(os.path.join(root, path, "index.html"))
    if os.path.isfile(os.path.join(root, path)):
        return True
    return os.path.isfile(os.path.join(root, path + ".html"))


bad = []
bad_download = []
linked = set()
checked = 0
pages = 0
pdf_anchors = 0
for base, _, files in os.walk(root):
    for name in sorted(files):
        if not HTML.search(name):
            continue
        pages += 1
        path = os.path.join(base, name)
        rel = os.path.relpath(path, root)
        # A relative link resolves against the directory the page lives in, not
        # against its extensionless URL.
        here = "/" + posixpath.dirname(rel)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        for raw in LINK.findall(text):
            href = raw.strip()
            if not href or href.startswith(("#", "mailto:", "data:", "tel:", "javascript:")):
                continue
            # Absolute URLs name another origin. The deploy target is not known
            # at build time, so only root-relative and relative paths are ours.
            if re.match(r"^[a-z][a-z0-9+.-]*://", href, re.I):
                continue
            bare = href.split("#")[0].split("?")[0]
            if bare == "":
                continue
            target = bare if bare.startswith("/") else posixpath.join(here, bare)
            # `normpath` drops the trailing slash, which is the difference between
            # a directory and a file here.
            trailing = bare.endswith("/")
            target = posixpath.normpath(target)
            if trailing:
                target = target.rstrip("/") + "/"
            checked += 1
            linked.add(posixpath.normpath(target.lstrip("/")))
            if not resolvable(target):
                if gap_only:
                    print(f"FAIL {rel}: {href} -> {target}")
                    print("site-links: 1 broken (gap check stops at the first)")
                    sys.exit(1)
                bad.append(f"{rel}: {href} -> {target}")
        if gap_only:
            continue
        # A PDF anchor must carry `download`: without it Pages serves the file as
        # a document and the click navigates instead of saving.
        for tag in ANCHOR.findall(text):
            match = ANCHOR_HREF.search(tag)
            if match is None:
                continue
            href = match.group(1).split("#")[0].split("?")[0]
            if not href.lower().endswith(".pdf"):
                continue
            pdf_anchors += 1
            if HAS_DOWNLOAD.search(tag) is None:
                bad_download.append(f"{rel}: {match.group(1)} has no download attribute")

pdfs = []
for base, _, files in os.walk(root):
    for name in sorted(files):
        if name.lower().endswith(".pdf"):
            pdfs.append(posixpath.normpath(os.path.relpath(os.path.join(base, name), root)))
orphans = [p for p in sorted(pdfs) if p not in linked]
missing = [p for p in expected if p not in pdfs]

if gap_only:
    print(
        f"site-links: gap check, {pages} pages, {len(pdfs)} PDFs"
        + (f" ({len(expected)} required)" if expected else "")
    )
else:
    print(
        f"site-links: {checked} internal links over {pages} pages, {len(pdfs)} PDFs"
        + (f" ({len(expected)} required)" if expected else "")
    )
if bad:
    for line in bad:
        print(f"FAIL {line}")
    print(f"site-links: {len(bad)} broken")
    sys.exit(1)
if bad_download:
    for line in bad_download:
        print(f"FAIL {line}")
    print(f"site-links: {len(bad_download)} PDF anchor(s) that would navigate instead of download")
    sys.exit(1)
if missing:
    for path in missing:
        print(f"FAIL required PDF not shipped {path}")
    print(f"site-links: {len(missing)} required PDF(s) missing")
    sys.exit(1)
if orphans:
    for path in orphans:
        print(f"FAIL no page links {path}")
    print(f"site-links: {len(orphans)} unlinked PDF(s) of {len(pdfs)}")
    sys.exit(1)
if gap_only:
    print(
        f"site-links: no gaps — every target resolves and all {len(pdfs)} built PDFs have a site link"
    )
    sys.exit(0)
print(
    f"site-links: every internal link resolves, all {len(pdfs)} PDFs are linked"
    + (f", and all {pdf_anchors} PDF anchors download" if pdf_anchors else "")
)
PY
