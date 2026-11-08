#!/usr/bin/env python3
"""Derivation equality: the gate that proves a refactor changed nothing.

A rename, a recomposition, a moved module — those may not change behaviour, so
they may not change a host's `hostChecks` derivation or its config fingerprint.
Review cannot prove that; a hash can, for a few minutes of evaluation.

    drv-equality.py snapshot [--out FILE]     write the baseline
    drv-equality.py compare  [--out FILE]     re-evaluate, diff, exit 1 on drift

One host per nix process, each under `oom-guard.sh`, because the rule that makes
`checks:host` safe applies here too. A host that already fails to evaluate is
compared by its ERROR TEXT: a pre-existing break is not this run's regression,
but a new one is.

The fingerprint is the secondary proof and the one that survives a moved source
path: assertion count, systemd unit names, /etc names, users, hostname and
state version, hashed. It is deliberately cheap — no package names, because
forcing them instantiates a package graph the gate does not need.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time

# A pre-existing error (cassini's `systemd` on darwin) must compare equal across
# revisions, and its message carries the source store path, which changes with
# every commit. Normalise the path, keep the sentence.
STORE = re.compile(r"/nix/store/[a-z0-9]{32}-[^\s:'\"]*")

ROOT = subprocess.run(
    ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True
).stdout.strip()
FLAKE = f"git+file://{ROOT}?submodules=1"
CACHE = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
DEFAULT_OUT = os.path.join(CACHE, "nixconfig", "drv-baseline.json")
HOST_TIMEOUT = os.environ.get("TIMEOUT", "240")

KIND_ATTR = {
    "nixos": "nixosConfigurations",
    "darwin": "darwinConfigurations",
    "home": "homeConfigurations",
}


def nix_eval(expr, timeout=60):
    r = subprocess.run(
        ["nix", "eval", "--json", "--impure", "--expr", expr],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    if r.returncode != 0:
        return None, r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "eval failed"
    return json.loads(r.stdout), None


def registry():
    """Every configuration the inventory says this flake builds."""
    data, err = nix_eval(
        f'let f = builtins.getFlake "{FLAKE}"; in f.inventory.hosts', timeout=120
    )
    if data is None:
        sys.exit(f"drv-equality: cannot read the registry: {err}")
    only = os.environ.get("HOSTS", "").split()
    hosts = []
    for name, h in sorted(data.items()):
        if not h.get("flake", True) or h.get("kind") not in KIND_ATTR:
            continue
        if only and name not in only:
            continue
        hosts.append((name, h["kind"], h.get("arch") or h.get("system") or "", h.get("status", "")))
    return hosts


# DEEP=1 replaces the pair with the one complete instrument: the toplevel
# derivation. Any config change that can matter changes it. It is also the
# >120 s force the repo forbids as a routine step, so it is opt-in.
EXPR = """
let
  f = builtins.getFlake "{flake}";
  cfg = f.{attr}.{host}.config;
