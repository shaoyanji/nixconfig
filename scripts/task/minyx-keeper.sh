#!/usr/bin/env bash
# Keep minyx's deployed configuration equal to main.
#
# delphi runs this because it is the board's declared builder (inventory
# `builder = "delphi"`): minyx is a 1 GiB Pi 3B where a `nix-shell -p` is slower
# than the LAN closure copy, and the fleet's x86 hosts cannot build aarch64 at
# all. The unit lives in hosts/delphi/minyx-keeper.nix; `task infra:minyx:keep`
# runs this same file.
#
# Deliberate choices, each of which has already bitten this fleet:
#   - ssh is LAN-only, BatchMode, short timeout. An unattended unit must fail,
#     never block: the tailnet path has hung on an interactive prompt before.
#   - `--builders ""`: a keeper must not spend nixbuild.net budget as a side
#     effect of looking [[flake/policies.nix]].
#   - No automatic rollback. Rollback on this board is a reflash (its runbook),
#     so the guard is build-then-switch plus a post-check that fails loudly.
#   - Nothing but the deployed rev is written on success, so the next run is a
#     no-op rather than a nightly rebuild.
#
# Vars: REPO, TARGET, HOST, STATE_DIR, DRY=1 (report only).
set -euo pipefail

REPO="${REPO:-$HOME/Documents/nixconfig}"
TARGET="${TARGET:-devji@192.168.3.3}"
HOST="${HOST:-minyx}"
STATE_DIR="${STATE_DIR:-/var/lib/minyx-keeper}"
DRY="${DRY:-0}"

REV_FILE="$STATE_DIR/deployed-rev"
STATUS_FILE="$STATE_DIR/status"

# frieren's autoUpgrade owns 04:00 and the fleet keeps 03:00-05:30 clear of
# top-level work. The timer is at 06:15; this is the belt to its braces.
WINDOW_START="${WINDOW_START:-0300}"
WINDOW_END="${WINDOW_END:-0530}"

now=$(date +%H%M)
if [ "$now" -ge "$WINDOW_START" ] && [ "$now" -le "$WINDOW_END" ]; then
  echo "minyx-keeper: inside the ${WINDOW_START}-${WINDOW_END} window; not starting work"
  exit 0
fi

# Bookkeeping must never decide the outcome: a run that deployed correctly is a
# success even if it could not write its own status line.
say() {
  printf 'minyx-keeper: %s\n' "$*"
  if ! { mkdir -p "$STATE_DIR" && printf '%s %s\n' "$(date -Is)" "$*" >"$STATUS_FILE"; } 2>/dev/null; then
    :
  fi
}

cd "$REPO" || {
  echo "minyx-keeper: no checkout at $REPO" >&2
  exit 1
}

git fetch --quiet origin main
want=$(git rev-parse origin/main)
have=$(cat "$REV_FILE" 2>/dev/null || true)

if [ "$want" = "$have" ]; then
  say "current ($want); nothing to do"
  exit 0
fi

# Ownership is declared, not assumed: only the named builder deploys this host.
declared=$(nix eval --raw ".#inventory.hosts.${HOST}.builder" 2>/dev/null || true)
me=$(hostname)
if [ -n "$declared" ] && [ "$declared" != "$me" ]; then
  echo "minyx-keeper: inventory names '$declared' as $HOST's builder, not '$me'" >&2
  exit 1
fi

say "behind: deployed ${have:-<none>} -> main $want"

if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$TARGET" true 2>/dev/null; then
  echo "minyx-keeper: $TARGET is unreachable over the LAN — the failover member is not being updated" >&2
  exit 1
fi

if [ "$DRY" = "1" ]; then
  say "DRY=1: would build $want and push it to $TARGET"
  exit 0
fi

nixos-rebuild switch \
  --flake ".#${HOST}" \
  --target-host "$TARGET" \
  --use-remote-sudo \
  --builders "" \
  -L

# A switch that reports success while leaving the resolver dead is the failure
# this post-check exists to catch: both units fail quietly otherwise.
ssh -o BatchMode=yes -o ConnectTimeout=8 "$TARGET" \
  'systemctl is-active --quiet blocky && systemctl is-active --quiet keepalived'
answer=$(dig +short +time=3 +tries=1 "@${TARGET#*@}" frieren.lan | head -1)
if [ -z "$answer" ]; then
  echo "minyx-keeper: $HOST is up but does not answer the zone" >&2
  exit 1
fi

if ! { mkdir -p "$STATE_DIR" && printf '%s\n' "$want" >"$REV_FILE"; } 2>/dev/null; then
  echo "minyx-keeper: could not record $REV_FILE — the next run will redeploy $want" >&2
fi
say "deployed $want; zone answers $answer"
