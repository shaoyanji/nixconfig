#!/usr/bin/env bash
# Boot (or stop) the frieren-canary microVM from the DECLARED runner.
#
# Everything here is derived from `.?submodules=1#nixosConfigurations.frieren-canary.config.microvm.declaredRunner`:
# the tap helpers, the virtiofsd wrappers (and therefore their socket names), and the
# hypervisor command line. Nothing is guessed.
#
# What the previous version got wrong, so the asserts below stay: it ran the
# supervisord conf's `command=` lines through `cut -d= -f2` with an unquoted
# expansion, so both shares were started as one word-split command line; it died on
# `grep` returning 1 under `set -e` with no message; it never checked root, KVM or
# the bridge before creating taps; it had no `microvm-shutdown`, so a guest that
# ignored SIGTERM left the hypervisor holding the tap; and its "sockets ready"
# message printed `${i}00ms`, which was only ever right by accident.
#
# The guest is ephemeral: this script creates the tap, starts the shares, runs the
# hypervisor in the foreground, and on exit tears all three down in reverse order.
#
#   sudo scripts/task/run-canary.sh            # boot, foreground, Ctrl-C stops
#   sudo scripts/task/run-canary.sh --stop     # stop a runner started elsewhere
#   sudo scripts/task/run-canary.sh --status   # is anything of this guest alive
set -euo pipefail

NAME="frieren-canary"
BRIDGE="brlan"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER_ATTR="microvmRunners.${NAME}"
RUN_DIR="/var/lib/microvms/${NAME}/run"
# The runner is a flake attribute, not a `./result-*` symlink in the checkout:
# a symlink in a git repo is a build artifact pretending to be a file. `nix build
# --no-link --print-out-paths` resolves it from the store (instant when cached),
# and CANARY_RUNNER lets an operator pin a path without editing this script.
RUNNER="${CANARY_RUNNER:-}"

die() {
  printf 'run-canary: %s\n' "$*" >&2
  exit 1
}

say() { printf '==> %s\n' "$*"; }

need_root() {
  [ "$(id -u)" -eq 0 ] || die "must run as root (tap creation, virtiofsd, bridge); prefix with sudo"
}

# --- runner contract ---------------------------------------------------------
# The build output is the contract: if a helper is missing, the flake changed and
# this script must not paper over it.
resolve_runner() {
  if [ -z "$RUNNER" ]; then
    # Nix's own stderr is kept: the previous version sent it to /dev/null and then
    # said only "could not resolve", which is indistinguishable between a broken
    # flake, an unset HOME (a systemd unit has none by default) and a failed build.
    local err
    err="$(mktemp)"
    if ! RUNNER="$(
      cd "$REPO_DIR" || exit 1
      NIX_CONFIG="experimental-features = nix-command flakes pipe-operators" \
        nix build --builders "" --no-link --print-out-paths ".#${RUNNER_ATTR}" 2>"$err"
    )"; then
      sed 's/^/  nix: /' "$err" >&2
      rm -f "$err"
      die "could not resolve .#${RUNNER_ATTR} — build it with: task vm:canary:build"
    fi
    rm -f "$err"
  fi
  [ -n "$RUNNER" ] || die "empty runner path for .#${RUNNER_ATTR}"
  [ -e "$RUNNER" ] || die "runner path does not exist: $RUNNER"
  RUNNER="$(readlink -f "$RUNNER")"
  [ -d "$RUNNER/bin" ] || die "runner has no bin/ directory: $RUNNER"
  for tool in tap-up tap-down virtiofsd-run microvm-run microvm-shutdown; do
    [ -x "$RUNNER/bin/${tool}" ] || die "runner is missing bin/${tool}: $RUNNER"
  done
}

# The socket names belong to the virtiofsd wrappers, not to this script, and the
# count comes from the supervisord config that actually starts them.
sockets() {
  local conf wrapper
  conf="$(grep -hoE '/nix/store/[^ ]*-virtiofsd-supervisord\.conf' "$RUNNER/bin/virtiofsd-run" | head -1)"
  [ -n "$conf" ] || die "virtiofsd-run does not name a supervisord config — runner layout changed"
  [ -r "$conf" ] || die "supervisord config listed by virtiofsd-run is missing: $conf"
  while read -r wrapper; do
    local sock
    sock="$(grep -hoE -- '--socket-path=[^ ]+' "$wrapper" | head -1 | cut -d= -f2-)"
    [ -n "$sock" ] && printf '%s\n' "$sock"
  done < <(sed -n 's/^command=\(.*virtiofsd-[^ ]*\)$/\1/p' "$conf")
}

count_sockets() {
  local want
  want="$(sockets | wc -l)"
  printf '%s' "$want"
}

sockets_ready() {
  local sock
  while read -r sock; do
    [ -S "$sock" ] || return 1
  done < <(sockets)
  return 0
}

stop_marker() {
  # supervisord runs in the foreground (nodaemon), so its pid file is ours to
  # write; the previous script wrote none and had nothing to stop.
  printf '%s\n' "${RUN_DIR}/virtiofsd.pid"
}

