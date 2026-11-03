#!/usr/bin/env bash
# rebuild-flags.sh — the finite envelope behind every rebuild. Three axes, no more:
#
#   --builders     local | none | remote     who compiles
#   --substitutes  on | off                  may Nix fetch a path instead
#   --flakes       accept | impure           the flake acceptance posture
#
# Everything else a rebuild needs is the host, the flake ref and the action, and
# those are arguments — not flags. Before this file the same three decisions were
# spelled five ways inside `infra:switch:*` alone (`REMOTE_BUILD=1` meaning "never
# compile here", `--option max-jobs 0 --option builders ""` typed inline, `--impure`
# in one task, `--use-substitutes` in another, nothing at all in the third), so the
# rule lived in prose and the flags lived in copies.
#
# Defaults are the cheap, safe ones: local / on / accept, which render NOTHING
# because they are what Nix does anyway. A flag only appears when a decision was
# actually made.
#
# Usage
#   rebuild-flags.sh                                  # the default envelope
#   rebuild-flags.sh --builders none                  # substitute-or-fail
#   rebuild-flags.sh --builders remote --flavour nix  # dispatch deliberately
#   rebuild-flags.sh --self-test                      # every combination, checked
#
#   rebuild.sh --builders | --substitutes | --flakes  # print one axis' value
#
# Flavour is the command being dressed: `nix` (build/eval/path-info),
# `nixos-rebuild`, `darwin-rebuild`, `home-manager`. It only changes spelling.
#
# Exit: 0 ok, 2 an unknown axis value (the envelope is closed on purpose — a typo
# must not quietly become "local builders"), 1 the self-test failed.
set -euo pipefail

BUILDERS="${REBUILD_BUILDERS:-local}"
SUBSTITUTES="${REBUILD_SUBSTITUTES:-on}"
FLAKES="${REBUILD_FLAKES:-accept}"
FLAVOUR="${REBUILD_FLAVOUR:-nix}"
SELF_TEST=0

while [ $# -gt 0 ]; do
  case "$1" in
  --builders | --substitutes | --flakes | --flavour)
    [ $# -ge 2 ] || {
      echo "rebuild-flags: $1 needs a value" >&2
      exit 2
    }
    case "$1" in
    --builders) BUILDERS="$2" ;;
    --substitutes) SUBSTITUTES="$2" ;;
    --flakes) FLAKES="$2" ;;
    --flavour) FLAVOUR="$2" ;;
    esac
    shift
    ;;
  --self-test) SELF_TEST=1 ;;
  -h | --help)
    sed -n '2,32p' "$0"
    exit 0
    ;;
  *)
    echo "rebuild-flags: unknown argument: $1" >&2
    exit 2
    ;;
  esac
  shift
done

case "$BUILDERS" in local | none | remote) ;; *)
  echo "rebuild-flags: --builders must be local|none|remote (got '$BUILDERS')" >&2
  exit 2
  ;;
esac
case "$SUBSTITUTES" in on | off) ;; *)
  echo "rebuild-flags: --substitutes must be on|off (got '$SUBSTITUTES')" >&2
  exit 2
  ;;
esac
case "$FLAKES" in accept | impure) ;; *)
  echo "rebuild-flags: --flakes must be accept|impure (got '$FLAKES')" >&2
  exit 2
  ;;
esac
case "$FLAVOUR" in nix | nixos-rebuild | darwin-rebuild | home-manager) ;; *)
  echo "rebuild-flags: --flavour must be nix|nixos-rebuild|darwin-rebuild|home-manager (got '$FLAVOUR')" >&2
  exit 2
  ;;
esac

render() { # builders substitutes flakes flavour
  local b="$1" s="$2" f="$3" fl="$4" out=""

  case "$b" in
  local) ;; # the Nix config decides; saying nothing is the honest spelling
  none)
    # Substitute or fail. `max-jobs 0` alone still lets Nix dispatch to a
    # configured remote builder, which uploads the whole closure before it starts
    # — `builders ""` is what makes it a refusal instead of a relay.
    out="$out --option max-jobs 0 --option builders \"\""
    ;;
  remote)
    # Dispatch deliberately, and say NOTHING about the builders list: it comes from
    # the Nix config (`/etc/nix/machines` via distributedBuilds). `--builders` takes
    # machine specs inline — `@file` is `nix.conf` include syntax, not a value, so
    # writing one here would be a silently wrong spelling. This is the flag set the
    # offload paths already use: only local jobs are forbidden.
    out="$out --option max-jobs 0"
    ;;
  esac

  # Substitutes default ON, so only the exception is worth a flag.
  [ "$s" = "off" ] && out="$out --option substituters \"\""

  # `accept` is Nix's default posture; only impurity is a decision.
  [ "$f" = "impure" ] && out="$out --impure"

  # Flavour decides the acceptance spelling for a command that does not take
  # `--option` (home-manager) and for the two that do. Kept explicit so a new
  # flavour cannot silently drop the flag.
  case "$fl" in
  nix | nixos-rebuild | darwin-rebuild) ;;
  home-manager)
    # home-manager accepts --option too, so nothing to translate yet; the case
    # exists so an added flavour has to say what it does.
    ;;
  esac

  out="${out# }"
  printf '%s' "$out"
}

if [ "$SELF_TEST" = 1 ]; then
  # The envelope is a table, so the test is a table: every combination, rendered
  # and compared. This is the only way to know a flag spelling is right without
  # building anything, and it is what `checks:rebuild` runs.
  fail=0
  check() { # expected builders substitutes flakes
    got="$(render "$2" "$3" "$4" nix)"
    if [ "$got" = "$1" ]; then
      printf 'ok    %-8s %-3s %-6s -> %s\n' "$2" "$3" "$4" "${got:-<empty>}"
    else
      printf 'FAIL  %-8s %-3s %-6s -> %s (expected %s)\n' "$2" "$3" "$4" "${got:-<empty>}" "${1:-<empty>}"
      fail=1
    fi
  }
  echo "== the envelope, every combination =="
  check "" local on accept
  check "--impure" local on impure
  check "--option substituters \"\"" local off accept
  check "--option substituters \"\" --impure" local off impure
  check "--option max-jobs 0 --option builders \"\"" none on accept
  check "--option max-jobs 0 --option builders \"\" --impure" none on impure
  check "--option max-jobs 0 --option builders \"\" --option substituters \"\"" none off accept
  check "--option max-jobs 0 --option builders \"\" --option substituters \"\" --impure" none off impure
  check "--option max-jobs 0" remote on accept
  check "--option max-jobs 0 --impure" remote on impure
  check "--option max-jobs 0 --option substituters \"\"" remote off accept
  check "--option max-jobs 0 --option substituters \"\" --impure" remote off impure

  echo "== the envelope is closed =="
  for bad in "--builders everywhere" "--substitutes maybe" "--flakes loose" "--flavour make"; do
    # shellcheck disable=SC2086
    if "$0" $bad >/dev/null 2>&1; then
      printf 'FAIL  accepted %s\n' "$bad"
      fail=1
    else
      printf 'ok    rejected %s\n' "$bad"
    fi
  done

  echo
  if [ "$fail" = 0 ]; then
    echo "rebuild-flags: ok — 12 combinations, closed set"
  else
    echo "rebuild-flags: DRIFT — the envelope does not render what it says"
  fi
  exit "$fail"
fi

render "$BUILDERS" "$SUBSTITUTES" "$FLAKES" "$FLAVOUR"
