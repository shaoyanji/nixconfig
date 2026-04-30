#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: nix-hash-update <config.json>"
  echo "Updates sha256 checksums for all URLs in the given JSON config"
  exit 1
fi

config_file="$1"

if [[ ! -f "$config_file" ]]; then
  echo "Error: File not found: $config_file"
  exit 1
fi

# Create temp files
tmp_urls=$(mktemp)
tmp_results=$(mktemp)
tmp_json=$(mktemp)
trap "rm -f $tmp_urls $tmp_results $tmp_json" EXIT

# Normalize URL (ensure https:// prefix)
normalize_url() {
  local url="$1"
  if [[ "$url" =~ ^https?:// ]]; then
    echo "$url"
  else
    echo "https://$url"
  fi
}

# Extract and normalize URLs to temp file
echo "Extracting URLs..."
jq -r '.[].url' "$config_file" | while read -r url; do
  normalize_url "$url"
done > "$tmp_urls"

# Count URLs
url_count=$(wc -l < "$tmp_urls")
echo "Fetching hashes in parallel ($url_count URLs)..."

# Fetch hashes in parallel using background jobs
pids=()
while read -r url; do
  (
    hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null || true)
    if [[ -n "$hash" ]]; then
      echo "$url $hash" >> "$tmp_results"
    fi
  ) &
  pids+=($!)
done < "$tmp_urls"

# Wait for all background jobs
for pid in "${pids[@]}"; do
  wait "$pid" || true
done

# Build JSON from results
echo "Building JSON..."
echo "[" > "$tmp_json"
first=true
while read -r url hash; do
  if [[ -n "$hash" ]]; then
    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo "," >> "$tmp_json"
    fi
    jq -n --arg url "$url" --arg sha "sha256:$hash" '{url: $url, sha256: $sha}' >> "$tmp_json"
  fi
done < "$tmp_results"
echo "]" >> "$tmp_json"

# Pretty-print and save
jq '.' "$tmp_json" > "$config_file"

echo "Updated $(jq 'length' "$config_file") entries in $config_file"