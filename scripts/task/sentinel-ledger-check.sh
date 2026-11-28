#!/usr/bin/env bash
# sentinel-ledger-check.sh — an active host may not be a missing row.
#
# The sentinel rollout's whole point (note p1-sentinel-push) is that a
# powered-off host shows `stale` in the fleet record — a host with NO row is
# the failure this gate names. A host is present when it has a line in the
# hub's ledger.jsonl (the hub's own events) or an incoming/<host>.json (what a
# peer's push leaves). The expectation set is inventory.toml: status active and
# kind nixos — the sentinel is a NixOS module, so darwin and containers are not
# asked of it.
#
# This is red until the rollout completes, deliberately: every missing name in
# the failure line is a host that has never pushed, and the only way green is a
# first contact — never a typed entry.
#
# Env: LEDGER_DIR (default /var/lib/fleet-sentinel — fixture override for the
# test), ACTIVE_JSON (precomputed inventory JSON, same override). Exit 0 =
# every active nixos host present, 1 = missing rows (named), 2 = no ledger at
# all — this is not the hub, which is a skip, not a verdict.
set -euo pipefail

# The fleet-wide probe is the hub's business: wired into checks:host it runs
# only when the checked host IS the hub — anywhere else the ledger is neither
# local nor its concern, and a skip is exit 0 so eval gates elsewhere never
# pay for a rollout they cannot influence.
if [ "${1:-}" = "--for-host" ] && [ "${2:-}" != "frieren" ]; then
  printf 'sentinel-ledger: skip (host %s is not the ledger hub)\n' "${2:-?}"
  exit 0
fi

LEDGER_DIR=${LEDGER_DIR:-/var/lib/fleet-sentinel}
[ -d "$LEDGER_DIR" ] || {
  printf 'sentinel-ledger: %s absent — not the hub, skip\n' "$LEDGER_DIR"
  exit 2
}

if [ -n "${ACTIVE_JSON:-}" ]; then
  active_json=$ACTIVE_JSON
else
  active_json=$(nix eval --json --builders "" ".#inventory.hosts" 2>/dev/null)
fi

set +e
missing=$(ACTIVE_HOSTS="$active_json" LEDGER_DIR="$LEDGER_DIR" python3 - <<'PY'
import json, os, sys

hosts = json.loads(os.environ["ACTIVE_HOSTS"])
ledger_dir = os.environ["LEDGER_DIR"]
ledger = os.path.join(ledger_dir, "ledger.jsonl")
incoming = os.path.join(ledger_dir, "incoming")

present = set()
if os.path.isdir(incoming):
    for name in os.listdir(incoming):
        if name.endswith(".json"):
            present.add(name[: -len(".json")])
if os.path.isfile(ledger):
    with open(ledger, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                host = json.loads(line).get("host")
            except json.JSONDecodeError:
                continue
            if host:
                present.add(host)

missing = sorted(
    name
    for name, h in hosts.items()
    if h.get("status") == "active" and h.get("kind") == "nixos" and name not in present
)
print("\n".join(missing))
PY
)
probe_rc=$?
set -e
if [ "$probe_rc" -ne 0 ]; then
  printf 'sentinel-ledger: FAIL: the inventory probe itself errored (rc %s) — a broken probe is never a pass\n' "$probe_rc" >&2
  exit 1
fi

if [ -n "$missing" ]; then
  count=$(printf '%s\n' "$missing" | grep -c .)
  printf 'sentinel-ledger: FAIL: %s active host(s) have no ledger row: %s\n' \
    "$count" "$(printf '%s' "$missing" | tr '\n' ' ')" >&2
  exit 1
fi
printf 'sentinel-ledger: PASS: every active nixos host has a ledger row\n'
