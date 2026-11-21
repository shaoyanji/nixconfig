set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v nix-instantiate >/dev/null 2>&1 || {
  echo "quotient-hash: nix-instantiate not on PATH" >&2
  exit 2
}
command -v jq >/dev/null 2>&1 || {
  echo "quotient-hash: jq not on PATH" >&2
  exit 2
}

error_log="$(mktemp)"
trap 'rm -f "$error_log"' EXIT

if ! report="$(nix-instantiate --eval --strict --json "$here/cases.nix" 2>"$error_log")"; then
  echo "quotient-hash: the property report did not evaluate" >&2
  sed 's/^/  /' "$error_log" >&2
  exit 1
fi

if jq -e '.ok == true' >/dev/null 2>&1 <<<"$report"; then
  jq -r '
    "quotient-hash: ok — \(.stats.numbers) numbers, \(.stats.distinctRepresentations) distinct Zeckendorf sets",
    "  classic split: \(.stats.classicBuckets)/\(.stats.classicBucketSpace) buckets, max load \(.stats.classicMaxLoad), avalanche moved \(.stats.avalancheMoved)/200",
    "  zeckendorf split: \(.stats.zeckendorfClasses) classes over \(.stats.keys) keys",
    "  sample hello -> class \(.stats.sample.quotient), remainder \(.stats.sample.remainder), terms \(.stats.sample.terms|tostring), pattern \(.stats.sample.pattern)"
  ' <<<"$report"
  exit 0
fi

echo "quotient-hash: FAILED" >&2
jq -r '.failures[] | "  \(.)"' <<<"$report" >&2
exit 1
