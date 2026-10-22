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
# TWO REASONS TO BOOT, AND ONLY ONE OF THEM IS FREE HERE
#   hygiene  any host, because a change reaches it. Belongs in CI: ~1 min on a
#            runner with /dev/kvm, ~8 min of a core under TCG.
#   self     the machine you are ABOUT TO SWITCH, because nobody can diagnose
#            its initrd from outside: a bad handoff is a box that never comes
#            back, and this is the only pre-flight that runs the boot. Allowed
#            under TCG (`--self`), niced, one vCPU — see below.
#   Machines that run this by hand are also serving (delphi: public TLS on
#   delphi.bountystash.com + ssh, 2 OCPU), so an unqualified local boot spends
#   someone's page load. The KVM probe refuses before any eval or build; `--self`
#   and ALLOW_TCG=1 are the deliberate paths.
#
# BUILD BUDGET
#   `--builders ""` is not a preference. A boot test still has to build, but it
#   must never dispatch that build to nixbuild.net, which bills per second — the
#   rule is that only `dev:nixbuild:warm` spends that budget on purpose.
#
# SELF-CONTAINED ASSERTION
#   The test asserts stage-2 from the GUEST SERIAL CONSOLE, not the driver's
#   backdoor shell: the shell has a hard 10 x 30 s connect budget from QEMU start,
#   and under TCG a full host takes minutes. The console line
#   `Reached target Multi-User System` is printed by stage-2 systemd only — the
#   initrd reaches `Initrd Default Target`.
#
# USAGE
#   boot-check.sh --host NAME [--arch ARCH] [--timeout SECONDS]
#   boot-check.sh --self [--timeout SECONDS]     the local host, TCG allowed
#
# COST, BECAUSE THIS GATE IS THE EXPENSIVE ONE
#   Every run prints elapsed and peak RSS (the OOM watchdog's own measurement of
#   the whole process group) and appends a one-line record to
#   `$XDG_STATE_HOME/nixconfig/boot-check.log`, then compares against the last
#   record for the same host+arch. A claim that a boot is affordable has to be a
#   number somebody can check, and a regression in cost is otherwise invisible.
#
# EXIT
#   0  booted to multi-user (or the host is preserved: nothing to check)
#   1  failed to boot or build, the host is not in the flake, or no /dev/kvm
#   2  watchdog aborted (host protected; the run stopped)
set -uo pipefail

HOST=""
ARCH=""
SELF=0
TIMEOUT=900
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --self) SELF=1; shift ;;
    *) echo "boot-check: unknown argument $1" >&2; exit 1 ;;
  esac
done

if [ "$SELF" = "1" ]; then
  # `--self` is an identity, not a permission: the exception exists because a bad
  # initrd on THIS box cannot be diagnosed from anywhere else. A remote host's
  # boot is hygiene, and hygiene does not get to spend this machine's cores.
  HERE="$(hostname -s)"
  if [ -n "$HOST" ] && [ "$HOST" != "$HERE" ]; then
    echo "boot-check: --self is for $(hostname), not '$HOST' — use --host for another machine." >&2
    exit 1
  fi
  HOST="$HERE"
fi

if [ -z "$HOST" ]; then
  cat >&2 <<'MSG'
boot-check: --host is REQUIRED and takes exactly one host.

  a boot test evaluates and builds a full host and then runs QEMU; a default set
  is the fleet-evaluation footgun checks:hosts refuses.

  task checks:boot HOST=frieren        one host, CI/anywhere with KVM
  task checks:boot:self                THIS host, before its own switch
MSG
  exit 1
fi

# KVM OR SOMETHING DELIBERATE, before the first eval: a guard placed after the
# build saves nothing when the build succeeded and the boot is what costs a core.
# `checks.policies` proves this probe precedes the first `nix build` here.
NICE=()
if [ ! -r /dev/kvm ]; then
  if [ "${ALLOW_TCG:-0}" != "1" ] && [ "$SELF" != "1" ]; then
    echo "boot-check: no usable /dev/kvm — refusing to boot a full host under TCG." >&2
    echo "  ~8 min of one core to prove what a runner proves in one, and the hosts" >&2
    echo "  that reach for this by hand are serving (delphi: public TLS + ssh, 2 OCPU)." >&2
    echo "  run it in CI:            task dev:ci:trigger:<host>   (boot-canary job)" >&2
    echo "  before THIS host's switch: task checks:boot:self" >&2
    echo "  deliberate emulation:    ALLOW_TCG=1 $(basename "$0") --host <host>" >&2
    echo "  rule: [[flake/policies.nix#boot-gate-needs-kvm]]" >&2
    exit 1
  fi
  if [ "$SELF" = "1" ]; then
    echo "boot-check: no /dev/kvm — emulated boot of $(hostname), one vCPU, below everything else in nice." >&2
  else
    echo "boot-check: /dev/kvm unusable, ALLOW_TCG=1 — emulated boot, expect minutes" >&2
  fi
  # Emulation is CPU-bound and the machine is serving; QEMU also only gets one
  # vCPU here (flake/boot-checks.nix), so the rest of the box stays responsive.
  NICE=(nice -n 19)
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
  if [ "$SELF" = "1" ]; then
    # A pre-switch boot is insurance, not a gate on coverage: a host the matrix
    # does not cover must still be switchable, with the gap said out loud.
    echo "boot-check: '$HOST' has no boot check on '$ARCH' — nothing to boot before this switch." >&2
    echo "  hostBootChecks carries active NixOS hosts only (see flake/boot-checks.nix)." >&2
    exit 0
  fi
  echo "boot-check: no boot check for '$HOST' on '$ARCH'." >&2
  echo "  hostBootChecks carries active NixOS hosts only (see flake/boot-checks.nix)." >&2
  exit 1
