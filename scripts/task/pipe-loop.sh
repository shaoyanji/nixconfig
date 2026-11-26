#!/usr/bin/env bash
# pipe-loop.sh — the standing lib/*.nix pipe-operator review loop, as one
# command. The gate (scripts/task/nix-style-check.sh, behind
# `task checks:nix:style`) IS the locked tier: converted classes must stay
# zero or the gate refuses. This script runs it, then lists the unlocked
# candidate classes for judgment — a survey hit is a review item, not a
# violation (index predicates and tuple destructuring are honest uses).
#
# Blast radius after any change: lib/ edits prove on
# `task checks:host HOST=<h>` (they reach host derivations); scripts/,
# tests/ and taskfiles prove on `task checks:tasks` + `task check:verify`.
# Stage by name — sibling lanes leave uncommitted work in this tree.
# Exit = the gate's exit: 0 means nothing locked regressed.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

roots=(lib modules flake hosts)

echo "== locked tier: checks:nix:style (the gate, verbatim) =="
if bash scripts/task/nix-style-check.sh; then
  gate=0
else
  gate=1
fi

survey() { # class  pattern  advice
  local name="$1" pat="$2" advice="$3" hits
  hits="$(rg -n --pcre2 "$pat" "${roots[@]}" 2>/dev/null || true)"
  echo
  echo "== survey: $name =="
  if [ -z "$hits" ]; then
    echo "  none"
  else
    echo "$hits" | sed 's/^/  /'
    echo "  -> $advice"
  fi
}

survey "attrValues |> map (mapAttrsToList?)" \
  'attrValues.{0,80}\|>\s*(builtins|lib)\.map' \
  'mapAttrsToList is the direct spelling — unless the pipe first wraps order-dependent output'

survey "map |> concatLists (concatMap?)" \
  '\|>\s*(builtins|lib)\.concatLists|(builtins|lib)\.concatLists.{0,40}map' \
  'concatMap is the one-pass spelling'

survey "elemAt flip-lambda (unapply or reuse an at-helper)" \
  '\((\w+)\s*:\s*(builtins|lib)\.elemAt\s+\1\s+\w+\s*\)' \
  'lib/gemini-portal.nix and lib/closure-graph.nix already carry `at = i: xs: ...`; a bare elemAt partial application also works'

survey "head over a filter result (findFirst?)" \
  '(builtins|lib)\.head.{0,30}\(.*filter|\|>\s*(builtins|lib)\.filter.{0,80}\|>\s*(builtins|lib)\.head' \
  'findFirst names the intent; head-of-split is canonical and exempt'

survey "listToAttrs (map {name,value}) — canonical" \
  'listToAttrs.{0,40}\(.*map|listToAttrs.{0,80}\|>\s*(builtins|lib)\.map' \
  'accepted idiom — census only, not for change'

echo
echo "== loop state =="
if [ "$gate" -eq 0 ]; then
  echo "locked tier clean; survey hits above are review items, not violations."
  echo "blast radius: lib/ -> task checks:host HOST=<h>; scripts|tests|taskfiles -> task checks:tasks + task check:verify"
else
  echo "a locked class has instances — the gate refused; fix the sites or extend the rule with a fixture case"
  exit 1
fi
