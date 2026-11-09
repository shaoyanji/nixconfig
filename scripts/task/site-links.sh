#!/usr/bin/env bash
# scripts/task/site-links.sh — every internal link a built site emits must resolve
# to a file in that site.
#
#   site-links.sh DIR
#
# Cloudflare Pages serves `work/x.html` at `/work/x` and 308-redirects the `.html`
# form; it has no rewrite that turns `/work/style.css` into `/style.css`. A
# stylesheet href built from the locale's depth instead of the page's depth is
# therefore silent: the page returns 200 and renders unstyled, and no status check
# sees it. This walks the artifact instead — resolve each root-relative or
# relative href/src the way the server will, and fail on one that lands nowhere.
#
# Exit: 0 every link resolves, 1 a link resolves to nothing, 2 the input is not a
# directory.
set -uo pipefail

dir=${1:?usage: site-links.sh DIR}
dir=$(cd "$dir" 2>/dev/null && pwd) || {
  echo "site-links: no such directory: $1" >&2
  exit 2
}

python3 - "$dir" <<'PY'
import os
import posixpath
import re
import sys

root = sys.argv[1]
HTML = re.compile(r"\.html$", re.I)
LINK = re.compile(r'(?:href|src)\s*=\s*"([^"]*)"', re.I)


def resolvable(target):
    """Mirror what Pages serves for a path: a file, or `x` as `x.html`."""
    path = target.lstrip("/")
    if path == "" or path.endswith("/"):
        return os.path.isfile(os.path.join(root, path, "index.html"))
    if os.path.isfile(os.path.join(root, path)):
        return True
    return os.path.isfile(os.path.join(root, path + ".html"))


bad = []
checked = 0
pages = 0
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
            if not resolvable(target):
                bad.append(f"{rel}: {href} -> {target}")

print(f"site-links: {checked} internal links over {pages} pages")
if bad:
    for line in bad:
        print(f"FAIL {line}")
    print(f"site-links: {len(bad)} broken")
    sys.exit(1)
print("site-links: every internal link resolves")
PY
