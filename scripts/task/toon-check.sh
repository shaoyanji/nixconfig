#!/usr/bin/env bash
# Gate for the TOON repair contract.
#
# Two things must stay true:
#   1. the repair tool turns a wrong `[n]` into the counted one (both directions
#      are checked: a short count and an over-count, since the strict decoder
#      rejects them with different errors);
#   2. every tracked `.toon` document strict-decodes, i.e. no hand-miscounted
#      length is sitting in the tree.
#
# Nothing here needs the fleet or a host eval.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

command -v toon >/dev/null 2>&1 || {
  echo "FAIL: toon not on PATH (pkgs.llm-agents.toon)"
  exit 1
}

fail=0

check_repair() {
  local declared="$1" rows="$2" name="$3" file expected
  file="$(mktemp)"
  expected="$(mktemp)"
  {
    printf 'items[%s]{id,name}:\n' "$declared"
    printf '%s\n' "$rows"
  } >"$file"
  {
    printf 'items[%s]{id,name}:\n' "$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
    printf '%s\n' "$rows"
  } >"$expected"

  if ! bash scripts/task/toon-fix.sh "$file" >/dev/null 2>&1; then
    echo "FAIL $name: fixer rejected a repairable document" >&2
    fail=1
  elif ! cmp -s "$file" "$expected"; then
    echo "FAIL $name: length not replaced with the counted rows" >&2
    diff "$expected" "$file" | sed -n '1,6p' >&2
    fail=1
  fi
  rm -f "$file" "$expected"
}

check_repair 2 '  1,alpha
  2,beta
  3,gamma' "under-count"
check_repair 9 '  1,alpha
  2,beta' "over-count"

# The tool must refuse what it cannot count, not mangle it. Both of these were
# real: JSON decoded as TOON keeps a garbage key, and prose round-trips as a
# valid TOON string, so both used to "succeed" while changing nothing.
check_refusal() {
  local name="$1" body="$2" file before
  file="$(mktemp)"
  printf '%s\n' "$body" >"$file"
  before="$(md5sum "$file" | cut -d' ' -f1)"
  if bash scripts/task/toon-fix.sh "$file" >/dev/null 2>&1; then
    echo "FAIL $name: refused input was accepted" >&2
    fail=1
  elif [ "$before" != "$(md5sum "$file" | cut -d' ' -f1)" ]; then
    echo "FAIL $name: refused input was modified anyway" >&2
    fail=1
  fi
  rm -f "$file"
}

check_refusal "json-object" '{"a":1}'
check_refusal "plain-prose" 'this is not toon'

# The IR contract: an agent emits TOON, the machine's converter produces the
# format on disk, and the result is the same document. Proves the `yq` path the
# skill tells agents to use, instead of asserting it in prose.
check_boundary() {
  local file expected yaml
  file="$(mktemp)"
  expected="$(mktemp)"
  yaml="$(mktemp)"
  printf 'hosts[2]{name,arch}:\n  frieren,x86_64-linux\n  fern,aarch64-linux\n' >"$file"

  if ! toon -d "$file" | jq -S . >"$expected"; then
    echo "FAIL boundary: TOON did not decode to JSON" >&2
    fail=1
  fi
  if ! toon -d "$file" | yq -p json -o yaml >"$yaml"; then
    echo "FAIL boundary: TOON -> YAML conversion failed" >&2
    fail=1
  fi
  if ! yq -p yaml -o json "$yaml" | jq -S . | diff -q - "$expected" >/dev/null; then
    echo "FAIL boundary: YAML round-trip lost data" >&2
    fail=1
  fi
  rm -f "$file" "$expected" "$yaml"
}

# The same contract for the other named source format, on the real registry
# rather than a fixture: 34 hosts, nested, through the IR and back. A converter
# that silently drops a field is the failure this catches.
check_boundary_toml() {
  local before after
  before="$(mktemp)"
  after="$(mktemp)"

  if ! yq -p toml -o json inventory.toml | jq -S . >"$before"; then
    echo "FAIL boundary: inventory.toml did not convert to JSON" >&2
    fail=1
  fi
  if ! {
    yq -p toml -o json inventory.toml |
      toon -e |
      toon -d |
      yq -p json -o toml |
      yq -p toml -o json |
      jq -S . >"$after"
  }; then
    echo "FAIL boundary: TOML -> TOON -> TOML pipeline failed" >&2
    fail=1
  elif ! diff -q "$before" "$after" >/dev/null; then
    echo "FAIL boundary: TOML round-trip lost data (inventory.toml)" >&2
    fail=1
  fi
  rm -f "$before" "$after"
}

check_boundary
check_boundary_toml

while IFS= read -r doc; do
  [ -n "$doc" ] || continue
  if ! toon -d "$doc" >/dev/null 2>/tmp/toon-gate.err; then
    echo "FAIL $doc: strict decode refused it (repair: task dev:toon:fix FILES=$doc)" >&2
    sed -n '1,3p' /tmp/toon-gate.err >&2
    fail=1
  fi
done < <(git ls-files '*.toon')

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: TOON is the IR (lengths counted, refusals kept, YAML and TOML round-trips lossless)."
