#!/usr/bin/env bash
# host-check-sweep.sh — run the per-host gate over a NAMED SET of hosts, ONE HOST
# AT A TIME, under the OOM watchdog.
#
# THERE IS NO FLEET DEFAULT, AND NO WAY TO ASK FOR "EVERY HOST".
#
# That is deliberate. A task whose default is 21-27 evaluations is precisely the
# footgun that was SIGKILLed at 6078.5 MiB / exit 137 on 2026-10-15 (nix flake check
# forces every flake output in ONE process), and shipping it in the Taskfile hands it
# to every agent that reads the contract — an agent will run a default. Name the
# hosts you mean, or let CI fan the fleet out over runners, where each host gets its
# own machine:
#
#   one host        task checks:host HOST=frieren
#   a named set     task checks:hosts HOSTS="frieren mtfuji"
#   the whole fleet CI — .github/workflows/nixcachix.yml, one host per runner
#
# Per invocation: a fresh nix process and a fresh watchdog, so peak memory is ONE
# host (~300-720 MiB measured) and the run stops on pressure instead of taking the
# host down.
#
# TWO MODES (they answer different questions):
#   build   realises hostChecks.<arch>.<host> — cached, substitutable, one host per
#           attr. CI's path.
#   eval    evaluates <kind>Configurations.<host>.config — module system, EVERY
#           assertion (throws on the first failure, so a broken host FAILS and the
#           message names what broke) and the compiled registry. ARCH-INDEPENDENT
#           (nothing is built), so it is the only way to check aarch64 and darwin
#           hosts from this machine. 1.4-8.6 s / ~290-700 MiB per host.
#
# WHO BUILDS IN "build" MODE — three flags, one question each:
#   (default)     --builders ""              compile the artifact here, but this
#                                            check can NEVER spend remote build
#                                            seconds (the rule in AGENTS.md: a
#                                            check must not be able to spend
#                                            budget). This is the normal gate.
#   STRICT=1      --max-jobs 0 --builders "" substitute or FAIL — "is this host
#                                            actually warmed / does CI cover it?"
#   OFFLOAD=1     --max-jobs 0 + /etc/nix/machines: hand the derivation to
#                                            nixbuild.net deliberately.
#
# WHERE THE COST ACTUALLY IS, because it decides what offloading can buy: the
# hostCheck derivation is a three-line `runCommand` that echoes a summary — its
# BUILD is free. The 6-13 s and ~700-960 MiB are pure EVALUATION (module system +
# every assertion), and nixbuild does not evaluate: it only runs a derivation you
# already evaluated. So no flag here moves the expensive half off this machine.
# What offloading does buy is the OTHER gate — `nixosConfigurations.<host>`, the
# real closure, via `task dev:nixbuild:warm` / `task dev:ci:trigger:<host>`.
# `--builders ""` here exists so this gate can never drift into doing that.
#
# USAGE
#   host-check-sweep.sh --hosts "a b c" [--mode build|eval] [--arch ARCH]
#                       [--timeout SECONDS] [--flake REF]
#
# --arch defaults to EACH HOST'S OWN arch, read from the compiled registry (one
# 0.2 s attr read, no host evaluation), not to the machine running this script.
# It used to default to x86_64-linux, which made the gate unrunnable on the one
# host that needs it most: `checks:host HOST=minyx` from delphi (aarch64) asked
# for hostChecks.x86_64-linux.minyx, an attribute that does not exist. Pass
# --arch to override; the x86_64 fleet never has to.
#
# --flake REF gates REF instead of the local tree (default "."). The nightly
# drift sweep passes github:shaoyanji/nixconfig so it reports what systemd.
# autoUpgrade will actually install, never a dirty local checkout.

#
# EXIT
#   0  every named host passed
#   1  a host FAILED, or --hosts was not given (names the hosts)
#   2  the watchdog aborted (host protected; the run stopped)
set -uo pipefail

MODE="build"
ARCH=""
TIMEOUT=120
HOSTS=""
REF="."
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --hosts) HOSTS="$2"; shift 2 ;;
    --flake) REF="$2"; shift 2 ;;
    *) echo "host-check-sweep: unknown argument $1" >&2; exit 1 ;;
  esac
done

case "$MODE" in build | eval) ;; *) echo "host-check-sweep: --mode must be build or eval" >&2; exit 1 ;; esac

if [ -z "${HOSTS// /}" ]; then
  cat >&2 <<'MSG'
host-check-sweep: --hosts is REQUIRED. There is no fleet-wide default, by design:
  a default set of 21-27 host evaluations is the footgun that was SIGKILLed at
  6078.5 MiB (exit 137) on 2026-10-15, and a Taskfile default hands it to every
  agent that reads the contract.

  one host        task checks:host HOST=frieren
  a named set     task checks:hosts HOSTS="frieren mtfuji"
  the whole fleet CI — one host per runner (.github/workflows/nixcachix.yml)
MSG
  exit 1
fi

