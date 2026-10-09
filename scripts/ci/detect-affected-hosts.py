#!/usr/bin/env python3
"""
detect-affected-hosts.py - Smart CI change detection based on git diff and inventory.toml.

Maps changed paths to affected active NixOS hosts to prevent frivolous CI builds.
Supports commit message directives:
  [skip ci] / [ci skip]       -> Skip all host builds
  [ci all]                   -> Build all active NixOS hosts
  [ci host1,host2]           -> Build specific active hosts
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tomllib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
INVENTORY_FILE = REPO_ROOT / "inventory.toml"

NON_BUILD_PATTERNS = [
    r"^\.agents/",
    r"^docs/",
    r"^taskfiles/",
    r"^scripts/",
    r"^\.github/",
    r"^\.gitignore$",
    r"^LICENSE$",
    r"^inventory\.toml$",
    r"^Taskfile\.yml$",
    r".*\.md$",
    r".*\.txt$",
    r"^\.sops\.yaml$",
]

SHARED_NIX_PATTERNS = [
    r"^flake\.nix$",
    r"^flake\.lock$",
    r"^flake/",
    r"^modules/",
    r"^lib/",
    r"^overlays/",
    r"^hosts/common/",
]


def load_active_nixos_hosts():
    if not INVENTORY_FILE.exists():
        return ["frieren"]
    with open(INVENTORY_FILE, "rb") as f:
        inv = tomllib.load(f)
    hosts = inv.get("hosts", {})
    return sorted([
        h for h, data in hosts.items()
        if data.get("status") == "active" and data.get("kind") == "nixos"
    ])


def run_git_cmd(cmd):
    try:
        res = subprocess.run(
            cmd,
            cwd=str(REPO_ROOT),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
        return res.stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def get_commit_message():
    return run_git_cmd(["git", "log", "-1", "--pretty=%B"])


def get_changed_files(base=None, head=None, working_tree=False):
    if working_tree:
        # Check uncommitted working tree changes (staged + unstaged)
        out = run_git_cmd(["git", "status", "--porcelain"])
        files = []
        for line in out.splitlines():
            if line:
                # Remove status prefix (e.g. " M file" or "?? file")
                path = line[3:].strip()
                if " -> " in path:
                    path = path.split(" -> ")[1].strip()
                files.append(path)
        return list(set(files))

    if not base:
        # Check against origin/main or previous commit
        if run_git_cmd(["git", "rev-parse", "--verify", "origin/main"]):
            base = "origin/main"
        else:
            base = "HEAD~1"

    if not head:
        head = "HEAD"

    # Compare base and head
    diff_out = run_git_cmd(["git", "diff", "--name-only", f"{base}...{head}"])
    if not diff_out and base != "HEAD~1":
        # Fall back to single commit diff
        diff_out = run_git_cmd(["git", "diff", "--name-only", "HEAD~1...HEAD"])

    return [f.strip() for f in diff_out.splitlines() if f.strip()]


def parse_commit_directives(msg, active_hosts):
    if not msg:
        return None, None

    # Check for skip flags
    if re.search(r"\[(skip ci|ci skip|no ci)\]", msg, re.IGNORECASE):
        return [], "Skipped via commit message directive ([skip ci])"

    # Check for build all
    if re.search(r"\[ci all\]", msg, re.IGNORECASE):
        return active_hosts, "Explicit [ci all] directive in commit message"

    # Check for specific hosts: [ci host1,host2] or [ci:host1,host2]
    match = re.search(r"\[ci[:\s]+([a-zA-Z0-9_,\s-]+)\]", msg, re.IGNORECASE)
    if match:
        requested = [h.strip() for h in match.group(1).split(",") if h.strip()]
        valid = [h for h in requested if h in active_hosts]
        if valid:
            return valid, f"Explicit host directive in commit message: {', '.join(valid)}"

    return None, None


def analyze_changed_files(files, active_hosts, shared_strategy="anchor", anchor_host="frieren"):
    if not files:
        return [], "No files changed"

    host_regex = re.compile(r"^hosts/([^/]+)/")
    non_build_regexes = [re.compile(p) for p in NON_BUILD_PATTERNS]
    shared_regexes = [re.compile(p) for p in SHARED_NIX_PATTERNS]

    affected_hosts = set()
    has_shared_changes = False
    unmatched_files = []

    for f in files:
        # 1. Check non-building paths
        if any(r.search(f) for r in non_build_regexes):
            continue

        # 2. Check host-specific paths
        m = host_regex.match(f)
        if m:
            host = m.group(1)
            if host in active_hosts:
                affected_hosts.add(host)
                continue
            elif host == "common":
                has_shared_changes = True
                continue
            else:
                # Preserved host or non-Nix host changed; does not trigger CI builds
                continue

        # 3. Check shared Nix paths
        if any(r.search(f) for r in shared_regexes):
            has_shared_changes = True
            continue

        # Any other Nix file (e.g. default.nix, shell.nix)
        if f.endswith(".nix"):
            has_shared_changes = True
        else:
            unmatched_files.append(f)

    if has_shared_changes:
        if shared_strategy == "all":
            return active_hosts, "Shared Nix modules modified (strategy: all active hosts)"
        elif shared_strategy == "none":
            return sorted(list(affected_hosts)), "Shared Nix modules modified (strategy: none; host-specific only)"
        else:
            # Anchor strategy: build the anchor host (frieren) plus any host-specific changes
            targets = set(affected_hosts)
            if anchor_host in active_hosts:
                targets.add(anchor_host)
            return sorted(list(targets)), f"Shared Nix modules modified (strategy: anchor to {anchor_host})"

    if affected_hosts:
        return sorted(list(affected_hosts)), f"Host-specific changes detected: {', '.join(sorted(affected_hosts))}"

    return [], "All modified files are documentation, metadata, or non-building assets"


def main():
    parser = argparse.ArgumentParser(description="Detect affected NixOS hosts for CI")
    parser.add_argument("--base", help="Git base ref (e.g. origin/main, HEAD~1)")
    parser.add_argument("--head", default="HEAD", help="Git head ref")
    parser.add_argument("--working-tree", action="store_true", help="Inspect local uncommitted changes")
    parser.add_argument("--commit-msg", help="Commit message to inspect for directives")
    parser.add_argument("--shared-strategy", choices=["anchor", "all", "none"], default="anchor",
                        help="How to handle shared module changes (default: anchor to frieren)")
    parser.add_argument("--anchor-host", default="frieren", help="Anchor host to build on shared changes")
    parser.add_argument("--format", choices=["table", "json", "names"], default="table",
                        help="Output format (default: table)")
    parser.add_argument("--ci", action="store_true",
                        help="CI mode: outputs to GITHUB_OUTPUT and JSON")

    args = parser.parse_args()

    active_hosts = load_active_nixos_hosts()
    commit_msg = args.commit_msg or get_commit_message()

    # 1. Check commit directives first
    directed_hosts, directive_reason = parse_commit_directives(commit_msg, active_hosts)
    if directed_hosts is not None:
        targets = directed_hosts
        reason = directive_reason
        files = []
    else:
        # 2. Inspect changed files
        files = get_changed_files(base=args.base, head=args.head, working_tree=args.working_tree)
        targets, reason = analyze_changed_files(
            files,
            active_hosts,
            shared_strategy=args.shared_strategy,
            anchor_host=args.anchor_host
        )

    has_machines = len(targets) > 0
    matrix = {
        "machine": targets if targets else [],
        "os": ["ubuntu-latest"]
    }

    # CI Mode output
    if args.ci:
        gh_output = os.environ.get("GITHUB_OUTPUT")
        if gh_output and os.path.exists(gh_output):
            with open(gh_output, "a", encoding="utf-8") as f:
                f.write(f"has_machines={'true' if has_machines else 'false'}\n")
                f.write(f"affected_hosts={','.join(targets)}\n")
                f.write(f"matrix={json.dumps(matrix)}\n")
                f.write(f"reason={reason}\n")
        print(json.dumps({
            "has_machines": has_machines,
            "affected_hosts": targets,
            "matrix": matrix,
            "reason": reason
        }, indent=2))
        return

    # CLI Output formats
    if args.format == "json":
        print(json.dumps({
            "has_machines": has_machines,
            "affected_hosts": targets,
            "matrix": matrix,
            "reason": reason,
            "changed_files_count": len(files)
        }, indent=2))
    elif args.format == "names":
        print(" ".join(targets))
    else:
        # Table / human readable
        print("=== CI Affected Hosts Analysis ===")
        print(f"Reason: {reason}")
        print(f"Changed files inspected: {len(files)}")
        if targets:
            print("\n🟢 Hosts to build:")
            for t in targets:
                print(f"  - {t}")
        else:
            print("\n⚪ No hosts affected (CI build will be skipped).")
        untouched = [h for h in active_hosts if h not in targets]
        if untouched:
            print(f"\nUntouched active hosts ({len(untouched)}):")
            print(f"  {', '.join(untouched)}")


if __name__ == "__main__":
    main()
