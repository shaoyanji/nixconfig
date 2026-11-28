#!/usr/bin/env bash
# site-orphans-check.sh — the host must not serve a file this build does not make.
#
# `checks:site:published` proves one inclusion: build ⊆ live, every file the build
# carries is served byte for byte. This is the other one, live ⊆ build. A page
# that still answers after its CV was renamed out of the tree passes every gate we
# have: the anchor resolves on the live host, the build is clean, and the file
# behind the old name is still there for whoever kept the URL. The same shape
# appears when a deploy uploads a directory the build does not make — a leftover
# in `/tmp/matt-site`, a `dist/` from the console — which is why the deploy
# directory and this gate name the same fix.
#
# Pages answers 404 for a path it does not carry, so a 200 is proof of a file, and
# `_headers` / `_redirects` never answer at all. Enumeration is the hard part:
# Pages publishes no listing. This walks the surface the way a reader does — from
# `/`, following every internal href/src and every `<loc>` in the sitemap — and
# holds each 200 to the build's own resolution rules (`x`, `x.html`,
# `x/index.html`). A file no live page reaches cannot be enumerated over HTTP;
# that gap is small on purpose, because a Pages deploy replaces the whole asset
# set, so an orphan is reachable by construction once a page names it.
#
# The references are `checks:site:published`'s: this tree's `.#ATTR.outPath`
# against the same attr at BASE, so a pass is main's build and not a copy of it.
# No build budget is spent — an unbuilt tree is "cannot tell", never a failure.
#
# Usage: site-orphans-check.sh
#   HOST=matt.bountystash.com ATTR=sites.matt-site BASE=origin/main
#   URL=http://127.0.0.1:8099   # a local surface, for proving the gate fires
#
# EXIT
#   0  everything the host serves is a file this build makes
#   1  orphan: the host serves a 200 for something the build does not carry
#   2  cannot tell: no A record, no build here, an eval failed, the walk hit its
#      page cap, or a request never answered
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2

HOST=${HOST:-matt.bountystash.com}
ATTR=${ATTR:-sites.matt-site}
BASE=${BASE:-origin/main}
URL=${URL:-}
TIMEOUT=${TIMEOUT:-25}
EVAL_TIMEOUT=${EVAL_TIMEOUT:-180}
MAX_PAGES=${MAX_PAGES:-120}
DEPLOY=${DEPLOY:-task matt:deploy:prod}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "site-orphans: $*" >&2
  exit 2
}

repo=$(git rev-parse --show-toplevel 2>/dev/null) || fail "not inside a git checkout"
base_sha=$(git rev-parse --verify --quiet "$BASE^{commit}") || fail "$BASE does not name a commit"

eval_out() { # REF LABEL -> outPath on stdout
  timeout "$EVAL_TIMEOUT" nix eval --raw "$1#${ATTR}.outPath" 2>"$tmp/$2.err"
}

tree_out=$(eval_out . tree) || {
  sed 's/^/  /' "$tmp/tree.err" >&2
  fail "could not evaluate .#${ATTR}.outPath in this tree"
}
[ -n "$tree_out" ] || fail ".#${ATTR}.outPath evaluated to an empty string"

main_out=$(eval_out "git+file://$repo?rev=$base_sha" main) || {
  sed 's/^/  /' "$tmp/main.err" >&2
  fail "could not evaluate ${ATTR} at $(git rev-parse --short "$base_sha")"
}
[ -n "$main_out" ] || fail "${ATTR} at $(git rev-parse --short "$base_sha") evaluated to an empty string"

if [ "$tree_out" != "$main_out" ]; then
  echo "FAIL this tree is not what ${BASE} builds" >&2
  echo "     tree: $tree_out" >&2
  echo "     ${BASE} $(git rev-parse --short "$base_sha"): $main_out" >&2
  exit 1
fi
echo "ok   ${ATTR} is the same build here and at ${BASE} $(git rev-parse --short "$base_sha")"

# The eval resolves a path without building it, so an unbuilt tree is a "cannot
# tell" and not a divergence — and this gate never compiles to find out.
[ -d "$main_out" ] || fail "$main_out is not built here — build ${ATTR} first (a gate spends no build budget)"

if [ -n "$URL" ]; then
  base=${URL%/}
  ip=
  echo "ok   walking ${base} (URL names a local surface, no DNS pin)"
else
  base="https://$HOST"
  # The DNS pin is `site-check.sh`'s: this fleet's resolver keeps a cached
  # NXDOMAIN for a hostname added to Cloudflare the same day.
  ip=$(dig +short @1.1.1.1 "$HOST" | grep -E '^[0-9]' | sed -n 1p)
  [ -n "$ip" ] || fail "1.1.1.1 returns no A record for $HOST"
fi

