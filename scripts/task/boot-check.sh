#!/usr/bin/env bash
# boot-check.sh — boot ONE host's real module graph in a VM and fail unless
# stage-1 hands off to stage-2.
#
# WHY THIS GATE EXISTS
#   `checks:host` proves the module system evaluates and every assertion holds.
#   CI builds the closure. A deploy proves `switch-to-configuration` ran. None of
#   them proves the machine reaches userspace — and that is the failure that
#   reached production: netbook generation 50 booted a 26.11 systemd-initrd that
#   never reached stage-2 (blank console, no journal entry for the boot) while
#   every gate was green. The old runtime instrument, `vm:canary:*`, boots a
#   SubZeroClaw sandbox guest — a different machine with its own kernel and root
#   — so it could not fail for the host being promoted.
#
# ONE HOST, NO DEFAULT
#   A boot test evaluates and builds a full host, then runs QEMU for minutes. A
#   default set would be the same footgun `checks:hosts` refuses: an agent runs a
#   default and pays for the fleet. Name one host at a time; CI fans out over
#   runners (`.github/workflows/nixcachix.yml`, job `boot-canary`).
#
# BUILD BUDGET
#   `--builders ""` is not a preference. A boot test still has to build, but it
#   must never dispatch that build to nixbuild.net, which bills per second — the
#   rule is that only `dev:nixbuild:warm` spends that budget on purpose.
#
# NOT A PRE-SWITCH HOOK
#   Never chain this in front of a switch: it boots a VM, it does not predict the
#   host's own hardware. See flake/boot-checks.nix for what it does and does not
#   prove.
#
# SELF-CONTAINED ASSERTION
#   The test asserts stage-2 from the GUEST SERIAL CONSOLE, not the driver's
#   backdoor shell: the shell has a hard 10 x 30 s connect budget from QEMU start,
#   and a full host under TCG (this machine has no /dev/kvm) takes minutes. The
#   console line `Reached target Multi-User System` is printed by stage-2 systemd
#   only — the initrd reaches `Initrd Default Target`.
#
# USAGE
#   boot-check.sh --host NAME [--arch ARCH] [--timeout SECONDS]
#
# EXIT
#   0  booted to multi-user (or the host is preserved: nothing to check)
#   1  failed to boot or build, or the host is not in the flake
#   2  watchdog aborted (host protected; the run stopped)
set -uo pipefail

HOST=""
ARCH=""
TIMEOUT=1800
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "boot-check: unknown argument $1" >&2; exit 1 ;;
  esac
done

if [ -z "$HOST" ]; then
  cat >&2 <<'MSG'
boot-check: --host is REQUIRED and takes exactly one host.

  a boot test evaluates and builds a full host and then runs QEMU; a default set
  is the fleet-evaluation footgun checks:hosts refuses.

  task checks:boot HOST=frieren
MSG
  exit 1
fi

# Registry facts first: a preserved host must not reach an eval, a cache query or
# a build (AGENTS.md), and the arch decides which attribute set exists.
status="$(nix eval --raw ".#inventory.hosts.\"$HOST\".status" 2>/dev/null)" || {
  echo "boot-check: '$HOST' is not a host in .#inventory" >&2
  exit 1
}
if [ -z "$ARCH" ]; then
  ARCH="$(nix eval --raw ".#inventory.hosts.\"$HOST\".arch" 2>/dev/null)" || {
    echo "boot-check: could not read the compiled arch for '$HOST'" >&2
    exit 1
  }
fi

if [ "$status" != "active" ]; then
  if [ "${ALLOW_PRESERVED:-0}" != "1" ]; then
    echo "boot-check: '$HOST' is '$status' — a dormant host is not this run's regression." >&2
    echo "  preserved hosts are never check targets; ALLOW_PRESERVED=1 overrides." >&2
    exit 0
  fi
  echo "boot-check: '$HOST' is '$status'; ALLOW_PRESERVED=1, checking anyway" >&2
fi

# A missing attribute is a clearer message here than nix's own path error, and
# the lookup is cheap: attr names only, no host evaluation.
if ! nix eval --json ".#hostBootChecks.\"$ARCH\"" --apply 'builtins.attrNames' 2>/dev/null |
  tr -d '[]"' | tr ',' '\n' | grep -qx "$HOST"; then
  echo "boot-check: no boot check for '$HOST' on '$ARCH'." >&2
  echo "  hostBootChecks carries active NixOS hosts only (see flake/boot-checks.nix)." >&2
  exit 1
fi

echo "boot-check: ${HOST} (${ARCH}) — building and booting its real module graph"
log="$(mktemp -t "boot-check-${HOST}.XXXXXX.log")"
bash scripts/task/oom-guard.sh --timeout "$TIMEOUT" --label "boot ${HOST}" -- \
  nix build --no-link -L --builders "" ".#hostBootChecks.${ARCH}.${HOST}" 2>&1 | tee "$log" >&2
rc=${PIPESTATUS[0]}

case "$rc" in
  0)
    echo "boot-check: ${HOST} reached multi-user.target — stage-2 is up"
    rm -f "$log"
    exit 0
    ;;
  2)
    echo "boot-check: aborted by the watchdog (the host is protected, not the config)" >&2
    rm -f "$log"
    exit 2
    ;;
  124)
    echo "boot-check: ${HOST} exceeded ${TIMEOUT}s — no stage-2 within the budget" >&2
    ;;
  *)
    # Distinguish "the VM ran and never handed off" from "it never got that far":
    # a stage-1 that dies surfaces as the driver's wait_for_unit timeout, while a
    # config error fails before QEMU starts.
    if grep -qiE 'TimeoutError|did not reach|wait_for_unit|Shell did not start|Guest root shell' "$log"; then
      echo "boot-check: ${HOST} did NOT reach stage-2 — the boot died before userspace" >&2
    else
      echo "boot-check: ${HOST} failed before the VM booted (eval/build); see the log" >&2
    fi
    ;;
esac

echo "  full log: ${log}" >&2
echo "  boot logs are QEMU serial output; a missing stage-2 shows as a wait timeout." >&2
exit 1
