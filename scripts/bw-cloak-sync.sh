#!/usr/bin/env bash
# scripts/bw-cloak-sync.sh — Automatic Bitwarden/Vaultwarden to Cloak TOTP sync
set -euo pipefail

REAL_SOURCE="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_SOURCE")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Run python parser
exec nix-shell -p python3 --run "python3 '$SCRIPT_DIR/bw-cloak-sync.py' $*"
