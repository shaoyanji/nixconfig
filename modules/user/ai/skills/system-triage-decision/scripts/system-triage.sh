#!/usr/bin/env bash
# Thin dispatcher: the decision engine has exactly one implementation, in the
# repo. This skill used to carry a copy, which went stale and answered for the
# repo (2026-10-23) -- every triage result was the old, non-status-aware mapping.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="${NIXCONFIG_ROOT:-$HOME/Documents/nixconfig}"

# From a checkout the relative path wins; `pwd -P` above lands in the nix store
# when the skill is materialized under ~/.agents/skills, where it cannot resolve.
ENGINE_PY="$SCRIPT_DIR/../../../../../../modules/services/systemone/engine.py"
if [ ! -f "$ENGINE_PY" ]; then
  ENGINE_PY="$REPO_ROOT/modules/services/systemone/engine.py"
fi

if [ -f "$ENGINE_PY" ]; then
  exec python3 "$ENGINE_PY" "$@"
fi

# Fleet hosts install the same file as a CLI (services.systemoneDecision).
if command -v systemone-decision >/dev/null 2>&1; then
  exec systemone-decision "$@"
fi

printf 'system-triage-decision: no engine found (looked for %s and systemone-decision)\n' "$ENGINE_PY" >&2
exit 127
