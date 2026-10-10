#!/usr/bin/env python3
# ==============================================================================
# CLOSURE ATTRIBUTION — who owns which bytes
# ==============================================================================
# Answers the question a size ranking cannot: "if I removed X, how much would
# actually come back?"
#
# A plain top-N list overstates every candidate, because Nix store paths are
# shared. On frieren, 16.2 GiB of 33.8 GiB is reachable from more than one owner,
# so most of what looks removable is substrate the rest of the system still needs.
#
# Method:
#   1. Read the reference graph out of `pkgs.closureInfo`'s `registration` file
#      (the same artifact lib/closure-graph.nix parses). Format per path:
#        <path> / <narHash> / <narSize> / <deriver> / <refCount> / <ref>...
#   2. Take the "branches" — the things that can own bytes: every
#      unit-*.{service,socket,timer} plus the package farms
#      (home-manager-path, home-manager-files, system-path).
#   3. Prune ancestor branches. `user-environment` reaches `home-manager-path`,
#      and an activation unit reaches everything it activates; if both are kept,
#      every descendant path is "reachable from 2 branches" and both read as 0.
#      Keeping only branches no other branch reaches fixes that.
#   4. A path is EXCLUSIVE to a branch when exactly one branch reaches it.
#      Exclusive bytes are the honest ceiling on removing that branch; SHARED
#      bytes only come back when the LAST owner of each path goes.
#
# Usage:
#   closure-attribution.py <closure-info-store-path> [--top N]
#
# Get the path with:
#   bash scripts/task/closure-graph.sh json | jq -r .infoPath
# or just run the wrapper task: dev:closure:attribution
#
# Local store only (closureInfo builds locally), same as closure-graph.sh.
# ==============================================================================

import collections
import re
import sys


def parse_args(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        sys.stdout.write(__doc__.split("\n", 2)[2].lstrip("\n"))
        raise SystemExit(0 if len(argv) > 1 else 2)
    info = argv[1].rstrip("/")
    top = 22
    if "--top" in argv:
        top = int(argv[argv.index("--top") + 1])
    return info, top


def load_graph(info):
    """-> (paths, nar{}, refs{}) from the closure-info registration file."""
    with open(info + "/store-paths") as fh:
        paths = fh.read().split()
    with open(info + "/registration") as fh:
        lines = fh.read().splitlines()

    nar, refs = {}, {}
    i = 0
    while i < len(lines):
        path = lines[i]
        nar[path] = int(lines[i + 2])
        ref_count = int(lines[i + 4])
        refs[path] = lines[i + 5 : i + 5 + ref_count]
        i += 5 + ref_count
    return paths, nar, refs


def make_reach(refs):
    memo = {}

    def reach(root):
        if root in memo:
            return memo[root]
        seen, stack = set(), [root]
        while stack:
            node = stack.pop()
            if node in seen:
                continue
            seen.add(node)
            for ref in refs.get(node, ()):
                if ref not in seen:
                    stack.append(ref)
        memo[root] = seen
        return seen

    return reach


def name(path):
    return re.sub(r"^/nix/store/[a-z0-9]*-", "", path)


def mib(n):
    return n / 1048576


def main():
    info, top = parse_args(sys.argv)
    paths, nar, refs = load_graph(info)
    reach = make_reach(refs)

    units = [p for p in paths if re.search(r"-unit-.*\.(service|socket|timer)$", p)]
    farms = [
        p
        for p in paths
        if re.search(r"-(home-manager-path|home-manager-files|system-path)$", p)
    ]
    all_branches = units + farms

    # Drop ancestors: keep only branches no other branch can reach, so a parent
    # cannot swallow its children's bytes into "shared".
    minimal = sorted(
        b for b in all_branches if not any(o != b and b in reach(o) for o in all_branches)
    )
    if not minimal:
        sys.exit("no branches found - is this a NixOS closure-info store path?")

    owners = collections.defaultdict(set)
    for branch in minimal:
        for path in reach(branch):
            owners[path].add(branch)

    exclusive = {
        b: [p for p in reach(b) if owners[p] == {b}] for b in minimal
    }
    orphan = [p for p in paths if p not in owners]

    total = sum(nar.values())
    excl_total = sum(sum(nar[p] for p in v) for v in exclusive.values())
    shared = [p for p in owners if len(owners[p]) > 1]

    print(f"branches: {len(all_branches)} -> {len(minimal)} after ancestor pruning")
    print()
    print(
        f"total {total / 2**30:.1f} GiB  =  exclusive {excl_total / 2**30:.1f} GiB"
        f"  +  shared {sum(nar[p] for p in shared) / 2**30:.1f} GiB"
        f"  +  core {sum(nar[p] for p in orphan) / 2**30:.1f} GiB"
    )
    print(
        "  exclusive = removable with that one owner alone; shared = only returns"
        " when the LAST owner goes; core = no branch reaches it (kernel, initrd)"
    )
    print(f"\n== top {top} owners by EXCLUSIVE bytes ==")
    for branch, owned in sorted(
        exclusive.items(), key=lambda kv: -sum(nar[p] for p in kv[1])
    )[:top]:
        owned_bytes = sum(nar[p] for p in owned)
        if owned_bytes < 20 * 1048576:
            continue
        print(f"{mib(owned_bytes):8.1f} MiB  {name(branch)}")
        for path in sorted(owned, key=lambda x: -nar[x])[:3]:
            print(f"            {mib(nar[path]):8.1f} MiB  {name(path)}")

    print(f"\n== core, top 12 of {len(orphan)} paths ==")
    for path in sorted(orphan, key=lambda x: -nar[x])[:12]:
        print(f"{mib(nar[path]):8.1f} MiB  {name(path)}")

    system_path = [p for p in paths if p.endswith("-system-path")]
    hm_path = [p for p in paths if p.endswith("-home-manager-path")]
    if system_path and hm_path:
        both = set(refs[system_path[0]]) & set(refs[hm_path[0]])
        # NOTE: an intersection of store paths means the SAME path is listed in
        # both farms. The store dedupes, so this costs nothing - it is listed only
        # to stop anyone "fixing" it as if it were waste.
        print(
            f"\n== the same {len(both)} store paths appear in both system-path and"
            " home-manager-path (no extra bytes - the store dedupes) =="
        )
        for path in sorted(both, key=lambda x: -nar.get(x, 0))[:8]:
            print(f"{mib(nar.get(path, 0)):8.1f} MiB  {name(path)}")


if __name__ == "__main__":
    main()
