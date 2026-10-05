#!/usr/bin/env bash
# bw-to-cloak.sh — Convert Bitwarden JSON export to cloak TOML format
set -euo pipefail

REAL_SOURCE="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_SOURCE")" && pwd)"

# If --apply or --diff is given, pass through directly
for arg in "$@"; do
  if [ "$arg" = "--apply" ] || [ "$arg" = "--diff" ]; then
    exec "$SCRIPT_DIR/bw-cloak-sync.sh" "$@"
  fi
done

# Default: print the merged TOML format for pipelines/sops
exec "$SCRIPT_DIR/bw-cloak-sync.sh" "$@" --print
