#!/usr/bin/env bash
# scripts/task/cv-blog-check.sh — the is-a.dev site publishes this build's CVs,
# and its `/cv/` page links every one of them.
#
# The CVs are built here (`.#sites.matt-site`) and copied into the blog
# checkout's `assets/files/`, so two sites share one set of PDFs and the drift is
# always the same shape: the anchor survives while the file behind it is a build
# behind, or a CV is added here and never linked there.
#
# Two assertions, both about the CVs and nothing else:
#   - every PDF the checkout publishes hashes equal to the artifact this tree
#     built, so "linked" cannot be satisfied by an older copy;
#   - inside the built `_site`, every published CV is the target of an anchor, that
#     anchor carries `download` (GitHub Pages serves a PDF inline without it), and
#     the href resolves to a file.
#
# It does NOT re-walk the whole blog. The blog's own CI runs `htmlproofer _site`,
# which is the link sweep that understands Jekyll's directory indexes and Liquid
# templates; this repo's walker is shaped for the Nix sites and would report the
# theme's `{url}` search templates as dead links.
#
# Env: BLOG_REPO (default ~/Documents/shaoyanji.is-a.dev), ARTIFACT (default
# /tmp/matt-site), SITE (default $BLOG_REPO/_site), REQUIRED (default "cv.pdf
# cv-de.pdf"). `bundle exec jekyll build` in BLOG_REPO is the blog's build; this
# gate reads `_site` and never spends it.
#
# EXIT
#   0  every published CV is this build, linked, with its target present
#   1  drift: a CV unpublished, stale, unlinked, navigating instead of
#      downloading, or pointing at nothing
#   2  cannot tell: no artifact, no checkout, or no `_site` to read
set -uo pipefail

BLOG_REPO="${BLOG_REPO:-$HOME/Documents/shaoyanji.is-a.dev}"
ARTIFACT="${ARTIFACT:-/tmp/matt-site}"
site="${SITE:-$BLOG_REPO/_site}"
files="$BLOG_REPO/assets/files"
REQUIRED="${REQUIRED:-cv.pdf cv-de.pdf}"

[ -d "$ARTIFACT" ] || {
  echo "cv-blog-check: no artifact at $ARTIFACT — run task matt:build first" >&2
  exit 2
}
[ -d "$files" ] || {
  echo "cv-blog-check: $files missing (BLOG_REPO names the checkout)" >&2
  exit 2
}
[ -d "$site" ] || {
  echo "cv-blog-check: $site missing — build the blog first (bundle exec jekyll build)" >&2
  exit 2
}

exec python3 - "$site" "$files" "$ARTIFACT" "$REQUIRED" <<'PY'
import hashlib
import os
import posixpath
import re
import sys

site, files, artifact, required = sys.argv[1:5]
required = required.split()
HTML = re.compile(r"\.html?$", re.I)
HREF = re.compile(r'(?:href|src)\s*=\s*"([^"]*)"', re.I)
ANCHOR = re.compile(r"<a\b[^>]*>", re.I)
ANCHOR_HREF = re.compile(r'\bhref\s*=\s*"([^"]*)"', re.I)
HAS_DOWNLOAD = re.compile(r"(?<![-_\w])download(?![\w-])", re.I)


def digest(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def resolve(target):
    """What GitHub Pages serves for a path: a file, `x.html`, or `x/index.html`."""
    path = target.lstrip("/")
    if path == "":
        return os.path.isfile(os.path.join(site, "index.html"))
    return (
        os.path.isfile(os.path.join(site, path))
        or os.path.isfile(os.path.join(site, path + ".html"))
        or os.path.isfile(os.path.join(site, path, "index.html"))
    )


published = sorted(f for f in os.listdir(files) if f.lower().endswith(".pdf"))
problems = []

missing = [name for name in required if name not in published]
for name in missing:
    problems.append(f"{name} is required but the checkout does not publish it")

for name in published:
    built = os.path.join(artifact, name)
    if not os.path.isfile(built):
        problems.append(f"{name} is published by the blog but this build does not produce it")
        continue
    got, want = digest(os.path.join(files, name)), digest(built)
    if got != want:
        problems.append(
            f"{name} is a different build: published {got[:12]}, artifact {want[:12]}"
        )

linked = {}
anchors = []
for base, _, names in os.walk(site):
    for name in sorted(names):
        if not HTML.search(name):
            continue
        path = os.path.join(base, name)
        rel = os.path.relpath(path, site)
        here = "/" + posixpath.dirname(rel)
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        for raw in HREF.findall(text):
            href = raw.strip()
            if not href or href.startswith(("#", "mailto:", "data:", "tel:", "javascript:")):
                continue
            if re.match(r"^[a-z][a-z0-9+.-]*://", href, re.I):
                continue
            bare = href.split("#")[0].split("?")[0]
            # A `{url}` is a Liquid/JS placeholder the theme substitutes at
            # runtime, not a link this artifact promises to serve.
            if not bare or "{" in bare or "}" in bare:
                continue
            target = bare if bare.startswith("/") else posixpath.join(here, bare)
            linked.setdefault(posixpath.normpath(target), set()).add(rel)
        for tag in ANCHOR.findall(text):
            match = ANCHOR_HREF.search(tag)
            if match is None:
                continue
            href = match.group(1)
            if not href.lower().split("#")[0].split("?")[0].endswith(".pdf"):
                continue
            anchors.append((rel, href, HAS_DOWNLOAD.search(tag) is not None))

for name in published:
    target = "/assets/files/" + name
    pages = linked.get(target)
    if not pages:
        problems.append(f"no page links {name}")
        continue
    if not resolve(target):
        problems.append(f"{name} is linked from {sorted(pages)[0]} but {target} is not in the artifact")
    if not any(a[1].split("#")[0].split("?")[0].endswith("/" + name) and a[2] for a in anchors):
        problems.append(f"{name} has no anchor carrying download (the click would navigate)")

if problems:
    for line in problems:
        print(f"FAIL {line}")
    print(f"cv-blog-check: {len(problems)} problem(s) across {len(published)} published CV(s)")
    sys.exit(1)

print(
    f"cv-blog-check: {len(published)} published CV(s) match this build and are linked "
    f"from {site} ({', '.join(published)})"
)
PY
