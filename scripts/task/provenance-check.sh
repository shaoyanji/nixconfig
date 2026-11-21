#!/usr/bin/env bash
# provenance-check.sh — every tracked file belongs to a declared class.
#
# The rule table is compiled: `nix eval --json .#provenance` emits
# {classes, rules:[{class, prefixes?, files?, suffixes?}]} in match order.
# `git ls-files` is the universe; a path matching no rule fails as unclassed
# bloat — either the file has no business being tracked, or its class is not
# declared, and both are the gate's business.
#
#   provenance-check.sh          verify + class histogram
#   provenance-check.sh class P  the class one path lands in (debugging)
#
# Exit: 0 every file classed · 1 unclassed paths exist · 2 usage.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

rules_json=$(nix eval --json ".?submodules=1#provenance")

classify() { # path -> class (stdout, empty when unclassed)
  printf '%s\n' "$1" | jq -Rrn --argjson r "$rules_json" '
    input as $p | [$r.rules[] | select(
      ((.files // []) | index($p) != null)
      or ((.prefixes // []) | map(. as $x | $p | startswith($x)) | any)
      or ((.suffixes // []) | map(. as $x | $p | endswith($x)) | any)
    ) | .class][0] // empty'
}

classify_all() { # stdin paths -> stdout "class<TAB>path" for every line
  jq -Rrn --argjson r "$rules_json" '
    inputs as $p | [([$r.rules[] | select(
      ((.files // []) | index($p) != null)
      or ((.prefixes // []) | map(. as $x | $p | startswith($x)) | any)
      or ((.suffixes // []) | map(. as $x | $p | endswith($x)) | any)
    ) | .class][0] // "unclassed"), $p] | @tsv'
}

if [ "${1:-}" = "class" ]; then
  [ -n "${2:-}" ] || {
    echo "provenance: class needs a path" >&2
    exit 2
  }
  classify "$2"
  exit 0
fi
[ $# -eq 0 ] || {
  echo "provenance: usage: provenance-check.sh [class PATH]" >&2
  exit 2
}

unclassed=0
declare -A hist=()
while IFS=$'\t' read -r c p; do
  if [ "$c" = "unclassed" ]; then
    printf 'unclassed  %s\n' "$p" >&2
    unclassed=$((unclassed + 1))
  else
    hist[$c]=$((${hist[$c]:-0} + 1))
  fi
done < <(git ls-files | classify_all)

for c in "${!hist[@]}"; do
  printf '%-12s %d\n' "$c" "${hist[$c]}"
done | sort
printf '%-12s %d\n' "TOTAL" "$(git ls-files | wc -l)"

[ "$unclassed" -eq 0 ] || {
  echo "provenance: $unclassed tracked file(s) match no class — bloat or a missing rule" >&2
  exit 1
}
echo "provenance: every tracked file classed"
