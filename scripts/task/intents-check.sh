#!/usr/bin/env bash
# intents-check.sh — the intent/capability schema gate (flake/intents.nix).
# Evaluates .#intents.gateReport: every declared kind's gate resolves to a real
# task, every capability provides declared kinds and a declared evidence floor,
# the admit() samples land their intended verdicts, and every xs source in the
# committed snapshot has a capability declaration. ACTION-verb coverage is
# reported, not gated — the field is free prose. ~3 s, eval only.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

report="$(nix eval --json .#intents.gateReport 2>/dev/null)"

ok="$(jq -r '.ok' <<<"$report")"
failures="$(jq -r '.failures | length' <<<"$report")"
verbs="$(jq -r '.undeclaredVerbs | length' <<<"$report")"
sources="$(jq -r '.undeclaredSources | length' <<<"$report")"

if [ "$ok" = "true" ]; then
  echo "intents ok: ${failures} failures — kinds' gates resolve, capabilities declared, admit verdicts as intended, all xs sources declared (${verbs} ACTION prefixes observed outside the verb table — reported, not gated)"
else
  echo "intents FAIL (${failures} failure(s), ${sources} undeclared source(s)):" >&2
  jq -r '.failures[] | "  - \(.)"' <<<"$report" >&2
  exit 1
fi
