#!/usr/bin/env bash
# Fail when a markdown link in this repo does not resolve.
#
# Two classes, both found in the tree on 2026-10-20:
#   1. `file:///Volumes/...` and `file:///home/<user>/...` — a link to one
#      machine's checkout. It renders as a dead link on every other host, and it
#      leaks a local path into a public document.
#   2. a relative path that is wrong (a moved file, a wrong `../` depth).
#
# Web links and `#anchors` are not checked: the first needs the network, the
# second needs a renderer. A deliberate dangling pointer carries `link-ok:`
# with a reason on the line.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

python3 - <<'PY'
import os, re, subprocess, sys

files = [f for f in subprocess.check_output(["git", "ls-files", "*.md"]).decode().split("\n") if f]
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)")

absolute, broken = [], []
for path in files:
    text = open(path, encoding="utf-8", errors="replace").read()
    for number, line in enumerate(text.split("\n"), 1):
        if "link-ok:" in line:
            continue
        for match in LINK.finditer(line):
            target = match.group(1).split("#")[0]
            if not target or target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            if target.startswith("file:"):
                absolute.append(f"{path}:{number}: {match.group(1)}")
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(path) or ".", target))
            if not os.path.exists(resolved):
                broken.append(f"{path}:{number}: {match.group(1)}")

if absolute:
    print("FAIL: machine-absolute links; use a repo-relative path")
    for item in absolute[:20]:
        print("  " + item)
if broken:
    print("FAIL: links that resolve to nothing")
    for item in broken[:20]:
        print("  " + item)
if absolute or broken:
    print(f"\n{len(absolute)} absolute, {len(broken)} broken, in {len(files)} tracked markdown files.")
    sys.exit(1)

print(f"PASS: {len(files)} tracked markdown files, every link resolves.")
PY
