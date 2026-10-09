#!/usr/bin/env python3
"""
detect-affected-hosts.py - Multi-architecture CI change detection based on git diff & inventory.toml.

Maps changed paths to affected fleet hosts across all architectures and kinds (NixOS, Darwin, Home-Manager).
Automatically routes each host to its corresponding GitHub Actions runner:
  x86_64-linux   -> ubuntu-latest
  aarch64-linux  -> ubuntu-24.04-arm
  aarch64-darwin -> macos-latest

Respects 'ci = false' in inventory.toml (e.g. unfree NVIDIA 580 on stark/kellerbench
which are built on frieren NAS / local machines).

Supports commit message directives:
  [skip ci] / [ci skip]       -> Skip all host builds
  [ci all]                   -> Build all active CI-eligible hosts
  [ci host1,host2]           -> Build specific active hosts (even if excluded by default)
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

RUNNER_MAP = {
    "x86_64-linux": "ubuntu-latest",
    "aarch64-linux": "ubuntu-24.04-arm",
    "aarch64-darwin": "macos-latest",
    "x86_64-darwin": "macos-13",
}

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

# Fallback exclusion for hosts requiring unfree NVIDIA drivers built on frieren/local
DEFAULT_CI_EXCLUDED = {"stark", "kellerbench"}


def get_flake_attr(kind, name):
    if kind == "nixos":
        return f"nixosConfigurations.{name}.config.system.build.toplevel"
    elif kind == "darwin":
        return f"darwinConfigurations.{name}.config.system.build.toplevel"
    elif kind == "home":
        return f"homeConfigurations.{name}.activationPackage"
    return None


def load_fleet_hosts():
    if not INVENTORY_FILE.exists():
        fallback_host = {
            "host": "frieren",
            "kind": "nixos",
            "arch": "x86_64-linux",
            "os": "ubuntu-latest",
            "attr": "nixosConfigurations.frieren.config.system.build.toplevel"
        }
        return {"frieren": fallback_host}, {"frieren": fallback_host}, DEFAULT_CI_EXCLUDED

    with open(INVENTORY_FILE, "rb") as f:
        inv = tomllib.load(f)

    hosts = inv.get("hosts", {})
    all_nix_hosts = {}
    active_hosts = {}
    ci_excluded = set(DEFAULT_CI_EXCLUDED)

    for h, data in hosts.items():
        kind = data.get("kind", "")
        if kind not in ["nixos", "darwin", "home"]:
            continue

        arch = data.get("arch", "x86_64-linux")
        attr = get_flake_attr(kind, h)
        runner_os = RUNNER_MAP.get(arch, "ubuntu-latest")

        host_info = {
            "host": h,
            "kind": kind,
            "arch": arch,
            "os": runner_os,
            "attr": attr,
        }
        all_nix_hosts[h] = host_info

        if data.get("status") == "active":
            active_hosts[h] = host_info
            if data.get("ci") is False:
                ci_excluded.add(h)

    return all_nix_hosts, active_hosts, ci_excluded


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
        out = run_git_cmd(["git", "status", "--porcelain"])
        files = []
        for line in out.splitlines():
            if line:
                path = line[3:].strip()
                if " -> " in path:
                    path = path.split(" -> ")[1].strip()
                files.append(path)
        return list(set(files))

    if not base:
        if run_git_cmd(["git", "rev-parse", "--verify", "origin/main"]):
            base = "origin/main"
        else:
            base = "HEAD~1"

    if not head:
        head = "HEAD"

    diff_out = run_git_cmd(["git", "diff", "--name-only", f"{base}...{head}"])
    if not diff_out and base != "HEAD~1":
        diff_out = run_git_cmd(["git", "diff", "--name-only", "HEAD~1...HEAD"])

    return [f.strip() for f in diff_out.splitlines() if f.strip()]


def parse_commit_directives(msg, active_hosts):
    if not msg:
        return None, None

    if re.search(r"\[(skip ci|ci skip|no ci)\]", msg, re.IGNORECASE):
        return [], "Skipped via commit message directive ([skip ci])"

    if re.search(r"\[ci all\]", msg, re.IGNORECASE):
        return sorted(list(active_hosts.keys())), "Explicit [ci all] directive in commit message"

    match = re.search(r"\[ci[:\s]+([a-zA-Z0-9_,\s-]+)\]", msg, re.IGNORECASE)
    if match:
        requested = [h.strip() for h in match.group(1).split(",") if h.strip()]
        valid = [h for h in requested if h in active_hosts]
        if valid:
            return valid, f"Explicit host directive in commit message: {', '.join(valid)}"

    return None, None


def analyze_changed_files(files, active_hosts, all_nix_hosts, ci_excluded, shared_strategy="anchor", anchor_host="frieren"):
    if not files:
        return [], "No files changed"

    host_regex = re.compile(r"^hosts/(?:([^/]+)/|([^/]+)\.nix$)")
    non_build_regexes = [re.compile(p) for p in NON_BUILD_PATTERNS]
    shared_regexes = [re.compile(p) for p in SHARED_NIX_PATTERNS]

    affected_hosts = set()
    skipped_policy = set()
    has_shared_changes = False

    for f in files:
        if any(r.search(f) for r in non_build_regexes):
            continue

        m = host_regex.match(f)
        if m:
            host = m.group(1) or m.group(2)
            if host in active_hosts:
                if host in ci_excluded:
                    skipped_policy.add(host)
                else:
                    affected_hosts.add(host)
                continue
            elif host == "common":
                has_shared_changes = True
                continue
            elif host in all_nix_hosts:
                # Preserved host modified; ignore
                continue

        if any(r.search(f) for r in shared_regexes):
            has_shared_changes = True
            continue

        if f.endswith(".nix"):
            has_shared_changes = True

    if has_shared_changes:
        eligible_active = [h for h in active_hosts.keys() if h not in ci_excluded]
        if shared_strategy == "all":
            return sorted(eligible_active), "Shared Nix modules modified (strategy: all CI-eligible active hosts)"
        elif shared_strategy == "none":
            return sorted(list(affected_hosts)), "Shared Nix modules modified (strategy: none; host-specific only)"
        else:
            targets = set(affected_hosts)
            if anchor_host in eligible_active:
                targets.add(anchor_host)
            return sorted(list(targets)), f"Shared Nix modules modified (strategy: anchor to {anchor_host})"

    if affected_hosts:
        msg = f"Host-specific changes detected: {', '.join(sorted(affected_hosts))}"
        if skipped_policy:
            msg += f" (excluded per CI policy: {', '.join(sorted(skipped_policy))})"
        return sorted(list(affected_hosts)), msg

    if skipped_policy:
        return [], f"Changes detected for {', '.join(sorted(skipped_policy))}, but skipped per CI policy (unfree driver/ci=false)"

    return [], "All modified files are documentation, metadata, or non-building assets"


def main():
    parser = argparse.ArgumentParser(description="Detect affected fleet hosts across all architectures for CI")
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

    all_nix_hosts, active_hosts, ci_excluded = load_fleet_hosts()
    commit_msg = args.commit_msg or get_commit_message()

    directed_hosts, directive_reason = parse_commit_directives(commit_msg, active_hosts)
    if directed_hosts is not None:
        targets = directed_hosts
        reason = directive_reason
        files = []
    else:
        files = get_changed_files(base=args.base, head=args.head, working_tree=args.working_tree)
        targets, reason = analyze_changed_files(
            files,
            active_hosts,
            all_nix_hosts=all_nix_hosts,
            ci_excluded=ci_excluded,
            shared_strategy=args.shared_strategy,
            anchor_host=args.anchor_host
        )

    has_machines = len(targets) > 0
    matrix_include = [active_hosts[h] for h in targets if h in active_hosts]
    matrix = {"include": matrix_include}

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

    if args.format == "json":
        print(json.dumps({
            "has_machines": has_machines,
            "affected_hosts": targets,
            "ci_excluded_hosts": sorted(list(ci_excluded)),
            "matrix": matrix,
            "reason": reason,
            "changed_files_count": len(files)
        }, indent=2))
    elif args.format == "names":
        print(" ".join(targets))
    else:
        print("=== Multi-Architecture CI Affected Hosts Analysis ===")
        print(f"Reason: {reason}")
        print(f"Changed files inspected: {len(files)}")
        if matrix_include:
            print("\n🟢 Targets to build:")
            for item in matrix_include:
                print(f"  - {item['host']:<12} [{item['kind']:<6} | {item['arch']:<14}] -> runner: {item['os']:<16} ({item['attr']})")
        else:
            print("\n⚪ No hosts affected (CI build will be skipped).")

        excluded_active = [h for h in active_hosts if h in ci_excluded]
        if excluded_active:
            print(f"\nExcluded from CI by policy ({len(excluded_active)}):")
            print(f"  {', '.join(excluded_active)} (unfree NVIDIA driver; built on frieren/local)")

        untouched = [h for h in active_hosts if h not in targets and h not in ci_excluded]
        if untouched:
            print(f"\nUntouched active hosts ({len(untouched)}):")
            print(f"  {', '.join(untouched)}")


if __name__ == "__main__":
    main()
