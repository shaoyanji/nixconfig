#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: nix-hash-update <config.json>"
  echo "Updates sha256 checksums for all URLs in the given JSON config."
  echo "Preserves the original JSON structure (only updates sha256 fields)."
  echo "Uses --unpack for fetchzip entries, plain fetch for fetchurl entries."
  exit 1
fi

config_file="$1"

if [[ ! -f "$config_file" ]]; then
  echo "Error: File not found: $config_file"
  exit 1
fi

tmp=$(mktemp)
trap "rm -f $tmp" EXIT

echo "Fetching hashes..."

count=0
jq -c '.[]' "$config_file" | while read -r entry; do
  url=$(echo "$entry" | jq -r '.url')
  fetchType=$(echo "$entry" | jq -r '.fetchType // "fetchurl"')
  unpack_flag=""
  if [[ "$fetchType" == "fetchzip" ]]; then
    unpack_flag="--unpack"
  fi
  echo "  [$fetchType] $url"
  hash=$(nix-prefetch-url $unpack_flag --type sha256 "$url" 2>/dev/null) || {
    echo "  ERROR: failed to fetch $url"
    continue
  }
  echo "$entry" | jq --arg sha "sha256:$hash" '.sha256 = $sha' >> "$tmp"
  echo "," >> "$tmp"
  count=$((count + 1))
done

# Remove trailing comma
sed -i '$ s/,$//' "$tmp"

result=$(printf '['; cat "$tmp"; printf ']')
echo "$result" | jq '.' > "$config_file"

echo "Updated $(jq 'length' "$config_file") entries in $config_file"