shutdown() {
  say "stopping guest"
  # Graceful first: the guest's own poweroff, via the control socket the runner
  # created. A guest that has not booted has no socket, so this is best-effort.
  timeout 20 "$RUNNER/bin/microvm-shutdown" >/dev/null 2>&1 || true
  # A guest that ignores the shutdown request, or a runner started by an older
  # version of this script, is still stopped: argv[0] is the guest's name.
  pkill -f '^microvm@frieren-canary' 2>/dev/null || true
  local pidfile
  pidfile="$(stop_marker)"
  if [ -s "$pidfile" ]; then
    local pid
    pid="$(cat "$pidfile")"
    # Negative pid: the process GROUP, so the virtiofsd children go with it.
    kill -TERM -- "-${pid}" 2>/dev/null || true
    rm -f "$pidfile"
  fi
  "$RUNNER/bin/tap-down" >/dev/null 2>&1 || true
  # Sockets are created in the run dir; leave none behind for the next boot.
  rm -f "$RUN_DIR"/*.sock "$RUN_DIR"/notify.vsock* 2>/dev/null || true
}

status() {
  local rc=0
  # microvm-run execs the hypervisor with `exec -a microvm@frieren-canary`, so the
  # argv[0] is the stable handle — not `cloud-hypervisor`, which every guest shares.
  if pgrep -f '^microvm@frieren-canary' >/dev/null 2>&1; then
    echo "hypervisor: running"
  else
    echo "hypervisor: not running"
    rc=1
  fi
  echo "tap ${NAME}: $(
    if ip link show microvm1 >/dev/null 2>&1; then echo present; else echo absent; fi
  )"
  return "$rc"
}

# --- modes -------------------------------------------------------------------
case "${1:-}" in
  --stop)
    need_root
    resolve_runner
    [ -d "$RUN_DIR" ] || die "no run directory: ${RUN_DIR} (never started)"
    shutdown
    say "stopped"
    exit 0
    ;;
  --status)
    resolve_runner
    status
    exit $?
    ;;
  "") ;;
  *) die "unknown argument: $1 (use --stop or --status)" ;;
esac

# --- boot --------------------------------------------------------------------
need_root
resolve_runner

[ -c /dev/kvm ] || die "no /dev/kvm: cloud-hypervisor cannot start without KVM"
ip link show "$BRIDGE" >/dev/null 2>&1 || die "bridge ${BRIDGE} is missing (modules/profiles/microvm-host.nix declares it)"

# One interface must own the guest subnet. On 2026-10-24 a stale hand-made
# `microbr` still carried 192.168.83.1/24 (nothing in this repo declares it), and
# because the kernel routes to it first every packet for the guest went to a DOWN
# bridge: the guest booted, sshd listened, and nothing ever answered — arp showed
# INCOMPLETE while the tap counters looked busy. This assert names that cause;
# without it the failure is indistinguishable from a broken guest.
bridge_cidr="$(ip -4 -o addr show dev "$BRIDGE" | awk '{print $4}' | head -1)"
[ -n "$bridge_cidr" ] || die "${BRIDGE} has no IPv4 address; the guest would have no gateway"
bridge_net="$(printf '%s' "$bridge_cidr" | cut -d/ -f1 | cut -d. -f1-3)"
while read -r iface addr _; do
  [ "$iface" = "$BRIDGE" ] && continue
  case "$addr" in
    "${bridge_net}."*)
      die "${iface} (${addr}) also holds ${bridge_net}.0/24: it steals the route to the guest. Remove that address — nothing in this repo declares it — and rerun."
      ;;
  esac
done < <(ip -o -4 addr show | awk '{print $2, $4}')

ip link set "$BRIDGE" up || die "could not bring ${BRIDGE} up"
mkdir -p "$RUN_DIR"

# The guest's identity: a host key shared over virtiofs, so sshd does not spend
# minutes generating one on every boot. Nothing declares this directory (the host
# module's tmpfiles do it for `microvm.vms`, and this canary is a standalone
# config), so a fresh host would have failed the virtiofs share with no message.
HOST_KEYS="/var/lib/microvms/${NAME}/ssh-host-keys"
install -d -m 0700 "$HOST_KEYS"
if [ ! -s "${HOST_KEYS}/ssh_host_ed25519_key" ]; then
  say "generating the guest host key (first boot)"
  ssh-keygen -q -t ed25519 -N "" -C "${NAME}" -f "${HOST_KEYS}/ssh_host_ed25519_key"
fi

cd "$RUN_DIR"

# A previous unclean exit leaves the hypervisor socket and the shares behind;
# cloud-hypervisor refuses to start on a stale socket.
shutdown
rm -f "${NAME}.sock" notify.vsock* 2>/dev/null || true

trap 'shutdown' EXIT INT TERM

say "creating tap microvm1 and attaching it to ${BRIDGE}"
"$RUNNER/bin/tap-up"
ip link set microvm1 master "$BRIDGE" || die "could not attach microvm1 to ${BRIDGE}"

# setsid: supervisord becomes a process-group leader, so the teardown above can
# signal the group rather than hunting for virtiofsd by name.
say "starting virtiofsd shares (supervised)"
setsid "$RUNNER/bin/virtiofsd-run" >"${RUN_DIR}/virtiofsd.log" 2>&1 &
echo "$!" >"$(stop_marker)"

waited=0
want="$(count_sockets)"
while ! sockets_ready; do
  [ "$waited" -ge 20 ] && {
    {
      echo "  cwd: $(pwd)"
      echo "  expected ${want} socket(s):"
      sockets | sed 's/^/    /'
      echo "  present:"
      # shellcheck disable=SC2012 # socket names are generated, never user input
      ls -l ./*.sock 2>/dev/null | sed 's/^/    /' || echo "    (none)"
      echo "  supervisord:"
      tail -6 "${RUN_DIR}/supervisord.log" 2>/dev/null | sed 's/^/    /' || true
    } >&2
    die "${want} virtiofsd socket(s) not ready after 20 iterations"
  }
  sleep 0.25
  waited=$((waited + 1))
done
say "shares ready (${want} sockets)"

say "starting cloud-hypervisor (${NAME})"
"$RUNNER/bin/microvm-run"
