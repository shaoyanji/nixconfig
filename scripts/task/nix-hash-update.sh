#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: nix-hash-update <config.json> [key ...]"
  echo "Updates sha256 checksums for the URLs in the given JSON config."
  echo "With keys, only those entries are fetched; the rest are left alone."
  exit 1
fi

config_file="$1"
shift
keys=("$@")

if [[ ! -f "$config_file" ]]; then
  echo "Error: File not found: $config_file"
  exit 1
fi

if [[ ${#keys[@]} -eq 0 ]]; then
  selector="."
else
  keys_json=$(printf '%s\n' "${keys[@]}" | jq -R . | jq -sc .)
  selector="map(select(.key as \$k | $keys_json | index(\$k)))"
  for key in "${keys[@]}"; do
    jq -e --arg k "$key" 'any(.[]; .key == $k)' "$config_file" >/dev/null || {
      echo "Error: no entry with key '$key' in $config_file" >&2
      exit 1
    }
  done
fi

echo "Fetching hashes..."

hashes='{}'
while IFS=$'\t' read -r key url fetchType; do
  [[ -n "$key" ]] || continue
  unpack_flag=""
  if [[ "$fetchType" == "fetchzip" ]]; then
    unpack_flag="--unpack"
  fi
  echo "  [$fetchType] $url"
  if ! hash=$(nix-prefetch-url $unpack_flag --type sha256 "$url" 2>/dev/null); then
    echo "  ERROR: failed to fetch $url" >&2
    # A named key that cannot be hashed is the whole point of the call, so it
    # fails; an unnamed sweep keeps going, as it always has.
    [[ ${#keys[@]} -eq 0 ]] || exit 1
    continue
  fi
  hashes=$(jq --arg k "$key" --arg s "sha256:$hash" '. + {($k): $s}' <<<"$hashes")
done < <(jq -r "$selector"'[] | [.key, .url, (.fetchType // "fetchurl")] | @tsv' "$config_file")

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
jq --argjson h "$hashes" 'map(if $h[.key] then .sha256 = $h[.key] else . end)' "$config_file" >"$tmp"

if cmp -s "$tmp" "$config_file"; then
  echo "Unchanged $(jq 'length' "$config_file") entries in $config_file"
else
  mv "$tmp" "$config_file"
  echo "Updated $(jq 'length' <<<"$hashes") entries in $config_file"
fi
