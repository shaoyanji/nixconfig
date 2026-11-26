#!/usr/bin/env bash
# intents-check.sh — the intent/capability schema gate (flake/intents.nix).
# Evaluates .#intents.gateReport: every declared kind's gate resolves to a real
# task, every capability provides declared kinds and a declared evidence floor,
# the admit() samples land their intended verdicts, and every xs source in the
# committed snapshot has a capability declaration. ACTION-verb coverage is
# reported, not gated — the field is free prose. ~3 s, eval only.
#
# With one argument, judges that file's JSON instead of evaluating — the
# fixture's seeded reports. Judgment is identical either way: ok means
# failures == [].
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

if [ $# -ge 1 ]; then
  report="$(cat "$1")"
else
  report="$(nix eval --json .#intents.gateReport 2>/dev/null)"
fi

ok="$(jq -r '.ok' <<<"$report")"
failures="$(jq -r '.failures | length' <<<"$report")"
verbs="$(jq -r '.undeclaredVerbs | length' <<<"$report")"
actors="$(jq -r '(.verbActorArtifacts // []) | length' <<<"$report")"
kindverbs="$(jq -r '(.verbKindArtifacts // []) | length' <<<"$report")"
sources="$(jq -r '.undeclaredSources | length' <<<"$report")"

if [ "$ok" = "true" ]; then
  echo "intents ok: ${failures} failures — kinds' gates resolve, capabilities declared, admit verdicts as intended, all xs sources declared (${verbs} ACTION prefixes outside the verb table after alias/actor/kind normalization: ${actors} actor tags, ${kindverbs} kind-prefixed dispatches — reported, not gated)"
else
  echo "intents FAIL (${failures} failure(s), ${sources} undeclared source(s)):" >&2
  jq -r '.failures[] | "  - \(.)"' <<<"$report" >&2
  exit 1
fi