exec python3 - "$base" "$ip" "$HOST" "$main_out" "$TIMEOUT" "$MAX_PAGES" "$DEPLOY" "$tmp/body" <<'PY'
import os
import posixpath
import re
import subprocess
import sys
from urllib.parse import urlsplit

base, ip, host, artifact, timeout, max_pages, deploy, body = sys.argv[1:9]
max_pages = int(max_pages)

# A local surface names itself; reporting the default HOST against 127.0.0.1
# would send the reader to a site the gate never asked.
if not ip:
    host = urlsplit(base).netloc or host

LINK = re.compile(r'(?:href|src)\s*=\s*"([^"]*)"', re.I)
LOC = re.compile(r"<loc>\s*(.*?)\s*</loc>", re.I | re.S)
RESOLVE = ["--resolve", "%s:443:%s" % (host, ip)] if ip else []

# Paths Pages consumes at deploy time and never serves. A 200 for one of these
# would be a file the build makes for the platform, not an orphan.
CONSUMED = {"_headers", "_redirects", "_routes.json"}


def served_paths():
    """What the build carries, under Pages' resolution rules: x, x.html, x/index.html."""
    paths = set()
    for root, _, names in os.walk(artifact):
        for name in names:
            paths.add(os.path.relpath(os.path.join(root, name), artifact))
    return paths


files = served_paths()


def in_build(path):
    p = path.lstrip("/")
    if p in CONSUMED:
        return True
    if p == "":
        return "index.html" in files
    if p.endswith("/"):
        return p + "index.html" in files
    return p in files or p + ".html" in files or p + "/index.html" in files


def get(path):
    meta = subprocess.run(
        ["curl", "-sSL", "--max-time", timeout] + RESOLVE
        + ["-o", body, "-w", "%{http_code} %{url_effective}", base + path],
        capture_output=True,
        text=True,
    ).stdout.strip()
    if not meta:
        return None, None, b""
    code, _, eff = meta.partition(" ")
    try:
        with open(body, "rb") as fh:
            payload = fh.read()
    except OSError:
        payload = b""
    return code, (urlsplit(eff).path or "/"), payload


def links(path, payload):
    text = payload.decode("utf-8", "replace")
    for raw in LINK.findall(text) + LOC.findall(text):
        href = raw.strip()
        if not href or href.startswith(("#", "mailto:", "data:", "tel:", "javascript:")):
            continue
        if re.match(r"^[a-z][a-z0-9+.-]*://", href, re.I):
            split = urlsplit(href)
            if split.netloc != host:
                continue
            href = split.path or "/"
        href = href.split("#")[0].split("?")[0]
        # A `{url}` is a Liquid/JS placeholder the theme substitutes at runtime,
        # not a link this surface promises to serve.
        if not href or "{" in href or "}" in href:
            continue
        if not href.startswith("/"):
            href = posixpath.join(posixpath.dirname(path), href)
        yield posixpath.normpath(href)


queue = ["/"]
if "sitemap.xml" in files:
    queue.append("/sitemap.xml")
seen = set()
answered = {}
unreachable = []

while queue:
    path = queue.pop(0)
    if path in seen:
        continue
    if len(seen) >= max_pages:
        print(
            "site-orphans: the walk hit its cap of %d page(s) — raise MAX_PAGES, "
            "this gate cannot tell" % max_pages,
            file=sys.stderr,
        )
        sys.exit(2)
    seen.add(path)
    code, effective, payload = get(path)
    if code is None:
        unreachable.append(path)
        continue
    if code != "200":
        # A link that 404s is staleness, not an orphan; `site-links` walks the
        # artifact for that and this gate would only repeat it.
        continue
    answered[effective] = len(payload)
    head = payload[:1024].lower()
    if b"<html" in head or b"<!doctype" in head or b"<urlset" in head:
        for target in links(effective, payload):
            if target not in seen:
                queue.append(target)

orphans = sorted(p for p in answered if not in_build(p))

for path in sorted(answered):
    if in_build(path):
        print("ok   %s%s" % (host, path))
    else:
        print(
            "FAIL %s%s answers 200 with %dB and no file in %s"
            % (host, path, answered[path], artifact)
        )

if unreachable:
    print(
        "site-orphans: %d request(s) never answered (%s) — cannot tell"
        % (len(unreachable), ", ".join(sorted(unreachable)[:5])),
        file=sys.stderr,
    )
    sys.exit(2)

if orphans:
    print(
        "site-orphans: %d orphan(s) at %s — the surface serves %s this build does not make"
        % (len(orphans), host, "a file" if len(orphans) == 1 else "files"),
        file=sys.stderr,
    )
    print(
        "site-orphans: redeploy it so the asset set is this build: %s" % deploy,
        file=sys.stderr,
    )
    sys.exit(1)

print(
    "site-orphans: all %d path(s) %s answers are files in %s"
    % (len(answered), host, artifact)
)
PY