fi

echo "boot-check: ${HOST} (${ARCH}) — building and booting its real module graph"
log="$(mktemp -t "boot-check-${HOST}.XXXXXX.log")"

# One record per run, in state (never the repo: this is a measurement, not config).
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/nixconfig"
ledger="$state_dir/boot-check.log"

# Report the cost the watchdog measured, and the delta against the previous run of
# the same host. Called on every exit path that ran the build: a failed boot still
# spent the core, and that is the number a later run compares against.
report_cost() {
  local rc="$1" stats elapsed peak drv prev prev_e prev_p
  # The guard's result line, e.g.
  #   boot delphi   511.32s  peak  2074.3 MiB  rc=0  baseline mem=0% io=0.2%
  stats="$(grep -E '[0-9]+\.[0-9]+s  peak +[0-9]+\.[0-9]+ MiB  rc=' "$log" | tail -1)"
  if [ -z "$stats" ]; then
    echo "  cost: not measured (the watchdog printed no result line)" >&2
    echo "  log:  ${log}" >&2
    return 0
  fi
  elapsed="$(echo "$stats" | awk '{for (i = 1; i <= NF; i++) if ($i ~ /^[0-9.]+s$/) {sub(/s$/, "", $i); print $i; exit}}')"
  peak="$(echo "$stats" | awk '{for (i = 1; i <= NF; i++) if ($(i + 1) == "MiB") {print $i; exit}}')"
  # The derivation the VM test ran, read off nix's own output so the record names
  # the thing measured without a second evaluation.
  drv="$(grep -o '/nix/store/[a-z0-9]*-vm-test-run-boot-[A-Za-z0-9._-]*\.drv' "$log" | tail -1)"
  drv="${drv:-not-built}"

  prev="$(grep -F " host=${HOST} arch=${ARCH} " "$ledger" 2>/dev/null | tail -1)"
  prev_e="$(echo "$prev" | awk '{for (i = 1; i <= NF; i++) if ($i ~ /^cost_s=/) {sub(/^cost_s=/, "", $i); print $i; exit}}')"
  prev_p="$(echo "$prev" | awk '{for (i = 1; i <= NF; i++) if ($i ~ /^peak_mib=/) {sub(/^peak_mib=/, "", $i); print $i; exit}}')"

  printf '  cost: %ss wall, %s MiB peak\n' "$elapsed" "$peak" >&2
  if [ -n "$prev_e" ] && [ -n "$prev_p" ]; then
    echo "  compared to the previous ${HOST} boot ($(printf '%s' "$prev" | awk '{print $1}')):" >&2
    awk -v e="$elapsed" -v pe="$prev_e" -v p="$peak" -v pp="$prev_p" \
      'BEGIN{printf "    wall %+.1fs, peak %+.1f MiB\n", e - pe, p - pp}' >&2
  else
    echo "  no earlier ${HOST} run recorded — this one becomes the baseline" >&2
  fi
  mkdir -p "$state_dir" 2>/dev/null
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) host=${HOST} arch=${ARCH} rc=${rc} cost_s=${elapsed} peak_mib=${peak} drv=${drv}" >>"$ledger"
  echo "  record: ${ledger}" >&2
}

bash scripts/task/oom-guard.sh --timeout "$TIMEOUT" --label "boot ${HOST}" -- \
  "${NICE[@]}" nix build --no-link -L --builders "" ".#hostBootChecks.${ARCH}.${HOST}" 2>&1 | tee "$log" >&2
rc=${PIPESTATUS[0]}

case "$rc" in
  0)
    echo "boot-check: ${HOST} reached multi-user.target — stage-2 is up"
    report_cost 0
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
    report_cost 124
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
    report_cost "$rc"
    ;;
esac

echo "  full log: ${log}" >&2
echo "  boot logs are QEMU serial output; a missing stage-2 shows as a wait timeout." >&2
exit 1
