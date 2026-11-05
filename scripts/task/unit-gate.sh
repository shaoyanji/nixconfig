#!/usr/bin/env bash
# The unit-file gate: does systemd understand every unit this host's config
# would install, and can each ExecStart actually exec?
#
# Born from a switch that failed after its eval passed twice: `path = [...]`
# written inside `serviceConfig` is not a directive, so systemd dropped it and
# the unit died at exec with status 127 — and a replaced `@python@` pointed at a
# directory, status 126. `systemd-analyze verify` reports both by name:
#
#   Unknown key 'Path' in section [Service], ignoring.
#   Command /nix/store/…-python3-3.14.7-env is not executable: Is a directory
#
# What this cannot prove is that the unit RUNS; that needs a container boot and
# a store of secrets and sockets that a real host has. The switch is the proof
# of the start. This is the proof of the file.
#
# usage: unit-gate.sh [--all]     env: HOST, EVAL_TIMEOUT, ALL=1
set -o pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root" || exit 2

host=${HOST:-$(hostname)}
timeout=${EVAL_TIMEOUT:-240}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# One eval, one process, under the watchdog: config.systemd.units is the module
# system's own answer (35 s / 2.6 GiB on delphi), far more than a leaf read and
# far less than a toplevel force.
raw="$tmp/eval.out"
if ! bash scripts/task/oom-guard.sh --timeout "$timeout" -- \
  nix eval --json ".?submodules=1#nixosConfigurations.$host.config.systemd.units" \
  --apply 'us: builtins.mapAttrs (n: u: u.text) us' >"$raw" 2>"$tmp/eval.err"; then
  echo "unit-gate: $host does not evaluate — this is an eval failure, not a unit failure" >&2
  tail -5 "$tmp/eval.err" >&2
  exit 2
fi

# The watchdog prints its own result line after the JSON; the payload is the
# line that starts with a brace.
payload="$tmp/units.json"
grep -m1 '^{' "$raw" >"$payload" || {
  echo "unit-gate: the eval produced no JSON (see $tmp/eval.err)" >&2
  exit 2
}

verify="$tmp/units"
mkdir -p "$verify"
kept=0
skipped=0

# A fragment is not a unit. NixOS emits `config.systemd.units.<name>.text` for
# vendor units too, and there it holds only the override (Environment=, a
# dependency), so verifying it standalone reports "no ExecStart=" — a property
# of the fragment, not of the host. Keep the units whose text is complete and
# skip the rest; the vendor file itself is not something this repo edits.
while IFS= read -r name; do
  # Never the microVM units. delphi has no /dev/kvm and its guest test is a known
  # failure (`microvm@test_instance` cannot exec its runtime paths); loading that
  # test into a gate is how it gets started again. Nothing here starts a unit,
  # and nothing here reads these at all.
  case "$name" in
    microvm*)
      skipped=$((skipped + 1))
      continue
      ;;
  esac
  jq -r --arg n "$name" '.[$n]' "$payload" >"$verify/$name"
  complete=1
  case "$name" in
    *.service) grep -qE '^(ExecStart|ExecStop|SuccessAction)=' "$verify/$name" || complete=0 ;;
    *.socket) grep -qE '^Listen' "$verify/$name" || complete=0 ;;
    *.timer) grep -qE '^(OnCalendar|OnBootSec|OnStartupSec|OnUnitActiveSec|OnUnitInactiveSec)=' "$verify/$name" || complete=0 ;;
  esac
  if [ "$complete" = 1 ]; then
    kept=$((kept + 1))
  else
    rm -f "$verify/$name"
    skipped=$((skipped + 1))
  fi
done < <(jq -r 'keys[]' "$payload")

# One invocation, so units resolve each other's dependencies. `Cannot add
# dependency job` is what a dependency missing from this set looks like — the
# host has it, this directory does not — so it is not a finding.
diag="$tmp/verify.out"
timeout 120 systemd-analyze verify "$verify"/* >"$diag" 2>&1
fixture_rc=$?

problems=0
warnings=0
findings="$tmp/findings"
: >"$findings"

# Paths in a finding are this run's temp dir; the unit name is what a reader
# needs, so it is what gets printed.
short() { sed -E "s#^$verify/##" <<<"$1"; }

while IFS= read -r line; do
  [ -n "$line" ] || continue
  line=$(short "$line")
  # Anything still carrying a path is a unit already installed on this host
  # (`/etc/systemd/system/tika.service`), which verify loaded as a dependency.
  # The pending config is what this gate judges; the running one is the old
  # generation and is fixed by the switch that realises this set.
  case "$line" in
    /*) continue ;;
  esac
  message=${line#*: }
  message=${message#: }
  case "$message" in
    *"Cannot add dependency job"* | *"Can't show "* | *"(man)"* | *"Unknown assignment"*)
      continue
      ;;
    # A store path this generation has not built yet, or a templated instance's
    # path that is created at runtime (`microvm@<name>`): neither is a unit-file
    # fault, and `nixos-rebuild` is what realizes or creates them.
    *"is not executable: No such file or directory"*)
      warnings=$((warnings + 1))
      printf 'warn  %s\n' "$line" >>"$findings"
      continue
      ;;
    # Known upstream, not ours to move: nixpkgs sets `ConditionFileNotEmpty`
    # inside serviceConfig (pihole-ftl.nix:414) where systemd ignores it, and
    # hosts/frieren/dns.nix already carries the workaround for the consequence.
    # Printed as a warning so it cannot disappear silently.
    *"Unknown key 'ConditionFileNotEmpty'"*)
      case "$line" in
        pihole-ftl*)
          warnings=$((warnings + 1))
          printf 'warn  %s (upstream: nixpkgs pihole-ftl.nix:414)\n' "$line" >>"$findings"
          continue
          ;;
      esac
      ;;
  esac
  case "$message" in
    "Unknown key "* | "Unknown section"* | "Unknown lvalue"* | *"is not executable"* | "Failed to parse"* | "Invalid "* | *"has no ExecStart"* | *"not absolute"*)
      problems=$((problems + 1))
      printf 'FAIL  %s\n' "$line" >>"$findings"
      ;;
    *)
      warnings=$((warnings + 1))
      printf 'warn  %s\n' "$line" >>"$findings"
      ;;
  esac
done <"$diag"

cat "$findings" 2>/dev/null

printf 'unit-gate: %s — %s unit(s) verified, %s fragment(s) skipped, %s problem(s), %s warning(s)\n' \
  "$host" "$kept" "$skipped" "$problems" "$warnings"

if [ "$problems" -gt 0 ]; then
  exit 1
fi
# verify exits 1 whenever it ignored anything at all, so its status is not the
# verdict; the findings above are.
[ "$fixture_rc" -le 1 ] || exit 2
exit 0
