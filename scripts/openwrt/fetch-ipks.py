#!/usr/bin/env python3
"""Resolve packages against the OpenWrt feed and download the .ipk closure.

Used by `openwrt get` (scripts/openwrt/openwrt.sh). Prints one local .ipk path
per line on stdout; progress goes to stderr so the caller can capture paths.

The box has no internet, so resolution happens here and the ipks are pushed
afterwards. Dependency order does not matter: `opkg install a.ipk b.ipk` in one
run resolves the batch.
"""
import argparse
import collections
import gzip
import hashlib
import os
import re
import sys
import time
import urllib.request

RELEASE_ROOT = "https://downloads.openwrt.org/releases/{release}"
FEEDS = ["packages/{arch}/base", "packages/{arch}/packages",
         "packages/{arch}/luci", "packages/{arch}/routing",
         "targets/{target}/packages"]
VIRTUAL = {"libc", "libgcc_s", "libpthread", "kernel", "librt", "libdl"}


def cached_fetch(url, cache, refresh=False):
    os.makedirs(cache, exist_ok=True)
    name = hashlib.sha1(url.encode()).hexdigest()[:16]
    path = os.path.join(cache, name)
    fresh = os.path.exists(path) and time.time() - os.path.getmtime(path) < 3600
    if refresh or not fresh:
        with urllib.request.urlopen(url, timeout=60) as resp, open(path, "wb") as out:
            out.write(resp.read())
    return path


def parse_index(path, feed_dir):
    pkgs, stanza = {}, {}
    with gzip.open(path, "rt", errors="replace") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line.strip():
                name = stanza.get("Package")
                if name:
                    stanza["_feed"] = feed_dir
                    stanza["_depends"] = [re.sub(r"\s*\(.*\)$", "", d).strip()
                                          for d in stanza.get("Depends", "").split(",") if d.strip()]
                    pkgs[name] = stanza
                stanza = {}
                continue
            if ": " in line:
                key, value = line.split(": ", 1)
                stanza[key] = value
    return pkgs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--release", required=True)
    ap.add_argument("--target", required=True)
    ap.add_argument("--arch", required=True)
    ap.add_argument("--installed", required=True, help="file with installed package names")
    ap.add_argument("--out", required=True, help="directory for downloaded ipks")
    ap.add_argument("--cache", default=os.path.join(os.path.expanduser("~"), ".cache/openwrt-feed"))
    ap.add_argument("--refresh", action="store_true")
    ap.add_argument("packages", nargs="+")
    args = ap.parse_args()

    installed = {line.strip() for line in open(args.installed) if line.strip()}
    root = RELEASE_ROOT.format(release=args.release)
    index, pkgs = {}, {}
    for feed in FEEDS:
        feed_dir = feed.format(arch=args.arch, target=args.target)
        url = f"{root}/{feed_dir}/Packages.gz"
        try:
            path = cached_fetch(url, args.cache, args.refresh)
        except Exception as exc:  # a missing feed (e.g. luci) is not fatal
            print(f"feed skipped: {feed_dir}: {exc}", file=sys.stderr)
            continue
        pkgs.update(parse_index(path, feed_dir))

    have, missing = {}, []
    queue = collections.deque(args.packages)
    seen = set()
    while queue:
        name = queue.popleft()
        if name in seen:
            continue
        seen.add(name)
        if name in installed:
            continue
        pkg = pkgs.get(name)
        if pkg is None:
            if name not in VIRTUAL:
                missing.append(name)
            continue
        have[name] = pkg
        for dep in pkg["_depends"]:
            if dep not in installed:
                queue.append(dep)

    if missing:
        print("not in the feed: " + ", ".join(missing), file=sys.stderr)
    if not have:
        if not missing:
            print("nothing to install: already present", file=sys.stderr)
        return 1 if missing else 0

    os.makedirs(args.out, exist_ok=True)
    total = 0
    for name, pkg in sorted(have.items()):
        url = f"{root}/{pkg['_feed']}/{pkg['Filename']}"
        dest = os.path.join(args.out, pkg["Filename"])
        if not os.path.exists(dest):
            with urllib.request.urlopen(url, timeout=60) as resp, open(dest, "wb") as out:
                out.write(resp.read())
        total += os.path.getsize(dest)
        print(dest)
    size = sum(int(p.get("Installed-Size", "0") or 0) for p in have.values()) / 1024
    print(f"resolved {len(have)} package(s), {total/1024:.0f} KiB download, "
          f"{size/1024:.1f} MiB installed", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
