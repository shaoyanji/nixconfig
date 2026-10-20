#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# Resolve the engine from the repo, not from a checkout path: the skill is
# symlinked into ~/.agents/skills, and `pwd -P` above resolves that link.
ENGINE_PY="$SCRIPT_DIR/../../../../../../modules/services/systemone/engine.py"

if [ ! -f "$ENGINE_PY" ]; then
  # Fallback to a local engine copy if this script was moved out of the repo
  ENGINE_PY="$SCRIPT_DIR/engine.py"
fi

exec python3 "$ENGINE_PY" "$@"