in {{
  drv =
    if {deep} then {deep_attr}
    else f.hostChecks.{system}.{host}.drvPath or null;
  fp = builtins.hashString "sha256" (builtins.toJSON {{
    assertions = builtins.length (cfg.assertions or []);
    services = builtins.attrNames (cfg.systemd.services or {{}});
    timers = builtins.attrNames (cfg.systemd.timers or {{}});
    etc = builtins.attrNames (cfg.environment.etc or {{}});
    users = builtins.attrNames (cfg.users.users or {{}});
    vars =
      (cfg.environment.sessionVariables or {{}})
      // (cfg.home.sessionVariables or {{}})
      // (cfg.environment.variables or {{}});
    ports = cfg.networking.firewall.allowedTCPPorts or [];
    timeZone = cfg.time.timeZone or null;
    hostname = cfg.networking.hostName or null;
    stateVersion =
      if cfg ? system && cfg.system ? stateVersion then cfg.system.stateVersion
      else if cfg ? home && cfg.home ? stateVersion then cfg.home.stateVersion
      else null;
  }});
}}
"""


# A standalone home-manager config has no system build; its activation package
# is `home.path`. Both are the complete instrument for their kind.
DEEP_ATTR = {
    "nixos": "cfg.system.build.toplevel.drvPath",
    "darwin": "cfg.system.build.toplevel.drvPath",
    "home": "cfg.home.path.drvPath",
}


def probe(name, kind, system):
    deep = "true" if os.environ.get("DEEP") == "1" else "false"
    expr = EXPR.format(
        flake=FLAKE,
        attr=KIND_ATTR[kind],
        host=name,
        system=system,
        deep=deep,
        deep_attr=DEEP_ATTR[kind],
    )
    cmd = [
        "bash",
        "scripts/task/oom-guard.sh",
        "--timeout",
        HOST_TIMEOUT,
        "--label",
        f"drv-equality {name}",
        "--",
        "nix",
        "eval",
        "--json",
        "--impure",
        "--expr",
        expr,
    ]
    started = time.time()
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    elapsed = round(time.time() - started, 2)
    payload = None
    for line in r.stdout.splitlines():
        line = line.strip()
        if line.startswith("{") and line.endswith("}"):
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                pass
    if payload is not None and r.returncode == 0:
        payload["seconds"] = elapsed
        return payload
    lines = [l.strip() for l in (r.stderr or r.stdout).splitlines() if l.strip()]
    # The `error:` line is the stable one; the line after it is often a
    # "did you mean" suggestion and the lines before it are trace frames.
    idx = next((i for i, l in enumerate(lines) if l.startswith("error:")), None)
    if idx is None:
        err = lines[-1] if lines else f"exit {r.returncode}"
    elif lines[idx] == "error:" and idx + 1 < len(lines):
        # nix prints the banner alone when the message is a multi-line trace.
        err = "error: " + lines[idx + 1]
    else:
        err = lines[idx]
    return {"error": STORE.sub("<store>", err)[:300], "seconds": elapsed}


def collect():
    state = {}
    hosts = registry()
    print(f"drv-equality: {len(hosts)} configuration(s)", file=sys.stderr)
    for i, (name, kind, system, status) in enumerate(hosts, 1):
        rec = probe(name, kind, system)
        state[name] = {"kind": kind, "system": system, "status": status, **rec}
        if "error" in rec:
            mark = "ERROR"
        else:
            mark = (rec.get("drv") or "no-drv")[-12:]
        print(
            f"  [{i}/{len(hosts)}] {name:14} {mark:14} {rec['seconds']:6.2f}s",
            file=sys.stderr,
        )
    return state


def load(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        sys.exit(
            f"drv-equality: no baseline at {path}\n"
            "  run `task checks:drv-equality MODE=snapshot` before the refactor."
        )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["snapshot", "compare", "show"], nargs="?", default="compare")
    ap.add_argument("--out", default=os.environ.get("OUT") or DEFAULT_OUT)
    args = ap.parse_args()

    hour = time.localtime().tm_hour
    if hour in (3, 4, 5) and os.environ.get("FORCE") != "1":
        print("drv-equality: inside the 03:00-05:30 eval window — set FORCE=1 to override")
        return 0

    if args.mode == "snapshot":
        state = collect()
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w") as fh:
            json.dump(state, fh, indent=1, sort_keys=True)
        bad = [n for n, v in state.items() if "error" in v]
        print(f"drv-equality: baseline written to {args.out} ({len(state)} hosts)")
        for n in bad:
            print(f"  note: {n} does not evaluate (recorded as its error text)")
        return 0

    if args.mode == "show":
        print(json.dumps(collect(), indent=1, sort_keys=True))
        return 0

    base = load(args.out)
    now = collect()

    changed, appeared, vanished, same, were_broken = [], [], [], 0, []
    for name, cur in now.items():
        old = base.get(name)
        if old is None:
            appeared.append(name)
            continue
        if "error" in old and "error" in cur:
            if old["error"] != cur["error"]:
                changed.append((name, "error text", old["error"], cur["error"]))
            else:
                were_broken.append(name)
            continue
        if ("error" in old) != ("error" in cur):
            changed.append(
                (name, "error state", old.get("error", "ok"), cur.get("error", "ok"))
            )
            continue
        if old.get("drv") != cur.get("drv") or old.get("fp") != cur.get("fp"):
            field = "drv" if old.get("drv") != cur.get("drv") else "fp"
            label = "derivation" if field == "drv" else "fingerprint"
            changed.append((name, label, old.get(field), cur.get(field)))
        else:
            same += 1
    only = os.environ.get("HOSTS", "").split()
    vanished = [n for n in base if n not in now and (not only or n in only)]
    appeared = [n for n in appeared if not only or n in only]

    for name, field, was, nowv in changed:
        print(f"CHANGED {name}: {field}\n  was {was}\n  now {nowv}")
    for name in appeared:
        print(f"NEW     {name}: not in the baseline")
    for name in vanished:
        print(f"GONE    {name}: in the baseline, not in the registry")
    if were_broken:
        print(f"(unchanged errors, not this run's regression: {', '.join(were_broken)})")

    if changed or appeared or vanished:
        print(
            f"\ndrv-equality: {len(changed) + len(appeared) + len(vanished)} difference(s), "
            f"{same} identical — a refactor must change none."
        )
        return 1
    print(f"drv-equality: {same} host(s) identical to the baseline")
    return 0


if __name__ == "__main__":
    sys.exit(main())
