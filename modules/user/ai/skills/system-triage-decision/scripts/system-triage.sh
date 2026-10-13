#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_PY="/Volumes/data/projects/nixconfig/modules/services/systemone/engine.py"

if [ ! -f "$ENGINE_PY" ]; then
  # Fallback to local script if outside nixconfig
  ENGINE_PY="$SCRIPT_DIR/engine.py"
fi

exec python3 "$ENGINE_PY" "$@"
