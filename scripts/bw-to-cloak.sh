#!/usr/bin/env bash
# bw-to-cloak.sh — Convert Bitwarden JSON export to cloak TOML format
#
# Reads a Bitwarden JSON export (unencrypted .json) from stdin or file,
# extracts all entries with TOTP URIs, and outputs cloak-compatible TOML.
#
# Usage:
#   bw-to-cloak.sh < bitwarden_export.json       # from stdin
#   bw-to-cloak.sh ./bitwarden_export.json        # from file
#   bw-to-cloak.sh > ~/.cloak/accounts            # pipe to cloak file
#   sops -d modules/secrets.yaml | yq '.cloak' | base64 -d | bw-to-cloak.sh   # round-trip
#
# Bitwarden export format (unencrypted JSON):
#   { "items": [{ "name": "...", "login": { "totp": "otpauth://..." }, "fields": [...] }] }
#
# Cloak TOML format:
#   [accountname]
#   key = "BASE32SECRET"
#   totp = true
#   hash_function = "SHA1"
#   [accountname.meta]
#   issuer = "..."
#
# Requires: jq

set -euo pipefail

INPUT="${1:-/dev/stdin}"

if [ ! -f "$INPUT" ] && [ "$INPUT" != "/dev/stdin" ]; then
  echo "Error: file not found: $INPUT" >&2
  echo "Usage: bw-to-cloak.sh [file]" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required (nixpkgs: jq-go)" >&2
  exit 1
fi

extract_secret() {
  local uri="$1"
  # otpauth://totp/ISSUER:ACCOUNT?secret=BASE32&issuer=ISSUER
  # otpauth://totp/ACCOUNT?secret=BASE32&issuer=ISSUER
  echo "$uri" | sed 's/.*secret=\([^&]*\).*/\1/'
}

extract_issuer() {
  local uri="$1"
  local name="$2"
  # Try query param first
  local issuer
  issuer=$(echo "$uri" | sed -n 's/.*issuer=\([^&]*\).*/\1/p')
  if [ -n "$issuer" ]; then
    echo "$issuer" | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null || echo "$issuer"
  else
    # Fallback: extract from path before colon
    local path_issuer
    path_issuer=$(echo "$uri" | sed 's|otpauth://totp/\([^:?]*\):.*|\1|')
    if [ "$path_issuer" != "$uri" ]; then
      echo "$path_issuer" | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null || echo "$path_issuer"
    else
      echo "$name"
    fi
  fi
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g' | sed 's/^-*//;s/-*$//'
}

# Parse JSON and output TOML
jq -r '.items[] | select(.login.totp != null and .login.totp != "") | {name, totp: .login.totp}' "$INPUT" | jq -c . | while IFS= read -r item; do
  name=$(echo "$item" | jq -r '.name')
  uri=$(echo "$item" | jq -r '.totp')
  slug=$(slugify "$name")

  # Extract the raw base32 secret from the otpauth URI
  secret=$(extract_secret "$uri")
  issuer=$(extract_issuer "$uri" "$name")

  if [ -z "$secret" ]; then
    echo "Warning: no secret found for '$name', skipping" >&2
    continue
  fi

  echo "[$slug]"
  echo "key = \"$secret\""
  echo "totp = true"
  echo "hash_function = \"SHA1\""
  echo ""
  echo "  [$slug.meta]"
  echo "  issuer = \"$issuer\""
  echo "  display_name = \"$name\""
  echo ""
done