# In eval mode we need each host's KIND to pick the right config set. Resolve it from
# the flake's output attr NAMES only — three cheap reads (0.2 s, no host evaluation),
# never by evaluating a host.
KINDS=""
if [ "$MODE" = eval ]; then
  NAMES=""
  for pair in "nixos nixosConfigurations" "darwin darwinConfigurations" "home homeConfigurations"; do
    set -- $pair
    n=$(timeout 30 nix eval --json "${REF}#$2" --apply 'builtins.attrNames' 2>/dev/null | tr -d '[]"' | tr ',' ' ')
    NAMES="${NAMES}
$(for h in $n; do [ -n "$h" ] && echo "$1 $h"; done)"
  done
  for h in $HOSTS; do
    kind=$(echo "$NAMES" | awk -v h="$h" '$2==h{print $1; exit}')
    if [ -z "$kind" ]; then
      echo "host-check-sweep: '$h' is not a host in this flake (nixos/darwin/home)" >&2
      exit 1
    fi
    KINDS="${KINDS}
$kind $h"
  done
else
  for h in $HOSTS; do KINDS="${KINDS}
nixos $h"; done
fi

count=$(echo "$HOSTS" | wc -w)
echo "host-check-sweep: ${count} named host(s), mode=${MODE}, arch=${ARCH:-per-host}, one process each, watchdog every 10s"
echo

failed=""
i=0
while read -r kind host; do
  [ -n "${host:-}" ] || continue
  i=$((i + 1))
  printf '[%d/%d] ' "$i" "$count"
  if [ "$MODE" = build ]; then
    # hostChecks is keyed by the HOST's arch, so an unset --arch has to be read
    # from the registry rather than assumed from `uname`. A bare
    # /run/current-system check would also be wrong: this gate must be callable
    # for a host whose arch differs from the caller's.
    host_arch="$ARCH"
    if [ -z "$host_arch" ]; then
      host_arch="$(timeout 30 nix eval --raw "${REF}?submodules=1#inventory.hosts.\"${host}\".arch" 2>/dev/null || true)"
      host_arch="${host_arch:-x86_64-linux}"
    fi
    build_flags=(--builders "")
    if [ "${OFFLOAD:-0}" = "1" ]; then
      # /etc/nix/machines supplies the builders; nothing may run locally.
      build_flags=(--max-jobs 0)
    elif [ "${STRICT:-0}" = "1" ]; then
      build_flags=(--max-jobs 0 --builders "")
    fi
    log="$(mktemp)"
    # tee on stdout, not a process substitution: PIPESTATUS gives the guard's
    # status after tee has flushed, so the classification below reads the whole log.
    bash scripts/task/oom-guard.sh --timeout "$TIMEOUT" --label "host-check ${host}" -- \
      nix build --no-link -L "${build_flags[@]}" "${REF}?submodules=1#hostChecks.${host_arch}.${host}" 2>&1 | tee "$log" >&2
    rc=${PIPESTATUS[0]}
    # A cache miss and a failed assertion both exit 1; only the first deserves the
    # warm-it advice, so classify by what nix said.
    if [ "$rc" -ne 0 ] && [ "${OFFLOAD:-0}" != "1" ] \
      && grep -qiE "don't know how to build|not substitutable|unable to download|cannot build|local builds are disabled" "$log"; then
      echo >&2
      if [ "${STRICT:-0}" = "1" ]; then
        echo "  ${host}: not in any cache (STRICT=1: substituting only, nothing may build)." >&2
      else
        echo "  ${host}: could not be built locally and no remote builder was allowed." >&2
      fi
      echo "  warm it (free, CI runner):  task dev:ci:trigger:${host}" >&2
      echo "  or hand it to nixbuild:     OFFLOAD=1 task checks:host HOST=${host}" >&2
      echo "  or compile here (default):  task checks:host HOST=${host}" >&2
    fi
    rm -f "$log"
  else
    case "$kind" in
      nixos) attr="nixosConfigurations.${host}" ;;
      darwin) attr="darwinConfigurations.${host}" ;;
      home) attr="homeConfigurations.${host}" ;;
    esac
    # The attr name is quoted because host names may contain hyphens
    # (frieren-canary) and bare Nix attr names may not.
    EXPR=$(printf 'c: let bad = builtins.filter (a: !a.assertion) c.assertions; in if bad != [] then throw ("assertion(s) failed: " + builtins.concatStringsSep " | " (map (a: a.message) bad)) else { hostname = c.fleet.inventory.hosts."%s".hostname; registry = builtins.length (builtins.attrNames c.fleet.inventory.hosts); assertions = builtins.length c.assertions; }' "$host")
    bash scripts/task/oom-guard.sh --timeout "$TIMEOUT" --label "eval ${host}" -- \
      nix eval --json "${REF}?submodules=1#${attr}.config" --apply "$EXPR"
    rc=$?
  fi
  case "$rc" in
    0) : ;;
    2)
      echo
      echo "ABORTED at ${host} after $((i - 1)) clean host(s) — host protected, run stopped." >&2
      exit 2
      ;;
    *) failed="${failed} ${host}" ;;
  esac
done <<<"$KINDS"

echo
if [ -n "$failed" ]; then
  echo "FAILED:${failed}" >&2
  exit 1
fi
echo "all ${count} named host(s): module system + assertions pass, compiled inventory resolves"
