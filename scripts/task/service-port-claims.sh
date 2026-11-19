#!/usr/bin/env bash
# A service record's `port` must be a port its host's prose already states.
#
# `software.services` is compiled, `software.key_services` is what a human wrote.
# A record may carry a port the prose never mentions only when the prose is wrong
# or the record was guessed; either way the two disagree, and the compiled map is
# the one an agent trusts. This gate makes that disagreement loud.
#
# It checks ONE direction on purpose: a port in the prose with no record is often a
# sub-component (dsh-web on loopback :3080) rather than a service, so that side is
# reported by nobody and cannot fail. `checks:ports` remains the liveness half for
# the local host; this gate is static and runs anywhere.
#
# `INVENTORY=` overrides the file (a negative-control fixture).
# Exit: 0 every ported record agrees, 1 a disagreement, 2 the gate cannot run or
# has nothing to check (a gate that proves nothing is a failure, not a pass).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
inv=${INVENTORY:-inventory.toml}

for t in yq jq; do
  command -v "$t" >/dev/null 2>&1 || {
    echo "service-port-claims: $t not on PATH" >&2
    exit 2
  }
done
[ -f "$inv" ] || {
  echo "service-port-claims: cannot read $inv" >&2
  exit 2
}

hosts=$(yq -p toml -o json '.hosts' "$inv" 2>/dev/null) || {
  echo "service-port-claims: $inv is not valid TOML" >&2
  exit 2
}

rows=$(jq -r '
  to_entries[] | .key as $h
  | (.value.software.services // [])[]
  | select(.port != null)
  | [$h, .name, (.port | tostring)] | @tsv
' <<<"$hosts")

if [ -z "$rows" ]; then
  echo "service-port-claims: no ported service records in $inv" >&2
  exit 2
fi

fail=0
n=0
while IFS=$'\t' read -r host name port; do
  [ -n "$host" ] || continue
  n=$((n + 1))
  text=$(jq -r --arg h "$host" '.[$h].software.key_services // [] | join(" ")' <<<"$hosts")
  if [ -z "$text" ]; then
    echo "FAIL $host/$name: record claims :${port} but the host has no prose"
    fail=1
    continue
  fi
  # Boundaries matter: :8443 must not satisfy a record saying 443.
  if ! printf '%s' "$text" | grep -Eq "(^|[^0-9])${port}([^0-9]|$)"; then
    echo "FAIL $host/$name: record claims :${port}; prose does not state it"
    fail=1
  fi
done <<<"$rows"

if [ "$fail" -ne 0 ]; then
  printf '\n%d ported service records checked; the prose is the other half.\n' "$n"
  exit 1
fi

printf 'PASS: %d ported service records agree with their host prose.\n' "$n"
