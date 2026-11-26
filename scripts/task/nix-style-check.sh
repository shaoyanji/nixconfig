#!/usr/bin/env bash
# nix-style-check.sh — the per-file alias gate. For the pure-alias set below,
# builtins.X and lib.X are literally the same function; a file spelling both
# mixes two vocabularies and reads as an unfinished unification. The
# per-file-majority sweeps (lib/*.nix, modules/, flake/) unified every file on
# 2026-11-24 — this keeps a refactor from re-introducing a minority spelling.
# grep only, ~1 s, no eval; a failure names file and function.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

fns=(attrNames attrValues catAttrs concatStringsSep elem elemAt filter
  filterAttrs "foldl'" genList getAttr hasAttr head isAttrs isList isString
  length listToAttrs mapAttrs tail throw toJSON toString)

# Roots may be overridden so a fixture can point the gate at a tree checked
# out of history (tests/nix-style/run.sh does exactly that).
if [ "$#" -gt 0 ]; then roots=("$@"); else roots=(lib modules flake hosts); fi

fail=0
# The code roots only — AGENTS.nix is generated data whose note bodies may
# name either spelling in prose, and modules/secrets is a foreign submodule.
while IFS= read -r f; do
  for fn in "${fns[@]}"; do
    if grep -qE "builtins\.$fn\b" "$f" && grep -qE "lib\.$fn\b" "$f"; then
      echo "nix-style FAIL: $f mixes builtins.$fn and lib.$fn" >&2
      fail=1
    fi
  done

  # A line that filters and then ends in `|> ...length` is `lib.count`
  # spelled the long way — 12 sites unified 2026-11-25 (763eaa83). The
  # line-end anchor is what keeps the honest controls free: `length`
  # inside a filter predicate or on a non-filter source never ends the
  # line this way.
  if grep -nE '(builtins|lib)\.filter\b.*\|>[[:space:]]*(builtins|lib)\.length[[:space:]]*;?[[:space:]]*$' "$f" | grep -q .; then
    echo "nix-style FAIL: $f pipes filter |> length — spell it lib.count" >&2
    grep -nE '(builtins|lib)\.filter\b.*\|>[[:space:]]*(builtins|lib)\.length[[:space:]]*;?[[:space:]]*$' "$f" >&2
    fail=1
  fi
done < <(find "${roots[@]}" -name '*.nix' -not -path 'modules/secrets/*')

if [ "$fail" -eq 0 ]; then
  echo "nix-style ok: no file mixes builtins./lib. spellings of the same pure alias, no filter|>length pipes"
else
  exit 1
fi
